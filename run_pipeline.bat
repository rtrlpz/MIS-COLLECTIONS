@echo off
setlocal EnableDelayedExpansion

:: Color codes: Green=0A, Red=0C, Yellow=0E, White=07
set CONDA_PYTHON=C:\Users\Leand\.conda\envs\mis-collections\python.exe
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
docker-compose --env-file .env -f database/docker-compose.yml up -d >nul 2>&1
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
docker exec postgres_collections pg_isready -h localhost -p 5432 >nul 2>&1
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

:: Step 4: Run database migrations
color 07
echo [4/6] Running database migrations...
for /f %%a in ('powershell -Command "[int](Get-Date -UFormat %%s)"') do set "step_start=%%a"
:: Run migrations using bash script (works in git-bash)
bash migrate.sh >nul 2>&1
if errorlevel 1 (
    color 0C
    echo [ERROR] Database migrations failed. Check logs.
    goto :end
)
for /f %%a in ('powershell -Command "[int](Get-Date -UFormat %%s)"') do set "step_end=%%a"
set /a "elapsed=step_end-step_start"
color 0A
echo [OK] Migrations complete. (%elapsed% seconds)

:: Step 5: Generate data
color 07
echo [5/6] Generating data...
for /f %%a in ('powershell -Command "[int](Get-Date -UFormat %%s)"') do set "step_start=%%a"
%CONDA_PYTHON% data_sources/generators/data_generator_v7.py
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
