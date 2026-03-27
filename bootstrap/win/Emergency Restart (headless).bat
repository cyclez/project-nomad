@echo off
title Emergency Nomad — Restart (Headless)
cd /d "%~dp0"

call usb-push.bat --restart --headless

echo.
if errorlevel 1 (
    echo   Something went wrong. Read the messages above.
) else (
    echo   Done. You can close this window.
)
echo.
pause
