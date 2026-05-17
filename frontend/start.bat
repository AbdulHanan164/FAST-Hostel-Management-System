@echo off
title FAST Hostel - Flutter Web (localhost:3000)
cd /d "%~dp0"

echo ============================================
echo   FAST Hostel - Frontend
echo   http://localhost:3000
echo ============================================
echo.

:: Add Flutter to PATH if not already present
set "FLUTTER_BIN=C:\flutter\bin"
echo %PATH% | find /i "%FLUTTER_BIN%" >nul 2>&1
if %errorlevel% neq 0 set "PATH=%PATH%;%FLUTTER_BIN%"

:: Verify Flutter
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Flutter not found. Expected at C:\flutter\bin
    echo Run this to install: git clone https://github.com/flutter/flutter.git -b stable --depth 1 C:\flutter
    pause & exit /b 1
)

:: Verify Node.js (for static server)
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Node.js not found. Install from https://nodejs.org
    pause & exit /b 1
)

echo [1/3] Getting dependencies...
call flutter pub get
if %errorlevel% neq 0 ( echo [ERROR] pub get failed. & pause & exit /b 1 )

echo.
echo [2/3] Building Flutter web release (this takes ~1-2 min)...
call flutter build web --release --base-href /
if %errorlevel% neq 0 ( echo [ERROR] flutter build web failed. & pause & exit /b 1 )

echo.
echo [3/3] Serving Flutter app on http://localhost:3000
echo       Press Ctrl+C to stop.
echo.

:: Auto-open browser after 3 seconds
start "" cmd /c "timeout /t 3 /nobreak >nul && start http://localhost:3000"

node serve_flutter.js
pause
