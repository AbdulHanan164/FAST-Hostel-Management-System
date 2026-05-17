@echo off
title FAST Hostel — Email OTP API (port 8000)
cd /d "%~dp0"

echo ============================================
echo   FAST Hostel — Email OTP API
echo   URL : http://localhost:8000
echo   Docs: http://localhost:8000/docs
echo ============================================
echo.

:: Install dependencies if venv doesn't exist
if not exist "venv\Scripts\activate.bat" (
    echo [1/2] Creating virtual environment...
    python -m venv venv
    if %errorlevel% neq 0 ( echo [ERROR] Failed to create venv. & pause & exit /b 1 )

    echo [2/2] Installing dependencies...
    call venv\Scripts\activate.bat
    pip install -r requirements.txt
    if %errorlevel% neq 0 ( echo [ERROR] pip install failed. & pause & exit /b 1 )
) else (
    call venv\Scripts\activate.bat
)

echo.
echo Starting FastAPI server... Press Ctrl+C to stop.
echo.

uvicorn main:app --host 0.0.0.0 --port 8000 --reload
pause
