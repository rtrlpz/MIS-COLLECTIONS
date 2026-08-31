# Test Suite — pytest

**Status:** 84 tests passing (81 fast + 3 slow) — Hybrid C suite

## Overview

The test suite validates data integrity, KPI view correctness, generator output, and pipeline idempotency. Tests are organized into two main files:

| File | Test Classes | Fast Tests | Slow Tests |
|------|-------------|------------|------------|
| `test_qa_validation.py` | 9 classes | 72 | 1 |
| `test_generator.py` | 5 classes | 9 | 2 |
| **Total** | **14 classes** | **81** | **3** |

## Quick Start

```bash
# Fast tests only (~5-6 min, includes DB percentile queries)
python -m pytest test/ -v -m "not slow"

# Full gate (~15 min: adds canonical 12-mo generation, seed repro, ETL idempotency)
python -m pytest test/ -v
```

## Test Structure

### conftest.py — Fixtures & Constants
- `cursor` — psycopg2 DB cursor (session-scoped)
- `TABLES` — List of 16 table names
- `PK_MAPPING` — Primary key columns per table
- `FK_RELATIONSHIPS` — Foreign key mappings (22 relationships)
- `GENERATOR_ROW_COUNTS` — 12-month baseline row counts (seed 42, ±10% tolerance)
- `GENERATOR_ROW_COUNTS_SMALL` — 3-month baseline for fast tests
- `METRIC_RANGES` — Percentile bounds for KPI metrics (single source of truth)
- `small_generated_data` — Session-scoped 3-month CSV generation (Hybrid C)
- `slow` — Custom pytest mark for slow tests

### test_qa_validation.py — 73 Tests (72 fast + 1 slow)

| Class | Tests | Validates |
|-------|-------|-----------|
| `TestRowCounts` | 1 | Dimension table counts (88, 10000, ~15480, etc.) |
| `TestNoNullPKs` | 10 (parametrized) | No nulls in PK columns across 16 tables |
| `TestFKIntegrity` | 21 (parametrized) | All FK relationships have no orphans |
| `TestDateRanges` | 1 | Fact dates within Jan–Dec 2025, calendar covers full period |
| `TestWeekdayOnly` | 1 | No interactions on weekends (bug fixed) |
| `TestDPDLogic` | 1 | DPD ≥ 0 in interactions, payments, EOM snapshots |
| `TestUtilizationBounds` | 1 | Utilization between 0 and 1 (decimal) |
| `TestCallDuration` | 2 | AHT > 0s, max < 3600s |
| `TestKPIViewOutput` | 15 (parametrized) | All 15 views return rows, % columns in 0–100 |
| `TestMetricRanges` | 6 | Median KPIs within conftest.METRIC_RANGES |
| `TestCappedKPPositive` | 1 | SUM(capped_kp) > 0 |
| `TestBBConversionPositive` | 1 | median(bucket_conversion) > 0 |
| `TestMigrationMatrixPopulated` | 1 | Migration matrix has rows |
| `TestMigrationDirectionMatchesRank` | 1 | Direction matches bucket sort_order |
| `TestCureFromDeepDelinquency` | 1 | Cures from 60+/90+ buckets exist |
| `TestETLIdempotency` | 1 (slow) | Running ETL twice = same row counts |

### test_generator.py — 11 Tests (9 fast + 2 slow)

| Class | Tests | Validates |
|-------|-------|-----------|
| `TestGeneratorOutput` | 3 | Generator exists, --help works, produces CSVs with correct structure |
| `TestGeneratorRowCounts` | 2 (1 fast, 1 slow) | Fast: 3-mo vs GENERATOR_ROW_COUNTS_SMALL; Slow: 12-mo vs GENERATOR_ROW_COUNTS ±10% |
| `TestGeneratorReproducibility` | 2 (1 fast fixture, 1 slow) | Seed 42 produces identical checksums |
| `TestGeneratorDataQuality` | 1 | No null PKs in generated CSVs across all dimension tables |
| `TestGeneratorPostFixInvariants` | 4 (fast) | Cure-flag completeness, PTP-payment consistency (per-plan), grace-period integrity, re-entry rate bounds (5-25%, chronological) |

### test_kpi_views.sql
168 lines of SQL validation queries for manual verification of KPI view outputs.

## Hybrid C Architecture (Aug 2026)

- **Fast tests** share ONE session-scoped 3-month generation (`--months 1,2,3` seed 42 → `data_sources/raw_test_session/`). Eliminates 8 separate full 12-month generations per suite run.
- **Slow gates** keep full fidelity:
  - Canonical 12-month baseline validation (±10% tolerance)
  - Seed reproducibility (fixture vs one extra small run)
  - ETL idempotency (reload verification)
- **Conftest import fix:** Package layout (`test/__init__.py`) requires `sys.path` insertion for `from conftest import` to work.

## Key Metrics (METRIC_RANGES in conftest.py)

| Metric | Range | Source |
|--------|-------|--------|
| RPC% | 35–60 | `v_contact_metrics` |
| PTP% | 5–40 | `v_promise_metrics` |
| KP% | 60–90 | `v_promise_metrics` |
| Utilization% | 30–60 | `v_productivity_metrics` |
| Cures/THT | 0.02–0.20 | `v_recovery_metrics` |
| ACW RPC (sec) | 80–180 | `v_handle_time_metrics` |

## Running Specific Tests

```bash
# Single test class
python -m pytest test/test_qa_validation.py::TestMetricRanges -v

# Single test
python -m pytest test/test_qa_validation.py::TestMetricRanges::test_median_rpc_pct_in_range -v

# With keyword filter (ALWAYS pair with -m "not slow" to avoid accidental slow test matches)
python -m pytest test/ -v -k "rpc" -m "not slow"
```

## Known Issues

- Targeted pytest runs using `-k` alone can match slow tests by name (e.g., `test_etl_idempotent_row_counts` matched by `row_counts`). **Always pair `-k` with `-m "not slow"`** for targeted fast runs.
- Generator seed reproducibility test requires the `small_generated_data` fixture to be available.