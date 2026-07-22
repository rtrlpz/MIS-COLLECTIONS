import os
import sys
from pathlib import Path
import psycopg2
import pytest
from dotenv import load_dotenv

# Register custom marks
def pytest_configure(config):
    config.addinivalue_line("markers", "slow: marks tests as slow (deselect with '-m not slow')")

# Resolve project root
ROOT_PATH = Path(__file__).resolve().parent.parent

# Load .env from project root
def _load_env():
    env_file_path = ROOT_PATH / ".env"
    load_dotenv(dotenv_path=env_file_path)
    return env_file_path

_load_env()

# DB config from environment (mirrors ETL script)
DB_CONFIG = {
    'host': os.getenv('POSTGRES_HOST', 'localhost'),
    'port': os.getenv('POSTGRES_PORT', '5433'),
    'user': os.getenv('POSTGRES_USER'),
    'password': os.getenv('POSTGRES_PASSWORD'),
    'database': os.getenv('POSTGRES_DB'),
}

# Table metadata from DDL
TABLES = [
    'dim_employees', 'dim_clients', 'dim_products',
    'dim_calendar', 'dim_accounts', 'fact_interactions', 'fact_ptp_log',
    'fact_payments', 'fact_agent_time_log', 'fact_eom_snapshot', 'fact_writeoffs'
]

PK_MAPPING = {
    'dim_employees': ['agent_id'],
    'dim_clients': ['client_id'],
    'dim_products': ['product_id'],
    'dim_calendar': ['date'],
    'dim_accounts': ['account_id'],
    'fact_interactions': ['interaction_id'],
    'fact_ptp_log': ['ptp_id'],
    'fact_payments': ['payment_id'],
    'fact_agent_time_log': ['log_id'],
    'fact_eom_snapshot': ['snapshot_date', 'account_id'],  # composite PK
    'fact_writeoffs': ['writeoff_id'],
}

FK_RELATIONSHIPS = [
    ('dim_accounts', 'client_id', 'dim_clients', 'client_id'),
    ('dim_accounts', 'product_id', 'dim_products', 'product_id'),
    ('fact_interactions', 'agent_id', 'dim_employees', 'agent_id'),
    ('fact_interactions', 'account_id', 'dim_accounts', 'account_id'),
    ('fact_interactions', 'interaction_date', 'dim_calendar', 'date'),
    ('fact_ptp_log', 'agent_id', 'dim_employees', 'agent_id'),
    ('fact_ptp_log', 'account_id', 'dim_accounts', 'account_id'),
    ('fact_ptp_log', 'ptp_date', 'dim_calendar', 'date'),
    ('fact_payments', 'account_id', 'dim_accounts', 'account_id'),
    ('fact_payments', 'payment_date', 'dim_calendar', 'date'),
    ('fact_payments', 'agent_id', 'dim_employees', 'agent_id'),  # nullable but check non-null
    ('fact_agent_time_log', 'agent_id', 'dim_employees', 'agent_id'),
    ('fact_agent_time_log', 'log_date', 'dim_calendar', 'date'),
    ('fact_eom_snapshot', 'account_id', 'dim_accounts', 'account_id'),
    ('fact_eom_snapshot', 'snapshot_date', 'dim_calendar', 'date'),
    ('fact_writeoffs', 'account_id', 'dim_accounts', 'account_id'),
    ('fact_writeoffs', 'writeoff_date', 'dim_calendar', 'date'),
]

# KPI Views and their percentage columns
KPI_VIEWS = {
    'v_contact_metrics': ['rpc_pct'],
    'v_promise_metrics': ['ptp_pct', 'kept_pct', 'bucket_conversion'],
    'v_recovery_metrics': ['cure_rate'],
    'v_productivity_metrics': ['utilization_pct'],
    'v_handle_time_metrics': [],
    'v_daily_mis': ['rpc_pct', 'ptp_pct', 'kept_pct', 'cure_rate', 'utilization_pct'],
    'v_monthly_summary': ['avg_rpc_pct', 'avg_ptp_pct', 'avg_kept_pct', 'avg_cure_rate', 'avg_utilization_pct'],
    'v_etl_load_summary': [],
    'v_data_freshness': [],
}

# Fact tables with date columns
FACT_DATE_COLUMNS = {
    'fact_interactions': 'interaction_date',
    'fact_ptp_log': 'ptp_date',
    'fact_payments': 'payment_date',
    'fact_agent_time_log': 'log_date',
    'fact_eom_snapshot': 'snapshot_date',
    'fact_writeoffs': 'writeoff_date',
}


@pytest.fixture(scope='session')
def db_connection():
    """Create a PostgreSQL connection for tests (mirrors ETL script config)."""
    conn = psycopg2.connect(**DB_CONFIG)
    conn.autocommit = True
    yield conn
    conn.close()


@pytest.fixture(scope='session')
def cursor(db_connection):
    """Create a cursor from the DB connection."""
    cur = db_connection.cursor()
    yield cur
    cur.close()


@pytest.fixture(scope='session')
def tables():
    return TABLES


@pytest.fixture(scope='session')
def pk_mapping():
    return PK_MAPPING


@pytest.fixture(scope='session')
def fk_relationships():
    return FK_RELATIONSHIPS


@pytest.fixture(scope='session')
def kpi_views():
    return KPI_VIEWS


@pytest.fixture(scope='session')
def fact_date_columns():
    return FACT_DATE_COLUMNS


@pytest.fixture(scope='session')
def root_path():
    return ROOT_PATH


# Expected row counts for generator output (seed 42, 12 months, Phase 6)
GENERATOR_ROW_COUNTS = {
    'dim_employees': 88,
    'dim_clients': 10000,
    'dim_products': 3,
    'dim_accounts': 15482,
    'dim_calendar': 396,
    'fact_interactions': 1355587,
    'fact_ptp_log': 58811,
    'fact_payments': 49419,
    'fact_agent_time_log': 20880,
    'fact_eom_snapshot': 185784,
    'fact_writeoffs': 222,
}

# Metric percentile ranges (calibrated May 2026)
METRIC_RANGES = {
    'rpc_pct': (35, 60),
    'ptp_pct': (20, 65),
    'kp_pct': (65, 90),
    'utilization_pct': (30, 60),
    'cures_per_tht': (0.08, 0.30),
    'acw_rpc_seconds': (80, 180),
}
