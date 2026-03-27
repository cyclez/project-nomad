#!/system/bin/sh
#
# emergency-nomad on-device bootstrap installer
#
# Moves a pre-assembled runtime tree from staging into the permanent
# runtime location. All heavy work (zip extraction, tar extraction,
# checksum verification) has already been done on the host.
#
# This script only uses tools available on Android API 21+ (Android 5.0):
#   sh, mv, rm, mkdir, chmod, echo, cat, date
#
# Invoked via:  adb shell sh /data/local/tmp/emergency-nomad-staging/on-device-install.sh
#

STAGING="/data/local/tmp/emergency-nomad-staging"
RUNTIME="/data/local/tmp/emergency-nomad"

# ------------------------------------------------------------------ preflight

if [ ! -d "$STAGING/runtime" ]; then
  echo "error: staged runtime not found at $STAGING/runtime" >&2
  exit 1
fi

echo "emergency-nomad on-device install"
echo "staging: $STAGING"
echo "runtime: $RUNTIME"
echo ""

# -------------------------------------------------------- remove previous install

if [ -d "$RUNTIME" ]; then
  echo "removing previous installation"
  rm -rf "$RUNTIME"
fi

# -------------------------------------------------------- move staged tree

echo "installing runtime"
mv "$STAGING/runtime" "$RUNTIME"

if [ ! -d "$RUNTIME" ]; then
  echo "error: move failed" >&2
  exit 1
fi

# -------------------------------------------------------- daemon permissions
# Recursive chmod without find (not available on API 21 toolbox).

set_exec() {
  for item in "$1"/*; do
    if [ -f "$item" ]; then
      chmod +x "$item"
    elif [ -d "$item" ]; then
      set_exec "$item"
    fi
  done
}

if [ -d "$RUNTIME/daemon" ]; then
  echo "setting daemon permissions"
  set_exec "$RUNTIME/daemon"
fi

# -------------------------------------------------------- install timestamp

if [ -d "$RUNTIME/config" ]; then
  echo "installed_at=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo unknown)" >> "$RUNTIME/config/runtime.conf"
fi

# -------------------------------------------------------- cleanup staging

# Make runtime world-writable so the APK service (different uid) can
# write temp files and the daemon can serve responses.
echo "setting permissions"
chmod -R 777 "$RUNTIME" 2>/dev/null || true

echo "cleaning staging"
rm -rf "$STAGING"

# -------------------------------------------------------- report

echo ""
echo "install complete: $RUNTIME"
if [ -f "$RUNTIME/config/runtime.conf" ]; then
  echo ""
  cat "$RUNTIME/config/runtime.conf"
fi
