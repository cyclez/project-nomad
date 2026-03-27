@echo off
title Emergency Nomad — Install
cd /d "%~dp0"

:: Find first .zip bundle in this folder
set "BUNDLE="
for %%f in (*.zip) do (
    if not defined BUNDLE set "BUNDLE=%%f"
)

if not defined BUNDLE (
    echo.
    echo   No .zip bundle found.
    echo.
    echo   Place your emergency bootstrap .zip file
    echo   in the same folder as this icon, then double-click again.
    echo.
    pause
    exit /b 1
)

call usb-push.bat "%BUNDLE%"

echo.
if errorlevel 1 (
    echo   Something went wrong. Read the messages above.
) else (
    echo   Done. You can close this window.
)
echo.
pause
