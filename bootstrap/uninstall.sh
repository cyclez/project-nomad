#!/usr/bin/env bash
#
# uninstall.sh
#
# Two modes:
#   uninstall.sh [SERIAL]         — easy: stop daemon, remove runtime, keep APK + config
#   uninstall.sh --full [SERIAL]  — full: remove everything including APK
#
# Easy uninstall is a security "temp wipe" — data gone, app stays for fast reinstall.
# Full uninstall is a "total wipe" — nothing left on the device.
#
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEVICE_RUNTIME="/data/local/tmp/emergency-nomad"
DEVICE_STAGING="/data/local/tmp/emergency-nomad-staging"
APK_PACKAGE="com.emergency.nomad"

FULL=false
ADB_SERIAL=""

# ================================================================== parse args
for arg in "$@"; do
  case "$arg" in
    --full) FULL=true ;;
    *)      ADB_SERIAL="$arg" ;;
  esac
done

# ================================================================== resolve adb
ADB_BIN=""
if [ -x "$SCRIPT_DIR/platform-tools/adb" ]; then
  ADB_BIN="$SCRIPT_DIR/platform-tools/adb"
elif [ -x "$SCRIPT_DIR/tools/platform-tools/adb" ]; then
  ADB_BIN="$SCRIPT_DIR/tools/platform-tools/adb"
elif command -v adb >/dev/null 2>&1; then
  ADB_BIN="$(command -v adb)"
else
  echo "error: adb not found" >&2
  exit 1
fi

adb_cmd() {
  if [ -n "$ADB_SERIAL" ]; then
    "$ADB_BIN" -s "$ADB_SERIAL" "$@"
  else
    "$ADB_BIN" "$@"
  fi
}

# ================================================================== detect device

if [ "$FULL" = true ]; then
  MODE_LABEL="FULL uninstall (remove everything)"
else
  MODE_LABEL="easy uninstall (remove runtime, keep APK)"
fi

echo ""
echo "  emergency-nomad — uninstall"
echo "  ───────────────────────────"
echo "  mode: $MODE_LABEL"
echo ""

DEVICE_COUNT=$("$ADB_BIN" devices | grep -c -E $'\tdevice$' || true)

if [ "$DEVICE_COUNT" -eq 0 ]; then
  echo "  No device connected."
  echo "  Connect the phone via USB and try again."
  echo ""
  exit 1
fi

if [ "$DEVICE_COUNT" -gt 1 ] && [ -z "$ADB_SERIAL" ]; then
  echo "  Multiple devices connected — pass serial as argument:"
  echo "    uninstall.sh [--full] <SERIAL>"
  echo ""
  "$ADB_BIN" devices
  exit 1
fi

if [ -z "$ADB_SERIAL" ]; then
  ADB_SERIAL=$("$ADB_BIN" devices | grep -E $'\tdevice$' | head -1 | cut -f1)
fi

MODEL=$(adb_cmd shell getprop ro.product.model | tr -d '\r\n')
echo "  device: $MODEL ($ADB_SERIAL)"

# Check what's installed
HAS_RUNTIME=$(adb_cmd shell "[ -d '$DEVICE_RUNTIME' ] && echo yes || echo no" | tr -d '\r\n')
HAS_APK=$(adb_cmd shell "pm list packages 2>/dev/null" | grep -q "$APK_PACKAGE" && echo yes || echo no)

echo "  runtime: $HAS_RUNTIME"
echo "  apk: $HAS_APK"

if [ "$HAS_RUNTIME" != "yes" ] && [ "$HAS_APK" != "yes" ]; then
  echo ""
  echo "  Nothing to remove."
  echo ""
  exit 0
fi

echo ""

# ================================================================== stop daemon + service

STEP=1
TOTAL=3
if [ "$FULL" = true ]; then
  TOTAL=4
fi

echo "  [$STEP/$TOTAL] stopping daemon + service..."
adb_cmd shell "am force-stop $APK_PACKAGE 2>/dev/null || true"
adb_cmd shell "pkill -f '[n]omad-daemon' 2>/dev/null || true"
sleep 0.5

# ================================================================== remove runtime

STEP=$((STEP + 1))
echo "  [$STEP/$TOTAL] removing runtime..."
adb_cmd shell "rm -rf '$DEVICE_RUNTIME' '$DEVICE_STAGING' 2>/dev/null || true"

# ================================================================== clear port forwards

STEP=$((STEP + 1))
echo "  [$STEP/$TOTAL] clearing port forwards..."
"$ADB_BIN" forward --remove-all 2>/dev/null || true

# ================================================================== full: remove APK

if [ "$FULL" = true ]; then
  STEP=$((STEP + 1))
  echo "  [$STEP/$TOTAL] removing APK..."
  adb_cmd uninstall "$APK_PACKAGE" 2>/dev/null || true
fi

# ================================================================== verify

echo ""

STILL_RUNTIME=$(adb_cmd shell "[ -d '$DEVICE_RUNTIME' ] && echo yes || echo no" | tr -d '\r\n')
STILL_APK=$(adb_cmd shell "pm list packages 2>/dev/null" | grep -q "$APK_PACKAGE" && echo yes || echo no)

if [ "$FULL" = true ]; then
  if [ "$STILL_RUNTIME" = "no" ] && [ "$STILL_APK" = "no" ]; then
    echo "  Full uninstall complete."
    echo "  All traces of emergency-nomad removed from $MODEL."
  else
    echo "  warning: some components may remain (runtime=$STILL_RUNTIME apk=$STILL_APK)"
  fi
else
  if [ "$STILL_RUNTIME" = "no" ]; then
    echo "  Easy uninstall complete."
    echo "  Runtime removed. APK kept for fast reinstall."
    if [ "$STILL_APK" = "yes" ]; then
      echo "  To remove everything: uninstall.sh --full"
    fi
  else
    echo "  warning: runtime directory still exists"
  fi
fi
echo ""
