# MIS-COLLECTIONS — Project Context

## Project Overview
Simulated bank collections analytics portfolio project. Generates synthetic data for ~80 agents, ~10,000 clients, ~20,000 accounts across Credit Cards, Personal Loans, and Mortgages (Oct–Dec 2025). Models the full collections lifecycle: dialer interactions, RPC tracking, promise-to-pay management, payment/cure events, and agent utilization.

**Goal:** Portfolio piece demonstrating end-to-end data engineering + analytics for a Scotiabank-style collections department.

## Tech Stack
- **Python 3.x** — Data generation (Faker), ETL ingestion (pandas, psycopg2)
- **PostgreSQL 15** — Dockerized database with pgAdmin
- **SQL** — KPI views, exploratory analysis
- **Power BI** — Collections dashboard (.pbix)
- **Excel** — Daily MIS report templates
- **Docker Compose** — Postgres + pgAdmin orchestration

## Directory Structure
```
MIS-COLLECTIONS/
├── .github/ISSUE_TEMPLATE/        # bug_report.md, feature_request.md
├── .gitignore
├── CONTEXT.md                     # THIS FILE — single-source project overview
├── LICENSE
├── README.md                      # Project overview & interview pitch
├── ROADMAP.md                     # Phase-by-phase task checklist (corrected priority order)
├── requirements.txt               # Python deps (pinned versions)
├── run_pipeline.bat               # Windows batch to run full pipeline (empty — Phase 7)
│
├── analysis/                      # SQL ANALYSIS LAYER (17 files — all EMPTY skeletons)
│   ├── README.md
│   └── sql/
│       ├── agent_level_operational_supervisors/   # 6 files: daily_agent_activity, agent_scorecard, agent_exception_report, coaching_opportunities, schedule_adherence, eda_agents
│       ├── team_level_tactical_managers/          # 6 files: team_comparison, agent_leaderboard, handle_time_benchmark, workload_distribution, campaign_effectiveness, eda_supervisors
│       └── portfolio_level_strategic_directors/   # 5 files: portfolio_health, recovery_trend_mom, target_vs_actual, portfolio_concentration, roll_rate_analysis
│
├── dashboards/                    # VISUALIZATION LAYER
│   ├── assets/
│   │   ├── reference_guide.html   # Business guide (994 lines)
│   │   └── screenshots/architecture_diagram.svg
│   └── dax_measures_dictionary.md # Exported DAX formulas
│
├── data_sources/                  # DATA GENERATION LAYER
│   ├── README.md
│   ├── generators/
│   │   ├── __init__.py
│   │   ├── config.py             # CFG and PRODUCT_CFG dicts (extracted from v7)
│   │   ├── logs/                  # Generator run logs (git-ignored)
│   │   │   └── generator.log      # Detailed run output with DEBUG-level daily progress
│   │   └── data_generator_v7.py   # Star schema generator (~1,050 lines) — Phase 1 COMPLETE
│   └── schema/
│       └── dictionary.md          # Column-level docs for all tables
│
├── database/                      # DATABASE LAYER
│   ├── README.md
│   ├── docker-compose.yml         # Postgres 15 + pgAdmin services
│   ├── etl/
│   │   ├── logs/                  # ETL run logs
│   │   │   └── logs               # ETL log file
│   │   └── data_to_pg.py          # ETL: CSV → PostgreSQL — Phase 2 COMPLETE (logging, --dry-run, --incremental, retry logic, etl_load_log)
│   ├── migrations/
│   │   ├── 001_create_tables.sql  # DDL: 11 tables with FK constraints
│   │   ├── 002_kpi_views.sql      # 7 KPI views — Phase 3/5 COMPLETE (v_contact_metrics, v_promise_metrics, v_recovery_metrics, v_productivity_metrics, v_handle_time_metrics, v_daily_mis, v_monthly_summary)
│   │   └── 003_agents_scorecards.sql  # EMPTY — agent scorecard view (NEXT TASK)
│   └── seeds/                     # Static lookup data (products, calendar)
│       └── README.md
│
├── docs/                          # DOCUMENTATION LAYER
│   ├── data_dictionary.md         # Full data dictionary (10 tables)
│   ├── executive_summary.md       # One-page summary for leadership
│   ├── execution_guide.md         # Granular task instructions for each roadmap item
│   └── kpi_definitions.md         # Comprehensive KPI reference (319 lines)
│
├── reports/                       # EXCEL REPORTING LAYER
│   ├── templates/daily_mis.xlsx   # Daily MIS template
│   └── output/                    # Generated reports (git-ignored)
│
└── test/                          # TESTING LAYER (all EMPTY — Phase 6)
    ├── README.md
    ├── __init__.py
    ├── qa_validation.py           # EMPTY — data integrity checks
    ├── test_generator.py          # EMPTY — generator unit tests
    └── test_kpi_views.sql         # EMPTY — KPI view tests
```

## Data Model (Star Schema)

### Dimension Tables (6)
| Table | Rows | Description |
|-------|------|-------------|
| Dim_Supervisors | 8 | Team leads with region, tenure, hire date |
| Dim_Agents | 80 | Agents with supervisor FK, region, hire date |
| Dim_Clients | 10,000 | Clients with region, risk score, segment |
| Dim_Products | 3 | Credit Card, Personal Loan, Mortgage |
| Dim_Accounts | ~20,000 | Accounts with product/client FK, balance, DPD |
| Dim_Calendar | ~365 | Date dimension with flags (weekday, month, quarter) |

### Fact Tables (5 per month)
| Table | Description |
|-------|-------------|
| Fact_Interactions | Dialer calls, RPC/non-RPC, connection flags |
| Fact_PTP_Log | Promise-to-pay events, state machine (kept/broken) |
| Fact_Payments | Payment transactions, cure events |
| Fact_Agent_Time_Log | Agent utilization, handle time, ACW |
| Fact_EOM_Snapshot | End-of-month account snapshots |

## Key Business Logic
- **Event-driven PTP state machine**: promises transition through scheduled → kept/broken
- **Payday seasonality**: payment probability spikes on specific days
- **DPD anchored to billing cycles**: days past due tied to account lifecycle
- **Agent-Cure vs Self-Cure**: distinguishes agent-driven recoveries from automatic payments
- **Weekday-only processing**: no collections activity on weekends
- **Anomaly injection**: realistic edge cases in the data
- **Mora replenishment**: accounts can re-enter delinquency

## KPI Framework
- **Contact**: Total connections, RPC, RPC%, RPC/Operating Hour, RPC Arrears
- **Promise**: PTP, PTP%, Kept, Broken, Kept%, Broken-to-Bucket conversion
- **Recovery**: Cures, Cured amount, Cures/Total Handle Time
- **Productivity**: Utilization%, No Touch Letter rate
- **Handle Time**: AHT-RPC, AHT-NonRPC, ACW-RPC, ACW-NonRPC

## Conventions
- Python scripts use `pandas` for data manipulation, `psycopg2` for DB connectivity
- SQL follows PostgreSQL dialect
- Table naming: `Dim_` prefix for dimensions, `Fact_` prefix for facts
- CSVs in `data_sources/raw_csv/` are generated, never manually edited
- Old/unused versions kept in `06_docs/unused/` (not tracked in repo)
- All documentation in Markdown or HTML

## Commands
```bash
# Generate data
python data_sources/generators/data_generator_v7.py

# Start database
docker-compose -f database/docker-compose.yml up -d

# Ingest data into PostgreSQL
python database/etl/data_to_pg.py

# Create tables manually (if needed)
psql -h localhost -p 5433 -U rtrlpz -d MSI_CollectionsDB -f database/migrations/001_create_tables.sql

# Run full pipeline (Windows)
run_pipeline.bat
```

## Current State & Pending Work
- **DONE**: 
  - **Phase 1** (Data Generation) — 100% complete:
    - CLI args (--output-dir, --months, --seed, --log-level)
    - Logging (file + console handlers with DEBUG-level daily progress)
    - Per-stage timing (dimensions, simulation, export, validation)
    - Config extraction (config.py with CFG + PRODUCT_CFG)
    - Output validation (21 checks: row counts, PK nulls, FK integrity)
    - Anomaly injection tracking (anomaly_report.csv)
    - requirements.txt with pinned versions
  - **Phase 2** (ETL Pipeline) — 100% complete:
    - Logging (file + console handlers)
    - validate_csv() with PK validation, row count, headers
    - Transaction wrapping (atomicity with single transaction)
    - Idempotency (TRUNCATE CASCADE before load)
    - Environment variable support (--env-file flag)
    - --dry-run flag (validate without DB connection, exit 0/1)
    - --incremental flag (skip already-loaded months based on fact_interactions)
    - etl_load_log table (creates table, logs each load with SHA256 checksum)
    - Retry logic (up to 3 connection attempts with 5-second sleep)
    - Error recovery (savepoints per table, writes errors/<table>_errors.csv)
    - run_pipeline.bat (Docker check → generate → ETL → colored output)
  - **Phase 3/5** (KPI Views) — 100% complete:
    - 7 views in 002_kpi_views.sql: v_contact_metrics, v_promise_metrics, v_recovery_metrics, v_productivity_metrics, v_handle_time_metrics, v_daily_mis, v_monthly_summary

- **PENDING**: 
  - Agent scorecard view (database/migrations/003_agents_scorecards.sql) — NEXT TASK
  - 17 analysis SQL files (all skeletoned under analysis/sql/)
  - Test implementations (Phase 6)
  - Database indexes, constraints, comments (Phase 3 partial) — RECENTLY COMPLETED:
    - `004_indexes.sql` — 27 indexes (16 FK/date + 5 single-column + 6 composite)
    - `003_constraints.sql` — 15 CHECK constraints across all fact and dimension tables
    - `005_comments.sql` — COMMENT ON statements for all 11 tables and their columns
  - Automation (Phase 7)
  - BI/reporting (Phase 9)
  - Final docs (Phase 8)

- **EMPTY FILES** (skeletons awaiting content):
  - All 17 files under analysis/sql/
  - database/migrations/003_agents_scorecards.sql
  - test/test_generator.py, test/test_kpi_views.sql, test/qa_validation.py
  - run_pipeline.bat (now implemented)

- **KNOWN ISSUES**:
  - `psycopg2` module not installed — run `pip install -r requirements.txt`
  - .env file at `database/.env` (resolved in code with fallback path)

## Session Notes
- ROADMAP.md priority table: Phase 1 → Phase 2 → Phase 3(+5) → Phase 4 → Phase 6 → Phase 9 → Phase 7 → Phase 8
- Phase 1 is 100% complete.
- Phase 2 ETL improvements are complete:
  - `database/etl/data_to_pg.py` enhanced with logging (file + console handlers)
  - `validate_csv()` with PK validation (21 checks: row counts, PK nulls, dimension FK integrity, fact table completeness, fact FK integrity)
  - argparse with `--env-file`, `--dry-run`, `--incremental`, `--log-level` flags
  - `etl_load_log` table: creates table, logs each load with SHA256 checksum
  - Retry logic: up to 3 connection attempts with 5-second sleep between attempts
  - Error recovery: savepoints per table, writes `errors/<table>_errors.csv`
  - TRUNCATE CASCADE with error handling for non-existent tables
  - Per-table and total elapsed time tracking
  - All print() replaced with logging.info()/logging.error()
- Phase 3/5 KPI views are complete:
  - `database/migrations/002_kpi_views.sql` now contains 7 views: `v_contact_metrics`, `v_promise_metrics`, `v_recovery_metrics`, `v_productivity_metrics`, `v_handle_time_metrics`, `v_daily_mis`, `v_monthly_summary`
- `run_pipeline.bat` now implemented:
  - Docker check (`docker info >nul 2>&1`)
  - Data generation + ETL with exit code checks
  - Colored output (green=success, red=error, white=info)
  - Pauses at end for output review
- `ROADMAP.md` updated to mark completed tasks:
  - `etl_load_log` table ✓
  - CSV checksum verification ✓
  - `002_kpi_views.sql` with 7 views ✓
- Known issues:
  - `psycopg2` module not installed — run `pip install -r requirements.txt`
  - `.env` file at `database/.env` (resolved in code with fallback path)
- Next work to start: Agent scorecard view (`database/migrations/003_agents_scorecards.sql`)
