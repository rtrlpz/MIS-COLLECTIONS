import os
import sys
import time
import argparse
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

# --- PARSE CLI ARGUMENTS ---
parser = argparse.ArgumentParser(description="Data ingestion script for MIS Collections")
parser.add_argument(
    "--env-file", type=str, default=None,
    help="Path to .env file (default: .env in script's directory)"
)
parser.add_argument(
    "--dry-run", action="store_true",
    help="Validate CSVs and print what would be loaded without connecting to database"
)
args = parser.parse_args()

# Configure logging early
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

# Ruta RELATIVA
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


def validate_csv(file_path: Path, table_name: str) -> tuple:
    """
    Validate a CSV file before ingestion.
    Returns (is_valid, error_message).
    Checks: file exists, has headers, row count > 0, PK not null.
    For Fact_EOM_Snapshot: both snapshot_date and account_id must not be null.
    """
    if not file_path.exists():
        return False, f"File not found: {file_path}"

    try:
        df = pd.read_csv(file_path)
    except Exception as e:
        return False, f"Failed to read CSV: {e}"

    if len(df.columns) == 0 or all(col.strip() == '' for col in df.columns):
        return False, "CSV has no valid headers"

    if len(df) == 0:
        return False, "CSV has 0 rows"

    if table_name == 'Fact_EOM_Snapshot':
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


def ingest_data_to_pg(df: pd.DataFrame, table_name: str, conn):
    """Cargar un DataFrame de pandas a una tabla de PostgreSQL usando COPY_FROM"""
    pg_table_name = table_name.lower()

    logging.info(f"  -> Ingesting {pg_table_name}...")

    buffer = StringIO()
    df.to_csv(buffer, header=True, index=False, na_rep='')
    buffer.seek(0)
    buffer.readline()

    cursor = conn.cursor()

    try:
        try:
            cursor.execute(f"TRUNCATE TABLE {pg_table_name} CASCADE")
            logging.info(f"  [INFO] Truncated {pg_table_name}")
        except psycopg2.Error as te:
            logging.warning(f"  [WARN] Could not truncate {pg_table_name}: {te}")

        cursor.copy_from(
            file=buffer,
            table=pg_table_name,
            sep=',',
            columns=df.columns.tolist(),
            null=''
        )
        conn.commit()
        logging.info(f"  [OK] {pg_table_name} completed. {len(df):,} records inserted.")

    except (Exception, psycopg2.Error) as error:
        logging.error(f"  [ERROR] while ingesting {pg_table_name}: {error}")
        conn.rollback()
    finally:
        cursor.close()


def run_dry_run():
    """Run validation only mode - print what would be loaded, no DB connection."""
    all_passed = True
    total_records = 0

    logging.info("--- DRY-RUN MODE: Validating CSVs (no database connection) ---")

    for table_name in TABLE_ORDER:
        if table_name in SHARED_TABLES:
            csv_file = DATA_DIR / 'shared' / f'{table_name}.csv'
            is_valid, msg = validate_csv(csv_file, table_name)

            if is_valid:
                df = pd.read_csv(csv_file)
                logging.info(f"  [OK] {table_name}: {csv_file} ({len(df):,} rows) - would load")
                total_records += len(df)
            else:
                logging.error(f"  [FAIL] {table_name}: {msg}")
                all_passed = False
        else:
            month_dirs = [d for d in DATA_DIR.iterdir() if d.is_dir() and d.name != 'shared']
            table_records = 0
            table_found = False

            for m_dir in sorted(month_dirs):
                csv_file = m_dir / f'{table_name}.csv'
                if csv_file.exists():
                    is_valid, msg = validate_csv(csv_file, table_name)

                    if is_valid:
                        df = pd.read_csv(csv_file)
                        logging.info(f"  [OK] {table_name} [{m_dir.name}]: {csv_file} ({len(df):,} rows) - would load")
                        table_records += len(df)
                        table_found = True
                    else:
                        logging.error(f"  [FAIL] {table_name} [{m_dir.name}]: {msg}")
                        all_passed = False

            if table_found:
                logging.info(f"  {table_name}: total {table_records:,} records would be loaded")
                total_records += table_records
            elif all_passed:
                logging.error(f"  [FAIL] {table_name}: No data found in any month folders")
                all_passed = False

    logging.info("--- DRY-RUN COMPLETE ---")
    logging.info(f"Total records that would be loaded: {total_records:,}")

    if all_passed:
        logging.info("All validations passed.")
        sys.exit(0)
    else:
        logging.error("Some validations failed.")
        sys.exit(1)


def main():
    if args.env_file:
        env_file_path = Path(args.env_file).resolve()
    else:
        env_file_path = Path(__file__).resolve().parent / ".env"

    load_dotenv(dotenv_path=env_file_path)
    logging.info(f"Loaded env file: {env_file_path}")

    DB_USER = os.getenv('POSTGRES_USER')
    DB_PASSWORD = os.getenv('POSTGRES_PASSWORD')
    DB_NAME = os.getenv('POSTGRES_DB')
    DB_PORT = os.getenv('POSTGRES_PORT', '5432')
    DB_HOST = os.getenv('POSTGRES_HOST', 'localhost')

    REQUIRED_ENV_VARS = ['POSTGRES_USER', 'POSTGRES_PASSWORD', 'POSTGRES_DB']
    missing_vars = [var for var in REQUIRED_ENV_VARS if not os.getenv(var)]

    if missing_vars:
        error_msg = f"ERROR: Missing required environment variables: {', '.join(missing_vars)}"
        error_msg += f"\nEnsure {env_file_path} exists and contains these variables."
        logging.error(error_msg)
        raise ValueError(error_msg)

    DB_CONFIG = {
        'host': DB_HOST,
        'database': DB_NAME,
        'user': DB_USER,
        'password': DB_PASSWORD,
        'port': DB_PORT
    }

    if args.dry_run:
        run_dry_run()
        return

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
                csv_file = DATA_DIR / 'shared' / f'{table_name}.csv'

                is_valid, msg = validate_csv(csv_file, table_name)
                if not is_valid:
                    logging.error(f"Validation failed for {table_name}: {msg}. Skipping...")
                    continue

                df = pd.read_csv(csv_file)
                ingest_data_to_pg(df, table_name, conn)
                logging.info(f"  {table_name} processed in {time.time() - t_table:.1f} seconds")

            else:
                logging.info(f"Processing transactional table: {table_name}")
                month_dirs = [d for d in DATA_DIR.iterdir() if d.is_dir() and d.name != 'shared']

                records_found = False
                table_records = 0

                for m_dir in sorted(month_dirs):
                    csv_file = m_dir / f'{table_name}.csv'

                    if csv_file.exists():
                        is_valid, msg = validate_csv(csv_file, table_name)
                        if not is_valid:
                            logging.error(f"Validation failed for {table_name} in {m_dir.name}: {msg}. Skipping...")
                            continue

                        records_found = True
                        df_temp = pd.read_csv(csv_file)
                        table_records += len(df_temp)

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
