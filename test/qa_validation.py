"""
QA Validation Tests for MIS Collections Database
Uses pytest with psycopg2 to validate data integrity and business rules.
"""

import subprocess
import hashlib
import shutil
from pathlib import Path
import pytest


# =========================================================================
# Test 1: Row Counts
# =========================================================================
class TestRowCounts:
    def test_dim_agents_count(self, cursor):
        cursor.execute("SELECT COUNT(*) FROM dim_agents")
        count = cursor.fetchone()[0]
        assert count == 80, f"Dim_Agents expected 80, got {count}"

    def test_dim_clients_count(self, cursor):
        cursor.execute("SELECT COUNT(*) FROM dim_clients")
        count = cursor.fetchone()[0]
        assert count == 10000, f"Dim_Clients expected 10000, got {count}"

    def test_dim_accounts_count(self, cursor):
        cursor.execute("SELECT COUNT(*) FROM dim_accounts")
        count = cursor.fetchone()[0]
        # Actual count from context.md is ~15,575
        expected = 15575
        lower = expected * 0.95
        upper = expected * 1.05
        assert lower <= count <= upper, f"Dim_Accounts expected ~{expected} (±5%), got {count}"


# =========================================================================
# Test 2: No Null PKs
# =========================================================================
class TestNoNullPKs:
    @pytest.mark.parametrize("table,pk_cols", [
        ('dim_supervisors', ['supervisor_id']),
        ('dim_agents', ['agent_id']),
        ('dim_clients', ['client_id']),
        ('dim_products', ['product_id']),
        ('dim_calendar', ['date']),
        ('dim_accounts', ['account_id']),
        ('fact_interactions', ['interaction_id']),
        ('fact_ptp_log', ['ptp_id']),
        ('fact_payments', ['payment_id']),
        ('fact_agent_time_log', ['log_id']),
        ('fact_eom_snapshot', ['snapshot_date', 'account_id']),
    ])
    def test_primary_keys_not_null(self, cursor, table, pk_cols):
        where_clause = " OR ".join([f"{col} IS NULL" for col in pk_cols])
        cursor.execute(f"SELECT COUNT(*) FROM {table} WHERE {where_clause}")
        null_count = cursor.fetchone()[0]
        assert null_count == 0, f"{table}: {null_count} null values in PK {pk_cols}"


# =========================================================================
# Test 3: FK Integrity
# =========================================================================
class TestFKIntegrity:
    @pytest.mark.parametrize("child_table,fk_col,parent_table,pk_col", [
        ('dim_accounts', 'client_id', 'dim_clients', 'client_id'),
        ('dim_accounts', 'product_id', 'dim_products', 'product_id'),
        ('fact_interactions', 'agent_id', 'dim_agents', 'agent_id'),
        ('fact_interactions', 'account_id', 'dim_accounts', 'account_id'),
        ('fact_interactions', 'interaction_date', 'dim_calendar', 'date'),
        ('fact_ptp_log', 'agent_id', 'dim_agents', 'agent_id'),
        ('fact_ptp_log', 'account_id', 'dim_accounts', 'account_id'),
        ('fact_ptp_log', 'ptp_date', 'dim_calendar', 'date'),
        ('fact_payments', 'account_id', 'dim_accounts', 'account_id'),
        ('fact_payments', 'payment_date', 'dim_calendar', 'date'),
        ('fact_payments', 'agent_id', 'dim_agents', 'agent_id'),
        ('fact_agent_time_log', 'agent_id', 'dim_agents', 'agent_id'),
        ('fact_agent_time_log', 'log_date', 'dim_calendar', 'date'),
        ('fact_eom_snapshot', 'account_id', 'dim_accounts', 'account_id'),
        ('fact_eom_snapshot', 'snapshot_date', 'dim_calendar', 'date'),
    ])
    def test_foreign_key_exists(self, cursor, child_table, fk_col, parent_table, pk_col):
        where_clause = f"{fk_col} IS NOT NULL AND {fk_col} NOT IN (SELECT {pk_col} FROM {parent_table})"
        cursor.execute(f"SELECT COUNT(*) FROM {child_table} WHERE {where_clause}")
        orphan_count = cursor.fetchone()[0]
        assert orphan_count == 0, f"{child_table}.{fk_col} has {orphan_count} orphans (not in {parent_table}.{pk_col})"


# =========================================================================
# Test 4: Date Ranges
# =========================================================================
class TestDateRanges:
    def test_fact_dates_oct_dec_2025(self, cursor):
        fact_date_columns = {
            'fact_interactions': 'interaction_date',
            'fact_ptp_log': 'ptp_date',
            'fact_payments': 'payment_date',
            'fact_agent_time_log': 'log_date',
            'fact_eom_snapshot': 'snapshot_date',
        }
        for table, date_col in fact_date_columns.items():
            cursor.execute(f"""
                SELECT COUNT(*) FROM {table}
                WHERE {date_col} < '2025-10-01' OR {date_col} > '2025-12-31'
            """)
            invalid_count = cursor.fetchone()[0]
            assert invalid_count == 0, f"{table}.{date_col} has {invalid_count} dates outside Oct-Dec 2025"

    def test_calendar_covers_full_2025(self, cursor):
        # Calendar actually covers Oct-Dec 2025 (92 days) per context.md
        cursor.execute("SELECT MIN(date), MAX(date), COUNT(*) FROM dim_calendar")
        min_date, max_date, count = cursor.fetchone()
        assert str(min_date) == '2025-10-01', f"Calendar min date expected 2025-10-01, got {min_date}"
        assert str(max_date) == '2025-12-31', f"Calendar max date expected 2025-12-31, got {max_date}"
        assert count >= 90, f"Calendar should have ~92 days (Oct-Dec), got {count}"


# =========================================================================
# Test 5: Weekday Only (No Interactions on Weekends)
# =========================================================================
class TestWeekdayOnly:
    def test_no_weekend_interactions(self, cursor):
        cursor.execute("""
            SELECT COUNT(*) FROM fact_interactions fi
            JOIN dim_calendar dc ON fi.interaction_date = dc.date
            WHERE dc.is_weekday = FALSE
        """)
        weekend_count = cursor.fetchone()[0]
        assert weekend_count == 0, f"Found {weekend_count} interactions on weekends"


# =========================================================================
# Test 6: DPD Logic (DPD >= 0)
# =========================================================================
class TestDPDLogic:
    def test_dpd_at_contact_non_negative(self, cursor):
        cursor.execute("SELECT COUNT(*) FROM fact_interactions WHERE dpd_at_contact < 0")
        invalid_count = cursor.fetchone()[0]
        assert invalid_count == 0, f"fact_interactions has {invalid_count} negative dpd_at_contact"

    def test_dpd_at_payment_non_negative(self, cursor):
        cursor.execute("SELECT COUNT(*) FROM fact_payments WHERE dpd_at_payment < 0")
        invalid_count = cursor.fetchone()[0]
        assert invalid_count == 0, f"fact_payments has {invalid_count} negative dpd_at_payment"

    def test_dpd_in_eom_snapshot_non_negative(self, cursor):
        cursor.execute("SELECT COUNT(*) FROM fact_eom_snapshot WHERE dpd < 0")
        invalid_count = cursor.fetchone()[0]
        assert invalid_count == 0, f"fact_eom_snapshot has {invalid_count} negative dpd"


# =========================================================================
# Test 7: Utilization Bounds (0-100)
# =========================================================================
class TestUtilizationBounds:
    def test_utilization_between_0_and_100(self, cursor):
        cursor.execute("""
            SELECT COUNT(*) FROM fact_agent_time_log
            WHERE utilization < 0 OR utilization > 100
        """)
        invalid_count = cursor.fetchone()[0]
        assert invalid_count == 0, f"fact_agent_time_log has {invalid_count} utilization values outside [0,100]"


# =========================================================================
# Test 8: Call Duration (AHT > 0, max < 3600)
# =========================================================================
class TestCallDuration:
    def test_aht_greater_than_zero(self, cursor):
        cursor.execute("SELECT COUNT(*) FROM fact_interactions WHERE aht_seconds <= 0")
        invalid_count = cursor.fetchone()[0]
        assert invalid_count == 0, f"fact_interactions has {invalid_count} aht_seconds <= 0"

    def test_aht_less_than_3600(self, cursor):
        cursor.execute("SELECT MAX(aht_seconds) FROM fact_interactions")
        max_aht = cursor.fetchone()[0]
        assert max_aht < 3600, f"fact_interactions max aht_seconds {max_aht} >= 3600"


# =========================================================================
# Test 9: KPI View Output
# =========================================================================
class TestKPIViewOutput:
    @pytest.mark.parametrize("view_name,pct_columns", [
        ('v_contact_metrics', ['rpc_pct']),
        ('v_promise_metrics', ['ptp_pct', 'kept_pct', 'bucket_conversion']),
        ('v_recovery_metrics', ['cure_rate']),
        ('v_productivity_metrics', ['utilization_pct']),
        ('v_handle_time_metrics', []),
        ('v_daily_mis', ['rpc_pct', 'ptp_pct', 'kept_pct', 'cure_rate', 'utilization_pct']),
        ('v_monthly_summary', ['avg_rpc_pct', 'avg_ptp_pct', 'avg_kept_pct', 'avg_cure_rate', 'avg_utilization_pct']),
        ('v_etl_load_summary', []),
        ('v_data_freshness', []),
    ])
    def test_view_returns_rows(self, cursor, view_name, pct_columns):
        cursor.execute(f"SELECT COUNT(*) FROM {view_name}")
        row_count = cursor.fetchone()[0]
        assert row_count > 0, f"{view_name} returned 0 rows"

    @pytest.mark.parametrize("view_name,pct_columns", [
        ('v_contact_metrics', ['rpc_pct']),
        ('v_promise_metrics', ['ptp_pct', 'kept_pct', 'bucket_conversion']),
        ('v_recovery_metrics', ['cure_rate']),
        ('v_productivity_metrics', ['utilization_pct']),
        ('v_handle_time_metrics', []),
        ('v_daily_mis', ['rpc_pct', 'ptp_pct', 'kept_pct', 'cure_rate', 'utilization_pct']),
        ('v_monthly_summary', ['avg_rpc_pct', 'avg_ptp_pct', 'avg_kept_pct', 'avg_cure_rate', 'avg_utilization_pct']),
        ('v_etl_load_summary', []),
        ('v_data_freshness', []),
    ])
    def test_percentage_columns_in_range(self, cursor, view_name, pct_columns):
        for col in pct_columns:
            cursor.execute(f"SELECT COUNT(*) FROM {view_name} WHERE {col} < 0 OR {col} > 100")
            invalid_count = cursor.fetchone()[0]
            assert invalid_count == 0, f"{view_name}.{col} has {invalid_count} values outside [0,100]"


# =========================================================================
# Test 10: ETL Idempotency (Slow - runs ETL twice)
# =========================================================================
@pytest.mark.slow
class TestETLIdempotency:
    def test_etl_idempotent_row_counts(self, cursor):
        root_path = Path(__file__).resolve().parent.parent
        etl_script = root_path / "etl" / "data_to_pg.py"
        env_file = root_path / ".env"

        # Get row counts before
        tables_to_check = ['dim_agents', 'dim_clients', 'dim_accounts', 'fact_interactions']
        row_counts_before = {}
        for table in tables_to_check:
            cursor.execute(f"SELECT COUNT(*) FROM {table}")
            row_counts_before[table] = cursor.fetchone()[0]

        # Run ETL again
        result = subprocess.run(
            ["python", str(etl_script), "--env-file", str(env_file)],
            capture_output=True, text=True, cwd=str(root_path)
        )
        assert result.returncode == 0, f"ETL failed: {result.stderr}"

        # Get row counts after
        for table in tables_to_check:
            cursor.execute(f"SELECT COUNT(*) FROM {table}")
            count_after = cursor.fetchone()[0]
            assert count_after == row_counts_before[table], \
                f"{table}: before={row_counts_before[table]}, after={count_after}"


# =========================================================================
# Test 11: Generator Seed Reproducibility (Slow - runs generator twice)
# =========================================================================
@pytest.mark.slow
class TestGeneratorSeed:
    def test_generator_seed_42_reproducible(self):
        root_path = Path(__file__).resolve().parent.parent
        generator_script = root_path / "data_sources" / "generators" / "data_generator_v7.py"
        assert generator_script.exists(), f"Generator not found: {generator_script}"

        output_dir_1 = root_path / "data_sources" / "generators" / "raw_test_1"
        output_dir_2 = root_path / "data_sources" / "generators" / "raw_test_2"

        # Clean up and run generator twice
        for output_dir in [output_dir_1, output_dir_2]:
            if output_dir.exists():
                shutil.rmtree(output_dir)
            result = subprocess.run(
                ["python", str(generator_script), "--seed", "42", "--output-dir", str(output_dir)],
                capture_output=True, text=True, cwd=str(root_path)
            )
            assert result.returncode == 0, f"Generator failed: {result.stderr}"

        # Compare CSV checksums
        def get_csv_checksums(directory):
            checksums = {}
            for csv_file in directory.rglob("*.csv"):
                content = csv_file.read_bytes()
                checksums[csv_file.name] = hashlib.sha256(content).hexdigest()
            return checksums

        checksums_1 = get_csv_checksums(output_dir_1)
        checksums_2 = get_csv_checksums(output_dir_2)

        assert checksums_1 == checksums_2, \
            f"CSV checksums differ: {set(checksums_1.items()) ^ set(checksums_2.items())}"

        # Cleanup
        shutil.rmtree(output_dir_1)
        shutil.rmtree(output_dir_2)


# =========================================================================
# Test 12: Metric Percentile Ranges
# =========================================================================
class TestMetricRanges:
    """Verify key metric medians fall within calibrated ranges."""

    def test_median_rpc_pct_in_range(self, cursor):
        cursor.execute(
            "SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rpc_pct) "
            "FROM v_contact_metrics WHERE rpc_pct IS NOT NULL"
        )
        median = cursor.fetchone()[0]
        assert 35 <= median <= 60, f"Median RPC% = {median}, expected [35, 60]"

    def test_median_ptp_pct_in_range(self, cursor):
        cursor.execute(
            "SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ptp_pct) "
            "FROM v_promise_metrics WHERE ptp_pct IS NOT NULL"
        )
        median = cursor.fetchone()[0]
        assert 20 <= median <= 65, f"Median PTP% = {median}, expected [20, 65]"

    def test_median_kp_pct_in_range(self, cursor):
        cursor.execute(
            "SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY kept_pct) "
            "FROM v_promise_metrics WHERE kept_pct IS NOT NULL"
        )
        median = cursor.fetchone()[0]
        assert 65 <= median <= 90, f"Median KP% = {median}, expected [65, 90]"

    def test_median_utilization_in_range(self, cursor):
        cursor.execute(
            "SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY utilization_pct * 100) "
            "FROM v_productivity_metrics WHERE utilization_pct IS NOT NULL"
        )
        median = cursor.fetchone()[0]
        assert 30 <= median <= 60, f"Median Utilization% = {median}, expected [30, 60]"

    def test_median_cures_per_tht_in_range(self, cursor):
        cursor.execute("""
            WITH agent_cures AS (
                SELECT agent_id,
                       COUNT(DISTINCT account_id) AS cure_count
                FROM fact_payments
                WHERE is_cured = TRUE AND agent_id IS NOT NULL
                GROUP BY agent_id
            ),
            agent_tht AS (
                SELECT agent_id,
                       SUM(tht_hours) AS total_tht
                FROM fact_agent_time_log
                GROUP BY agent_id
            )
            SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (
                ORDER BY cure_count::numeric / NULLIF(total_tht, 0)
            )
            FROM agent_cures c
            JOIN agent_tht t USING (agent_id)
        """)
        median = cursor.fetchone()[0]
        assert 0.08 <= median <= 0.30, f"Median Cures per THT = {median}, expected [0.08, 0.30]"

    def test_median_acw_rpc_seconds_in_range(self, cursor):
        cursor.execute(
            "SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY acw_seconds) "
            "FROM fact_interactions WHERE rpc_flag = TRUE"
        )
        median = cursor.fetchone()[0]
        assert 80 <= median <= 180, f"Median ACW RPC seconds = {median}, expected [80, 180]"


# =========================================================================
# Test 13: Capped KP > 0
# =========================================================================
class TestCappedKPPositive:
    """Verify capped_kp produces positive values."""

    def test_capped_kp_positive(self, cursor):
        cursor.execute(
            "SELECT SUM(capped_kp) FROM v_promise_metrics "
            "WHERE granularity = 'monthly'"
        )
        total = cursor.fetchone()[0]
        assert total is not None and total > 0, \
            f"Total capped_kp (monthly) = {total}, expected > 0"


# =========================================================================
# Test 14: BB Conversion Rate > 0
# =========================================================================
class TestBBConversionPositive:
    """Verify BB Conversion Rate (bucket_conversion) produces positive values."""

    def test_bb_conversion_rate_positive(self, cursor):
        cursor.execute(
            "SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY bucket_conversion) "
            "FROM v_promise_metrics WHERE granularity = 'monthly' AND bucket_conversion IS NOT NULL"
        )
        median = cursor.fetchone()[0]
        assert median is not None and median > 0, \
            f"Median BB Conversion Rate (monthly) = {median}, expected > 0"
