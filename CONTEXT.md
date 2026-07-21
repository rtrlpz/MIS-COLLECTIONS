# MIS-COLLECTIONS — Project Context

## Project Overview
Simulated bank collections analytics portfolio project. Generates synthetic data for ~80 agents, ~10,000 clients, ~15,575 accounts across Credit Cards, Personal Loans, and Mortgages (Oct–Dec 2025). Models the full collections lifecycle: dialer interactions, RPC tracking, promise-to-pay management, payment/cure events, and agent utilization.

**Goal:** Portfolio piece demonstrating end-to-end data engineering + analytics for a Scotiabank-style collections department. 9 Power BI dashboards across Executive, Managerial, Supervision, and Analytical tiers.
**Last updated:** 2026-07-21 (Session: Dashboard consolidation to 9 pages, generator/schema/DAX implementation plan created)

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
├── CLAUDE.md                      # Short AI-agent project context (UPDATED with file map)
├── CONTEXT.md                     # THIS FILE — single-source project overview
├── LICENSE
├── README.md                      # Project overview & interview pitch
├── ROADMAP.md                     # Phase-by-phase task checklist
├── requirements.txt               # Python deps (pinned versions)
├── run_pipeline.bat               # Windows batch: full pipeline (COLOR bug fixed)
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
│   │   ├── dax/                   # DAX SOURCE OF TRUTH (CSV + docs)
│   │   │   ├── collections_dax_v2.csv           # 207 measures (87 base + 120 new)
│   │   │   ├── collections_dax.csv              # Legacy v1 (73 measures)
│   │   │   └── dax_targets_and_comparisons.md   # 120 new: goals, RAG, MoM/WoW/DoD/YoY/OTC
│   │   ├── docs/
│   │   │   ├── dax_measures_dictionary_v2.md    # v2.1: 207 measures documented
│   │   │   ├── mis_collections_build_plan.md    # 5-phase Power BI build plan
│   │   │   ├── execution_guide.md               # 2,499-line enterprise build guide
│   │   │   ├── reference_guide.html             # 1,555-line DAX reference
│   │   │   └── legacy/dax_measures_dictionary.md # v1 backup
│   │   ├── theme/Tema 1.json                    # Power BI theme (#262A76, Calibri)
│   │   ├── SVGs/                                 # Icons (Google Material, Streamline)
│   │   ├── screenshots/architecture_diagram.svg
│   │   └── bg/                                   # Background images
│   └── collections_project/
│       ├── collections_dashboard_v4.pbix         # Latest (START FRESH, don't modify)
│       ├── collections_dashboard_v3.pbix         # Legacy
│       └── collections_dashboard_v2.pbix         # Legacy (8.9 MB)
│
├── data_sources/                  # DATA GENERATION LAYER
│   ├── generators/
│   │   ├── config.py             # 45+ calibration params (CFG + PRODUCT_CFG)
│   │   ├── data_generator_v7.py   # 12 tables, 500K+ rows, weekend-bug-fixed
│   │   └── raw/                   # Generated CSVs (DO NOT EDIT)
│   └── schema/dictionary.md
│
├── database/                      # DATABASE LAYER
│   ├── docker-compose.yml         # Postgres 15 + pgAdmin
│   ├── migrations/
│   │   ├── 001_create_tables.sql  # DDL: 11 tables (star schema)
│   │   ├── 002_kpi_views.sql      # 9 KPI views
│   │   ├── 003_constraints.sql    # 15 CHECK constraints
│   │   ├── 004_agents_scorecards.sql  # v_agent_scorecards (composite weighted)
│   │   ├── 005_indexes.sql        # 27 indexes
│   │   └── 006_comments.sql       # 63 COMMENT ON
│   └── seeds/
│       ├── 001_dim_products.sql   # 3 products
│       └── 002_dim_calendar.sql   # 365 rows (full year 2025)
│
├── etl/                           # ETL LAYER (was database/etl/)
│   ├── data_to_pg.py              # CSV → PostgreSQL (idempotent, incremental, transactional)
│   └── errors/                    # Error CSVs from failed loads
│
├── docs/                          # DOCUMENTATION LAYER
│   ├── kpi_definitions.md         # 319-line KPI reference with formulas
│   ├── data_dictionary.md         # Full column-level dictionary
│   ├── executive_summary.md       # 1-page leadership summary
│   ├── execution_guide.md         # 2,499-line enterprise build guide
│   └── interviews/                # Case study prep materials
│
├── reports/                       # EXCEL REPORTING LAYER (Phase D pending)
│   └── (empty — generate_daily_mis.py pending)
│
├── test/                          # TESTING LAYER — 76 tests passing (74 fast + 2 slow)
│   ├── conftest.py               # Fixtures, METRIC_RANGES, GENERATOR_ROW_COUNTS
│   ├── qa_validation.py          # 66 tests: data integrity + KPI views + metric ranges
│   ├── test_generator.py          # 10 tests: generator + row counts + 4 invariants
│   └── test_kpi_views.sql         # SQL view validation queries
│
└── .github/                       # CI templates (ISSUE_TEMPLATE, WORKFLOW)
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

#### Phase 8.5 — Generator + Schema Enhancements (IN PROGRESS)
- **Goal**: Extend generator for 12 months of data, add new columns for 9 dashboards
- **Generator changes**: G1-G9 (open_date spread, channels, write-offs, cost_per_hour, credit_limit, income_bracket, hire_dates)
- **Schema changes**: +8 columns, +1 table (fact_writeoffs), +3 views, +4 constraints, +6 indexes
- **Target**: 12 months of data (Jan-Dec 2025) for full YoY capability
- **DAX update**: 207 existing + 91 from markdown + 22 new = ~320 measures
- **Files**: `PLAN_DASHBOARDS.md` (full implementation plan)

#### Phase 9 — Power BI Dashboard Build (9 dashboards)
- Build fresh PBIX (not modify existing collections_dashboard_v4.pbix)
- **9 pages** (consolidated from original 10 — Executive Collections merged with Scorecard):
  1. Executive Collections (merged) — operational + risk + cost per account
  2. Agent Performance — RPC%, KP%, Cure, Util, AHT, Composite Score, WoW trends
  3. Dialer Performance — Call volume, answer rate, RPC dialer-only, AHT by channel
  4. Portfolio Management — Arrears waterfall, delinquency bands, DPD migration Sankey
  5. Operations Command Center (limited) — Calls Offered/Answered, AHT, Occupancy
  6. Credit Risk (limited) — Delinquency by segment, Roll rates, Cure rates, Credit utilization
  7. Financial Recovery — Recovery vs cost, Write-offs, Cost-to-collect, Net recovery
  8. Vintage Analysis — DPD by account age, Vintage curves, Cure by vintage month
  9. Roll Rate Analysis — Sankey (prev→curr), Skip/deteriorate rates, Stuck 90+
- Import mode, star schema, **~320 DAX measures** across 6 tables + 2 calculated tables
- RLS by supervisor_id on Dim_Agents
- **Build plan**: `dashboards/assets/docs/mis_collections_build_plan.md`

#### Phase 10 — Excel Daily MIS Report
- Python (openpyxl) script at `reports/generate_daily_mis.py`
- 3 sheets: KPI dashboard, Agent deep dive, Methodological notes
- Queries `v_daily_mis` directly

#### Phase 11 — Publishing & Governance
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
- `docs/execution_guide.md` — 2,499-word enterprise Power BI build guide (13 sections)
- `dashboards/assets/docs/mis_collections_build_plan.md` — 5-phase build plan for Phase C/D/E
- `dashboards/assets/docs/reference_guide.html` — 1,555-line DAX + dashboard blueprint
- `dashboards/assets/dax/dax_targets_and_comparisons.md` — 120 new measures: goals, RAG, time intel
- `dashboards/assets/dax/collections_dax_v2.csv` — 207 measures (source of truth)
- `dashboards/assets/docs/dax_measures_dictionary_v2.md` — v2.1 full documentation
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
- **DAX v2 (June 2026)**: Full audit of all 3 source files (dax_measures_dictionary.md, collections_dax.csv, execution_guide.md patterns). Rebuilt into `dashboards/assets/dax/collections_dax_v2.csv` (87 measures across 5 tables) and `dashboards/assets/docs/dax_measures_dictionary_v2.md` (full documentation). Changes: removed 5 broken cross-table measures (Schedule Paid Full/Partial/Broken, Total Expected, Schedule Fulfillment Rate), rewrote Roll Rate from broken RELATEDTABLE pattern to CALCULATE+CONTAINS, added format specs column, added Roll Rate measures with documented calculated column alternative. Legacy v1 files preserved as backups.
- **DAX targets & comparisons (July 2026)**: Added `dashboards/assets/dax/dax_targets_and_comparisons.md` — 120 new DAX measures (29 goals/RAG + 91 time intelligence) plus 2 calculated tables. New `_Goals & Targets` measure table with goals for PTP% 80%, KP% 80%, ACW RPC 120s, ACW Non-RPC 25s, Capped KP/RPC Arrears 37%, Cures/THT 2.4, Utilization 90%. 3-tier RAG (Green #00B050, Amber #FFC000, Red #FF0000). 5 comparison types: MoM, WoW, DoD, YoY, OTC — each with Prior Period, Abs Change, and % Change variants. Updated `collections_dax_v2.csv` with 57 new rows (29 _Goals & Targets, 28 _Time Intelligence additions). Updated `dax_measures_dictionary_v2.md` to v2.1. Total DAX stock: 207 measures (87 base + 120 new). ROADMAP.md updated to reflect actual counts.
- **Dashboard consolidation (July 2026)**: 9 dashboards selected (from original 14+4=18). Excluded: WFM, QA, Compliance, Customer Experience, Recovery Forecast. Merged Executive Collections + Executive Scorecard into single page. `PLAN_DASHBOARDS.md` created with full implementation plan (generator G1-G9, schema changes, DAX expansion to ~320 measures, 12-month data).

## Quick Reference
- **Project root**: `C:\Users\Leand\Desktop\Portafolio-Projects\MIS-COLLECTIONS`
- **Conda env**: `mis-collections`
- **DB connection**: host=localhost, port=5433, user=[REDACTED], password=[REDACTED], db=MSI_CollectionsDB
- **Pipeline command**: `./run_pipeline.bat` (from project root in CMD)
- **Run tests**: `python -m pytest test/ -v -m "not slow"`
- **DAX base CSV**: `dashboards/assets/dax/collections_dax_v2.csv`
- **DAX targets module**: `dashboards/assets/dax/dax_targets_and_comparisons.md`
- **DAX dictionary**: `dashboards/assets/docs/dax_measures_dictionary_v2.md`
- **Execution guide**: `dashboards/assets/docs/execution_guide.md`
- **Build plan**: `dashboards/assets/docs/mis_collections_build_plan.md`
- **Total DAX measures**: 207 (87 base + 29 goals/targets + 91 time comparisons)
