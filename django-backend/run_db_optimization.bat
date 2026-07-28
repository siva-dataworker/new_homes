@echo off
REM ============================================
REM Database Performance Optimization Runner
REM Loads environment variables and runs optimization
REM ============================================

echo.
echo ============================================
echo Database Performance Optimization
echo ============================================
echo.

REM Set database credentials
REM Replace these with your actual Supabase credentials
set DB_HOST=aws-0-ap-south-1.pooler.supabase.com
set DB_PORT=6543
set DB_NAME=postgres
set DB_USER=postgres.kfmkwzphqxshwbtdkbnp
set DB_PASSWORD=Finebuilde29

echo Loading database credentials...
echo Host: %DB_HOST%
echo Port: %DB_PORT%
echo Database: %DB_NAME%
echo User: %DB_USER%
echo.

REM Run the optimization script
python apply_db_optimization.py

echo.
echo ============================================
echo Press any key to exit...
pause >nul
