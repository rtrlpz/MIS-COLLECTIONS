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
- DB: localhost:5433, user=rtrlpz, password=rtrlpz, db=MSI_CollectionsDB
- Star schema: 6 dim tables, 5 fact tables, 9 KPI views
- Weekend bug FIXED: interactions Mon-Fri only, payments allowed on weekends
- 41 fast QA tests passing (0 failures), 2 slow tests
- Config calibrated May 2026 — 11 param changes + 2 new params to match real data (see CONTEXT.md Session Notes)
- Pipeline runs in ~157s end-to-end (3 months data)
- All 3 months (Oct-Dec 2025) loaded in PostgreSQL
- `.env` at project root (was database/.env)
- ETL at `etl/` (was database/etl/)

## Key Documents
- `docs/execution_guide.md` — 14,877-word enterprise build guide (13 sections)
- `dashboards/assets/mis_collections_build_plan.md` — 5-phase Power BI build plan
- `CONTEXT.md` — Full project context, conventions, session history

## Next Phase
- Phase C: Build Power BI dashboard (5 pages, fresh PBIX, import mode, star schema, 70+ DAX, RLS)
- Phase D: Excel MIS report generator (openpyxl)
- Phase E: Publish, user guide, handoff

## Reference
For full project context read: `CONTEXT.md`
