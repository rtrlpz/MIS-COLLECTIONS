"""
Unit Tests for Data Generator
Tests generator output structure, reproducibility, and data quality.
"""

import subprocess
import hashlib
import shutil
from pathlib import Path
import pytest


ROOT_PATH = Path(__file__).resolve().parent.parent
GENERATOR_SCRIPT = ROOT_PATH / "data_sources" / "data_generator_v7.py"


class TestGeneratorOutput:
    """Test generator output structure and completeness."""

    def test_generator_exists(self):
        assert GENERATOR_SCRIPT.exists(), f"Generator not found: {GENERATOR_SCRIPT}"

    def test_generator_help_runs(self):
        result = subprocess.run(
            ["python", str(GENERATOR_SCRIPT), "--help"],
            capture_output=True, text=True, timeout=30
        )
        assert result.returncode == 0, f"Generator --help failed: {result.stderr}"
        assert "seed" in result.stdout.lower() or "--seed" in result.stdout

    def test_generator_produces_csv_files(self):
        """Run generator and verify CSV files are created."""
        output_dir = ROOT_PATH / "data_sources" / "raw_test_gen"

        if output_dir.exists():
            shutil.rmtree(output_dir)

        result = subprocess.run(
            ["python", str(GENERATOR_SCRIPT), "--seed", "42", "--output-dir", str(output_dir)],
            capture_output=True, text=True, timeout=600
        )
        assert result.returncode == 0, f"Generator failed: {result.stderr}"

        # Check shared tables exist
        shared_dir = output_dir / "shared"
        assert shared_dir.exists(), "shared directory not created"
        for table in ['Dim_Employees', 'Dim_Clients', 'Dim_Products', 'Dim_Calendar', 'Dim_Accounts']:
            csv_file = shared_dir / f"{table}.csv"
            assert csv_file.exists(), f"{table}.csv not found"
            assert csv_file.stat().st_size > 0, f"{table}.csv is empty"

        # Check month directories created
        month_dirs = [d for d in output_dir.iterdir() if d.is_dir() and d.name != 'shared']
        assert len(month_dirs) > 0, "No monthly directories created"

        for month_dir in month_dirs:
            for table in ['Fact_Interactions', 'Fact_PTP_Log', 'Fact_Payments', 'Fact_Agent_Time_Log', 'Fact_EOM_Snapshot']:
                csv_file = month_dir / f"{table}.csv"
                assert csv_file.exists(), f"{table}.csv not found in {month_dir.name}"
                assert csv_file.stat().st_size > 0, f"{table}.csv is empty in {month_dir.name}"

        # Cleanup
        shutil.rmtree(output_dir)


class TestGeneratorRowCounts:
    """Test row counts in generated CSV output match expected ranges."""

    EXPECTED_COUNTS = {
        'Dim_Employees': 88,
        'Dim_Clients': 10000,
        'Dim_Products': 3,
        'Dim_Calendar': 396,
        'Dim_Accounts': 15482,
        'Fact_Interactions': 1355587,
        'Fact_PTP_Log': 58811,
        'Fact_Payments': 49419,
        'Fact_Agent_Time_Log': 20880,
        'Fact_EOM_Snapshot': 185784,
        'Fact_Writeoffs': 222,
    }
    TOLERANCE = 0.05  # ±5% for fact tables

    def test_generated_csv_row_counts(self):
        """Run generator and verify CSV row counts."""
        output_dir = ROOT_PATH / "data_sources" / "raw_test_row_counts"
        if output_dir.exists():
            shutil.rmtree(output_dir)

        result = subprocess.run(
            ["python", str(GENERATOR_SCRIPT), "--seed", "42", "--output-dir", str(output_dir)],
            capture_output=True, text=True, timeout=600
        )
        assert result.returncode == 0, f"Generator failed: {result.stderr}"

        import pandas as pd

        # Check dimension table counts (exact match)
        shared_dir = output_dir / "shared"
        for table in ['Dim_Employees', 'Dim_Clients', 'Dim_Products', 'Dim_Calendar']:
            df = pd.read_csv(shared_dir / f"{table}.csv")
            assert len(df) == self.EXPECTED_COUNTS[table], \
                f"{table}: expected {self.EXPECTED_COUNTS[table]}, got {len(df)}"

        # Dim_Accounts has slight per-run variation
        df_accts = pd.read_csv(shared_dir / "Dim_Accounts.csv")
        expected = self.EXPECTED_COUNTS['Dim_Accounts']
        tol = expected * self.TOLERANCE
        assert abs(len(df_accts) - expected) <= tol, \
            f"Dim_Accounts: expected ~{expected}, got {len(df_accts)}"

        # Check fact table counts aggregated across months
        month_dirs = sorted(d for d in output_dir.iterdir() if d.is_dir() and d.name != 'shared')
        assert len(month_dirs) == 12, f"Expected 12 month dirs, got {len(month_dirs)}"

        for table in ['Fact_Interactions', 'Fact_PTP_Log', 'Fact_Payments',
                       'Fact_Agent_Time_Log', 'Fact_EOM_Snapshot', 'Fact_Writeoffs']:
            total = 0
            for month_dir in month_dirs:
                df = pd.read_csv(month_dir / f"{table}.csv")
                total += len(df)
            expected = self.EXPECTED_COUNTS[table]
            tol = expected * self.TOLERANCE
            assert abs(total - expected) <= tol, \
                f"{table}: expected ~{expected}, got {total}"

        # Cleanup
        shutil.rmtree(output_dir)


class TestGeneratorReproducibility:
    """Test that generator produces identical output with same seed."""

    def test_seed_reproducibility(self):
        """Run generator twice with same seed, compare checksums."""
        output_dir_1 = ROOT_PATH / "data_sources" / "raw_test_1"
        output_dir_2 = ROOT_PATH / "data_sources" / "raw_test_2"

        for output_dir in [output_dir_1, output_dir_2]:
            if output_dir.exists():
                shutil.rmtree(output_dir)
            result = subprocess.run(
                ["python", str(GENERATOR_SCRIPT), "--seed", "42", "--output-dir", str(output_dir)],
                capture_output=True, text=True, timeout=600
            )
            assert result.returncode == 0, f"Generator failed: {result.stderr}"

        # Compare CSV checksums
        def get_csv_checksums(directory):
            checksums = {}
            for csv_file in directory.rglob("*.csv"):
                content = csv_file.read_bytes()
                checksums[csv_file.relative_to(directory)] = hashlib.sha256(content).hexdigest()
            return checksums

        checksums_1 = get_csv_checksums(output_dir_1)
        checksums_2 = get_csv_checksums(output_dir_2)

        assert checksums_1 == checksums_2, \
            f"CSV checksums differ: {set(checksums_1.items()) ^ set(checksums_2.items())}"

        # Cleanup
        shutil.rmtree(output_dir_1)
        shutil.rmtree(output_dir_2)


class TestGeneratorDataQuality:
    """Test data quality rules in generated output."""

    def test_no_null_pks_in_generated_data(self):
        """Verify no null primary keys in generated CSVs."""
        output_dir = ROOT_PATH / "data_sources" / "raw_test_quality"
        if output_dir.exists():
            shutil.rmtree(output_dir)

        result = subprocess.run(
            ["python", str(GENERATOR_SCRIPT), "--seed", "42", "--output-dir", str(output_dir)],
            capture_output=True, text=True, timeout=600
        )
        assert result.returncode == 0, f"Generator failed: {result.stderr}"

        import pandas as pd

        # Check shared tables
        pk_mapping = {
            'Dim_Employees': 'agent_id',
            'Dim_Clients': 'client_id',
            'Dim_Products': 'product_id',
            'Dim_Calendar': 'date',
            'Dim_Accounts': 'account_id',
        }

        shared_dir = output_dir / "shared"
        for table, pk_col in pk_mapping.items():
            df = pd.read_csv(shared_dir / f"{table}.csv")
            null_count = df[pk_col].isna().sum()
            assert null_count == 0, f"{table}: {null_count} null values in {pk_col}"

        # Cleanup
        shutil.rmtree(output_dir)


class TestGeneratorPostFixInvariants:
    """Test data invariants guaranteed by Phase 1-5 fixes."""

    ROOT_PATH = Path(__file__).resolve().parent.parent
    GENERATOR_SCRIPT = ROOT_PATH / "data_sources" / "data_generator_v7.py"

    @pytest.fixture(scope='class', autouse=True)
    def generated_data(self):
        """Run generator once per class."""
        output_dir = self.ROOT_PATH / "data_sources" / "raw_test_invariants"
        if output_dir.exists():
            shutil.rmtree(output_dir)
        result = subprocess.run(
            ["python", str(self.GENERATOR_SCRIPT), "--seed", "42", "--output-dir", str(output_dir)],
            capture_output=True, text=True, timeout=600
        )
        assert result.returncode == 0, f"Generator failed: {result.stderr}"
        yield output_dir
        if output_dir.exists():
            shutil.rmtree(output_dir)

    def test_cure_flag_completeness(self, generated_data):
        """No row with is_cured=True has cure_flag='None'."""
        import pandas as pd
        month_dirs = sorted(d for d in generated_data.iterdir() if d.is_dir() and d.name != 'shared')
        for md in month_dirs:
            df = pd.read_csv(md / "Fact_Payments.csv")
            bad = df[(df['is_cured'] == True) & (df['cure_flag'] == 'None')]
            assert len(bad) == 0, f"{md.name}: {len(bad)} rows with is_cured=True and cure_flag=None"

    def test_ptp_payment_consistency(self, generated_data):
        """Kept PTPs have amount_paid >= 95% of promised_amount."""
        import pandas as pd
        month_dirs = sorted(d for d in generated_data.iterdir() if d.is_dir() and d.name != 'shared')
        for md in month_dirs:
            pay = pd.read_csv(md / "Fact_Payments.csv")
            ptp = pd.read_csv(md / "Fact_PTP_Log.csv")
            merged = pay[pay['ptp_id'].notna()].merge(ptp, on='ptp_id', how='left', suffixes=('_pay', '_ptp'))
            kept = merged[merged['status'] == 'Kept']
            underpaid = kept[kept['amount_paid'] < kept['promised_amount'] * 0.95]
            assert len(underpaid) == 0, f"{md.name}: {len(underpaid)} kept PTPs underpaid"

    def test_grace_period_integrity(self, generated_data):
        """All grace_until_date >= promised_date."""
        import pandas as pd
        month_dirs = sorted(d for d in generated_data.iterdir() if d.is_dir() and d.name != 'shared')
        for md in month_dirs:
            ptp = pd.read_csv(md / "Fact_PTP_Log.csv")
            ptp['grace_until_date'] = pd.to_datetime(ptp['grace_until_date'])
            ptp['promised_date'] = pd.to_datetime(ptp['promised_date'])
            bad = ptp[ptp['grace_until_date'] < ptp['promised_date']]
            assert len(bad) == 0, f"{md.name}: {len(bad)} PTPs with grace < promise"

    def test_reentry_rate_bounds(self, generated_data):
        """Accounts cured between consecutive months have 5-25% re-entry by N+1.
        Range widened from 10-25% to 5-25% after 12-month expansion (G7) —
        longer time horizon means more accounts fully recover, reducing re-entry."""
        import pandas as pd
        month_dirs = sorted(d for d in generated_data.iterdir() if d.is_dir() and d.name != 'shared')
        month_names = sorted(md.name for md in month_dirs)
        if len(month_names) < 3:
            return

        eoms = {}
        for md in month_dirs:
            eoms[md.name] = pd.read_csv(md / "Fact_EOM_Snapshot.csv")

        mora_m0 = set(eoms[month_names[0]][eoms[month_names[0]]['status'] == 'Mora']['account_id'])
        activo_m1 = set(eoms[month_names[1]][eoms[month_names[1]]['status'] == 'Activo']['account_id'])
        cured_01 = mora_m0 & activo_m1

        if len(cured_01) == 0:
            return

        mora_m2 = set(eoms[month_names[2]][eoms[month_names[2]]['status'] == 'Mora']['account_id'])
        reentries = cured_01 & mora_m2
        rate = len(reentries) / len(cured_01) * 100

        assert 5 <= rate <= 25, \
            f"Re-entry rate {rate:.1f}% outside 5-25% range ({len(reentries)}/{len(cured_01)})"
