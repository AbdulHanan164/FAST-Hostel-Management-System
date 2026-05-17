@echo off
title FAST Hostel - Flutter Web
cd /d "%~dp0"

echo ============================================
echo   FAST Hostel Management System
echo   Starting Flutter Web Server...
echo ============================================
echo.

:: Check if Flutter is available
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Flutter not found in PATH.
    echo Please install Flutter and add it to your system PATH.
    echo https://docs.flutter.dev/get-started/install
    pause
    exit /b 1
)

echo [INFO] Flutter found. Fetching dependencies...
call flutter pub get

echo.
echo [INFO] Launching Flutter Web on http://localhost:3000
echo [INFO] Press Ctrl+C to stop the server.
echo.

:: Open browser after a short delay
start "" cmd /c "timeout /t 4 /nobreak >nul && start http://localhost:3000"

:: Run Flutter web
flutter run -d chrome --web-port=3000 --web-renderer=html

pause
