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
- DB: localhost:5433, user=rtrlpz, db=MSI_CollectionsDB
- Star schema: 6 dim tables, 5 fact tables, 9 KPI views
- Known bug: generator creates ~25K weekend interactions (xfail test)
- Pipeline runs in ~83s end-to-end

## Reference
For full project context, conventions, data model, and session history, read:
`CONTEXT.md`
