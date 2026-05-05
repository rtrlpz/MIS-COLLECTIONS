@echo off
setlocal EnableDelayedExpansion

:: Color codes: Green=0A, Red=0C, Yellow=0E, White=07
color 07

echo.
echo === MIS COLLECTIONS PIPELINE ===
echo.

:: Step1: Check if Docker is running
echo [1/3] Checking if Docker is running...
docker info >nul 2>&1
if errorlevel 1 (
    color 0C
    echo [ERROR] Docker is not running. Please start Docker Desktop first.
    goto :end
)
color 0A
echo [OK] Docker is running.

:: Step2: Generate data
color 07
echo [2/3] Generating data...
python data_sources/generators/data_generator_v7.py
if errorlevel 1 (
    color 0C
    echo [ERROR] Data generation failed. Check logs for details.
    goto :end
)
color 0A
echo [OK] Data generated successfully.

:: Step3: Run ETL
color 07
echo [3/3] Loading data into PostgreSQL...
python database/etl/data_to_pg.py
if errorlevel 1 (
    color 0C
    echo [ERROR] ETL failed. Check logs for details.
    goto :end
)
color 0A
echo [OK] Data loaded successfully.

:: Success summary
echo.
color 0A
echo ========================================
echo Pipeline complete. Data generated and loaded.
echo ========================================
goto :end

:end
echo.
color 07
echo Press any key to exit...
pause >nul
exit /b
