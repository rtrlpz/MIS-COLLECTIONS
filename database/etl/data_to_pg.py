import os
import time
import logging
from io import StringIO
from pathlib import Path

import pandas as pd
import psycopg2
from dotenv import load_dotenv

"""
Script de Ingesta V2 - Adaptado para carpetas mensuales (Shared vs Transaccional)
Antes de correr este script, asegurarse que la base de datos y sus tablas han sido creadas.
"""

LOG_DIR = Path(__file__).resolve().parent / "logs"
LOG_DIR.mkdir(exist_ok=True)
LOG_FILE = LOG_DIR / "logs"

logging.basicConfig(
    level=logging.INFO,
    format='[%(levelname)s] %(asctime)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)

# Agrega esta línea para que Python lea el archivo .env
load_dotenv()

# Obtenemos las variables. Si no existen en él .env, retornarán None.
DB_USER = os.getenv('POSTGRES_USER')
DB_PASSWORD = os.getenv('POSTGRES_PASSWORD')
DB_NAME = os.getenv('POSTGRES_DB')
DB_PORT = os.getenv('POSTGRES_PORT', '5432')  # Asegúrate que coincida con tu Docker
DB_HOST = os.getenv('POSTGRES_HOST', 'localhost')

# Validación de seguridad
if not all([DB_USER, DB_PASSWORD, DB_NAME]):
    raise ValueError(
        "ERROR: Faltan credenciales. Asegúrate de que el archivo .env existe y contiene POSTGRES_USER, POSTGRES_PASSWORD y POSTGRES_DB.")

# --- 1. CONFIGURACIÓN DE CONEXIÓN A DB Y DATOS ---#
DB_CONFIG = {
    'host': DB_HOST,
    'database': DB_NAME,
    'user': DB_USER,
    'password': DB_PASSWORD,
    'port': DB_PORT
}

# Ruta RELATIVA
# Sube tres niveles desde database/etl/ para llegar a la raíz del proyecto
ROOT_PATH = Path(__file__).resolve().parent.parent.parent
DATA_DIR = ROOT_PATH / "data_sources" / "generators" / "raw"

# Separamos lógicamente las tablas estáticas de las transaccionales
SHARED_TABLES = [
    'Dim_Supervisors',
    'Dim_Agents',
    'Dim_Calendar',
    'Dim_Clients',
    'Dim_Products',
    'Dim_Accounts'
]

TRANSACTIONAL_TABLES = [
    'Fact_Payments',
    'Fact_EOM_Snapshot',
    'Fact_Interactions',
    'Fact_Agent_Time_Log',
    'Fact_PTP_Log'
]

# Mantenemos el orden de ingesta para respetar las dependencias de Foreign Keys
TABLE_ORDER = SHARED_TABLES + TRANSACTIONAL_TABLES

# Mapeo de Primary Keys por tabla
PK_MAPPING = {
    'Dim_Supervisors': 'supervisor_id',
    'Dim_Agents': 'agent_id',
    'Dim_Clients': 'client_id',
    'Dim_Products': 'product_id',
    'Dim_Accounts': 'account_id',
    'Fact_Interactions': 'interaction_id',
    'Fact_PTP_Log': 'ptp_id',
    'Fact_Payments': 'payment_id',
    'Fact_Agent_Time_Log': 'log_id',
}


def validate_csv(file_path: Path, table_name: str) -> tuple[bool, str]:
    """
    Validate a CSV file before ingestion.
    Returns (is_valid, error_message).
    Checks:
      1. File exists
      2. Has headers (not empty)
      3. Row count > 0
      4. Primary key column has no null values
         For Fact_EOM_Snapshot: both snapshot_date and account_id must not be null
    """
    # 1. File exists
    if not file_path.exists():
        return False, f"File not found: {file_path}"

    try:
        df = pd.read_csv(file_path)
    except Exception as e:
        return False, f"Failed to read CSV: {e}"

    # 2. Has headers (check if columns are not empty)
    if len(df.columns) == 0 or all(col.strip() == '' for col in df.columns):
        return False, "CSV has no valid headers"

    # 3. Row count > 0
    if len(df) == 0:
        return False, "CSV has 0 rows"

    # 4. Primary key / required columns null check
    if table_name == 'Fact_EOM_Snapshot':
        # Special case: validate both snapshot_date and account_id
        if 'snapshot_date' in df.columns and df['snapshot_date'].isna().any():
            null_count = df['snapshot_date'].isna().sum()
            return False, f"snapshot_date has {null_count} null values"
        if 'account_id' in df.columns and df['account_id'].isna().any():
            null_count = df['account_id'].isna().sum()
            return False, f"account_id has {null_count} null values"
    else:
        pk_col = PK_MAPPING.get(table_name)
        if pk_col and pk_col in df.columns:
            if df[pk_col].isna().any():
                null_count = df[pk_col].isna().sum()
                return False, f"Primary key '{pk_col}' has {null_count} null values"
        elif pk_col:
            return False, f"Primary key column '{pk_col}' not found in CSV"

    return True, "Validation passed"


# --- 2. FUNCIÓN PARA LA INGESTA ---
def ingest_data_to_pg(df: pd.DataFrame, table_name: str, conn):
    """ Cargar un DataFrame de pandas a una tabla de PostgreSQL usando COPY_FROM """
    # Convertimos el nombre a minúsculas para que coincida exactamente con PostgreSQL
    pg_table_name = table_name.lower()

    logging.info(f"  -> Ingesting {pg_table_name}...")

    buffer = StringIO()
    # Usamos na_rep='' para asegurar que los nulos de pandas se pasen limpios a Postgres
    df.to_csv(buffer, header=True, index=False, na_rep='')
    buffer.seek(0)
    buffer.readline()  # Salta el header

    cursor = conn.cursor()

    try:
        # Truncate table before loading (ensures clean slate for re-runs)
        try:
            cursor.execute(f"TRUNCATE TABLE {pg_table_name} CASCADE")
            logging.info(f"  [INFO] Truncated {pg_table_name}")
        except psycopg2.Error as te:
            # Table may not exist yet; log warning and continue
            logging.warning(f"  [WARN] Could not truncate {pg_table_name}: {te}")

        cursor.copy_from(
            file=buffer,
            table=pg_table_name,  # Usamos el nombre en minúsculas aquí
            sep=',',
            columns=df.columns.tolist(),
            null=''  # Le dice a Postgres que los strings vacíos son NULL
        )
        conn.commit()
        logging.info(f"  [OK] {pg_table_name} completed. {len(df):,} records inserted.")

    except (Exception, psycopg2.Error) as error:
        logging.error(f"  [ERROR] while ingesting {pg_table_name}: {error}")
        conn.rollback()
    finally:
        cursor.close()


# --- 3. PROCESO PRINCIPAL ---
def main():
    conn = None
    t_start = time.time()

    try:
        logging.info("Trying to connect to PostgreSQL...")
        conn = psycopg2.connect(**DB_CONFIG)
        logging.info("Connected to PostgreSQL")

        logging.info("--- STARTING INGESTION ---")

        for table_name in TABLE_ORDER:
            t_table = time.time()

            if table_name in SHARED_TABLES:
                # 1. Tablas compartidas (Buscamos en la carpeta /shared/)
                csv_file = DATA_DIR / 'shared' / f'{table_name}.csv'

                is_valid, msg = validate_csv(csv_file, table_name)
                if not is_valid:
                    logging.error(f"Validation failed for {table_name}: {msg}. Skipping...")
                    continue

                df = pd.read_csv(csv_file)

                # IMPORTANTE: Se eliminó el bloque legacy "if table_name == 'agents'"

                ingest_data_to_pg(df, table_name, conn)
                logging.info(f"  {table_name} processed in {time.time() - t_table:.1f} seconds")

            else:
                # 2. Tablas Transaccionales (Optimizadas para cargar mes a mes sin colapsar la RAM)
                logging.info(f"Processing transactional table: {table_name}")
                month_dirs = [d for d in DATA_DIR.iterdir() if d.is_dir() and d.name != 'shared']

                records_found = False
                table_records = 0

                for m_dir in sorted(month_dirs):  # Sorted para que entre en orden cronológico
                    csv_file = m_dir / f'{table_name}.csv'

                    if csv_file.exists():
                        is_valid, msg = validate_csv(csv_file, table_name)
                        if not is_valid:
                            logging.error(f"Validation failed for {table_name} in {m_dir.name}: {msg}. Skipping...")
                            continue

                        records_found = True
                        df_temp = pd.read_csv(csv_file)
                        table_records += len(df_temp)

                        # Limpieza específica de datos
                        if 'rpc_flag' in df_temp.columns:
                            df_temp['rpc_flag'] = df_temp['rpc_flag'].astype(str).str.lower()

                        if not df_temp.empty:
                            logging.info(f"     Loading month: {m_dir.name}...")
                            ingest_data_to_pg(df_temp, table_name, conn)

                if not records_found:
                    logging.error(f"No data found for {table_name} in any month folders.")
                else:
                    logging.info(f"  {table_name} processed {table_records:,} records in {time.time() - t_table:.1f} seconds")

        logging.info("--- INGESTION COMPLETE ---")
        logging.info(f"Total elapsed time: {time.time() - t_start:.1f} seconds")

    except psycopg2.OperationalError as e:
        logging.error(f"FATAL: No se pudo conectar a la base de datos. Error: {e}")
    except Exception as e:
        logging.error(f"Ocurrió un error inesperado: {e}")
    finally:
        if conn:
            conn.close()
            logging.info("Connection closed.")


if __name__ == '__main__':
    main()
