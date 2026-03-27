@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1
title Emergency Nomad — Uninstall

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "DEVICE_RUNTIME=/data/local/tmp/emergency-nomad"
set "DEVICE_STAGING=/data/local/tmp/emergency-nomad-staging"
set "APK_PACKAGE=com.emergency.nomad"
set "FULL=0"
set "ADB_SERIAL="

:: Parse args
:parse
if "%~1"=="" goto start
if /i "%~1"=="--full" (set "FULL=1" & shift & goto parse)
set "ADB_SERIAL=%~1"
shift
goto parse

:start
:: Resolve adb
set "ADB="
if exist "%SCRIPT_DIR%\tools\platform-tools\adb.exe" (
    set "ADB=%SCRIPT_DIR%\tools\platform-tools\adb.exe"
) else (
    where adb >nul 2>&1
    if !errorlevel!==0 for /f "delims=" %%a in ('where adb') do set "ADB=%%a"
)
if "%ADB%"=="" (echo   error: adb not found & exit /b 1)

if "%FULL%"=="1" (
    echo.
    echo   emergency-nomad — FULL uninstall
) else (
    echo.
    echo   emergency-nomad — easy uninstall
)
echo   ───────────────────────────
echo.

:: Detect device
set "DEVICE_COUNT=0"
set "FIRST_SERIAL="
for /f "tokens=1,2" %%a in ('"%ADB%" devices') do (
    if "%%b"=="device" (
        set /a DEVICE_COUNT+=1
        if not defined FIRST_SERIAL set "FIRST_SERIAL=%%a"
    )
)
if %DEVICE_COUNT%==0 (echo   No device connected. & exit /b 1)
if "%ADB_SERIAL%"=="" set "ADB_SERIAL=%FIRST_SERIAL%"

for /f "delims=" %%v in ('"%ADB%" -s %ADB_SERIAL% shell getprop ro.product.model') do set "MODEL=%%v"
echo   device: %MODEL% (%ADB_SERIAL%)
echo.

:: Stop
echo   [1] stopping daemon + service...
"%ADB%" -s %ADB_SERIAL% shell "am force-stop %APK_PACKAGE% 2>/dev/null || true"
"%ADB%" -s %ADB_SERIAL% shell "pkill -f '[n]omad-daemon' 2>/dev/null || true"
timeout /t 1 /nobreak >nul

:: Remove runtime
echo   [2] removing runtime...
"%ADB%" -s %ADB_SERIAL% shell "rm -rf '%DEVICE_RUNTIME%' '%DEVICE_STAGING%' 2>/dev/null || true"

:: Clear forwards
echo   [3] clearing port forwards...
"%ADB%" forward --remove-all >nul 2>&1

:: Full: remove APK
if "%FULL%"=="1" (
    echo   [4] removing APK...
    "%ADB%" -s %ADB_SERIAL% uninstall %APK_PACKAGE% >nul 2>&1
)

echo.
if "%FULL%"=="1" (
    echo   Full uninstall complete.
    echo   All traces removed from %MODEL%.
) else (
    echo   Easy uninstall complete.
    echo   Runtime removed. APK kept for fast reinstall.
    echo   For full removal: uninstall.bat --full
)
echo.
