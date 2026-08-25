import os
import shutil
import subprocess
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
    'fact_payments', 'fact_agent_time_log', 'fact_eom_snapshot', 'fact_writeoffs',
    # P2/P3 additions
    'dim_delinquency_bucket', 'dim_strategy', 'dim_employee_history',
    'fact_recoveries'
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
    # P2/P3 additions
    'dim_delinquency_bucket': ['bucket_key'],
    'dim_strategy': ['strategy_id'],
    'dim_employee_history': ['hist_id'],
    'fact_recoveries': ['recovery_id'],
}

FK_RELATIONSHIPS = [
    ('dim_accounts', 'client_id', 'dim_clients', 'client_id'),
    ('dim_accounts', 'product_id', 'dim_products', 'product_id'),
    ('fact_interactions', 'agent_id', 'dim_employees', 'agent_id'),
    ('fact_interactions', 'account_id', 'dim_accounts', 'account_id'),
    ('fact_interactions', 'interaction_date', 'dim_calendar', 'date'),
    ('fact_interactions', 'strategy_id', 'dim_strategy', 'strategy_id'),          # I5 (P3)
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
    ('fact_eom_snapshot', 'bucket_key', 'dim_delinquency_bucket', 'bucket_key'),  # I2 (P2)
    ('fact_writeoffs', 'account_id', 'dim_accounts', 'account_id'),
    ('fact_writeoffs', 'writeoff_date', 'dim_calendar', 'date'),
    ('dim_employee_history', 'agent_id', 'dim_employees', 'agent_id'),            # I4 (P3)
    ('fact_recoveries', 'account_id', 'dim_accounts', 'account_id'),              # N4 (P4)
    ('fact_recoveries', 'recovery_date', 'dim_calendar', 'date'),                 # N4 (P4)
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
    'v_promise_timeline': [],
    'v_monthend_portfolio': ['mora_pct'],
    'v_writeoff_recovery': ['recovery_pct'],
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
# Regenerated baseline (P3/P4 engine, seed 42, Aug 2026): equilibrium
# replenishment + seasonality + strategy arms + installment plans.
GENERATOR_ROW_COUNTS = {
    'dim_employees': 88,
    'dim_clients': 10000,
    'dim_products': 3,
    'dim_accounts': 15480,
    'dim_calendar': 486,
    'fact_interactions': 1338499,
    'fact_ptp_log': 106226,
    'fact_payments': 120874,
    'fact_agent_time_log': 20880,
    'fact_eom_snapshot': 182968,
    'fact_writeoffs': 441,
    'fact_recoveries': 323,
}

# Metric percentile ranges (calibrated May 2026, refreshed against 12-month DB Aug 2026)
METRIC_RANGES = {
    'rpc_pct': (35, 60),
    'ptp_pct': (5, 40),
    'kp_pct': (60, 90),
    'utilization_pct': (30, 60),
    'cures_per_tht': (0.02, 0.20),
    'acw_rpc_seconds': (80, 180),
}

# ---------------------------------------------------------------------------
# Hybrid C test-data strategy
# ---------------------------------------------------------------------------
# Fast tests share ONE session-scoped reduced-scale generation (--months 1,2,3,
# seed 42). Heavy gates remain slow-marked: canonical 12-month baseline
# validation and seed reproducibility (test_generator.py), ETL idempotency
# (test_qa_validation.py).
TEST_MONTHS = "1,2,3"

# Measured at seed 42 / Jan–Mar 2025 (P3/P4 engine, Aug 2026)
GENERATOR_ROW_COUNTS_SMALL = {
    # Deterministic dimensions (exact for any --months value)
    'dim_employees': 88,
    'dim_clients': 10000,
    'dim_products': 3,
    # Calendar spans one month before START through END+90d:
    # Dec-2024 → Jun-2025 for --months 1,2,3 = 211 rows
    'dim_calendar': 211,
    # Seed-stable dimension (matches the 12-month baseline exactly)
    'dim_accounts': 15480,
    # Facts (±15% guard in tests; deterministic at fixed seed but kept defensive)
    'fact_interactions': 304902,
    'fact_ptp_log': 30864,
    'fact_payments': 35167,
    'fact_agent_time_log': 5120,
    'fact_eom_snapshot': 46259,
    'fact_writeoffs': 149,
    'fact_recoveries': 29,   # sparse early: jan=0 is legitimate (header-only CSV)
}


@pytest.fixture(scope='session')
def small_generated_data():
    """Run the generator ONCE per session at reduced scale (Jan–Mar 2025).

    All structural/invariant/reproducibility tests read from this output.
    Teardown removes the directory; .gitignore covers crash leftovers.
    """
    out_dir = ROOT_PATH / 'data_sources' / 'raw_test_session'
    if out_dir.exists():
        shutil.rmtree(out_dir)
    result = subprocess.run(
        [sys.executable, str(ROOT_PATH / 'data_sources' / 'data_generator_v7.py'),
         '--seed', '42', '--months', TEST_MONTHS, '--output-dir', str(out_dir)],
        capture_output=True, text=True, timeout=600, cwd=str(ROOT_PATH),
    )
    assert result.returncode == 0, f"Generator failed:\n{result.stderr[-3000:]}"
    yield out_dir
    shutil.rmtree(out_dir, ignore_errors=True)
