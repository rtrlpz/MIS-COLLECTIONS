"""
Unit Tests for Data Generator
Tests generator output structure, reproducibility, and data quality.

Speed strategy (Hybrid C):
- Fast tests share ONE session-scoped 3-month generation
  (conftest.small_generated_data, --months 1,2,3 seed 42).
- Slow-marked gates carry the heavy work: canonical 12-month baseline
  validation and seed reproducibility here; ETL idempotency in
  test_qa_validation.py.
"""

import hashlib
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

import pandas as pd
import pytest

# Package layout (test/__init__.py exists): make plain `conftest` importable
sys.path.insert(0, str(Path(__file__).resolve().parent))

from conftest import GENERATOR_ROW_COUNTS, GENERATOR_ROW_COUNTS_SMALL, TEST_MONTHS

ROOT_PATH = Path(__file__).resolve().parent.parent
GENERATOR_SCRIPT = ROOT_PATH / "data_sources" / "data_generator_v7.py"

SHARED_TABLES = ['Dim_Employees', 'Dim_Clients', 'Dim_Products', 'Dim_Calendar', 'Dim_Accounts']
MONTHLY_FACT_TABLES = ['Fact_Interactions', 'Fact_PTP_Log', 'Fact_Payments',
                       'Fact_Agent_Time_Log', 'Fact_EOM_Snapshot', 'Fact_Writeoffs',
                       'Fact_Recoveries']
SMALL_MONTH_DIRS = len(TEST_MONTHS.split(','))


def chrono_month_dirs(generated_root):
    """Month dirs sorted CHRONOLOGICALLY ("february_2025" < "january_2025"
    alphabetically, so name-sorting silently scrambles month order)."""
    dirs = [d for d in generated_root.iterdir() if d.is_dir() and d.name != 'shared']
    return sorted(dirs, key=lambda d: datetime.strptime(d.name, "%B_%Y"))


class TestGeneratorOutput:
    """Test generator output structure and completeness."""

    def test_generator_exists(self):
        assert GENERATOR_SCRIPT.exists(), f"Generator not found: {GENERATOR_SCRIPT}"

    def test_generator_help_runs(self):
        result = subprocess.run(
            [sys.executable, str(GENERATOR_SCRIPT), "--help"],
            capture_output=True, text=True, timeout=30
        )
        assert result.returncode == 0, f"Generator --help failed: {result.stderr}"
        assert "seed" in result.stdout.lower() or "--seed" in result.stdout

    def test_generator_produces_csv_files(self, small_generated_data):
        """Verify CSV files are created for every table at reduced scale."""
        output_dir = small_generated_data

        # Check shared tables exist and are non-empty (header-only is still >0 bytes)
        shared_dir = output_dir / "shared"
        assert shared_dir.exists(), "shared directory not created"
        for table in SHARED_TABLES:
            csv_file = shared_dir / f"{table}.csv"
            assert csv_file.exists(), f"{table}.csv not found"
            assert csv_file.stat().st_size > 0, f"{table}.csv is empty"

        # Check month directories created
        month_dirs = chrono_month_dirs(output_dir)
        assert len(month_dirs) == SMALL_MONTH_DIRS, \
            f"Expected {SMALL_MONTH_DIRS} month dirs, got {len(month_dirs)}"

        for month_dir in month_dirs:
            # Fact_Recoveries may legitimately be header-only in early months
            # (write-offs must age in first) — file existence is the contract.
            for table in MONTHLY_FACT_TABLES:
                csv_file = month_dir / f"{table}.csv"
                assert csv_file.exists(), f"{table}.csv not found in {month_dir.name}"
                assert csv_file.stat().st_size > 0, f"{table}.csv is empty in {month_dir.name}"


class TestGeneratorRowCounts:
    """Row-count validation at two fidelities.

    - Fast: reduced-scale run vs GENERATOR_ROW_COUNTS_SMALL — catches gross
      breakage (missing tables, wrong month slicing) in seconds.
    - Slow (canonical): full 12-month run vs GENERATOR_ROW_COUNTS ±10% —
      THE calibration-drift gate. Baselines come from conftest (single
      source of truth, P3/P4 engine regeneration of Aug 2026).
    """

    _KEY = {
        'Dim_Employees': 'dim_employees',
        'Dim_Clients': 'dim_clients',
        'Dim_Products': 'dim_products',
        'Dim_Calendar': 'dim_calendar',
        'Dim_Accounts': 'dim_accounts',
        'Fact_Interactions': 'fact_interactions',
        'Fact_PTP_Log': 'fact_ptp_log',
        'Fact_Payments': 'fact_payments',
        'Fact_Agent_Time_Log': 'fact_agent_time_log',
        'Fact_EOM_Snapshot': 'fact_eom_snapshot',
        'Fact_Writeoffs': 'fact_writeoffs',
        'Fact_Recoveries': 'fact_recoveries',
    }
    TOLERANCE = 0.10        # ±10% for fact tables (canonical 12-month gate)
    TOLERANCE_SMALL = 0.15  # ±15% guard at reduced scale

    @classmethod
    def expected(cls, csv_name):
        return GENERATOR_ROW_COUNTS[cls._KEY[csv_name]]

    @classmethod
    def expected_small(cls, csv_name):
        return GENERATOR_ROW_COUNTS_SMALL[cls._KEY[csv_name]]

    def test_small_run_structure(self, small_generated_data):
        """Reduced-scale structural counts: dims exact, facts within guard."""
        shared_dir = small_generated_data / "shared"
        for table in ['Dim_Employees', 'Dim_Clients', 'Dim_Products', 'Dim_Calendar']:
            df = pd.read_csv(shared_dir / f"{table}.csv")
            expected = self.expected_small(table)
            assert len(df) == expected, f"{table}: expected {expected}, got {len(df)}"

        df_accts = pd.read_csv(shared_dir / "Dim_Accounts.csv")
        expected = self.expected_small('Dim_Accounts')
        tol = expected * self.TOLERANCE
        assert abs(len(df_accts) - expected) <= tol, \
            f"Dim_Accounts: expected ~{expected}, got {len(df_accts)}"

        month_dirs = chrono_month_dirs(small_generated_data)
        assert len(month_dirs) == SMALL_MONTH_DIRS, \
            f"Expected {SMALL_MONTH_DIRS} month dirs, got {len(month_dirs)}"

        for table in MONTHLY_FACT_TABLES:
            total = sum(len(pd.read_csv(md / f"{table}.csv")) for md in month_dirs)
            expected = self.expected_small(table)
            tol = max(expected * self.TOLERANCE_SMALL, 1)  # sparse tables: tiny abs floor
            assert abs(total - expected) <= tol, \
                f"{table}: expected ~{expected}, got {total}"

    @pytest.mark.slow
    def test_canonical_12mo_row_counts(self):
        """Canonical gate: full 12-month run vs GENERATOR_ROW_COUNTS."""
        output_dir = ROOT_PATH / "data_sources" / "raw_test_row_counts"
        if output_dir.exists():
            shutil.rmtree(output_dir)

        result = subprocess.run(
            [sys.executable, str(GENERATOR_SCRIPT), "--seed", "42",
             "--output-dir", str(output_dir)],
            capture_output=True, text=True, timeout=900
        )
        assert result.returncode == 0, f"Generator failed: {result.stderr}"

        try:
            # Dimension table counts (exact match)
            shared_dir = output_dir / "shared"
            for table in ['Dim_Employees', 'Dim_Clients', 'Dim_Products', 'Dim_Calendar']:
                df = pd.read_csv(shared_dir / f"{table}.csv")
                assert len(df) == self.expected(table), \
                    f"{table}: expected {self.expected(table)}, got {len(df)}"

            # Dim_Accounts has slight per-run variation
            df_accts = pd.read_csv(shared_dir / "Dim_Accounts.csv")
            expected = self.expected('Dim_Accounts')
            tol = expected * self.TOLERANCE
            assert abs(len(df_accts) - expected) <= tol, \
                f"Dim_Accounts: expected ~{expected}, got {len(df_accts)}"

            # Fact table counts aggregated across months
            month_dirs = chrono_month_dirs(output_dir)
            assert len(month_dirs) == 12, f"Expected 12 month dirs, got {len(month_dirs)}"

            for table in MONTHLY_FACT_TABLES:
                total = sum(len(pd.read_csv(md / f"{table}.csv")) for md in month_dirs)
                expected = self.expected(table)
                tol = max(expected * self.TOLERANCE, 1)  # sparse tables: tiny abs floor
                assert abs(total - expected) <= tol, \
                    f"{table}: expected ~{expected}, got {total}"
        finally:
            shutil.rmtree(output_dir, ignore_errors=True)


@pytest.mark.slow
class TestGeneratorReproducibility:
    """Same seed → byte-identical output.

    Compares the session fixture against ONE extra reduced-scale run
    (was: two extra FULL runs — the most expensive test in the suite
    duplicated identical coverage).
    """

    def test_seed_reproducibility(self, small_generated_data):
        output_dir_2 = ROOT_PATH / "data_sources" / "raw_test_repro"
        if output_dir_2.exists():
            shutil.rmtree(output_dir_2)

        result = subprocess.run(
            [sys.executable, str(GENERATOR_SCRIPT), "--seed", "42",
             "--months", TEST_MONTHS, "--output-dir", str(output_dir_2)],
            capture_output=True, text=True, timeout=600
        )
        assert result.returncode == 0, f"Generator failed: {result.stderr}"

        try:
            def get_csv_checksums(directory):
                checksums = {}
                for csv_file in directory.rglob("*.csv"):
                    content = csv_file.read_bytes()
                    checksums[csv_file.relative_to(directory)] = hashlib.sha256(content).hexdigest()
                return checksums

            checksums_1 = get_csv_checksums(small_generated_data)
            checksums_2 = get_csv_checksums(output_dir_2)

            assert checksums_1 == checksums_2, \
                f"CSV checksums differ: {set(checksums_1.items()) ^ set(checksums_2.items())}"
        finally:
            shutil.rmtree(output_dir_2, ignore_errors=True)


class TestGeneratorDataQuality:
    """Test data quality rules in generated output."""

    def test_no_null_pks_in_generated_data(self, small_generated_data):
        """Verify no null primary keys in generated CSVs."""
        pk_mapping = {
            'Dim_Employees': 'agent_id',
            'Dim_Clients': 'client_id',
            'Dim_Products': 'product_id',
            'Dim_Calendar': 'date',
            'Dim_Accounts': 'account_id',
        }

        shared_dir = small_generated_data / "shared"
        for table, pk_col in pk_mapping.items():
            df = pd.read_csv(shared_dir / f"{table}.csv")
            null_count = df[pk_col].isna().sum()
            assert null_count == 0, f"{table}: {null_count} null values in {pk_col}"


class TestGeneratorPostFixInvariants:
    """Test data invariants guaranteed by Phase 1-5 fixes."""

    @pytest.fixture(scope='class')
    def generated_data(self, small_generated_data):
        """Reuse the session-scoped reduced-scale generation."""
        return small_generated_data

    def test_cure_flag_completeness(self, generated_data):
        """No row with is_cured=True has cure_flag='None'."""
        for md in chrono_month_dirs(generated_data):
            df = pd.read_csv(md / "Fact_Payments.csv")
            bad = df[(df['is_cured'] == True) & (df['cure_flag'] == 'None')]
            assert len(bad) == 0, f"{md.name}: {len(bad)} rows with is_cured=True and cure_flag=None"

    def test_ptp_payment_consistency(self, generated_data):
        """Kept PTPs have TOTAL paid >= 95% of promised_amount.

        N5 (P4): plans may settle in two installments, so the invariant is
        evaluated per plan (sum of that ptp_id's payments), never per row.
        """
        month_dirs = chrono_month_dirs(generated_data)
        # N5: installment plans legitimately span month boundaries (promise on
        # Apr 29, parts on May 3/6), so totals are aggregated GLOBALLY before
        # being joined back to each month's promise rows.
        pays = [pd.read_csv(md / "Fact_Payments.csv") for md in month_dirs]
        pay = pd.concat(pays, ignore_index=True)
        totals = (pay[pay['ptp_id'].notna()]
                  .groupby('ptp_id')['amount_paid'].sum().rename('total_paid'))
        for md in month_dirs:
            ptp = pd.read_csv(md / "Fact_PTP_Log.csv")
            merged = ptp.merge(totals, on='ptp_id', how='left')
            kept = merged[merged['status'] == 'Kept']
            underpaid = kept[kept['total_paid'].fillna(0) < kept['promised_amount'] * 0.95]
            assert len(underpaid) == 0, f"{md.name}: {len(underpaid)} kept PTPs underpaid"

    def test_grace_period_integrity(self, generated_data):
        """All grace_until_date >= promised_date."""
        for md in chrono_month_dirs(generated_data):
            ptp = pd.read_csv(md / "Fact_PTP_Log.csv")
            ptp['grace_until_date'] = pd.to_datetime(ptp['grace_until_date'])
            ptp['promised_date'] = pd.to_datetime(ptp['promised_date'])
            bad = ptp[ptp['grace_until_date'] < ptp['promised_date']]
            assert len(bad) == 0, f"{md.name}: {len(bad)} PTPs with grace < promise"

    def test_reentry_rate_bounds(self, generated_data):
        """Accounts cured between consecutive months have 5-25% re-entry by N+1.

        BUGFIX (Aug 2026): month dirs were previously sorted ALPHABETICALLY,
        which scrambles chronology ("february" < "january") — the test was
        measuring arbitrary/backwards month pairs since Phase 6 and only
        passed because pre-P3 rates were uniformly low. Chronological
        measurement on the P3/P4 equilibrium engine gives a stable
        10.4–14.3% band across all ten 12-month windows (Q1 window: 11.6%),
        comfortably inside the G7-era 5-25% bound, which is kept unchanged.
        """
        month_dirs = chrono_month_dirs(generated_data)
        if len(month_dirs) < 3:
            return

        eoms = {md.name: pd.read_csv(md / "Fact_EOM_Snapshot.csv") for md in month_dirs}
        names = [md.name for md in month_dirs]

        mora_m0 = set(eoms[names[0]][eoms[names[0]]['status'] == 'Mora']['account_id'])
        activo_m1 = set(eoms[names[1]][eoms[names[1]]['status'] == 'Activo']['account_id'])
        cured_01 = mora_m0 & activo_m1

        if len(cured_01) == 0:
            return

        mora_m2 = set(eoms[names[2]][eoms[names[2]]['status'] == 'Mora']['account_id'])
        reentries = cured_01 & mora_m2
        rate = len(reentries) / len(cured_01) * 100

        assert 5 <= rate <= 25, \
            f"Re-entry rate {rate:.1f}% outside 5-25% range ({len(reentries)}/{len(cured_01)})"
