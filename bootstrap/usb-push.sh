#!/usr/bin/env bash
#
# emergency-nomad USB bootstrap push
#
# Pushes a pre-assembled emergency runtime to an Android device via USB/ADB.
# All extraction, verification, and assembly happens on this host machine.
# The device only needs: sh, mv, mkdir, chmod, rm (API 21+).
#
# Target host: macOS, Linux, WSL
# Dependencies: adb, python3, unzip, tar
#
# See bootstrap/DECLARATION.md for what this tool does and does not do.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DECLARATION="$SCRIPT_DIR/DECLARATION.md"
RESOLVER="$SCRIPT_DIR/android/resolve-install-plan.py"
JSON_FIELD="$SCRIPT_DIR/android/json-field.py"
DEVICE_INSTALLER="$SCRIPT_DIR/android/on-device-install.sh"
SERVICE_APK="$SCRIPT_DIR/apk/nomad-service.apk"

DEVICE_STAGING="/data/local/tmp/emergency-nomad-staging"
DEVICE_RUNTIME="/data/local/tmp/emergency-nomad"
DAEMON_PORT="1234"
ACCESS_TOKEN=""
SERVICE_APK_PATH=""

# ================================================================== defaults

ADB_SERIAL=""
STORAGE_PROFILE=""
BUNDLE_ZIP=""
MODE="install"    # install | restart
HEADLESS=false
YES=false

# ================================================================== usage

usage() {
  cat <<'EOF'
Usage:
  usb-push.sh [-s SERIAL] [-p PROFILE] [--headless] <bundle.zip>
  usb-push.sh --restart [-s SERIAL] [--headless]

Push an emergency bootstrap bundle to an Android device via USB/ADB,
or restart a previously installed daemon.

Install mode (default):
  Pushes bundle, installs runtime, launches daemon, opens browser.
  All extraction and verification happen on this machine, not on the device.

Restart mode (--restart):
  Relaunches the daemon on a device that already has the runtime installed.
  Does not push or install anything.

Options:
  -s SERIAL    ADB device serial (required if multiple devices connected)
  -p PROFILE   Storage profile override (full, reduced, volatile)
  --headless   Keep cable attached, forward port to host, use browser on computer
               (for phones with broken screens)
  --restart    Skip install, just relaunch the daemon
  --yes, -y    Skip consent prompt (for automation)
  -h           Show this help
EOF
  exit "${1:-0}"
}

# ================================================================== parse args

# Manual long-opt parsing before getopts
POSITIONAL=()
while [ $# -gt 0 ]; do
  case "$1" in
    --headless) HEADLESS=true; shift ;;
    --restart)  MODE="restart"; shift ;;
    --yes|-y)   YES=true; shift ;;
    -*)         POSITIONAL+=("$1"); shift ;;
    *)          POSITIONAL+=("$1"); shift ;;
  esac
done
set -- "${POSITIONAL[@]+"${POSITIONAL[@]}"}"

OPTIND=1
while getopts "s:p:h" opt; do
  case "$opt" in
    s) ADB_SERIAL="$OPTARG" ;;
    p) STORAGE_PROFILE="$OPTARG" ;;
    h) usage 0 ;;
    *) usage 1 ;;
  esac
done
shift $((OPTIND - 1))

if [ "$MODE" = "install" ]; then
  BUNDLE_ZIP="${1:-}"
  if [ -z "$BUNDLE_ZIP" ]; then
    echo "error: bundle.zip path required" >&2
    usage 1
  fi
  if [ ! -f "$BUNDLE_ZIP" ]; then
    echo "error: file not found: $BUNDLE_ZIP" >&2
    exit 1
  fi
fi

# ================================================================== helpers

# Resolve adb: bundled platform-tools first, then PATH
ADB_BIN=""
if [ -x "$SCRIPT_DIR/platform-tools/adb" ]; then
  ADB_BIN="$SCRIPT_DIR/platform-tools/adb"
elif command -v adb >/dev/null 2>&1; then
  ADB_BIN="$(command -v adb)"
fi

adb_cmd() {
  if [ -z "$ADB_BIN" ]; then
    echo "error: adb not found" >&2
    exit 1
  fi
  if [ -n "$ADB_SERIAL" ]; then
    "$ADB_BIN" -s "$ADB_SERIAL" "$@"
  else
    "$ADB_BIN" "$@"
  fi
}

# Host-side SHA-256 (macOS has shasum, Linux has sha256sum)
sha256_verify() {
  local file="$1" expected="$2" actual=""
  if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$file" | cut -d' ' -f1)
  elif command -v shasum >/dev/null 2>&1; then
    actual=$(shasum -a 256 "$file" | cut -d' ' -f1)
  else
    echo "warning: no sha256 tool on host, skipping verification for $(basename "$file")" >&2
    return 0
  fi
  if [ "$actual" != "$expected" ]; then
    echo "error: checksum mismatch for $file" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    return 1
  fi
  return 0
}

# Read a field from bootstrap.json using python3 (built-in on macOS/Linux)
manifest_field() {
  python3 "$JSON_FIELD" "$1" "$2"
}

find_service_apk() {
  if [ -f "$SCRIPT_DIR/nomad-service.apk" ]; then
    printf '%s\n' "$SCRIPT_DIR/nomad-service.apk"
    return 0
  fi
  if [ -f "$SERVICE_APK" ]; then
    printf '%s\n' "$SERVICE_APK"
    return 0
  fi
  return 0
}

# Generate a random access token (12 hex chars, 48 bits entropy).
# Prevents other apps on the device from accessing the daemon at localhost.
generate_token() {
  if command -v sha256sum >/dev/null 2>&1; then
    head -c 32 /dev/urandom | sha256sum | head -c 12
  elif command -v shasum >/dev/null 2>&1; then
    head -c 32 /dev/urandom | shasum -a 256 | head -c 12
  else
    od -An -tx1 -N6 /dev/urandom | tr -d ' \n'
  fi
}

# Read access token from device runtime.conf (for --restart mode)
read_device_token() {
  local token
  token=$(adb_cmd shell "cat '$DEVICE_RUNTIME/config/runtime.conf' 2>/dev/null" \
    | grep '^access_token=' | cut -d= -f2 | tr -d '\r\n')
  echo "$token"
}

# Build the full local URL with token
local_url() {
  echo "http://127.0.0.1:$DAEMON_PORT/s/$ACCESS_TOKEN"
}

# ================================================================== detect device

detect_device() {
  echo "--- device ---"
  echo ""

  if [ -z "$ADB_BIN" ]; then
    echo "error: adb not found" >&2
    exit 1
  fi

  local device_count
  device_count=$("$ADB_BIN" devices | grep -c -E $'\tdevice$' || true)

  if [ "$device_count" -eq 0 ]; then
    echo "error: no ADB device connected" >&2
    echo "Ensure USB debugging is enabled and the device is plugged in." >&2
    exit 1
  fi

  if [ "$device_count" -gt 1 ] && [ -z "$ADB_SERIAL" ]; then
    echo "error: multiple devices connected — use -s SERIAL" >&2
    "$ADB_BIN" devices
    exit 1
  fi

  if [ -z "$ADB_SERIAL" ]; then
    ADB_SERIAL=$("$ADB_BIN" devices | grep -E $'\tdevice$' | head -1 | cut -f1)
  fi

  DEVICE_ABI=$(adb_cmd shell getprop ro.product.cpu.abi | tr -d '\r\n')
  DEVICE_API=$(adb_cmd shell getprop ro.build.version.sdk | tr -d '\r\n')
  DEVICE_MODEL=$(adb_cmd shell getprop ro.product.model | tr -d '\r\n')

  echo "device: $ADB_SERIAL"
  echo "model:  $DEVICE_MODEL"
  echo "abi:    $DEVICE_ABI"
  echo "api:    $DEVICE_API"
  echo ""
}

# ================================================================== launch daemon

install_apk() {
  echo "--- installing service APK ---"
  echo ""

  local apk="$SERVICE_APK_PATH"

  if [ -z "$apk" ]; then
    echo "warning: nomad-service.apk not found, skipping APK install" >&2
    echo "  daemon will be launched directly (won't survive reboot)" >&2
    echo ""
    return 1
  fi

  echo "apk: $apk"
  adb_cmd install -r "$apk" 2>&1 | tail -1
  echo ""
  return 0
}

launch_daemon() {
  echo "--- launching daemon ---"
  echo ""

  # Kill any existing daemon
  adb_cmd shell "pkill -f '[n]omad-daemon' 2>/dev/null || true"
  adb_cmd shell "am force-stop com.emergency.nomad 2>/dev/null || true"
  sleep 1

  # Try launching via APK Service (survives reboot + watchdog)
  local service_ok=false
  if adb_cmd shell "pm list packages 2>/dev/null" | grep -q "com.emergency.nomad"; then
    adb_cmd shell "am start -n com.emergency.nomad/.StartActivity" 2>/dev/null
    service_ok=true
    echo "started via Android Service (survives reboot)"
  else
    # Fallback: direct launch (old method, no reboot survival)
    adb_cmd shell "sh -c 'setsid $DEVICE_RUNTIME/daemon/nomad-daemon </dev/null >/dev/null 2>&1 & exit 0'"
    echo "started directly (will NOT survive reboot — install APK for persistence)"
  fi

  # Wait for daemon to bind
  sleep 5

  # Verify daemon is running
  local pid
  pid=$(adb_cmd shell "pgrep -f '[n]omad-daemon' 2>/dev/null | head -1" | tr -d '\r\n')
  if [ -z "$pid" ]; then
    echo "warning: daemon may not have started (no PID found)" >&2
  else
    echo "daemon running: PID $pid on port $DAEMON_PORT"
  fi
  echo ""
}

# ================================================================== open browser / port forward

open_access() {
  local url
  url=$(local_url)

  if [ "$HEADLESS" = true ]; then
    echo "--- headless mode: port forward ---"
    echo ""
    echo "Forwarding device port $DAEMON_PORT to this computer."
    echo "Keep the USB cable connected."
    echo ""
    adb_cmd forward "tcp:$DAEMON_PORT" "tcp:$DAEMON_PORT"
    echo "Open on this computer:"
    echo ""
    echo "  $url"
    echo ""

    # Try to open browser on host
    if command -v open >/dev/null 2>&1; then
      open "$url" 2>/dev/null || true
    elif command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$url" 2>/dev/null || true
    fi
  else
    echo "--- opening browser on device ---"
    echo ""
    adb_cmd shell "am start -a android.intent.action.VIEW -d '$url' 2>/dev/null || true"
    echo "Browser opened on device."
    echo "Bookmark this address:"
    echo ""
    echo "  $url"
    echo ""
    echo "You can disconnect the USB cable now."
    echo ""
  fi
}

# ================================================================== restart mode

if [ "$MODE" = "restart" ]; then
  detect_device

  # Read existing token from device
  ACCESS_TOKEN=$(read_device_token)
  if [ -z "$ACCESS_TOKEN" ]; then
    echo "warning: no access token found in runtime.conf" >&2
    echo "  the runtime may not be installed yet" >&2
  fi

  launch_daemon
  open_access

  echo "--- done ---"
  echo "Daemon relaunched on $DEVICE_MODEL ($ADB_SERIAL)."
  exit 0
fi

# ================================================================== install mode: preflight

echo "--- preflight ---"
echo ""

if [ -z "$ADB_BIN" ]; then
  echo "error: adb not found — place platform-tools/ next to this script or install adb" >&2
  exit 1
fi
echo "adb: $ADB_BIN"

for tool in python3 unzip tar; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: $tool not found in PATH" >&2
    exit 1
  fi
  echo "$tool: $(command -v "$tool")"
done

SERVICE_APK_PATH="$(find_service_apk)"

# Check bundle contains bootstrap.json
if ! unzip -l "$BUNDLE_ZIP" bootstrap.json >/dev/null 2>&1; then
  echo "error: bundle does not contain bootstrap.json at root" >&2
  exit 1
fi
echo "bundle: $BUNDLE_ZIP"
echo ""

# ================================================================== detect device

detect_device

# ================================================================== host temp dir

TMPDIR_HOST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_HOST"' EXIT

# Extract bootstrap.json from the bundle
unzip -q -o "$BUNDLE_ZIP" bootstrap.json -d "$TMPDIR_HOST"
MANIFEST="$TMPDIR_HOST/bootstrap.json"

# ================================================================== compatibility checks

API_MIN=$(manifest_field "$MANIFEST" "compatibility.android_api_min")
if [ "$DEVICE_API" -lt "$API_MIN" ]; then
  echo "error: device API $DEVICE_API < minimum $API_MIN" >&2
  exit 1
fi

ABI_SUPPORTED=$(python3 -c "
import json,sys
m=json.load(open(sys.argv[1]))
print('yes' if sys.argv[2] in m['compatibility']['supported_abis'] else 'no',end='')
" "$MANIFEST" "$DEVICE_ABI")

if [ "$ABI_SUPPORTED" != "yes" ]; then
  echo "error: device ABI $DEVICE_ABI not supported by this bundle" >&2
  exit 1
fi

echo "compatibility: api $DEVICE_API >= $API_MIN, abi $DEVICE_ABI supported"

# ================================================================== resolve install plan

echo ""
echo "--- resolve install plan ---"
echo ""

PLAN_ARGS=("$MANIFEST" "$DEVICE_ABI")
if [ -n "$STORAGE_PROFILE" ]; then
  PLAN_ARGS+=("$STORAGE_PROFILE")
fi

python3 "$RESOLVER" "${PLAN_ARGS[@]}" > "$TMPDIR_HOST/install-plan.txt"

# Show plan summary
grep -v '^#' "$TMPDIR_HOST/install-plan.txt" | grep -v '^$' | while IFS= read -r line; do
  echo "  $line"
done
echo ""

# ================================================================== declaration + consent

echo "============================================================"
if [ -f "$DECLARATION" ]; then
  cat "$DECLARATION"
else
  echo "(DECLARATION.md not found — proceed with caution)"
fi
echo "============================================================"
echo ""
echo "target:  $DEVICE_MODEL ($ADB_SERIAL)"
echo "abi:     $DEVICE_ABI"
echo "api:     $DEVICE_API"
echo "bundle:  $(basename "$BUNDLE_ZIP")"
RESOLVED_PROFILE=$(grep '^# bundle=' "$TMPDIR_HOST/install-plan.txt" | sed 's/.*profile=//' | sed 's/ .*//')
echo "profile: $RESOLVED_PROFILE"
echo ""
echo "THIS WILL:"
echo "  - overwrite any previous emergency-nomad installation on this device"
echo "  - use storage space on the device"
if [ -n "$SERVICE_APK_PATH" ]; then
  echo "  - install the bundled helper APK (com.emergency.nomad)"
else
  echo "  - install only the runtime tree (no helper APK bundled on this host)"
fi
echo "  - launch a local daemon bound to 127.0.0.1:$DAEMON_PORT"
echo "  - open a browser on the device (or forward port if --headless)"
echo ""
echo "THIS WILL NOT:"
echo "  - use the network"
echo "  - root the device"
echo "  - modify bootloader, recovery, or the system partition"
echo "  - change radios or airplane-mode state for you"
echo ""
if [ "$YES" = true ]; then
  echo "Proceed? [y/N] y  (--yes flag)"
else
  printf "Proceed? [y/N] "
  read -r confirm < /dev/tty
  case "$confirm" in
    y|Y) ;;
    *)
      echo "Aborted by operator."
      exit 0
      ;;
  esac
fi

# ================================================================== assemble runtime tree on host

echo ""
echo "--- assembling runtime tree ---"
echo ""

LOCAL_RUNTIME="$TMPDIR_HOST/staging/runtime"
mkdir -p "$LOCAL_RUNTIME/config"

# Generate access token for this installation
ACCESS_TOKEN=$(generate_token)
echo "access_token=$ACCESS_TOKEN" >> "$LOCAL_RUNTIME/config/runtime.conf"
echo "access token: $ACCESS_TOKEN"

while IFS= read -r line; do
  # Handle config comments
  case "$line" in
    '# config: '*)
      echo "${line#\# config: }" >> "$LOCAL_RUNTIME/config/runtime.conf"
      continue
      ;;
    '#'*|'')
      continue
      ;;
  esac

  # Parse: ACTION SOURCE_PATH DEST_SUBDIR SHA256
  action=$(echo "$line" | cut -d' ' -f1)
  source_path=$(echo "$line" | cut -d' ' -f2)
  dest_subdir=$(echo "$line" | cut -d' ' -f3)
  checksum=$(echo "$line" | cut -d' ' -f4)

  dest_dir="$LOCAL_RUNTIME/$dest_subdir"
  mkdir -p "$dest_dir"

  echo "[$action] $source_path -> $dest_subdir"

  # Extract file from zip on the host
  unzip -q -o "$BUNDLE_ZIP" "$source_path" -d "$TMPDIR_HOST/zip_extract"
  extracted="$TMPDIR_HOST/zip_extract/$source_path"

  if [ ! -f "$extracted" ]; then
    echo "error: $source_path not found in bundle" >&2
    exit 1
  fi

  # Verify checksum on the host
  if [ "$checksum" != "-" ]; then
    if ! sha256_verify "$extracted" "$checksum"; then
      exit 1
    fi
    echo "  sha256: ok"
  fi

  # Process based on action
  case "$action" in
    extract)
      tar xf "$extracted" -C "$dest_dir"
      ;;
    copy|seed)
      cp "$extracted" "$dest_dir/$(basename "$source_path")"
      ;;
    *)
      echo "warning: unknown action '$action', skipped" >&2
      ;;
  esac

  # Clean per-file temp
  rm -rf "$TMPDIR_HOST/zip_extract"

done < "$TMPDIR_HOST/install-plan.txt"

echo ""

# ================================================================== push to device

echo "--- pushing to device ---"
echo ""

adb_cmd shell "rm -rf '$DEVICE_STAGING' && mkdir -p '$DEVICE_STAGING'"

echo "pushing runtime tree..."
adb_cmd push "$LOCAL_RUNTIME" "$DEVICE_STAGING/runtime"

echo "pushing installer..."
adb_cmd push "$DEVICE_INSTALLER" "$DEVICE_STAGING/on-device-install.sh"

echo ""

# ================================================================== run on-device install

echo "--- running on-device install ---"
echo ""

adb_cmd shell "sh '$DEVICE_STAGING/on-device-install.sh'"

echo ""

# ================================================================== install APK + launch daemon + open access

install_apk || true
launch_daemon
open_access

echo "--- done ---"
echo ""
echo "Bootstrap complete: $DEVICE_MODEL ($ADB_SERIAL)"
echo ""
echo "Your address (save this):"
echo ""
echo "  $(local_url)"
echo ""
if [ "$HEADLESS" = true ]; then
  echo "Headless mode: keep cable connected, use browser on this computer."
else
  echo "You can disconnect the USB cable. The daemon stays running."
  echo "If the phone restarts, reconnect and run: usb-push.sh --restart"
fi
