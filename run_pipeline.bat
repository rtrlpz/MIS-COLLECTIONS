@echo off
setlocal EnableDelayedExpansion

:: Color codes: Green=10, Red=12, White=7, Yellow=14
set "GREEN=10"
set "RED=12"
set "YELLOW=14"
set "WHITE=7"

echo.
call :print_color "=== MIS COLLECTIONS PIPELINE ===" %YELLOW%
echo.

:: Step 1: Check if Docker is running
call :print_color "[1/3] Checking if Docker is running..." %WHITE%
docker info >nul 2>&1
if errorlevel 1 (
    call :print_color "[ERROR] Docker is not running. Please start Docker Desktop first." %RED%
    goto :end
)
call :print_color "[OK] Docker is running." %GREEN%

:: Step 2: Generate data
call :print_color "[2/3] Generating data..." %WHITE%
python data_sources/generators/data_generator_v7.py
if errorlevel 1 (
    call :print_color "[ERROR] Data generation failed. Check logs for details." %RED%
    goto :end
)
call :print_color "[OK] Data generated successfully." %GREEN%

:: Step 3: Run ETL
call :print_color "[3/3] Loading data into PostgreSQL..." %WHITE%
python database/etl/data_to_pg.py
if errorlevel 1 (
    call :print_color "[ERROR] ETL failed. Check logs for details." %RED%
    goto :end
)
call :print_color "[OK] Data loaded successfully." %GREEN%

:: Success summary
echo.
call :print_color "========================================" %GREEN%
call :print_color "Pipeline complete. Data generated and loaded." %GREEN%
call :print_color "========================================" %GREEN%
goto :end

:end
echo.
call :print_color "Press any key to exit..." %WHITE%
pause >nul
exit /b

:: Function to print colored text
:print_color
set "msg=%~1"
set "color=%~2"
<nul set /p "=." > "%TEMP%.~color"
findstr /a:%color% "." "%TEMP%.~color" nul
<nul set /p "=%msg%" > "%TEMP%.~color"
findstr /a:%color% "%msg%" "%TEMP%.~color" nul
echo.
del "%TEMP%.~color" >nul 2>&1
goto :eof
