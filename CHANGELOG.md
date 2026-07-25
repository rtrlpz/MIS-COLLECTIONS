# Changelog

## [1.0.0] — 2026-07-25

### Phase 3 — DAX Cleanup & Gap Analysis
- Added `Avg AHT (sec)` and `Avg ACW (sec)` overall measures matching real ScotiaBank metric set
- DAX count: 258 measures across 15 tables

### Phase 2 — Critical Bug Fixes
- **Product ID**: Aligned `PRD_001` → `PRD-01` in seed to match generator format
- **Duplicate table**: Removed `etl_load_log` from `002_kpi_views.sql` (was defined in `001_create_tables.sql`)
- **Cartesian join**: Removed product grouping from `v_recovery_metrics.agent_daily` — was double-counting in `v_daily_mis`
- **Unweighted averages**: Replaced `AVG(rpc/ptp/kept_pct)` with weighted `SUM/SUM` in `v_monthly_summary`
- **Dead config**: Removed unused `rpc_rate_by_channel` from `config.py`
- **DAX columns**: Fixed `Fact_EOM_Snapshot[product_id]` → `Dim_Accounts[product_type]` and `Fact_EOM_Snapshot[open_date]` → `Dim_Accounts[open_date]`

### Phase 8.5 — G1-G9 Generator Enhancements
- Vintage `open_date` spread (23 months, weighted)
- Agent hire dates + experience tiers (senior/mid/junior)
- Credit limit lognormal distribution per product
- Client income brackets (5 segments)
- Interaction channel mix (Dialer/FICO/SMS/Manual)
- `Fact_Writeoffs` table (5% write-off rate at 91+ DPD)
- 12-month data expansion (Jan-Dec 2025, seasonal patterns)
- Supervisor hire dates (5-year span)
- Agent cost model (hourly rates by tier + overhead)
- 256 DAX measures across all tables
- Dashboard blueprints for 9 pages
- Schema: 6 new columns + 3 new tables + 12 views
- Tests: 76 total (74 fast + 2 slow)

## [0.9.0] — 2026-07-16

### Enhanced
- Consolidated 10 dashboards to 9
- Added PLAN_DASHBOARDS.md with G1-G9 plan
- DAX v2 expansion to 256 measures
- Full documentation refresh (CONTEXT.md, CLAUDE.md redacted)

## [0.8.0] — 2026-05-26

### Fixed
- Cure misclassification: payments marked as Non-Cured when arrears reached 0
- Payment excess loss: amounts beyond arrears now applied correctly
- DPD capture at interaction and payment time
- Added audit columns, CHECK constraints, indexes on `fact_payments`

## [0.7.0] — 2026-05-10

### Enhanced
- Calibrated generator parameters against real historic data distributions
- Decoupled agent skill into 3 dimensions (contact, negotiation, efficiency)
- Added monthly performance drift (±8%) for realistic variance
- Computed THT from actual interaction handle times (not Op Hr)
- Clustered 60% of self-cures on payday weeks

### Fixed
- DAX type safety for all measures
- Corrected Cured Amounts measure

## [0.6.0] — 2026-05-01

### Added
- 17 analytical SQL queries across 3 tiers (agent, team, portfolio)
- ETL monitoring views: `v_etl_load_summary`, `v_data_freshness`
- Test suite: 66 QA validation tests + 10 generator tests

### Fixed
- Payment processing dates now allowed on weekends (was weekday-only bug)
- Flattened `dim_supervisor` into `dim_employees` (self-ref FK) for Power BI
- Corrected KP%, cure count, BB Conversion, Capped KP in SQL views
- Refactored `v_monthly_summary` to single-pass design
- Fixed portfolio-level Cartesian bug

## [0.5.0] — 2026-04-20

### Added
- All 9 KPI views (contact, promise, recovery, productivity, handle time, daily_mis, monthly, ETL summary, freshness)
- Agent scorecard view (`v_agent_scorecards`) with composite weighted scoring
- Seed scripts for `dim_products` and `dim_calendar`
- CHECK constraints (15) and indexes (27) for data integrity
- COMMENT ON for all tables and columns

### Pipeline
- Full pipeline orchestration via `run_pipeline.bat`
- ETL with transactions, idempotency (TRUNCATE + reload), retry logic
- Dry-run mode for pre-flight CSV validation
- Incremental mode to skip already-loaded months

## [0.4.0] — 2026-04-10

### Added
- Anomaly tracking with anomaly_report.csv export
- Extracted CFG and PRODUCT_CFG into `config.py`
- Post-generation validation (row counts, PK/FK checks)
- Structured logging with file + console handlers
- CLI arguments: `--output-dir`, `--months`, `--seed`
- Execution guide with granular task instructions
- Consistent CSV formatting with ISO dates and fixed decimals

## [0.3.0] — 2026-04-01

### Added
- V7 folder architecture with automated tests
- Issue templates for consistent contributions
- ROADMAP.md for project planning
- `__init__.py` files for package structure

## [0.2.0] — 2026-03-15

### Added
- Dockerized PostgreSQL + pgAdmin
- ETL pipeline with psycopg2
- First Power BI dashboard
- Initial DDL with 11 tables (star schema)

## [0.1.0] — 2026-03-01

### Added
- Project folder structure
- Initial data generator scripts
- Database DDL for tables
