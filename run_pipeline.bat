@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"

:: Color codes: Green=0A, Red=0C, Yellow=0E, White=07
set CONDA_PYTHON=%USERPROFILE%\.conda\envs\mis-collections\python.exe
set PGUSER=rtrlpz
set PGDB=MIS_CollectionsDB
set CONTAINER=postgres_collections
color 07

:: Get start time in seconds since epoch using PowerShell
for /f %%a in ('powershell -Command "[int](Get-Date -UFormat %%s)"') do set "start_epoch=%%a"

echo.
echo === MIS COLLECTIONS PIPELINE ===
echo.

:: Step 1: Check if Docker is running
echo [1/6] Checking if Docker is running...
docker info >nul 2>&1
if errorlevel 1 (
    color 0C
    echo [ERROR] Docker is not running. Please start Docker Desktop first.
    goto :end
)
color 0A
echo [OK] Docker is running.

:: Step 2: Start Docker containers
color 07
echo [2/6] Starting PostgreSQL container...
for /f %%a in ('powershell -Command "[int](Get-Date -UFormat %%s)"') do set "step_start=%%a"
docker compose --env-file .env -f database/docker-compose.yml up -d >nul 2>&1
if errorlevel 1 (
    color 0C
    echo [ERROR] Failed to start Docker containers.
    goto :end
)
for /f %%a in ('powershell -Command "[int](Get-Date -UFormat %%s)"') do set "step_end=%%a"
set /a "elapsed=step_end-step_start"
color 0A
echo [OK] Containers started. (%elapsed% seconds)

:: Step 3: Wait for PostgreSQL to be ready
color 07
echo [3/6] Waiting for PostgreSQL to be ready...
for /f %%a in ('powershell -Command "[int](Get-Date -UFormat %%s)"') do set "wait_start=%%a"
set /a "wait_timeout=30"
:wait_loop
docker exec %CONTAINER% pg_isready -h localhost -p 5432 >nul 2>&1
if not errorlevel 1 goto :ready
for /f %%a in ('powershell -Command "[int](Get-Date -UFormat %%s)"') do set "now=%%a"
set /a "waited=now-wait_start"
if !waited! GTR %wait_timeout% (
    color 0C
    echo [ERROR] PostgreSQL did not become ready in %wait_timeout% seconds.
    goto :end
)
ping -n 3 localhost >nul
goto :wait_loop
:ready
for /f %%a in ('powershell -Command "[int](Get-Date -UFormat %%s)"') do set "now=%%a"
set /a "ready_elapsed=now-wait_start"
color 0A
echo [OK] PostgreSQL is ready. (%ready_elapsed% seconds)

:: Step 4: Run database migrations (pure CMD — no bash dependency)
color 07
echo [4/6] Running database migrations...
for /f %%a in ('powershell -Command "[int](Get-Date -UFormat %%s)"') do set "step_start=%%a"

:: Ensure etl_load_log table exists
docker exec %CONTAINER% psql -U %PGUSER% -d %PGDB% -c "CREATE TABLE IF NOT EXISTS etl_load_log (id SERIAL PRIMARY KEY, table_name TEXT NOT NULL, rows_loaded INT, loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, status TEXT, csv_checksum TEXT);" >nul 2>&1
if errorlevel 1 goto :migrate_fail
echo   [OK] etl_load_log table

:: Run each SQL file via docker exec with type piping (CMD native)
type database\migrations\001_create_tables.sql | docker exec -i %CONTAINER% psql -v ON_ERROR_STOP=1 -U %PGUSER% -d %PGDB% >nul 2>&1
if errorlevel 1 goto :migrate_fail
echo   [OK] 001_create_tables.sql

type database\seeds\001_dim_products.sql | docker exec -i %CONTAINER% psql -v ON_ERROR_STOP=1 -U %PGUSER% -d %PGDB% >nul 2>&1
if errorlevel 1 goto :migrate_fail
echo   [OK] 001_dim_products.sql

type database\seeds\002_dim_calendar.sql | docker exec -i %CONTAINER% psql -v ON_ERROR_STOP=1 -U %PGUSER% -d %PGDB% >nul 2>&1
if errorlevel 1 goto :migrate_fail
echo   [OK] 002_dim_calendar.sql

type database\seeds\003_dim_delinquency_bucket.sql | docker exec -i %CONTAINER% psql -v ON_ERROR_STOP=1 -U %PGUSER% -d %PGDB% >nul 2>&1
if errorlevel 1 goto :migrate_fail
echo   [OK] 003_dim_delinquency_bucket.sql

type database\seeds\004_dim_calendar_extension.sql | docker exec -i %CONTAINER% psql -v ON_ERROR_STOP=1 -U %PGUSER% -d %PGDB% >nul 2>&1
if errorlevel 1 goto :migrate_fail
echo   [OK] 004_dim_calendar_extension.sql

type database\migrations\003_constraints.sql | docker exec -i %CONTAINER% psql -v ON_ERROR_STOP=1 -U %PGUSER% -d %PGDB% >nul 2>&1
if errorlevel 1 goto :migrate_fail
echo   [OK] 003_constraints.sql

type database\migrations\002_kpi_views.sql | docker exec -i %CONTAINER% psql -v ON_ERROR_STOP=1 -U %PGUSER% -d %PGDB% >nul 2>&1
if errorlevel 1 goto :migrate_fail
echo   [OK] 002_kpi_views.sql

type database\migrations\004_agents_scorecards.sql | docker exec -i %CONTAINER% psql -v ON_ERROR_STOP=1 -U %PGUSER% -d %PGDB% >nul 2>&1
if errorlevel 1 goto :migrate_fail
echo   [OK] 004_agents_scorecards.sql

type database\migrations\005_indexes.sql | docker exec -i %CONTAINER% psql -v ON_ERROR_STOP=1 -U %PGUSER% -d %PGDB% >nul 2>&1
if errorlevel 1 goto :migrate_fail
echo   [OK] 005_indexes.sql

type database\migrations\006_comments.sql | docker exec -i %CONTAINER% psql -v ON_ERROR_STOP=1 -U %PGUSER% -d %PGDB% >nul 2>&1
if errorlevel 1 goto :migrate_fail
echo   [OK] 006_comments.sql

type database\migrations\007_remove_post_writeoff_snapshots.sql | docker exec -i %CONTAINER% psql -v ON_ERROR_STOP=1 -U %PGUSER% -d %PGDB% >nul 2>&1
if errorlevel 1 goto :migrate_fail
echo   [OK] 007_remove_post_writeoff_snapshots.sql

type database\migrations\008_dim_delinquency_bucket.sql | docker exec -i %CONTAINER% psql -v ON_ERROR_STOP=1 -U %PGUSER% -d %PGDB% >nul 2>&1
if errorlevel 1 goto :migrate_fail
echo   [OK] 008_dim_delinquency_bucket.sql

type database\migrations\009_strategy_scd2.sql | docker exec -i %CONTAINER% psql -v ON_ERROR_STOP=1 -U %PGUSER% -d %PGDB% >nul 2>&1
if errorlevel 1 goto :migrate_fail
echo   [OK] 009_strategy_scd2.sql

type database\migrations\010_fact_recoveries.sql | docker exec -i %CONTAINER% psql -v ON_ERROR_STOP=1 -U %PGUSER% -d %PGDB% >nul 2>&1
if errorlevel 1 goto :migrate_fail
echo   [OK] 010_fact_recoveries.sql

:: Post-migration assertion: all expected views must exist
for /f %%v in ('docker exec %CONTAINER% psql -U %PGUSER% -d %PGDB% -t -A -c "SELECT COUNT(*) FROM pg_views WHERE schemaname='public' AND viewname LIKE 'v_%%';"') do set "ACTUAL_VIEWS=%%v"
set "ACTUAL_VIEWS=%ACTUAL_VIEWS: =%"
if not "%ACTUAL_VIEWS%"=="16" (
    color 0C
    echo   [FAIL] Expected 16 views, found '%ACTUAL_VIEWS%'. Migration drift detected.
    goto :end
)
echo   [OK] view count = 16

for /f %%a in ('powershell -Command "[int](Get-Date -UFormat %%s)"') do set "step_end=%%a"
set /a "elapsed=step_end-step_start"
color 0A
echo [OK] Migrations complete. (%elapsed% seconds)
goto :step5

:migrate_fail
color 0C
echo [ERROR] Database migration failed. Check Docker logs: docker logs %CONTAINER%
goto :end

:: Step 5: Generate data
:step5
color 07
echo [5/6] Generating data...
for /f %%a in ('powershell -Command "[int](Get-Date -UFormat %%s)"') do set "step_start=%%a"
%CONDA_PYTHON% data_sources/data_generator_v7.py
if errorlevel 1 (
    color 0C
    echo [ERROR] Data generation failed. Check logs for details.
    goto :end
)
for /f %%a in ('powershell -Command "[int](Get-Date -UFormat %%s)"') do set "step_end=%%a"
set /a "elapsed=step_end-step_start"
color 0A
echo [OK] Data generated successfully. (%elapsed% seconds)

:: Step 6: Run ETL
color 07
echo [6/6] Loading data into PostgreSQL...
for /f %%a in ('powershell -Command "[int](Get-Date -UFormat %%s)"') do set "step_start=%%a"
%CONDA_PYTHON% etl/data_to_pg.py
if errorlevel 1 (
    color 0C
    echo [ERROR] ETL failed. Check logs for details.
    goto :end
)
for /f %%a in ('powershell -Command "[int](Get-Date -UFormat %%s)"') do set "step_end=%%a"
set /a "elapsed=step_end-step_start"
color 0A
echo [OK] Data loaded successfully. (%elapsed% seconds)

:: Success summary with total elapsed time
for /f %%a in ('powershell -Command "[int](Get-Date -UFormat %%s)"') do set "end_epoch=%%a"
set /a "total_elapsed=end_epoch-start_epoch"
echo.
color 0A
echo ========================================
echo Pipeline complete. Data generated and loaded.
echo Total elapsed time: %total_elapsed% seconds
echo ========================================
goto :end

:end
echo.
color 07
echo Press any key to exit...
pause >nul
exit /b
