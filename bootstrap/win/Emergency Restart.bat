@echo off
title Emergency Nomad — Restart
cd /d "%~dp0"

echo.
echo   Fallback restart: use this only if the phone rebooted
echo   and did not come back by itself after about 2 minutes.
echo.

call usb-push.bat --restart

echo.
if errorlevel 1 (
    echo   Something went wrong. Read the messages above.
) else (
    echo   Done. You can close this window.
)
echo.
pause
