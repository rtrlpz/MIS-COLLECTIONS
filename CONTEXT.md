# MIS-COLLECTIONS — Project Context

## Project Overview
Simulated bank collections analytics portfolio project. Generates synthetic data for ~80 agents, ~10,000 clients, ~15,575 accounts across Credit Cards, Personal Loans, and Mortgages (Oct–Dec 2025). Models the full collections lifecycle: dialer interactions, RPC tracking, promise-to-pay management, payment/cure events, and agent utilization.

**Goal:** Portfolio piece demonstrating end-to-end data engineering + analytics for a Scotiabank-style collections department.

## Tech Stack
- **Python 3.x** — Data generation (Faker), ETL ingestion (pandas, psycopg2)
- **PostgreSQL 15** — Dockerized database with pgAdmin
- **SQL** — KPI views, exploratory analysis
- **Power BI** — Collections dashboard (.pbix)
- **Excel** — Daily MIS report generation (openpyxl)
- **Docker Compose** — Postgres + pgAdmin orchestration
- **pytest** — Testing framework (installed in mis-collections env)

## Directory Structure
```
MIS-COLLECTIONS/
├── .env                           # DB credentials (git-ignored) — at root, was database/.env
├── CLAUDE.md                      # Short AI-agent project context
├── CONTEXT.md                     # THIS FILE — single-source project overview
├── LICENSE
├── README.md                      # Project overview & interview pitch
├── ROADMAP.md                     # Phase-by-phase task checklist
├── requirements.txt               # Python deps (pinned versions)
├── run_pipeline.bat               # Windows batch: full pipeline (fixed: CONDA_PYTHON, ping, --env-file)
├── migrate.sh                     # DB migrations (ordering fixed: KPI views before scorecards)
│
├── analysis/                      # SQL ANALYSIS LAYER — 17 files, all complete
│   └── sql/
│       ├── agent_level_operational_supervisors/   # 6 files
│       ├── team_level_tactical_managers/          # 6 files
│       └── portfolio_level_strategic_directors/   # 5 files
│
├── dashboards/                    # VISUALIZATION LAYER
│   ├── assets/
│   │   ├── mis_collections_build_plan.md    # 396-line build plan
│   │   ├── reference_guide.html             # Business guide (1,555 lines)
│   │   └── screenshots/architecture_diagram.svg
│   ├── collections_project/
│   │   ├── collections_dashboard_v2.pbix    # Legacy (8.9 MB) — build plan says start fresh
│   ├── themes/
│   │   └── collections_theme.json          # Corporate theme
│   └── templates/
│       └── page_template.pbit
│
├── etl/                           # ETL LAYER (was database/etl/)
│   ├── data_to_pg.py              # CSV → PostgreSQL (path resolution fixed)
│   ├── errors/                    # Error CSVs from failed loads
│   └── logs/                      # ETL run logs (git-ignored)
│
├── data_sources/                  # DATA GENERATION LAYER
│   ├── generators/
│   │   ├── config.py             # CFG and PRODUCT_CFG dicts
│   │   ├── data_generator_v7.py   # Star schema generator (weekend bug FIXED)
│   │   └── raw/                   # Generated CSVs (git-ignored)
│   └── schema/dictionary.md
│
├── database/                      # DATABASE LAYER
│   ├── docker-compose.yml         # Postgres 15 + pgAdmin services
│   ├── migrations/
│   │   ├── 001_create_tables.sql  # DDL: 11 tables (DROPs before CREATEs)
│   │   ├── 002_kpi_views.sql      # 9 KPI views
│   │   ├── 003_constraints.sql    # 15 CHECK constraints
│   │   ├── 004_agents_scorecards.sql  # v_agent_scorecards
│   │   ├── 005_indexes.sql        # 27 indexes
│   │   └── 006_comments.sql       # 63 COMMENT ON (payments comment updated)
│   └── seeds/
│       ├── 001_dim_products.sql   # 3 product seed rows
│       └── 002_dim_calendar.sql   # 365 calendar rows (full year 2025)
│
├── docs/                          # DOCUMENTATION LAYER
│   ├── execution_guide.md         # 14,877-word enterprise build guide (13 sections)
│   ├── kpi_definitions.md         # KPI formulas, targets, benchmarks
│   ├── data_dictionary.md         # Column-level metadata
│   ├── executive_summary.md       # One-page leadership summary
│   ├── ROADMAP.md                 # Phase tracker — 82% complete
│   └── interviews/                # Case study prep materials
│
├── reports/                       # EXCEL REPORTING LAYER
│   └── templates/                 # (pending Phase D build)
│
├── test/                          # TESTING LAYER — 41 fast tests passing
│   ├── conftest.py               # Pytest fixtures
│   ├── qa_validation.py          # Data integrity tests (weekend test: PASSING)
│   └── test_generator.py          # Generator unit tests
│
├── dax/                           # DAX source control (exported via Tabular Editor)
│   ├── _contact_and_volume.dax
│   ├── _promise_and_recovery.dax
│   └── _portfolio_and_trends.dax
│
└── security/                      # RLS configuration
    └── rls_test_users.csv
```

## Data Model (Star Schema)

### Dimension Tables (6)
| Table | Rows | Description |
|-------|------|-------------|
| Dim_Supervisors | 8 | Team leads with region, team name |
| Dim_Agents | 80 | Agents with supervisor FK, skill score |
| Dim_Clients | 10,000 | Clients with segment, risk score |
| Dim_Products | 3 | Credit Card, Personal Loan, Mortgage |
| Dim_Accounts | ~15,575 | Accounts with product/client FK, balance, DPD |
| Dim_Calendar | 92 (gen) / 365 (seed) | Date dimension with weekday/payday flags |

### Fact Tables (5 per month)
| Table | Rows (3mo) | Description |
|-------|------------|-------------|
| Fact_Interactions | ~500K | Dialer calls, RPC/non-RPC, AHT/ACW (weekdays only) |
| Fact_PTP_Log | ~31K | Promise-to-pay events, Kept/Broken state machine |
| Fact_Payments | ~21K | Payment transactions, Agent-Cure vs Self-Cure (weekends OK) |
| Fact_Agent_Time_Log | ~5K | Agent login/logout, utilization, handle time |
| Fact_EOM_Snapshot | ~47K | End-of-month account snapshots with DPD buckets |

## Key Business Logic
- **Event-driven PTP state machine**: promises transition through scheduled → kept/broken
- **Payday seasonality**: payment probability spikes on specific days
- **DPD anchored to billing cycles**: days past due tied to account lifecyle
- **Agent-Cure vs Self-Cure**: distinguishes agent-driven recoveries from automatic payments
- **Payments on any date**: payment_date = date made, not processed — weekend payments allowed
- **Weekday-only interactions**: no call center activity on weekends (bug FIXED — 0 weekend interactions now)
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

# Run full pipeline (Windows)
./run_pipeline.bat

# Run migrations manually
bash migrate.sh

# Run tests (fast only — 41 tests, weekend test now PASSING)
python -m pytest test/ -v -m "not slow"

# Run all tests (including slow ETL idempotency and generator seed tests)
python -m pytest test/ -v
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
- **Weekend bug FIXED**: Interactions now Mon-Fri only; payments allowed on any date (2,228 weekend payments, 0 weekend interactions)
- **Dead code removed**: `next_weekday()` function deleted
- **Generates**: ~500K interactions, ~31K PTP events, ~21K payments across 3 months

#### Phase 2 (ETL Pipeline) — 100% Complete (Moved to root)
- `etl/` directory moved from `database/etl/` to root
- `database/etl/write_script.py` deleted (dead code)
- Empty `database/etl/` directory removed
- Path resolution in `data_to_pg.py` corrected
- Logging (file + console handlers)
- validate_csv() with PK validation, row count, headers
- Transaction wrapping (atomicity with single transaction)
- Idempotency (TRUNCATE CASCADE before load)
- Environment variable support (--env-file flag)
- --dry-run flag (validate without DB connection, exit 0/1)
- --incremental flag (skip already-loaded months)
- etl_load_log table (creates table, logs each load with SHA256 checksum)
- Retry logic (up to 3 connection attempts with 5-second sleep)
- Error recovery (savepoints per table, writes errors/<table>_errors.csv)
- Per-table and total elapsed time tracking

#### Phase 3/5 (KPI Views & Database Layer) — 100% Complete

**9 KPI Views** in `002_kpi_views.sql`:
1. `v_contact_metrics`
2. `v_promise_metrics`
3. `v_recovery_metrics`
4. `v_productivity_metrics`
5. `v_handle_time_metrics`
6. `v_daily_mis`
7. `v_monthly_summary`
8. `v_etl_load_summary`
9. `v_data_freshness`

**Database Enhancements**:
- `003_constraints.sql` — 15 CHECK constraints
- `004_agents_scorecards.sql` — v_agent_scorecards
- `005_indexes.sql` — 27 indexes
- `006_comments.sql` — 63 COMMENT ON statements (fact_payments.payment_date updated to note weekend allowance)
- Seed files with `ON CONFLICT DO NOTHING` for idempotency
- **Migration ordering fixed**: 002_kpi_views.sql runs before 004_agents_scorecards.sql (was referencing non-existent v_monthly_summary)

#### Phase 4 (Analysis SQL Files) — 100% Complete (17 of 17)
All 17 SQL files verified with valid content — none empty.

#### Phase 6 (Testing) — 100% Complete
- `test/conftest.py` — Pytest fixtures
- `test/qa_validation.py` — Data integrity tests:
  - 41 fast tests passing (0 failures)
  - **Weekend test**: Now PASSING (was XFAIL) — `test_no_weekend_interactions` confirms 0 weekend interactions
  - Test structure unchanged — only removed `pytest.xfail()` marker
- `test/test_generator.py` — Generator unit tests

#### Phase 7 (Automation) — 100% Complete
- `run_pipeline.bat` — Fixed: `timeout /t 2` → `ping -n 3 localhost` (cross-shell), `python` → `%CONDA_PYTHON%`, added `--env-file .env` for docker-compose
- `migrate.sh` — Ordering fixed: 002 before 004
- `.env` moved from `database/.env` to `./.env`
- Pipeline end-to-end verified: ~157s (all 3 months loaded)
- Data status: All 3 months (Oct-Dec 2025) loaded in PostgreSQL

### ⏳ PENDING (Next Phases)

#### Phase C — Power BI Dashboard Build (formerly Phase 9)
- Build fresh PBIX (not modify existing collections_dashboard_v2.pbix)
- 5 pages: Executive, Agent Scorecard, Team Performance, Portfolio Health, Promise Intelligence
- Import mode, star schema, 70+ DAX measures, RLS by supervisor team
- Build plan at `dashboards/assets/mis_collections_build_plan.md`
- No longer blocked by weekend bug — clean data ready

#### Phase D — Excel Daily MIS Report
- Python (openpyxl) script at `reports/generate_daily_mis.py`
- 3 sheets: KPI dashboard, Agent deep dive, Methodological notes
- Queries `v_daily_mis` directly

#### Phase E — Publishing & Governance
- Publish PBIX to Power BI Service
- Schedule gateway refresh
- Distribute Excel report
- RLS testing
- User guide + handoff

### ✅ RESOLVED ISSUES
- ~~Weekend interactions bug~~ — **FIXED**: Interactions Mon-Fri only; payments allowed on weekends
- ~~`psycopg2` module not installed~~ — **RESOLVED**
- ~~`pytest` not installed~~ — **RESOLVED**
- ~~`run_pipeline.bat` COLOR bug~~ — **RESOLVED**
- ~~Migration ordering~~ — **FIXED**: 002_kpi_views.sql runs before 004_agents_scorecards.sql
- ~~`.env` at `database/.env`~~ — **MOVED**: Now at `./.env` (project root)
- ~~`database/etl/`~~ — **MOVED**: ETL now at root `etl/`
- ~~`database/etl/write_script.py`~~ — **DELETED**: Dead code removed

### 🐛 KNOWN BUGS
- None currently. Weekend interaction bug is fixed. Pipeline verified end-to-end.

## Key Documents
- `docs/execution_guide.md` — 14,877-word enterprise Power BI build guide (13 sections, replaces old task-level document)
- `dashboards/assets/mis_collections_build_plan.md` — 396-line build plan for Phase C/D/E
- `dashboards/assets/reference_guide.html` — 1,555-line DAX reference with 70+ measures
- `docs/kpi_definitions.md` — Business formulas and benchmarks for all KPIs

## Session Notes
- **Weekend rule changed**: Payments now allowed on weekend dates (payment_date = date made, not processed). Interactions remain weekday-only.
- **Generator changes**: 7 edits to `data_generator_v7.py` — removed `if is_wkday:` guards for payment processing and self-cures, removed `next_weekday()` function, changed interaction guard to weekday-only, updated docstring.
- **Test changes**: Removed `pytest.xfail()` from `test_no_weekend_interactions` — test now passes.
- **Comment changes**: Updated `006_comments.sql` fact_payments.payment_date description.
- **execution_guide.md replaced**: Old 1,547-line task-prompt document replaced with 2,499-line enterprise architecture guide with 13 sections, wireframes, DAX patterns, RLS architecture.
- **Data flow**: Generator → CSVs → ETL → PostgreSQL → Power BI Import (~500K rows, ~100 MB compressed) → Excel (openpyxl)
- **Pipeline timing**: ~157s end-to-end (up from ~83s due to 3 months of data vs 1 month previously)
- **Test count**: 41 fast tests passing (was 9 of 11 with 1 xfail)

## Quick Reference
- **Project root**: `C:\Users\Leand\Desktop\Portafolio-Projects\MIS-COLLECTIONS`
- **Conda env**: `mis-collections`
- **DB connection**: host=localhost, port=5433, user=rtrlpz, password=rtrlpz, db=MSI_CollectionsDB
- **Pipeline command**: `./run_pipeline.bat` (from project root in CMD)
- **Run tests**: `python -m pytest test/ -v -m "not slow"`
- **execution_guide.md**: `docs/execution_guide.md` (2,499 lines, 13 sections)
- **Build plan**: `dashboards/assets/mis_collections_build_plan.md` (5 phases, A→E)
