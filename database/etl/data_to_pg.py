import os
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
    try:
        logging.info("Trying to connect to PostgreSQL...")
        conn = psycopg2.connect(**DB_CONFIG)
        logging.info("Connected to PostgreSQL")

        logging.info("--- STARTING INGESTION ---")

        for table_name in TABLE_ORDER:

            if table_name in SHARED_TABLES:
                # 1. Tablas compartidas (Buscamos en la carpeta /shared/)
                csv_file = DATA_DIR / 'shared' / f'{table_name}.csv'

                if not csv_file.exists():
                    logging.error(f"File {csv_file} not found. Skipping...")
                    continue

                df = pd.read_csv(csv_file)

                # IMPORTANTE: Se eliminó el bloque legacy "if table_name == 'agents'"

                ingest_data_to_pg(df, table_name, conn)

            else:
                # 2. Tablas Transaccionales (Optimizadas para cargar mes a mes sin colapsar la RAM)
                logging.info(f"Processing transactional table: {table_name}")
                month_dirs = [d for d in DATA_DIR.iterdir() if d.is_dir() and d.name != 'shared']

                records_found = False

                for m_dir in sorted(month_dirs):  # Sorted para que entre en orden cronológico
                    csv_file = m_dir / f'{table_name}.csv'

                    if csv_file.exists():
                        records_found = True
                        df_temp = pd.read_csv(csv_file)

                        # Limpieza específica de datos
                        if 'rpc_flag' in df_temp.columns:
                            df_temp['rpc_flag'] = df_temp['rpc_flag'].astype(str).str.lower()

                        if not df_temp.empty:
                            logging.info(f"     Loading month: {m_dir.name}...")
                            ingest_data_to_pg(df_temp, table_name, conn)

                if not records_found:
                    logging.error(f"No data found for {table_name} in any month folders.")

        logging.info("--- INGESTION COMPLETE ---")

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
