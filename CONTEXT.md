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
│   │   ├── dax_measures_dictionary.md       # 73 DAX measures (type-safe TRUE()/FALSE())
│   │   ├── mis_collections_build_plan.md    # 396-line build plan
│   │   ├── reference_guide.html             # Business guide (1,555 lines)
│   │   ├── fix_syntetic_data.md             # Generator calibration plan
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
├── test/                          # TESTING LAYER — 74 fast tests passing
│   ├── conftest.py               # Pytest fixtures + GENERATOR_ROW_COUNTS + METRIC_RANGES
│   ├── qa_validation.py          # Data integrity + metric percentile-range tests
│   └── test_generator.py          # Generator unit tests + Phase 6 invariant tests (10 total)
│
└── security/                      # RLS configuration
    └── rls_test_users.csv
```

## Data Model (Star Schema)

### Dimension Tables (6)
| Table | Rows | Description |
|-------|------|-------------|
| Dim_Supervisors | 8 | Standalone reference table (no FK linkage to Dim_Agents) |
| Dim_Agents | 80 | Agents with denormalized supervisor_name, team_name, region, tenure_cohort, 3 skill dimensions |
| Dim_Clients | 10,000 | Clients with segment, risk score |
| Dim_Products | 3 | Credit Card, Personal Loan, Mortgage |
| Dim_Accounts | ~15,575 | Accounts with product/client FK, balance, DPD |
| Dim_Calendar | 122 (gen) / 365 (seed) | Date dimension with weekday/payday flags (Sep–Dec 2025) |

### Fact Tables (5 per month)
| Table | Rows (3mo) | Description |
|-------|------------|-------------|
| Fact_Interactions | ~343K (seed 42) | Dialer calls, RPC/non-RPC, AHT/ACW (weekdays only) |
| Fact_PTP_Log | ~22K (seed 42) | Promise-to-pay events, Kept/Broken state machine |
| Fact_Payments | ~20K (seed 42) | Payment transactions, Agent-Cure vs Self-Cure (weekends OK) |
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
- **Progressive severity**: self-cure rate decays by `0.5^cure_count` (min 0.1); agent connection rate penalized for repeat-offender accounts; AHT/ACW increases for escalated collection stages
- **Monitoring pool**: `other_pool` restricted to accounts that have ever been in Mora — no calling clean Activo accounts
- **Utilization cap**: clamped at 0.95 to reflect unavoidable idle/wrap-up time

## KPI Framework
- **Contact**: Total connections, RPC, RPC%, RPC/Operating Hour, RPC Arrears
- **Promise**: PTP, PTP%, Kept, Broken, Kept%, Broken-to-Bucket conversion
- **Recovery**: Cures, Cured amount, Cures/Total Handle Time
- **Productivity**: Utilization%, Contacts per Agent Hour
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

# Run tests (fast only — 74 tests passing)
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
- **Generates**: ~344K interactions, ~28K PTP events, ~23K payments across 3 months (post-calibration)
- **Config calibrated** (May 2026): 11 parameter changes + 2 new params to match real-data medians (connects/day ~48, RPC% 45.9, PTP% 73.0, KP% 80.6). See Session Notes for full diff.
- **Skill split**: Single `skill_score` replaced with 3 independent dimensions (`contact_skill`, `negotiation_skill`, `efficiency_skill`) plus `tenure_cohort` (Low/Mid/High) in Dim_Agents
- **Monthly drift**: ±8% per-agent rate drift regenerated each calendar month, matching real RPC% swings (38%–67%)

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

**9 KPI Views** in `002_kpi_views.sql` (all joins to `dim_supervisors` removed — data sourced from denormalized `dim_agents`):
1. `v_contact_metrics`
2. `v_promise_metrics`
3. `v_recovery_metrics`
4. `v_productivity_metrics`
5. `v_handle_time_metrics`
6. `v_daily_mis`
7. `v_monthly_summary`
8. `v_etl_load_summary`
9. `v_data_freshness`

**Schema Design Changes**:
- **Dim_Agents denormalized**: `supervisor_name`, `team_name`, `region` moved into `dim_agents` — removes FK to `dim_supervisors` (VertiPaq-friendly, simplifies Power BI DAX)
- `dim_supervisors` retained as standalone reference table (no enforced FK linkage)
- `003_constraints.sql` — 15 CHECK constraints
- `004_agents_scorecards.sql` — v_agent_scorecards
- `005_indexes.sql` — 27 indexes
- `006_comments.sql` — 63 COMMENT ON statements; dim_agent column comments updated for denormalized fields
- Seed files with `ON CONFLICT DO NOTHING` for idempotency
- **Migration ordering fixed**: 002_kpi_views.sql runs before 004_agents_scorecards.sql (was referencing non-existent v_monthly_summary)

#### Phase 4 (Analysis SQL Files) — 100% Complete (17 of 17)
All 17 SQL files verified with valid content — none empty.

#### Phase 6 (Testing) — 100% Complete
- `test/conftest.py` — Pytest fixtures, GENERATOR_ROW_COUNTS, METRIC_RANGES constants
- `test/qa_validation.py` — Data integrity tests:
  - 64 fast tests passing (0 failures): structural integrity + 9 KPI views + metric percentile ranges + capped KP + BB Conversion
  - 2 slow tests (ETL idempotency, generator seed reproducibility)
- `test/test_generator.py` — Generator unit tests + CSV row count validation + 4 Phase 6 invariant tests:
  - `TestGeneratorOutput` (3 tests), `TestGeneratorRowCounts` (1 test), `TestGeneratorReproducibility` (1 test), `TestGeneratorDataQuality` (1 test)
  - `TestGeneratorPostFixInvariants` (4 tests): cure-flag completeness, PTP-payment consistency, grace-period integrity, re-entry rate bounds

#### Phase 7 (Automation) — 100% Complete
- `run_pipeline.bat` — Fixed: `timeout /t 2` → `ping -n 3 localhost` (cross-shell), `python` → `%CONDA_PYTHON%`, added `--env-file .env` for docker-compose
- `migrate.sh` — Ordering fixed: 002 before 004
- `.env` moved from `database/.env` to `./.env`
- Pipeline end-to-end verified: ~157s (all 3 months loaded)
- Data status: All 3 months (Oct-Dec 2025) loaded in PostgreSQL

### ✅ DONE (After Phase 7)

#### Phase 5 (Generator Enhancements) — 100% Complete
- **Progressive severity**: Self-cure rate decays by `0.5^cure_count` (min 0.1); agent connection rate penalized for repeat-offender accounts; AHT/ACW increases for escalated collection stages
- **Monitoring pool**: `other_pool` restricted to accounts that have ever been in Mora (`ever_mora` tracking) — no calling clean Activo accounts
- **Utilization cap**: Clamped at 0.95 to reflect unavoidable idle/wrap-up time
- 6 edits to `data_generator_v7.py`

#### Phase 6 (Invariant Tests) — 100% Complete
- `TestGeneratorPostFixInvariants` class with 4 tests:
  - **Cure-flag completeness**: 0 rows with `is_cured=True` and `cure_flag="None"`
  - **PTP-payment consistency**: All kept PTPs have `amount_paid >= 95%` of `promised_amount`
  - **Grace-period integrity**: All `grace_until_date >= promised_date`
  - **Re-entry rate bounds**: 10-25% of cured accounts re-default within 1 month

### ⏳ PENDING (Next Phases)

#### Phase C — Power BI Dashboard Build (formerly Phase 9)
- Build fresh PBIX (not modify existing collections_dashboard_v2.pbix)
- 5 pages: Executive, Agent Scorecard, Team Performance, Portfolio Health, Promise Intelligence
- Import mode, star schema, 70+ DAX, RLS by supervisor team
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
- None currently. Weekend interaction bug fixed. Dim_Agents denormalized. Pipeline verified end-to-end. KPI views corrected: cure count uses `COUNT(DISTINCT account_id)` (no double-count), BB Conversion uses correct `kept_pct * ptp_pct / 100` formula.

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
- **Config calibration (May 2026)**: 11 `config.py` parameter changes + 2 new params to align generated data with real-world medians. Changes: `connection_rate` (0.50,0.90)→(0.45,0.80), `rpc_rate_base` (0.45,0.80)→(0.35,0.65), `ptp_rate_base` (0.60,0.85)→(0.65,0.88), `kp_tendency` (0.55,0.85)→(0.70,0.92), `accts_per_agent_day` (60,100)→(50,80), `attempts_per_acct` (1,3)→(1,2), `break_minutes` (45,90)→(20,45), `acw_rpc.mu` 90→125, `aht_nrpc.mu` 52→58, `self_cure_base_rate` 0.0006→0.0010, `grace_period_days` (2,4)→(3,7). Added `self_cure_payday_boost: 2.5`, `monthly_drift_std: 0.08`. Actual row counts (v7, seed 42): Interactions 344K, PTP 28K, Payments 23K.
- **Skill split + tenure cohorts**: Single `skill_score` replaced with 3 independent dimensions (`contact_skill`, `negotiation_skill`, `efficiency_skill`). Added `tenure_cohort` (Low/Mid/High) to Dim_Agents. Tenure adjusts base rate ranges within config bounds; skills applied multiplicatively. Efficiency skill inversely scales AHT/ACW (lower = faster handle times).
- **Monthly agent drift**: At the start of each calendar month, a ±8% multiplier (`monthly_drift_std: 0.08`) is drawn per agent and applied persistently to `connection_rate`, `rpc_rate`, `ptp_rate`, and `kp_tendency` for the entire month. Mirrors real RPC% swings of 38%–67% month-to-month.
- **THT normalization**: `fact_agent_time_log.tht_hours` now computed from actual `SUM(aht + acw)` across all interactions per agent-day; `utilization = actual_tht_s / (op_hrs * 3600)` (real ratio, capped at 1.0). Removed synthetic `off_phone_shrinkage` formula.
- **Self-cure payday boost**: On payday weeks (days 13-17 and last 3 calendar days), `self_cure_base_rate` multiplied by 2.5x (`self_cure_payday_boost`). Clusters ~47% of self-cures on payday periods (vs ~23% uniform baseline), matching real consumer behavior.
- **DAX type safety fixes**: All `rpc_flag = "true"`/`"false"` string comparisons replaced with `TRUE()`/`FALSE()` boolean literals in `dax_measures_dictionary.md` (lines 12, 15, 19-22). Added `[Cured Amounts]` measure (cured-only filtered SUM). `Total Amount Paid` annotated as all-payments; `Cured Amount Prior Month`, `Cured Amount MoM %`, `Cured Amount YTD` now reference `[Cured Amounts]` instead of `[Total Amount Paid]`.
- **Data flow**: Generator → CSVs → ETL → PostgreSQL → Power BI Import (~422K rows, ~100 MB compressed pre-calibration) → Excel (openpyxl)
- **Pipeline timing**: ~126s end-to-end (calibrated generator with 3 months; ~67s gen + ~59s ETL)
- **Test count**: 74 fast tests passing (was 68 — added 4 Phase 6 invariant tests). 2 slow tests (ETL idempotency, generator seed).
- **Dim_Agents denormalized**: Added `supervisor_name`, `team_name`, `region` directly to `dim_agents`; removed FK constraint to `dim_supervisors`. All 5 KPI views updated to reference `da.team_name` instead of joining `dim_supervisors`. Generator populates denormalized fields via lookup. Generator seed reproducibility unaffected (using seed 42). Pipeline runs ~37s ETL.
- **SQL view fixes (Commit 0a)**: `v_recovery_metrics` cure count in agent_daily/product_daily changed from `SUM(is_cured)` to `COUNT(DISTINCT account_id)` — matches monthly_agent CTE, eliminates double-counting accounts cured multiple times same day. `v_promise_metrics` bucket_conversion changed from `kept_count*100/rpc_count` to `kept_pct * ptp_count / rpc_count` — correctly reflects BB Conversion Rate as `[PTP%] * [KP%]`. `v_productivity_metrics` comment stripped of misnamed "no-touch rate" reference. `006_comments.sql` utilization column comment corrected to "decimal 0-1" (was incorrectly labeled as percentage).
- **Test calibration (Commit 5)**: Added `TestGeneratorRowCounts` — validates CSV row counts for all 10 tables at ±5% tolerance against seed 42 baseline. Added `TestMetricRanges` — 6 percentile-range tests (RPC% 35-60, PTP% 20-65, KP% 65-90, Utilization% 30-60, Cures/THT 0.08-0.30, ACW RPC 80-180). Added `TestCappedKPPositive` (SUM capped_kp > 0). Added `TestBBConversionPositive` (median bucket_conversion > 0). All ranges calibrated against current 1-month DB data.
- **Generator row counts (seed 42, 3mo, v7 calibrated)**: Dim tables exact (8/80/10000/3/122/15567), Facts ±5% (Interactions 342996, PTP 22150, Payments 19504, Agent Time 5280, EOM Snapshot 46701).
- **Phase 5 — Generator enhancements**: 6 edits to `data_generator_v7.py`. (1) `other_pool` restricted to accounts that have ever been in Mora (`ever_mora` set tracks initial Mora + replenishments). (2) Self-cure rate decays by `0.5^cure_count` (min 0.1) for repeat offenders. (3) Agent connection rate penalized by `1.0 - 0.2*cure_count` (min 0.4). (4) AHT/ACW boosted by `1.0 + 0.15*cure_count` for escalated accounts. (5) `cure_count` tracked per account, incremented on each cure (self-cure or agent-assisted). (6) Utilization cap lowered from 1.0 to 0.95.
- **Phase 6 — Invariant tests**: Added `TestGeneratorPostFixInvariants` class (4 tests) to `test/test_generator.py`. Test 20 (cure-flag completeness): 0 rows with `is_cured=True` and `cure_flag="None"`. Test 21 (PTP-payment consistency): all kept PTPs have `amount_paid >= 95%` of `promised_amount`. Test 22 (grace-period integrity): all `grace_until_date >= promised_date`. Test 23 (re-entry rate bounds): 10-25% of cured accounts re-default within 1 month. All 4 tests pass with seed 42.

## Quick Reference
- **Project root**: `C:\Users\Leand\Desktop\Portafolio-Projects\MIS-COLLECTIONS`
- **Conda env**: `mis-collections`
- **DB connection**: host=localhost, port=5433, user=rtrlpz, password=rtrlpz, db=MSI_CollectionsDB
- **Pipeline command**: `./run_pipeline.bat` (from project root in CMD)
- **Run tests**: `python -m pytest test/ -v -m "not slow"`
- **execution_guide.md**: `docs/execution_guide.md` (2,499 lines, 13 sections)
- **Build plan**: `dashboards/assets/mis_collections_build_plan.md` (5 phases, A→E)
