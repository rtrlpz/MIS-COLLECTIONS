# MIS-COLLECTIONS — Project Context

## Project Overview
Simulated bank collections analytics portfolio project. Generates synthetic data for ~80 agents, ~10,000 clients, ~15,575 accounts across Credit Cards, Personal Loans, and Mortgages (Oct–Dec 2025). Models the full collections lifecycle: dialer interactions, RPC tracking, promise-to-pay management, payment/cure events, and agent utilization.

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
├── .idea/                         # JetBrains IDE config files
├── CONTEXT.md                     # THIS FILE — single-source project overview
├── LICENSE
├── README.md                      # Project overview & interview pitch
├── ROADMAP.md                     # Phase-by-phase task checklist
├── requirements.txt               # Python deps (pinned versions)
├── run_pipeline.bat               # Windows batch to run full pipeline (Phase 7 COMPLETE, COLOR bug fixed)
├── migrate.sh                     # Bash script for DB migrations (called by run_pipeline.bat)
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
│   │   ├── dax_measures_dictionary.pdf/.docx
│   │   └── screenshots/architecture_diagram.svg
│   ├── collections_project/collections_dashboard_v2.pbix
│   └── dax_measures_dictionary.md
│
├── data_sources/                  # DATA GENERATION LAYER
│   ├── README.md
│   ├── __init__.py
│   ├── generators/
│   │   ├── __init__.py
│   │   ├── config.py             # CFG and PRODUCT_CFG dicts (extracted from v7)
│   │   ├── data_generator_v7.py   # Star schema generator (~1,050 lines) — Phase 1 COMPLETE
│   │   └── README.md
│   └── schema/
│       └── dictionary.md          # Column-level docs for all tables
│
├── database/                      # DATABASE LAYER
│   ├── README.md
│   ├── .env                      # Environment variables for DB connection
│   ├── docker-compose.yml         # Postgres 15 + pgAdmin services
│   ├── etl/
│   │   ├── data_to_pg.py          # ETL: CSV → PostgreSQL — Phase 2 COMPLETE
│   │   ├── write_script.py        # Utility script
│   │   └── logs/                  # ETL run logs (git-ignored)
│   ├── migrations/
│   │   ├── 001_create_tables.sql  # DDL: 11 tables with FK constraints
│   │   ├── 002_kpi_views.sql      # 9 KPI views — Phase 3/5 COMPLETE (v_contact_metrics, v_promise_metrics, v_recovery_metrics, v_productivity_metrics, v_handle_time_metrics, v_daily_mis, v_monthly_summary, v_etl_load_summary, v_data_freshness)
│   │   ├── 003_constraints.sql     # 15 CHECK constraints (Phase 3 COMPLETE)
│   │   ├── 004_agents_scorecards.sql  # v_agent_scorecards with composite scoring (Phase 3 COMPLETE)
│   │   ├── 005_indexes.sql          # 27 indexes (Phase 3 COMPLETE)
│   │   └── 006_comments.sql       # 63 COMMENT ON statements (Phase 3 COMPLETE)
│   └── seeds/
│       ├── 001_dim_products.sql   # 3 product seed rows with ON CONFLICT DO NOTHING
│       ├── 002_dim_calendar.sql  # 365 calendar rows for 2025 with ON CONFLICT DO NOTHING
│       └── README.md
│
├── docs/                          # DOCUMENTATION LAYER
│   ├── data_dictionary.md         # Full data dictionary (10 tables)
│   ├── executive_summary.md       # One-page summary for leadership
│   ├── execution_guide.md         # Granular task instructions for each roadmap item
│   ├── kpi_definitions.md         # Comprehensive KPI reference (319 lines)
│   ├── interviews/
│   │   ├── interview_prep/business_guide.html
│   │   ├── interview_prep/sql_cheatsheet.md
│   │   └── interview_prep/talking_points.md
│   ├── setup/
│   │   ├── github_projects_import.csv
│   │   └── notion_import.csv
│   └── TODO/                      # Miscellaneous planning docs (not tracked)
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
| Dim_Accounts | ~15,575 | Accounts with product/client FK, balance, DPD |
| Dim_Calendar | ~92 | Date dimension with flags (weekday, month, quarter) |

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
- **Anomaly injection**: realistic edge cases in the data (~9,117 injected)
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
- CSVs in `data_sources/generators/raw/` are generated, never manually edited
- All documentation in Markdown or HTML

## Commands
```bash
# Generate data
python data_sources/generators/data_generator_v7.py

# Start database
docker-compose -f database/docker-compose.yml up -d

# Ingest data into PostgreSQL
python database/etl/data_to_pg.py

# Run full pipeline (Windows)
./run_pipeline.bat

# Run migrations manually
bash migrate.sh
```

## Current State & Pending Work

### ✅ DONE (Completed Phases)

#### Phase 1 (Data Generation) — 100% Complete
- CLI args (--output-dir, --months, --seed, --log-level)
- Logging (file + console handlers with DEBUG-level daily progress)
- Per-stage timing (dimensions, simulation, export, validation)
- Config extraction (config.py with CFG + PRODUCT_CFG)
- Output validation (21 checks: row counts, PK nulls, FK integrity)
- Anomaly injection tracking (anomaly_report.csv with ~9,117 anomalies)
- requirements.txt with pinned versions
- **Generates**: ~506K interactions, ~31K PTP events, ~21K payments across 3 months

#### Phase 2 (ETL Pipeline) — 100% Complete
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
- Per-table and total elapsed time tracking

#### Phase 3/5 (KPI Views & Database Layer) — 100% Complete

**9 KPI Views** in `002_kpi_views.sql`:
1. `v_contact_metrics` — Contact KPIs per agent/day/team/month
2. `v_promise_metrics` — Promise KPIs with PTP%, Kept%, Broken tracking
3. `v_recovery_metrics` — Recovery KPIs (cures, cured amounts, agent vs self-cures)
4. `v_productivity_metrics` — Utilization%, contacts/hour, no-touch rate
5. `v_handle_time_metrics` — AHT and ACW separated by RPC/non-RPC
6. `v_daily_mis` — Consolidated daily view combining all KPI categories
7. `v_monthly_summary` — Month-level rollup for dashboard trends
8. `v_etl_load_summary` — Latest ETL load per table with data freshness (CREATES etl_load_log table)
9. `v_data_freshness` — Shows days since each fact table was last updated

**Database Enhancements**:
- `003_constraints.sql` — 15 CHECK constraints with idempotent DO blocks
- `004_agents_scorecards.sql` — v_agent_scorecards view with composite scoring (5 KPIs weighted 25%/25%/20%/15%/15%)
- `005_indexes.sql` — 27 indexes (16 FK/date + 5 single-column + 6 composite)
- `006_comments.sql` — 63 COMMENT ON statements for all 11 tables and columns
- Seed files with `ON CONFLICT DO NOTHING` for idempotency

#### Phase 7 (Automation) — 100% Complete
- `run_pipeline.bat` — Docker check → start containers → wait for PostgreSQL → migrations (bash migrate.sh) → generate data → ETL → colored output → timing per stage
- **COLOR bug fixed**: Removed trailing colons from COLOR commands (was causing help text spam)
- Pipeline runs end-to-end in ~83 seconds
- `migrate.sh` — Runs all SQL migrations by piping via `cat file.sql | docker exec -i psql`

### ⏳ PENDING (Next Phases)

#### Phase 4 (Analysis SQL Files) — NEXT TO START
- 17 analysis SQL files (all skeletoned under analysis/sql/)
- **Agent Level (6 files)**: daily_agent_activity, agent_scorecard, agent_exception_report, coaching_opportunities, schedule_adherence, eda_agents
- **Team Level (6 files)**: team_comparison, agent_leaderboard, handle_time_benchmark, workload_distribution, campaign_effectiveness, eda_supervisors
- **Portfolio Level (5 files)**: portfolio_health, recovery_trend_mom, target_vs_actual, portfolio_concentration, roll_rate_analysis

#### Phase 6 (Testing)
- test/test_generator.py — Generator unit tests
- test/test_kpi_views.sql — KPI view tests
- test/qa_validation.py — Data integrity checks

#### Phase 9 (BI/Reporting)
- Build Power BI dashboard using collections_dashboard_v2.pbix template
- Create Excel reports from templates

#### Phase 8 (Final Documentation)
- Update ROADMAP.md with completed tasks
- Finalize executive summary and interview materials

### 📋 EMPTY FILES (Skeletons Awaiting Content)
- All 17 files under analysis/sql/
- test/test_generator.py, test/test_kpi_views.sql, test/qa_validation.py

### 🧹 FILES TO CLEAN UP (Unused)
- `run_pipeline.ps1` — Unfinished PowerShell version (can delete)
- `run_migration.sh` — Duplicate of migrate.sh (can delete)
- `002_kpi_views.sql.bak` — Backup file (can delete)

### ✅ RESOLVED ISSUES
- ~~`psycopg2` module not installed~~ — **RESOLVED**: `pip install psycopg2` shows "Requirement already satisfied"
- ~~`run_pipeline.bat` COLOR bug~~ — **RESOLVED**: Removed trailing colons from COLOR commands
- `.env` file at `database/.env` — Resolved in code with fallback path

## Session Notes
- **ROADMAP.md priority order**: Phase 1 → Phase 2 → Phase 3(+5) → Phase 4 → Phase 6 → Phase 9 → Phase 7 → Phase 8
- **PostgreSQL container**: `postgres_collections`, port 5433 (external), 5432 (internal)
- **Migration approach**: `bash migrate.sh` calls `cat file.sql | docker exec -i psql` (not direct psql which fails in Windows PATH)
- **All 9 KPI views verified** in pgAdmin after migration
- **etl_load_log table**: tracks table_name, rows_loaded, loaded_at, status, csv_checksum
- **Pipeline data volumes**: ~506K interactions, ~31K PTP events, ~21K payments across 3 months (Oct-Dec 2025)
- **Fact_EOM_Snapshot**: 15,575 accounts (not ~20,000 as originally estimated)
- **psycopg2 confirmed installed** in `mis-collections` conda environment

## Next Steps (After Session)
1. **Clean up unused files**: Delete `run_pipeline.ps1`, `run_migration.sh`, `002_kpi_views.sql.bak`
2. **Phase 4**: Implement 17 analysis SQL files (priority per ROADMAP.md)
3. Phase 6: Implement test files
4. Phase 9: Build BI dashboard
5. Phase 8: Finalize documentation

## Quick Reference
- **Project root**: `C:\Users\Leand\Desktop\Portafolio-Projects\MIS-COLLECTIONS`
- **Conda env**: `mis-collections`
- **DB connection**: host=localhost, port=5433, user=rtrlpz, db=MSI_CollectionsDB
- **Pipeline command**: `./run_pipeline.bat` (from project root in CMD)
- **Verify views**: `SELECT * FROM v_etl_load_summary;` or `SELECT * FROM v_data_freshness;`
