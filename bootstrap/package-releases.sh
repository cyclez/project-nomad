#!/usr/bin/env bash
#
# package-releases.sh
#
# Builds distributable packages for macOS and Windows.
# Each package is a self-contained zip — user only needs adb.
#
# Output:
#   bootstrap/releases/emergency-nomad-mac-<date>.zip
#   bootstrap/releases/emergency-nomad-win-<date>.zip
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(date +%Y.%m.%d)"
OUT="$SCRIPT_DIR/releases"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

VENDOR="$SCRIPT_DIR/vendor"

mkdir -p "$OUT"

# ================================================================== check vendor deps
echo "checking bundled dependencies..."
if [ ! -d "$VENDOR/mac-extract/platform-tools" ]; then
  echo "error: macOS platform-tools not found at $VENDOR/mac-extract/platform-tools" >&2
  echo "Run: curl -sL https://dl.google.com/android/repository/platform-tools-latest-darwin.zip -o $VENDOR/platform-tools-darwin.zip && unzip -q $VENDOR/platform-tools-darwin.zip -d $VENDOR/mac-extract" >&2
  exit 1
fi
if [ ! -d "$VENDOR/win-extract/platform-tools" ]; then
  echo "error: Windows platform-tools not found at $VENDOR/win-extract/platform-tools" >&2
  echo "Run: curl -sL https://dl.google.com/android/repository/platform-tools-latest-windows.zip -o $VENDOR/platform-tools-windows.zip && unzip -q $VENDOR/platform-tools-windows.zip -d $VENDOR/win-extract" >&2
  exit 1
fi
echo "  macOS adb: $("$VENDOR/mac-extract/platform-tools/adb" version 2>&1 | head -1)"
echo "  Windows adb: found ($(du -sh "$VENDOR/win-extract/platform-tools/adb.exe" | cut -f1))"
echo ""

# ================================================================== build test bundle first
echo "building test bundle..."
bash "$SCRIPT_DIR/build-test-bundle.sh" 2>&1 | tail -2
BUNDLE=$(ls -1 "$SCRIPT_DIR"/emergency-bootstrap-*.zip 2>/dev/null | head -1)
if [ -z "$BUNDLE" ]; then
  echo "error: no bundle found after build" >&2
  exit 1
fi
echo ""

# ================================================================== macOS package
echo "packaging macOS..."

MAC="$WORK/emergency-nomad-mac"
mkdir -p "$MAC/tools/android"

# Scripts
cp "$SCRIPT_DIR/usb-push.sh"                        "$MAC/tools/"
cp "$SCRIPT_DIR/emergency-watch.sh"                  "$MAC/tools/"
cp "$SCRIPT_DIR/android/on-device-install.sh"        "$MAC/tools/android/"
cp "$SCRIPT_DIR/android/resolve-install-plan.py"     "$MAC/tools/android/"
cp "$SCRIPT_DIR/android/json-field.py"               "$MAC/tools/android/"
cp "$SCRIPT_DIR/DECLARATION.md"                      "$MAC/tools/"

# APK
if [ -f "$SCRIPT_DIR/apk/nomad-service.apk" ]; then
  cp "$SCRIPT_DIR/apk/nomad-service.apk"             "$MAC/tools/"
else
  echo "warning: nomad-service.apk not found — build with bootstrap/apk/build-apk.sh" >&2
fi

# Launchers
cp "$SCRIPT_DIR/Emergency Install.command"              "$MAC/"
cp "$SCRIPT_DIR/Emergency Restart.command"              "$MAC/"
cp "$SCRIPT_DIR/Emergency Restart (headless).command"   "$MAC/"
cp "$SCRIPT_DIR/Emergency Uninstall.command"            "$MAC/"
cp "$SCRIPT_DIR/Emergency Uninstall (full).command"     "$MAC/"
cp "$SCRIPT_DIR/Welcome.command"                        "$MAC/"

# Uninstall script
cp "$SCRIPT_DIR/uninstall.sh"                           "$MAC/tools/"

# Fix launcher paths to point to tools/
for cmd in "$MAC"/*.command; do
  sed -i '' 's|./emergency-watch.sh|./tools/emergency-watch.sh|' "$cmd" 2>/dev/null || true
  sed -i '' 's|./usb-push.sh|./tools/usb-push.sh|' "$cmd" 2>/dev/null || true
  sed -i '' 's|./uninstall.sh|./tools/uninstall.sh|' "$cmd" 2>/dev/null || true
done

# Fix emergency-watch.sh to find usb-push.sh in same dir
sed -i '' 's|SCRIPT_DIR/usb-push.sh|SCRIPT_DIR/tools/usb-push.sh|' "$MAC/tools/emergency-watch.sh" 2>/dev/null || true

# Bundle
cp "$BUNDLE" "$MAC/"

# Bundled ADB
cp -R "$VENDOR/mac-extract/platform-tools" "$MAC/tools/platform-tools"

# Make executable
chmod +x "$MAC/tools/"*.sh "$MAC"/*.command "$MAC/tools/platform-tools/adb"

MAC_ZIP="emergency-nomad-mac-${VERSION}.zip"
cd "$WORK"
zip -qr "$OUT/$MAC_ZIP" "emergency-nomad-mac"
cd - >/dev/null
echo "  $OUT/$MAC_ZIP ($(du -sh "$OUT/$MAC_ZIP" | cut -f1))"

# ================================================================== Windows package
echo "packaging Windows..."

WIN="$WORK/emergency-nomad-win"
mkdir -p "$WIN/tools"

# Scripts
cp "$SCRIPT_DIR/win/usb-push.bat"                   "$WIN/"
cp "$SCRIPT_DIR/win/tools/resolve-install-plan.ps1"  "$WIN/tools/"
cp "$SCRIPT_DIR/android/on-device-install.sh"        "$WIN/tools/"
cp "$SCRIPT_DIR/DECLARATION.md"                      "$WIN/"

# APK
if [ -f "$SCRIPT_DIR/apk/nomad-service.apk" ]; then
  cp "$SCRIPT_DIR/apk/nomad-service.apk"               "$WIN/tools/"
fi

# Launchers
cp "$SCRIPT_DIR/win/Emergency Install.bat"              "$WIN/"
cp "$SCRIPT_DIR/win/Emergency Restart.bat"              "$WIN/"
cp "$SCRIPT_DIR/win/Emergency Restart (headless).bat"   "$WIN/"
cp "$SCRIPT_DIR/win/Emergency Uninstall.bat"            "$WIN/"
cp "$SCRIPT_DIR/win/Emergency Uninstall (full).bat"     "$WIN/"
cp "$SCRIPT_DIR/win/Welcome.bat"                        "$WIN/"

# Uninstall script
cp "$SCRIPT_DIR/win/uninstall.bat"                      "$WIN/"

# Bundled ADB
cp -R "$VENDOR/win-extract/platform-tools" "$WIN/tools/platform-tools"

# Bundle
cp "$BUNDLE" "$WIN/"

WIN_ZIP="emergency-nomad-win-${VERSION}.zip"
cd "$WORK"
zip -qr "$OUT/$WIN_ZIP" "emergency-nomad-win"
cd - >/dev/null
echo "  $OUT/$WIN_ZIP ($(du -sh "$OUT/$WIN_ZIP" | cut -f1))"

# ================================================================== done
echo ""
echo "packages ready:"
echo "  mac: $OUT/$MAC_ZIP"
echo "  win: $OUT/$WIN_ZIP"
