#!/usr/bin/env bash
#
# build-test-bundle.sh
#
# Builds a minimal but functional test bundle for emergency-nomad.
# The daemon is a shell script that serves the PWA via nc on localhost:1234.
# No compilation required. Works on any Mac/Linux with bash + tar + shasum.
#
# Output: bootstrap/emergency-bootstrap-test-<date>.zip
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COLLECTIONS_DIR="$REPO_ROOT/collections"
BUNDLE_ID="android-bootstrap-test"
BUNDLE_VERSION="$(date +%Y.%m.%d)"
BUNDLE_NAME="emergency-bootstrap-${BUNDLE_ID}-${BUNDLE_VERSION}.zip"
OUT="$SCRIPT_DIR/$BUNDLE_NAME"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

sha256_of() {
  shasum -a 256 "$1" | cut -d' ' -f1
}

size_of() {
  wc -c < "$1" | tr -d ' '
}

echo ""
echo "emergency-nomad — build test bundle"
echo "────────────────────────────────────"
echo "bundle: $BUNDLE_NAME"
echo ""

# ================================================================== PWA

echo "building pwa..."
mkdir -p "$WORK/pwa"

cat > "$WORK/pwa/index.html" <<'EOF'
<!DOCTYPE html>
<html lang="it">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
  <title>Emergency Nomad</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
    .grid {
      display: grid;
      width: 100vw;
      height: 100vh;
      grid-template-columns: 1fr 1fr;
      grid-template-rows: 1fr 1fr;
    }
    .corner {
      display: flex;
      align-items: center;
      justify-content: center;
      font-family: sans-serif;
      font-size: clamp(1.5rem, 6vw, 3rem);
      font-weight: 900;
      letter-spacing: 0.05em;
      color: #fff;
      background: #111;
      border: 2px solid #222;
      cursor: pointer;
      -webkit-tap-highlight-color: transparent;
      transition: background 0.1s, color 0.1s;
      user-select: none;
    }
    .corner:active { background: #fff; color: #000; }
    .corner.ok     { background: #003300; color: #00ff00; }
    .corner.error  { background: #330000; color: #ff3333; }
    .corner.busy   { background: #1a1a00; color: #ffff00; }
  </style>
</head>
<body>
  <div class="grid">
    <div class="corner" id="search" onclick="tap(this,'CERCA...')">CERCA</div>
    <div class="corner" id="maps"   onclick="tap(this,'MAPPA...')">MAPPA</div>
    <div class="corner" id="status" onclick="checkStatus()">STATO</div>
    <div class="corner" id="sync"   onclick="armSync()">SYNC</div>
  </div>
  <script>
    function tap(el, msg) {
      el.classList.add('busy');
      el.textContent = msg;
      setTimeout(function() {
        el.classList.remove('busy');
        el.textContent = el.id.toUpperCase().replace('SEARCH','CERCA').replace('MAPS','MAPPA');
      }, 1500);
    }
    function checkStatus() {
      var el = document.getElementById('status');
      el.classList.remove('error','busy');
      el.classList.add('ok');
      el.textContent = 'OK';
      setTimeout(function() {
        el.classList.remove('ok');
        el.textContent = 'STATO';
      }, 2000);
    }
    function armSync() {
      var el = document.getElementById('sync');
      el.classList.add('busy');
      el.textContent = 'ARMED';
      setTimeout(function() {
        el.classList.remove('busy');
        el.classList.add('error');
        el.textContent = 'OFFLINE';
        setTimeout(function() {
          el.classList.remove('error');
          el.textContent = 'SYNC';
        }, 2000);
      }, 2000);
    }
  </script>
</body>
</html>
EOF

tar cf "$WORK/pwa-shell.tar" -C "$WORK/pwa" .
PWA_SHA=$(sha256_of "$WORK/pwa-shell.tar")
PWA_SIZE=$(size_of "$WORK/pwa-shell.tar")
echo "  pwa-shell.tar: $PWA_SHA"

# ================================================================== Daemon (arm64)

echo "building daemon arm64..."
mkdir -p "$WORK/daemon-arm64"

cat > "$WORK/daemon-arm64/nomad-daemon" <<'DAEMON'
#!/system/bin/sh
#
# emergency-nomad test daemon
# Serves the local PWA on 127.0.0.1:1234 via nc loop.
# Replaces itself with a real binary when available.
#
RUNTIME="/data/local/tmp/emergency-nomad"
PWA_INDEX="$RUNTIME/pwa/index.html"
PORT=1234

echo "nomad-daemon starting on 127.0.0.1:$PORT"
echo "runtime: $RUNTIME"

# NOMAD_TMPDIR is set by the Android Service (app-writable dir).
# Fallback to RUNTIME for direct adb shell launch.
RESP="${NOMAD_TMPDIR:-$RUNTIME}/.nomad-resp"

while true; do
  BODY=""
  if [ -f "$PWA_INDEX" ]; then
    BODY=$(cat "$PWA_INDEX")
  else
    BODY="<html><body><h1>emergency nomad</h1><p>pwa not found at $PWA_INDEX</p></body></html>"
  fi
  BODY_LEN=$(printf '%s' "$BODY" | wc -c | tr -d ' ')
  printf 'HTTP/1.0 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %s\r\nConnection: close\r\n\r\n%s' "$BODY_LEN" "$BODY" > "$RESP"
  nc -l -s 127.0.0.1 -p $PORT < "$RESP" >/dev/null 2>&1
done
DAEMON

chmod +x "$WORK/daemon-arm64/nomad-daemon"
tar cf "$WORK/daemon-arm64.tar" -C "$WORK/daemon-arm64" .
DAEMON64_SHA=$(sha256_of "$WORK/daemon-arm64.tar")
DAEMON64_SIZE=$(size_of "$WORK/daemon-arm64.tar")
echo "  daemon-arm64.tar: $DAEMON64_SHA"

# ================================================================== Daemon (armv7 — same script)

echo "building daemon armv7..."
cp "$WORK/daemon-arm64.tar" "$WORK/daemon-armv7.tar"
DAEMON_ARMV7_SHA=$DAEMON64_SHA
DAEMON_ARMV7_SIZE=$DAEMON64_SIZE
echo "  daemon-armv7.tar: $DAEMON_ARMV7_SHA"

# ================================================================== Collections

echo "copying collections..."
mkdir -p "$WORK/collections"
cp "$COLLECTIONS_DIR/kiwix-categories.json" "$WORK/collections/"
cp "$COLLECTIONS_DIR/maps.json" "$WORK/collections/"
cp "$COLLECTIONS_DIR/wikipedia.json" "$WORK/collections/"

# ================================================================== bootstrap.json

echo "generating bootstrap.json..."

node - <<NODESCRIPT
const fs = require('fs');
const manifest = {
  schema_version: "1.0",
  bundle: {
    id: "$BUNDLE_ID",
    version: "$BUNDLE_VERSION",
    label: "Emergency Nomad Test Bundle",
    format: "zip",
    description: "Minimal test bundle — shell daemon + PWA placeholder. Not for production."
  },
  compatibility: {
    android_api_min: 21,
    supported_abis: ["arm64-v8a", "armeabi-v7a"]
  },
  defaults: {
    seed_network_policy: "OFF",
    oneshot_enabled: true,
    storage_profile: "reduced",
    loopback_base_url: "http://127.0.0.1:1234/api/v1"
  },
  runtime: {
    pwa_payload_id: "pwa-shell",
    daemon_payloads: [
      { abi: "arm64-v8a", payload_id: "daemon-arm64" },
      { abi: "armeabi-v7a", payload_id: "daemon-armv7" }
    ]
  },
  storage_profiles: [
    {
      id: "full",
      label: "Full",
      max_persistent_mb: 512,
      keep_tags: ["core", "ui", "daemon"],
      notes: "Full test profile."
    },
    {
      id: "reduced",
      label: "Reduced",
      max_persistent_mb: 256,
      keep_tags: ["core", "ui", "daemon"],
      notes: "Default test profile."
    },
    {
      id: "volatile",
      label: "Volatile",
      max_persistent_mb: 64,
      keep_tags: ["core", "ui", "daemon"],
      notes: "Minimal test profile."
    }
  ],
  payloads: [
    {
      id: "pwa-shell",
      kind: "pwa",
      path: "payloads/pwa-shell.tar",
      abi: "any",
      required: true,
      retention: "required",
      install_tags: ["core", "ui"],
      size_bytes: $PWA_SIZE,
      sha256: "$PWA_SHA",
      content_type: "application/x-tar"
    },
    {
      id: "daemon-arm64",
      kind: "daemon",
      path: "payloads/daemon/arm64-v8a/nomad-daemon.tar",
      abi: "arm64-v8a",
      required: true,
      retention: "required",
      install_tags: ["core", "daemon"],
      size_bytes: $DAEMON64_SIZE,
      sha256: "$DAEMON64_SHA",
      content_type: "application/x-tar"
    },
    {
      id: "daemon-armv7",
      kind: "daemon",
      path: "payloads/daemon/armeabi-v7a/nomad-daemon.tar",
      abi: "armeabi-v7a",
      required: true,
      retention: "required",
      install_tags: ["core", "daemon"],
      size_bytes: $DAEMON_ARMV7_SIZE,
      sha256: "$DAEMON_ARMV7_SHA",
      content_type: "application/x-tar"
    }
  ],
  upstream_inputs: [
    { kind: "collections_manifest", path: "collections/kiwix-categories.json", required: true },
    { kind: "collections_manifest", path: "collections/maps.json", required: true },
    { kind: "collections_manifest", path: "collections/wikipedia.json", required: true }
  ]
};
fs.writeFileSync('$WORK/bootstrap.json', JSON.stringify(manifest, null, 2));
console.log('  bootstrap.json written');
NODESCRIPT

# ================================================================== Validate

echo "validating manifest..."
node "$SCRIPT_DIR/android/validate-bootstrap-manifest.mjs" "$WORK/bootstrap.json"

# ================================================================== Assemble zip

echo "assembling zip..."

mkdir -p \
  "$WORK/bundle/payloads/daemon/arm64-v8a" \
  "$WORK/bundle/payloads/daemon/armeabi-v7a" \
  "$WORK/bundle/collections"

cp "$WORK/bootstrap.json"          "$WORK/bundle/"
cp "$WORK/pwa-shell.tar"           "$WORK/bundle/payloads/"
cp "$WORK/daemon-arm64.tar"        "$WORK/bundle/payloads/daemon/arm64-v8a/nomad-daemon.tar"
cp "$WORK/daemon-armv7.tar"        "$WORK/bundle/payloads/daemon/armeabi-v7a/nomad-daemon.tar"
cp "$WORK/collections/"*           "$WORK/bundle/collections/"

cd "$WORK/bundle"
zip -qr "$OUT" .
cd - >/dev/null

# ================================================================== Done

echo ""
echo "bundle ready: $OUT"
echo "size: $(du -sh "$OUT" | cut -f1)"
echo ""
echo "to install:"
echo "  ./bootstrap/usb-push.sh $OUT"
