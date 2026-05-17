@echo off
title FAST Hostel - Launcher
cd /d "%~dp0"

:menu
cls
echo.
echo  ============================================
echo    FAST Hostel Management System
echo    Local Development Launcher
echo  ============================================
echo.
echo    [1]  Landing Page  --  http://localhost:8080
echo    [2]  Flutter App   --  http://localhost:3000
echo    [3]  Backend Emu   --  http://localhost:4000
echo    [4]  All Three     --  Open all in windows
echo    [5]  Exit
echo.
set /p choice="  Choose [1-5]: "

if "%choice%"=="1" (
    start "Landing Page" cmd /k "cd /d %~dp0frontend && node serve_landing.js"
    timeout /t 3 /nobreak >nul
    start "" "http://localhost:8080"
    goto menu
)
if "%choice%"=="2" (
    start "Flutter Web" cmd /k "cd /d %~dp0frontend && call start.bat"
    goto menu
)
if "%choice%"=="3" (
    start "Firebase Backend" cmd /k "cd /d %~dp0backend && call start.bat"
    goto menu
)
if "%choice%"=="4" (
    start "Landing Page"     cmd /k "cd /d %~dp0frontend && node serve_landing.js"
    timeout /t 2 /nobreak >nul
    start "Flutter Web"      cmd /k "cd /d %~dp0frontend && call start.bat"
    timeout /t 2 /nobreak >nul
    start "Firebase Backend" cmd /k "cd /d %~dp0backend && call start.bat"
    timeout /t 5 /nobreak >nul
    start "" "http://localhost:8080"
    goto menu
)
if "%choice%"=="5" exit /b 0
goto menu
