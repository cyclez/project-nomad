@echo off
chcp 65001 >nul 2>&1
title Emergency Nomad
cls
echo.
echo   ╔═══════════════════════════════════════════════╗
echo   ║                                               ║
echo   ║          EMERGENCY NOMAD                      ║
echo   ║          Offline Emergency Runtime             ║
echo   ║                                               ║
echo   ╚═══════════════════════════════════════════════╝
echo.
echo   This folder contains everything needed to install
echo   an emergency offline information system on an
echo   Android phone via USB cable.
echo.
echo   No internet connection is needed.
echo   After install, the phone runs locally by itself.
echo.
echo   ─────────────────────────────────────────────────
echo.
echo   BEFORE AN EMERGENCY (do this now):
echo.
echo   1. On the Android phone:
echo      Settings ^> About phone ^> tap "Build number" 7 times
echo      Settings ^> Developer options ^> USB debugging: ON
echo.
echo   2. Connect the phone via USB cable (must be a DATA cable).
echo.
echo   3. On the phone, tap "Allow" when asked.
echo      Check "Always allow from this computer".
echo.
echo   ─────────────────────────────────────────────────
echo.
echo   DURING AN EMERGENCY:
echo.
echo      Double-click "Emergency Install"
echo.
echo   AFTER PHONE REBOOT:
echo.
echo      Wait up to 2 minutes.
echo      If the local page does not come back,
echo      double-click "Emergency Restart"
echo.
echo   TO REMOVE FROM PHONE:
echo.
echo      Double-click "Emergency Uninstall"
echo.
echo   ─────────────────────────────────────────────────
echo.
echo   ADB (Android Debug Bridge) is included.
echo   Requires Windows 10 or later.
echo.
pause
