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
GENERATOR_SCRIPT = ROOT_PATH / "data_sources" / "generators" / "data_generator_v7.py"


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
        output_dir = ROOT_PATH / "data_sources" / "generators" / "raw_test_gen"

        if output_dir.exists():
            shutil.rmtree(output_dir)

        result = subprocess.run(
            ["python", str(GENERATOR_SCRIPT), "--seed", "42", "--output-dir", str(output_dir)],
            capture_output=True, text=True, timeout=300
        )
        assert result.returncode == 0, f"Generator failed: {result.stderr}"

        # Check shared tables exist
        shared_dir = output_dir / "shared"
        assert shared_dir.exists(), "shared directory not created"
        for table in ['Dim_Supervisors', 'Dim_Agents', 'Dim_Clients', 'Dim_Products', 'Dim_Calendar', 'Dim_Accounts']:
            csv_file = shared_dir / f"{table}.csv"
            assert csv_file.exists(), f"{table}.csv not found"
            assert csv_file.stat().st_size > 0, f"{table}.csv is empty"

        # Check monthly fact tables exist
        month_dirs = [d for d in output_dir.iterdir() if d.is_dir() and d.name != 'shared']
        assert len(month_dirs) > 0, "No monthly directories created"

        for month_dir in month_dirs:
            for table in ['Fact_Interactions', 'Fact_PTP_Log', 'Fact_Payments', 'Fact_Agent_Time_Log', 'Fact_EOM_Snapshot']:
                csv_file = month_dir / f"{table}.csv"
                assert csv_file.exists(), f"{table}.csv not found in {month_dir.name}"
                assert csv_file.stat().st_size > 0, f"{table}.csv is empty in {month_dir.name}"

        # Cleanup
        shutil.rmtree(output_dir)


class TestGeneratorReproducibility:
    """Test that generator produces identical output with same seed."""

    def test_seed_reproducibility(self):
        """Run generator twice with same seed, compare checksums."""
        output_dir_1 = ROOT_PATH / "data_sources" / "generators" / "raw_test_1"
        output_dir_2 = ROOT_PATH / "data_sources" / "generators" / "raw_test_2"

        for output_dir in [output_dir_1, output_dir_2]:
            if output_dir.exists():
                shutil.rmtree(output_dir)
            result = subprocess.run(
                ["python", str(GENERATOR_SCRIPT), "--seed", "42", "--output-dir", str(output_dir)],
                capture_output=True, text=True, timeout=300
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
        output_dir = ROOT_PATH / "data_sources" / "generators" / "raw_test_quality"
        if output_dir.exists():
            shutil.rmtree(output_dir)

        result = subprocess.run(
            ["python", str(GENERATOR_SCRIPT), "--seed", "42", "--output-dir", str(output_dir)],
            capture_output=True, text=True, timeout=300
        )
        assert result.returncode == 0, f"Generator failed: {result.stderr}"

        import pandas as pd

        # Check shared tables
        pk_mapping = {
            'Dim_Supervisors': 'supervisor_id',
            'Dim_Agents': 'agent_id',
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
