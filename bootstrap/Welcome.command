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

  This folder can install Emergency Nomad on an
  Android phone by USB cable.

  No internet connection is needed.
  After install, the phone runs locally by itself.

  ─────────────────────────────────────────────────

  BEFORE AN EMERGENCY:

  1. On the phone, open Settings.

  2. Find "Build number".
     Use Settings search if needed.
     Then tap it 7 times.

  3. Go back and find "USB debugging".
     Use Settings search if needed.
     Turn it ON.

  4. Connect the phone with a real data cable.

  5. On the phone, tap "Allow" when asked.
     Also check:
     "Always allow from this computer"

  ─────────────────────────────────────────────────

  IF MACOS BLOCKS THE APP:

     If you see "Unidentified Developer",
     open Terminal like this:

       Press Command + Space
       Type Terminal
       Press Return

     Then type:

       bash "./Emergency Unblock.command"

     Then try again.

  ─────────────────────────────────────────────────

  DURING AN EMERGENCY:

     Double-click "Emergency Install.command"

     Read the screen.
     Type y and press Return when asked.

  ─────────────────────────────────────────────────

  AFTER PHONE REBOOT:

     Wait up to 2 minutes.
     If the local page does not come back,
     then double-click "Emergency Restart.command"

  ─────────────────────────────────────────────────

  TO REMOVE FROM PHONE:

     Double-click "Emergency Uninstall.command"

  ─────────────────────────────────────────────────

  FILES IN THIS FOLDER:

     Emergency Install.command - install to the phone
     Emergency Restart.command - fallback restart after reboot
     Emergency Restart (headless).command - broken-screen mode
     Emergency Uninstall.command - remove from phone
     Emergency Unblock.command - remove macOS security block
     Welcome.command - this screen
     *.zip - the emergency bundle
     tools/ - scripts, do not modify

  ─────────────────────────────────────────────────

  ADB (Android Debug Bridge) is included.
  Python3 is also required.

WELCOME

echo ""
read -rp "  Press Enter to close."
