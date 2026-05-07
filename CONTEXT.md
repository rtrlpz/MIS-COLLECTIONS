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
- **pytest** — Testing framework (installed in mis-collections env)

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
├── analysis/                      # SQL ANALYSIS LAYER (17 files — 13 of 17 COMPLETE)
│   ├── README.md
│   └── sql/
│       ├── agent_level_operational_supervisors/   # 6 files: 3 COMPLETE, 3 remaining
│       ├── team_level_tactical_managers/          # 6 files: ALL COMPLETE
│       └── portfolio_level_strategic_directors/   # 5 files: 4 COMPLETE, 1 remaining
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
│   │   ├── 002_kpi_views.sql      # 9 KPI views — Phase 3/5 COMPLETE
│   │   ├── 003_constraints.sql     # 15 CHECK constraints (Phase 3 COMPLETE)
│   │   ├── 004_agents_scorecards.sql  # v_agent_scorecards (Phase 3 COMPLETE)
│   │   ├── 005_indexes.sql          # 27 indexes (Phase 3 COMPLETE)
│   │   └── 006_comments.sql       # 63 COMMENT ON statements (Phase 3 COMPLETE)
│   └── seeds/
│       ├── 001_dim_products.sql   # 3 product seed rows
│       ├── 002_dim_calendar.sql  # 92 calendar rows (Oct-Dec 2025)
│       └── README.md
│
├── docs/                          # DOCUMENTATION LAYER
│   ├── data_dictionary.md         # Full data dictionary (10 tables)
│   ├── executive_summary.md       # One-page summary for leadership
│   ├── execution_guide.md         # Granular task instructions
│   ├── kpi_definitions.md         # Comprehensive KPI reference (319 lines)
│   ├── interviews/
│   │   ├── interview_prep/business_guide.html
│   │   ├── interview_prep/sql_cheatsheet.md
│   │   └── interview_prep/talking_points.md
│   ├── setup/
│   │   ├── github_projects_import.csv
│   │   └── notion_import.csv
│   └── TODO/                      # Miscellaneous planning docs
│
├── reports/                       # EXCEL REPORTING LAYER
│   ├── templates/daily_mis.xlsx   # Daily MIS template
│   └── output/                    # Generated reports (git-ignored)
│
└── test/                          # TESTING LAYER (Phase 6 COMPLETE)
    ├── README.md
    ├── __init__.py
    ├── conftest.py               # Pytest fixtures (DB connection, metadata)
    ├── qa_validation.py          # 11 data integrity tests (9 fast + 2 slow)
    ├── test_generator.py          # Generator unit tests
    └── test_kpi_views.sql       # SQL validation queries for KPI views
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
- **Weekday-only processing**: no collections activity on weekends (**NOTE: Generator bug creates 25,786 weekend interactions**)
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
- Test files use pytest with fixtures in `conftest.py`

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

# Run tests (fast only - excludes slow tests)
cd C:\Users\Leand\Desktop\Portafolio-Projects\MIS-COLLECTIONS
/c/Users/Leand/.conda/envs/mis-collections/python -m pytest test/ -v -m "not slow"

# Run all tests (including slow ETL idempotency and generator seed tests)
/c/Users/Leand/.conda/envs/mis-collections/python -m pytest test/ -v
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
8. `v_etl_load_summary` — Latest ETL load per table with data freshness
9. `v_data_freshness` — Shows days since each fact table was last updated

**Database Enhancements**:
- `003_constraints.sql` — 15 CHECK constraints with idempotent DO blocks
- `004_agents_scorecards.sql` — v_agent_scorecards view with composite scoring
- `005_indexes.sql` — 27 indexes (16 FK/date + 5 single-column + 6 composite)
- `006_comments.sql` — 63 COMMENT ON statements for all 11 tables and columns
- Seed files with `ON CONFLICT DO NOTHING` for idempotency

#### Phase 6 (Testing) — 100% Complete
- `test/conftest.py` — Pytest fixtures (DB connection, table metadata, PK/FK mappings, KPI views, custom `slow` mark)
- `test/qa_validation.py` — 11 data integrity tests:
  1. ✅ Row counts (Dim_Agents=80, Dim_Clients=10000, Dim_Accounts~15575 ±5%)
  2. ✅ No null PKs across all tables
  3. ✅ FK integrity (all FK values exist in referenced dimension tables)
  4. ✅ Date ranges (fact dates within Oct-Dec 2025, calendar covers Oct-Dec 2025)
  5. ❌ No weekend interactions (XFAIL - generator bug creates 25,786 weekend rows)
  6. ✅ DPD >= 0 in all tables
  7. ✅ Utilization BETWEEN 0 AND 100
  8. ✅ AHT > 0s, max < 3600s
  9. ✅ KPI views return rows, percentages in 0-100 range
  10. 🐌 ETL idempotency (marked `@pytest.mark.slow`)
  11. 🐌 Generator seed reproducibility (marked `@pytest.mark.slow`)
- `test/test_generator.py` — Generator unit tests:
  - TestGeneratorOutput: output structure, reproducibility, data quality
  - TestGeneratorReproducibility: seed reproducibility
  - TestGeneratorDataQuality: no null PKs in generated data
- `test/test_kpi_views.sql` — SQL validation queries for KPI views

#### Phase 7 (Automation) — 100% Complete
- `run_pipeline.bat` — Docker check → start containers → wait for PostgreSQL → migrations → generate data → ETL → colored output → timing per stage
- **COLOR bug fixed**: Removed trailing colons from COLOR commands
- Pipeline runs end-to-end in ~83 seconds
- `migrate.sh` — Runs all SQL migrations by piping via `cat file.sql | docker exec -i psql`

### ⏳ PENDING (Next Phases)

#### Phase 4 (Analysis SQL Files) — IN PROGRESS (13 of 17 COMPLETE)
**Agent Level (6 files)**:
- ✅ `coaching_opportunities.sql` — COMPLETE
- ✅ `schedule_adherence.sql` — COMPLETE
- ✅ `eda_agents.sql` — COMPLETE
- ❌ `daily_agent_activity.sql` — EMPTY
- ❌ `agent_scorecard.sql` — EXISTS (uses v_agent_scorecards)
- ❌ `agent_exception_report.sql` — EMPTY

**Team Level (6 files)** — ALL COMPLETE:
- ✅ `team_comparison.sql`
- ✅ `agent_leaderboard.sql`
- ✅ `handle_time_benchmark.sql`
- ✅ `workload_distribution.sql`
- ✅ `campaign_effectiveness.sql`
- ✅ `eda_supervisors.sql`

**Portfolio Level (5 files)**:
- ✅ `target_vs_actual.sql` — COMPLETE
- ✅ `portfolio_concentration.sql` — COMPLETE
- ✅ `recovery_trend_mom.sql` — COMPLETE
- ✅ `roll_rate_analysis.sql` — COMPLETE
- ❌ `portfolio_health.sql` — EMPTY

#### Phase 9 (BI/Reporting)
- Build Power BI dashboard using collections_dashboard_v2.pbix template
- Create Excel reports from templates

#### Phase 8 (Final Documentation)
- Update ROADMAP.md with completed tasks
- Finalize executive summary and interview materials

### 📋 EMPTY FILES (Skeletons Awaiting Content)
**Analysis SQL (3 remaining)**:
- `analysis/sql/agent_level_operational_supervisors/daily_agent_activity.sql`
- `analysis/sql/agent_level_operational_supervisors/agent_exception_report.sql`
- `analysis/sql/portfolio_level_strategic_directors/portfolio_health.sql`

### 🧹 FILES TO CLEAN UP (Unused)
- `run_pipeline.ps1` — Unfinished PowerShell version (can delete)
- `run_migration.sh` — Duplicate of migrate.sh (can delete)
- `002_kpi_views.sql.bak` — Backup file (can delete)

### ✅ RESOLVED ISSUES
- ~~`psycopg2` module not installed~~ — **RESOLVED**: Installed in mis-collections conda env
- ~~`pytest` not installed~~ — **RESOLVED**: `pip install pytest` in mis-collections env
- ~~`run_pipeline.bat` COLOR bug~~ — **RESOLVED**: Removed trailing colons from COLOR commands
- `.env` file at `database/.env` — Resolved in code with fallback path

### 🐛 KNOWN BUGS
- **Weekend interactions**: Generator creates 25,786 weekend interactions despite business rule "weekday-only processing". `Dim_Calendar.is_weekday` is correctly set to FALSE for weekends, but `data_generator_v7.py` doesn't filter weekend dates when generating interactions.

## Session Notes
- **ROADMAP.md priority order**: Phase 1 → Phase 2 → Phase 3(+5) → Phase 4 → Phase 6 → Phase 9 → Phase 7 → Phase 8
- **PostgreSQL container**: `postgres_collections`, port 5433 (external), 5432 (internal)
- **Migration approach**: `bash migrate.sh` calls `cat file.sql | docker exec -i psql`
- **All 9 KPI views verified** in pgAdmin after migration
- **etl_load_log table**: tracks table_name, rows_loaded, loaded_at, status, csv_checksum
- **Pipeline data volumes**: ~506K interactions, ~31K PTP events, ~21K payments across 3 months (Oct-Dec 2025)
- **Fact_EOM_Snapshot**: 15,575 accounts (not ~20,000 as originally estimated)
- **psycopg2 confirmed installed** in `mis-collections` conda environment
- **pytest installed** in `mis-collections` conda environment for testing

## Next Steps (After Session)
1. **Clean up unused files**: Delete `run_pipeline.ps1`, `run_migration.sh`, `002_kpi_views.sql.bak`
2. **Phase 4**: Complete remaining 3 analysis SQL files:
   - `daily_agent_activity.sql`
   - `agent_exception_report.sql`
   - `portfolio_health.sql`
3. **Fix generator bug**: Update `data_generator_v7.py` to filter weekend dates (remove 25,786 weekend interactions)
4. Phase 9: Build BI dashboard
5. Phase 8: Finalize documentation

## Session Notes (Current Session - Phase 6 Completion)
- **Completed Phase 6 (Testing)**:
  - Created `test/conftest.py` with DB connection fixture and metadata fixtures
  - Created `test/qa_validation.py` with 11 tests (9 fast + 2 slow)
  - Created `test/test_generator.py` with generator unit tests
  - Created `test/test_kpi_views.sql` with SQL validation queries
- **Test results**: 9 of 11 tests pass, 1 xfail (weekend bug), 2 marked slow
- **Known limitations**: No tenure data in dim_agents/dim_supervisors, no account-to-region mapping in fact_eom_snapshot
- **Data status**: Only October 2025 loaded - MoM comparisons return NULL until Nov/Dec loaded

## Quick Reference
- **Project root**: `C:\Users\Leand\Desktop\Portafolio-Projects\MIS-COLLECTIONS`
- **Conda env**: `mis-collections`
- **DB connection**: host=localhost, port=5433, user=rtrlpz, db=MSI_CollectionsDB
- **Pipeline command**: `./run_pipeline.bat` (from project root in CMD)
- **Verify views**: `SELECT * FROM v_etl_load_summary;` or `SELECT * FROM v_data_freshness;`
- **Run tests**: `/c/Users/Leand/.conda/envs/mis-collections/python -m pytest test/ -v -m "not slow"`
