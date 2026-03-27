#!/usr/bin/env bash
#
# build-apk.sh
#
# Builds the emergency-nomad APK without Android Studio.
# Uses aapt2 + javac + d8 + apksigner from the Android SDK build-tools.
#
# Output: bootstrap/apk/nomad-service.apk
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ================================================================== SDK paths

# Use bundled JDK if system Java is too old for modern build-tools
VENDOR_JDK="$SCRIPT_DIR/../vendor/jdk17/Contents/Home"
if [ -x "$VENDOR_JDK/bin/java" ]; then
  export JAVA_HOME="$VENDOR_JDK"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
BT_DIR="$SDK/build-tools"
PLATFORM_DIR="$SDK/platforms"

# Find latest build-tools
BUILD_TOOLS=$(ls -d "$BT_DIR"/*/ 2>/dev/null | sort -V | tail -1)
if [ -z "$BUILD_TOOLS" ]; then
  echo "error: no build-tools found in $BT_DIR" >&2
  exit 1
fi

# Find android.jar (any API level works for compilation)
ANDROID_JAR=$(find "$PLATFORM_DIR" -name android.jar 2>/dev/null | sort -V | tail -1)
if [ -z "$ANDROID_JAR" ]; then
  echo "error: no android.jar found in $PLATFORM_DIR" >&2
  exit 1
fi

AAPT2="$BUILD_TOOLS/aapt2"
D8="$BUILD_TOOLS/d8"
APKSIGNER="$BUILD_TOOLS/apksigner"

for tool in "$AAPT2" "$D8" "$APKSIGNER"; do
  if [ ! -x "$tool" ]; then
    echo "error: $tool not found or not executable" >&2
    exit 1
  fi
done

echo "build-tools: $BUILD_TOOLS"
echo "android.jar: $ANDROID_JAR"
echo ""

# ================================================================== work dir

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

OUT="$SCRIPT_DIR/nomad-service.apk"
SRC="$SCRIPT_DIR/src"
MANIFEST="$SCRIPT_DIR/AndroidManifest.xml"

# ================================================================== compile resources

echo "[1/5] compiling resources..."
"$AAPT2" compile --dir "$SCRIPT_DIR/res" -o "$WORK/res.zip" 2>/dev/null || true

# Link — produce base APK with manifest + resources
echo "[2/5] linking APK..."
LINK_ARGS=(
  "$AAPT2" link
  --manifest "$MANIFEST"
  -I "$ANDROID_JAR"
  --min-sdk-version 21
  --target-sdk-version 35
  --version-code 1
  --version-name "1.0"
  -o "$WORK/base.apk"
)

if [ -f "$WORK/res.zip" ]; then
  LINK_ARGS+=(-R "$WORK/res.zip")
fi

"${LINK_ARGS[@]}"

# ================================================================== compile Java

echo "[3/5] compiling Java..."
mkdir -p "$WORK/classes"

javac \
  -source 8 -target 8 \
  -classpath "$ANDROID_JAR" \
  -d "$WORK/classes" \
  "$SRC"/com/emergency/nomad/*.java \
  2>&1

# ================================================================== dex

echo "[4/5] creating DEX..."
"$D8" \
  --min-api 21 \
  --output "$WORK" \
  "$WORK"/classes/com/emergency/nomad/*.class

# Add classes.dex to APK
cd "$WORK"
cp base.apk unsigned.apk
# Add dex to the APK zip
zip -q unsigned.apk classes.dex
cd - >/dev/null

# ================================================================== sign

echo "[5/5] signing APK..."

# Generate debug keystore if missing
KEYSTORE="$SCRIPT_DIR/.debug.keystore"
if [ ! -f "$KEYSTORE" ]; then
  keytool -genkeypair \
    -dname "CN=Emergency Nomad,O=Emergency,C=XX" \
    -keystore "$KEYSTORE" \
    -storepass android \
    -keypass android \
    -alias debug \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    2>/dev/null
fi

# Align
if [ -x "$BUILD_TOOLS/zipalign" ]; then
  "$BUILD_TOOLS/zipalign" -f 4 "$WORK/unsigned.apk" "$WORK/aligned.apk"
else
  cp "$WORK/unsigned.apk" "$WORK/aligned.apk"
fi

# Sign
"$APKSIGNER" sign \
  --ks "$KEYSTORE" \
  --ks-pass pass:android \
  --key-pass pass:android \
  --ks-key-alias debug \
  --out "$OUT" \
  "$WORK/aligned.apk"

# ================================================================== done

echo ""
echo "APK ready: $OUT"
echo "size: $(du -sh "$OUT" | cut -f1)"
echo ""
echo "install: adb install $OUT"
