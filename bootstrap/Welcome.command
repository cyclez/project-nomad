#!/usr/bin/env bash
#
# Double-click this file to see setup instructions.
#
clear
cat <<'WELCOME'

  ╔═══════════════════════════════════════════════╗
  ║                                               ║
  ║          EMERGENCY NOMAD                      ║
  ║          Offline Emergency Runtime             ║
  ║                                               ║
  ╚═══════════════════════════════════════════════╝

  This folder contains everything needed to install
  an emergency offline information system on an
  Android phone via USB cable.

  No internet connection is needed.

  ─────────────────────────────────────────────────

  BEFORE AN EMERGENCY (do this now):

  1. On the Android phone:
     Settings → About phone → tap "Build number" 7 times
     Settings → Developer options → USB debugging: ON

  2. Connect the phone via USB cable (must be a DATA cable).

  3. On the phone, tap "Allow" when asked.
     Check "Always allow from this computer".

  ─────────────────────────────────────────────────

  DURING AN EMERGENCY:

     Double-click "Emergency Install"

     That's it. Follow the on-screen instructions.

  ─────────────────────────────────────────────────

  AFTER PHONE REBOOT:

     Double-click "Emergency Restart"

  ─────────────────────────────────────────────────

  TO REMOVE FROM PHONE:

     Double-click "Emergency Uninstall"

  ─────────────────────────────────────────────────

  FILES IN THIS FOLDER:

     Emergency Install       — install the runtime
     Emergency Restart       — restart after reboot
     Emergency Restart (headless) — broken screen mode
     Emergency Uninstall     — remove from phone
     Welcome                 — this screen
     *.zip                   — the emergency bundle
     tools/                  — scripts (do not modify)

  ─────────────────────────────────────────────────

  ADB (Android Debug Bridge) is included.
  Python3 is required (built-in on macOS since 2019).

WELCOME

echo ""
read -rp "  Press Enter to close."
