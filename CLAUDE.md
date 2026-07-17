# MIS-COLLECTIONS — Collections Analytics Portfolio

**Stack:** Python 3, PostgreSQL 15 (Docker), SQL, Power BI, openpyxl
**Root:** `C:\Users\Leand\Desktop\Portafolio-Projects\MIS-COLLECTIONS`
**Conda env:** `mis-collections`

## Commands
- Generate data: `python data_sources/generators/data_generator_v7.py`
- Start DB: `docker-compose -f database/docker-compose.yml up -d`
- Run pipeline: `./run_pipeline.bat` (Windows CMD)
- Run migrations: `bash migrate.sh`
- Run tests (fast): `python -m pytest test/ -v -m "not slow"`
- Run all tests: `python -m pytest test/ -v`

## Critical Rules (must follow)
- NEVER commit .env files, credentials, or secrets
- NEVER modify generated CSVs (data_sources/generators/raw/)
- Table naming: Dim_ prefix for dimensions, Fact_ prefix for facts
- All SQL follows PostgreSQL dialect
- Tests use pytest with conftest.py fixtures

## Key Facts
- DB: localhost:5433, user=[REDACTED], password=[REDACTED], db=MSI_CollectionsDB
- Star schema: 6 dim tables, 5 fact tables, 9 KPI views
- Weekend bug FIXED: interactions Mon-Fri only, payments allowed on weekends
- 74 fast tests + 2 slow = 76 total passing (0 failures) — includes 4 Phase 6 invariant tests
- Config calibrated May 2026 — 11 param changes + 2 new params to match real data (see CONTEXT.md Session Notes)
- SQL view fixes: cure count uses COUNT(DISTINCT account_id), BB Conversion uses kept_pct * ptp_pct / 100
- Monthly drift: ±8% per-agent rate drift each month (RPC% swings 38–67%)
- Generator CSV row counts validated at ±5% tolerance (seed 42 baseline)
- Pipeline runs in ~157s end-to-end (3 months data)
- All 3 months (Oct-Dec 2025) loaded in PostgreSQL
- `.env` at project root (was database/.env)
- ETL at `etl/` (was database/etl/)
- **Phase 5** — Progressive severity (cure_count decay), other_pool restricted to ever-Mora accounts, utilization capped at 0.95
- **Phase 6** — 4 new invariant tests: cure-flag completeness, PTP-payment consistency, grace-period integrity, re-entry rate bounds (10-25%)
- Dim_Calendar: 122 rows (Sep–Dec 2025)
- Generator seed 42 row counts: Interactions 342,996 / PTP 22,150 / Payments 19,504 / Agent Time 5,280 / EOM 46,701

## DAX v2
- `dashboards/assets/dax/collections_dax_v2.csv` — 87 DAX measures across 5 tables (source of truth)
- `dashboards/assets/docs/dax_measures_dictionary_v2.md` — Full documentation with formulas, formats, dependencies
- Legacy v1 files preserved as backups: `collections_dax.csv`, `dax_measures_dictionary.md`

## Key Documents
- `docs/execution_guide.md` — 14,877-word enterprise build guide (13 sections)
- `dashboards/assets/mis_collections_build_plan.md` — 5-phase Power BI build plan
- `CONTEXT.md` — Full project context, conventions, session history

## Next Phase
- Phase C: Build Power BI dashboard (5 pages, fresh PBIX, import mode, star schema, 87 DAX across 5 tables, RLS)
- Phase D: Excel MIS report generator (openpyxl)
- Phase E: Publish, user guide, handoff

## Reference
For full project context read: `CONTEXT.md`
