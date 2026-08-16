# MIS Collections — Troubleshooting Guide

## Docker Issues

### Docker Desktop not running
```
[ERROR] Docker is not running. Please start Docker Desktop first.
```
**Fix:** Start Docker Desktop from Start Menu / Applications, wait for the whale icon, then re-run.

### Port 5433 already in use
```
Error starting userland proxy: listen tcp4 0.0.0.0:5433: bind: address already in use
```
**Fix:** Change `POSTGRES_PORT` in `.env` to an available port (e.g., `5434`).

### Container won't start
```
docker-compose -f database/docker-compose.yml up -d
```
Check logs:
```bash
docker logs postgres_collections
```
Common causes: corrupt data volume → delete `database/data/` and retry.

## PostgreSQL Connection Errors

### psycopg2.OperationalError: could not connect to server
1. Verify Docker is running: `docker ps`
2. Check container is up: `docker logs postgres_collections`
3. Wait for PostgreSQL to finish starting (5-10s after container launch)
4. Verify credentials in `.env` match `database/docker-compose.yml`

### password authentication failed
**Fix:** Check `POSTGRES_USER` / `POSTGRES_PASSWORD` in `.env`. These must match what was set when the container was first created. If credentials changed, delete the volume: `docker-compose -f database/docker-compose.yml down -v && docker-compose -f database/docker-compose.yml up -d`

## Pipeline Issues

### run_pipeline.bat fails — "conda not found"
**Fix:** Edit `run_pipeline.bat` line 5 to point to your conda python:
```
set CONDA_PYTHON=C:\Users\<you>\.conda\envs\mis-collections\python.exe
```

### bash database/migrate.sh fails
```
database/migrate.sh: line X: psql: command not found
```
**Fix:** Run migrations manually:
```bash
docker exec -i postgres_collections psql -U postgres -d MSI_CollectionsDB < database/migrations/001_create_tables.sql
docker exec -i postgres_collections psql -U postgres -d MSI_CollectionsDB < database/migrations/002_kpi_views.sql
# ... repeat for each migration file in order
```

### Migration order dependencies
Migrations must run in order: `001` → `006`. Running `002` before `001` will fail because tables don't exist yet.

## Generator Issues

### Generator runs but produces 0 rows
**Fix:** Check `--months` argument. Default is all 12 months. Verify `start_date` and `end_date` in log output.

### Generator fails with ImportError
```
ImportError: cannot import name 'DATA_EXPANSION_CFG'
```
**Fix:** Run from the project root: `python data_sources/data_generator_v7.py`. The relative import `from config` expects the package context.

### Output CSVs look empty or truncated
Check `data_sources/logs/generator.log` for errors. Common cause: disk space or permissions on the `raw/` directory.

## ETL Issues

### ETL fails — table doesn't exist
**Fix:** Run migrations first: `bash database/migrate.sh`

### ETL fails — CSV not found
**Fix:** Run generator first: `python data_sources/data_generator_v7.py`

### --incremental mode skips months unexpectedly
The incremental mode uses checksums to detect changes. If a CSV changed, delete the `etl_load_log` entry for that table:
```sql
DELETE FROM etl_load_log WHERE table_name = 'fact_interactions';
```

## Test Issues

### Tests fail with "no database"
**Fix:** Ensure PostgreSQL container is running (`docker ps`) and has data loaded.

### Tests fail with "relation does not exist"
**Fix:** Run migrations to create all tables and views.

### pytest not found
```bash
conda activate mis-collections
pip install pytest
```

## Power BI Issues

### DAX measure errors (yellow triangles)
Verify the measure formula in `dashboards/dax/collections_dax_v2.csv` references existent columns. Common mismatches:
- `product_id` → should be on `Dim_Products`, not `Fact_EOM_Snapshot`
- `open_date` → should be on `Dim_Accounts`, not `Fact_EOM_Snapshot`

### Import refresh fails
**Fix:** Ensure PostgreSQL is running and credentials in `.env` match the Power BI data source settings.

## Environment File

A valid `.env` file at the project root is required:
```
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_password
POSTGRES_DB=MSI_CollectionsDB
POSTGRES_PORT=5433
PGADMIN_DEFAULT_EMAIL=admin@admin.com
PGADMIN_DEFAULT_PASSWORD=admin
PGADMIN_PORT=8081
```
