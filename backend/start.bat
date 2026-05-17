@echo off
title FAST Hostel — Firebase Emulators (localhost:4000)
cd /d "%~dp0"

echo ============================================
echo   FAST Hostel — Backend
echo   Emulator UI : http://localhost:4000
echo   Firestore   : http://localhost:8080
echo   Functions   : http://localhost:5001
echo ============================================
echo.

:: Add npm global to PATH
set "NPM_BIN=C:\Users\%USERNAME%\AppData\Roaming\npm"
echo %PATH% | find /i "%NPM_BIN%" >nul 2>&1
if %errorlevel% neq 0 set "PATH=%PATH%;%NPM_BIN%"

:: Verify Firebase CLI
where firebase >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Firebase CLI not found.
    echo Install with: npm install -g firebase-tools
    pause & exit /b 1
)

:: Verify Java (required for emulators)
where java >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Java not found. Required for Firebase Emulators.
    echo Install from: https://www.java.com/download
    pause & exit /b 1
)

echo [1/2] Installing function dependencies...
cd functions
call npm install
if %errorlevel% neq 0 ( echo [ERROR] npm install failed. & pause & exit /b 1 )
cd ..

echo.
echo [2/2] Starting Firebase Emulators...
echo       Press Ctrl+C to stop.
echo.

start "" cmd /c "timeout /t 5 /nobreak >nul && start http://localhost:4000"

firebase emulators:start --only functions,firestore --project fast-hostel-managment
pause
