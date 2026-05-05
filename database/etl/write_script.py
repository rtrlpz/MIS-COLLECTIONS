import textwrap

content = """
import os
import sys
import time
import hashlib
import argparse
import logging
from io import StringIO
from pathlib import Path

import pandas as pd
import psycopg2
from dotenv import load_dotenv

# Script de Ingesta V2 - Adaptado para carpetas mensuales (Shared vs Transaccional)
# Antes de correr este script, asegurse que la base de datos y sus tablas han sido creadas.

# --- PARSE CLI ARGUMENTS ---
parser = argparse.ArgumentParser(description="Data ingestion script for MIS Collections")
parser.add_argument("--env-file", type=str, default=None, help="Path to .env file")
parser.add_argument("--dry-run", action="store_true", help="Validate CSVs without DB connection")
parser.add_argument("--incremental", action="store_true", help="Skip already-loaded months")
args = parser.parse_args()

# Configure logging
LOG_DIR = Path(__file__).resolve().parent / "logs"
LOG_DIR.mkdir(exist_ok=True)
LOG_FILE = LOG_DIR / "logs"

logging.basicConfig(
    level=logging.INFO,
    format='[%(levelname)s] %(asctime)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S',
    handlers=[logging.FileHandler(LOG_FILE), logging.StreamHandler()]
)

# Paths
ROOT_PATH = Path(__file__).resolve().parent.parent.parent
DATA_DIR = ROOT_PATH / "data_sources" / "generators" / "raw"

# Table definitions
SHARED_TABLES = ['Dim_Supervisors', 'Dim_Agents', 'Dim_Calendar', 'Dim_Clients', 'Dim_Products', 'Dim_Accounts']
TRANSACTIONAL_TABLES = ['Fact_Payments', 'Fact_EOM_Snapshot', 'Fact_Interactions', 'Fact_Agent_Time_Log', 'Fact_PTP_Log']
TABLE_ORDER = SHARED_TABLES + TRANSACTIONAL_TABLES

PK_MAPPING = {
    'Dim_Supervisors': 'supervisor_id', 'Dim_Agents': 'agent_id',
    'Dim_Clients': 'client_id', 'Dim_Products': 'product_id',
    'Dim_Accounts': 'account_id', 'Fact_Interactions': 'interaction_id',
    'Fact_PTP_Log': 'ptp_id', 'Fact_Payments': 'payment_id',
    'Fact_Agent_Time_Log': 'log_id',
}

def validate_csv(file_path: Path, table_name: str) -> tuple:
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
        for col in ['snapshot_date', 'account_id']:
            if col in df.columns and df[col].isna().any():
                return False, f"{col} has {df[col].isna().sum()} null values"
    else:
        pk_col = PK_MAPPING.get(table_name)
        if pk_col and pk_col in df.columns:
            if df[pk_col].isna().any():
                return False, f"Primary key '{pk_col}' has {df[pk_col].isna().sum()} null values"
        elif pk_col:
            return False, f"Primary key column '{pk_col}' not found in CSV"
    return True, "Validation passed"

def compute_checksum(file_path: Path) -> str:
    sha256_hash = hashlib.sha256()
    try:
        with open(file_path, "rb") as f:
            for byte_block in iter(lambda: f.read(4096), b"")):
                sha256_hash.update(byte_block)
        return sha256_hash.hexdigest()
    except Exception as e:
        logging.error(f"Failed to compute checksum: {e}")
        return ""

def create_etl_load_log_table(conn):
    cursor = conn.cursor()
    try:
        cursor.execute("
                CREATE TABLE IF NOT EXISTS etl_load_log (
                id SERIAL PRIMARY KEY,
                table_name VARCHAR(100),
                rows_loaded INT,
                loaded_at TIMESTAMP DEFAULT NOW(),
                status VARCHAR(20),
                csv_checksum VARCHAR(64)
            )
        ")
        conn.commit()
        logging.info("  [INFO] Ensured etl_load_log table exists")
    except Exception as e:
        logging.error(f"Failed to create etl_load_log: {e}")
    finally:
        cursor.close()

def log_etl_load(table_name: str, rows_loaded: int, status: str, checksum: str, conn):
    cursor = conn.cursor()
    try:
        cursor.execute(
            "INSERT INTO etl_load_log (table_name, rows_loaded, status, csv_checksum) VALUES (%s, %s, %s, %s)",
            (table_name, rows_loaded, status, checksum)
        )
        conn.commit()
    except Exception as e:
        logging.error(f"Failed to log ETL load: {e}")
    finally:
        cursor.close()

def ingest_data_to_pg(df: pd.DataFrame, table_name: str, conn):
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
            logging.warning(f"  [WARN] Could not truncate: {te}")
        cursor.copy_from(file=buffer, table=pg_table_name, sep=',', columns=df.columns.tolist(), null='')
        conn.commit()
        logging.info(f"  [OK] {pg_table_name}: {len(df):,} records inserted.")
        return True, len(df)
    except Exception as e:
        logging.error(f"  [ERROR] Ingesting {pg_table_name}: {e}")
        conn.rollback()
        return False, 0
    finally:
        cursor.close()

def run_dry_run():
    all_passed = True
    total_records = 0
    logging.info("--- DRY-RUN MODE: Validating CSVs (no database connection) ---")
    for table_name in TABLE_ORDER:
        if table_name in SHARED_TABLES:
            csv_file = DATA_DIR / 'shared' / f'{table_name}.csv'
            is_valid, msg = validate_csv(csv_file, table_name)
            if is_valid:
                df = pd.read_csv(csv_file)
                logging.info(f"  [OK] {table_name}: {len(df):,} rows - would load")
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
                        logging.info(f"  [OK] {table_name} [{m_dir.name}]: {len(df):,} rows - would load")
                        table_records += len(df)
                        table_found = True
                    else:
                        logging.error(f"  [FAIL] {table_name} [{m_dir.name}]: {msg}")
                        all_passed = False
            if table_found:
                logging.info(f"  {table_name}: total {table_records:,} records would be loaded")
                total_records += table_records
            elif all_passed:
                logging.error(f"  [FAIL] {table_name}: No data found")
                all_passed = False
    logging.info("--- DRY-RUN COMPLETE ---")
    logging.info(f"Total records that would be loaded: {total_records:,}")
    sys.exit(0 if all_passed else 1)

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

    if not all([DB_USER, DB_PASSWORD, DB_NAME]):
        logging.error("ERROR: Missing required environment variables")
        sys.exit(1)

    DB_CONFIG = {'host': DB_HOST, 'database': DB_NAME, 'user': DB_USER, 'password': DB_PASSWORD, 'port': DB_PORT}

    if args.dry_run:
        run_dry_run()
        return

    conn = None
    t_start = time.time()
    existing_months = set()

    try:
        # Retry logic for database connection (up to 3 attempts)
        for attempt in range(3):
            try:
                logging.info(f"Trying to connect to PostgreSQL... (attempt {attempt + 1}/3)")
                conn = psycopg2.connect(**DB_CONFIG)
                logging.info("Connected to PostgreSQL")
                break
            except psycopg2.OperationalError as e:
                logging.warning(f"  [WARN] Connection attempt {attempt + 1} failed: {e}")
                if attempt < 2:
                    logging.info("  Waiting 5 seconds before retrying...")
                    time.sleep(5)
                else:
                    logging.error("FATAL: Failed to connect to database after 3 attempts.")
                    sys.exit(1)

        create_etl_load_log_table(conn)

        if args.incremental:
            try:
                cursor = conn.cursor()
                cursor.execute("SELECT DISTINCT EXTRACT(MONTH FROM interaction_date)::int FROM fact_interactions")
                results = cursor.fetchall()
                existing_months = {row[0] for row in results if row[0] is not None}
                cursor.close()
                logging.info(f"  [INFO] Incremental mode: existing months: {sorted(existing_months)}")
            except Exception as e:
                logging.warning(f"  [WARN] Could not query existing months: {e}")
                existing_months = set()

        logging.info("--- STARTING INGESTION ---")

        for table_name in TABLE_ORDER:
            t_table = time.time()
            if table_name in SHARED_TABLES:
                csv_file = DATA_DIR / 'shared' / f'{table_name}.csv'
                is_valid, msg = validate_csv(csv_file, table_name)
                if not is_valid:
                    logging.error(f"Validation failed for {table_name}: {msg}. Skipping...")
                    checksum = compute_checksum(csv_file) if csv_file.exists() else ""
                    log_etl_load(table_name.lower(), 0, 'FAILED', checksum, conn)
                    continue
                df = pd.read_csv(csv_file)
                checksum = compute_checksum(csv_file)
                success, rows = ingest_data_to_pg(df, table_name, conn)
                log_etl_load(table_name.lower(), rows, 'SUCCESS' if success else 'FAILED', checksum, conn)
                logging.info(f"  {table_name} processed in {time.time() - t_table:.1f}s")
            else:
                logging.info(f"Processing transactional table: {table_name}")
                month_dirs = [d for d in DATA_DIR.iterdir() if d.is_dir() and d.name != 'shared']
                records_found = False
                table_records = 0
                months_skipped = []
                for m_dir in sorted(month_dirs):
                    if args.incremental and m_dir.name.isdigit():
                        month_num = int(m_dir.name)
                        if month_num in existing_months:
                            months_skipped.append(m_dir.name)
                            continue
                    csv_file = m_dir / f'{table_name}.csv'
                    if csv_file.exists():
                        is_valid, msg = validate_csv(csv_file, table_name)
                        if not is_valid:
                            logging.error(f"Validation failed for {table_name} in {m_dir.name}: {msg}")
                            checksum = compute_checksum(csv_file)
                            log_etl_load(table_name.lower(), 0, 'FAILED', checksum, conn)
                            continue
                        records_found = True
                        df_temp = pd.read_csv(csv_file)
                        table_records += len(df_temp)
                        if 'rpc_flag' in df_temp.columns:
                            df_temp['rpc_flag'] = df_temp['rpc_flag'].astype(str).str.lower()
                        if not df_temp.empty:
                            logging.info(f"     Loading month: {m_dir.name}...")
                            checksum = compute_checksum(csv_file)
                            success, rows = ingest_data_to_pg(df_temp, table_name, conn)
                            log_etl_load(table_name.lower(), rows, 'SUCCESS' if success else 'FAILED', checksum, conn)
                if months_skipped:
                    logging.info(f"  [INFO] Skipped months: {', '.join(sorted(months_skipped))}")
                if not records_found:
                    logging.error(f"No data found for {table_name}")
                else:
                    logging.info(f"  {table_name}: {table_records:,} records in {time.time() - t_table:.1f}s")

        logging.info("--- INGESTION COMPLETE ---")
        logging.info(f"Total elapsed time: {time.time() - t_start:.1f}s")

    except Exception as e:
        logging.error(f"Unexpected error: {e}")
    finally:
        if conn:
            conn.close()
            logging.info("Connection closed.")

if __name__ == '__main__':
    main()
"""

with open('data_to_pg.py', 'w', encoding='utf-8') as f:
    f.write(textwrap.dedent(content).strip() + '\n')
print('data_to_pg.py written successfully')
