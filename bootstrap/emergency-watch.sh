#!/usr/bin/env bash
#
# emergency-watch.sh
#
# Watches for an Android device via USB/ADB and installs automatically
# when the device is connected and authorized.
#
# The only manual step required: tap "Allow" on the phone screen.
# Everything else is automatic.
#
# Works on any computer with bash + adb + node (2013+).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BUNDLE_ZIP="${1:-}"
EXTRA_ARGS=("${@:2}")

POLL_INTERVAL=1
LAST_STATE=""

# ================================================================== usage

if [ -z "$BUNDLE_ZIP" ]; then
  echo ""
  echo "Usage: emergency-watch.sh <bundle.zip> [usb-push options]"
  echo ""
  echo "Waits for a phone to connect via USB, then installs automatically."
  echo "The only thing you need to do on the phone: tap OK when it asks."
  echo ""
  exit 1
fi

if [ ! -f "$BUNDLE_ZIP" ]; then
  echo "error: bundle not found: $BUNDLE_ZIP" >&2
  exit 1
fi

# Resolve adb: bundled platform-tools first, then PATH
ADB_BIN=""
if [ -x "$SCRIPT_DIR/platform-tools/adb" ]; then
  ADB_BIN="$SCRIPT_DIR/platform-tools/adb"
elif command -v adb >/dev/null 2>&1; then
  ADB_BIN="$(command -v adb)"
else
  echo "error: adb not found" >&2
  exit 1
fi

# ================================================================== watch loop

clear_line() {
  printf "\r\033[K"
}

print_state() {
  clear_line
  printf "%s" "$1"
}

echo ""
echo "  emergency-nomad — auto installer"
echo "  ─────────────────────────────────"
echo "  bundle: $(basename "$BUNDLE_ZIP")"
echo ""

SPINNER='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
SPIN_IDX=0

while true; do
  # Read current ADB state
  ADB_OUT=$("$ADB_BIN" devices 2>/dev/null)

  DEVICE_LINE=$(echo "$ADB_OUT" | grep -E $'\tdevice$' | head -1 || true)
  UNAUTH_LINE=$(echo "$ADB_OUT" | grep -E $'\tunauthorized$' | head -1 || true)

  SPIN_CHAR="${SPINNER:$((SPIN_IDX % ${#SPINNER})):1}"
  SPIN_IDX=$((SPIN_IDX + 1))

  if [ -n "$DEVICE_LINE" ]; then
    # Authorized device found — go
    SERIAL=$(echo "$DEVICE_LINE" | cut -f1)
    clear_line
    echo ""
    echo "  Phone connected: $SERIAL"
    echo ""
    echo "  Starting install..."
    echo ""
    exec bash "$SCRIPT_DIR/usb-push.sh" -s "$SERIAL" "${EXTRA_ARGS[@]}" "$BUNDLE_ZIP"

  elif [ -n "$UNAUTH_LINE" ]; then
    # Device visible but not authorized
    if [ "$LAST_STATE" != "unauthorized" ]; then
      clear_line
      echo ""
      echo "  ┌─────────────────────────────────────────┐"
      echo "  │                                         │"
      echo "  │   LOOK AT YOUR PHONE                    │"
      echo "  │                                         │"
      echo "  │   A popup is asking permission.         │"
      echo "  │   Tap  OK  or  Allow .                  │"
      echo "  │                                         │"
      echo "  │   Tip: also check                       │"
      echo "  │   \"Always allow from this computer\"     │"
      echo "  │                                         │"
      echo "  └─────────────────────────────────────────┘"
      echo ""
      LAST_STATE="unauthorized"
    fi
    print_state "  $SPIN_CHAR waiting for authorization..."

  else
    # No device
    if [ "$LAST_STATE" != "waiting" ]; then
      clear_line
      echo ""
      echo "  ┌─────────────────────────────────────────┐"
      echo "  │                                         │"
      echo "  │   Plug in the phone via USB cable       │"
      echo "  │                                         │"
      echo "  │   Make sure the phone is unlocked.      │"
      echo "  │   USB debugging must be enabled.        │"
      echo "  │                                         │"
      echo "  └─────────────────────────────────────────┘"
      echo ""
      LAST_STATE="waiting"
    fi
    print_state "  $SPIN_CHAR waiting for phone..."
  fi

  sleep $POLL_INTERVAL
done
