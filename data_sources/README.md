# Data Sources — Synthetic Data Generator

This directory contains the synthetic data generation engine for the collections analytics platform.

## Contents

| Path | Purpose |
|------|---------|
| `data_generator_v7.py` | Main generator (P3/P4 engine: ~1.9M rows, 12 months) |
| `config.py` | 45+ calibration parameters (CFG + PRODUCT_CFG) |
| `schema/dictionary.md` | Column-level data dictionary |

## Quick Start

```bash
# From project root
python data_sources/data_generator_v7.py
```

Output CSVs are written to `data_sources/raw/`:
- `shared/` — 5 dimension tables (accounts, calendar, clients, employees, products) + P3 dims (employee_history, strategy)
- `YYYY_month/` — 7 fact tables per month (interactions, ptp, payments, agent_time, eom_snapshot, writeoffs, recoveries)

## Key Facts

- **12 months** (Jan-Dec 2025) with seasonal patterns
- **~1.34M interactions**, ~106K PTPs, ~121K payments, ~21K agent time, ~183K EOM snapshots, ~441 writeoffs, ~323 recoveries
- Weekday-only interactions (bug fixed), payments allowed on weekends
- ±8% monthly performance drift per agent for realistic variance
- See `config.py` for all calibration knobs
