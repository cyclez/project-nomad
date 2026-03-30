# Emergency Runtime — Development Phases

Report for development agents. Based on real-device testing (Samsung S10e, API 31, arm64-v8a) and architectural analysis of the bootstrap framework.

## Prime Directive

**Installation reliability beats features. Always.**

This is emergency software. The person using it may be stressed, in the dark, with a cracked screen, on a phone they've never seen before. Every development decision must pass this test:

> "Does this make the install more likely to fail?"
>
> If yes, don't do it. Find another way or drop the feature.

Concrete rules:

- **No install step may depend on network.** Not at install time, not at first run, not ever. The bundle is the world.
- **No install step may require user judgment.** If the user has to choose between options, choose for them. The installer knows the device.
- **No install step may fail silently.** If something goes wrong, say what, say why, say what to do. The user cannot debug.
- **No feature may break the install path.** A feature that works 90% of the time but causes install failures 10% of the time ships disabled or doesn't ship.
- **The install must work on the worst device in scope.** API 21, 1GB RAM, USB 2.0, 64MB available storage. If it doesn't work there, it doesn't work.

## Operating Model

The phone is ideally **already bootstrapped in peacetime**. The USB installer is a fallback for phones that don't have it yet. The primary runtime lives on the phone and maintains itself via smart network policies.

### Network Modes

| Mode | Behavior | Use case |
|------|----------|----------|
| **ghost** | Zero network activity. No probes, no DNS, no pings. Invisible. | Hostile zone, OPSEC, active emergency |
| **always listening** | Passive. Fetches content when network appears. | Peacetime maintenance, keeping corpus current |
| **wait** | Armed. Ready to fetch as soon as network becomes available, then disarms. | Pre-emergency, "last update before going dark" |

Ghost is stricter than the current `OFF` — the device does not touch the network at all, not even to check reachability. Always listening is the normal peacetime mode. Wait is the armed one-shot from the LOCAL_API contract, bounded by timeout and optional byte/download caps.

---

## What Exists (Phase 0 — complete)

Tested end-to-end, 5/5 install-verify-clean cycles on real hardware.

- USB installer for Mac (bash + python3) and Windows (batch + PowerShell)
- APK service (16KB): watchdog + BOOT_COMPLETED receiver
- Daemon survives reboot via Android Service
- Test daemon (nc shell script, one request at a time — placeholder)
- Test PWA (4-corner HTML — placeholder)
- Bundle format: bootstrap.json manifest, JSON Schema, storage profiles, SHA-256 verified payloads
- Self-contained packages: adb + APK bundled, zero network at install time
- Easy uninstall (remove runtime, keep APK) and full uninstall (remove everything)

### Real-Device Constraints Discovered

These are not theoretical — they were hit and solved during testing. **Every agent working on the install path must know these.**

| Constraint | Impact | Solution in place |
|------------|--------|-------------------|
| `/data/local/` not writable on Android 12+ | Runtime must live in `/data/local/tmp/` | Path changed, chmod 777 for DAC |
| SELinux blocks execute on `shell_data_file` | App user can't exec binaries pushed by adb | Shell scripts run via `sh` (read, not exec) |
| SELinux blocks write to `shell_data_file` | App user can't write temp files in adb-pushed dirs | `NOMAD_TMPDIR` env points to app's own data dir |
| Toybox nc doesn't forward piped stdin | Daemon can't pipe HTTP response to nc | Write response to file, use `< file` redirect |
| Toybox nc wildcard bind fails in app context | nc can't listen on `*:PORT` | Explicit `-s 127.0.0.1` bind |
| App can't create sockets without permission | nc/daemon can't listen | `INTERNET` permission in APK manifest |
| `pkill -f pattern` matches own adb shell | pkill kills the shell running pkill | `[n]omad-daemon` regex trick |
| `adb shell "nohup cmd &"` hangs | adb waits for background process | `sh -c '... & exit 0'` forces shell exit |
| Android 12 blocks background service start | Can't start Service from adb shell | StartActivity (invisible) triggers Service |
| `timeout` not on macOS | Can't timeout hung adb commands | Removed, used background kill instead |

### SELinux Escalation Path

This is the most important constraint for future phases. As the daemon evolves from shell script to compiled binary, SELinux requirements escalate:

```
Phase 0 (now):    sh script → SELinux allows read on shell_data_file ✓
Phase 1 (binary): compiled binary → SELinux blocks execute on shell_data_file ✗
                   → binary must live in app_data_file context
                   → APK must copy binary from staging to its own data dir
Phase 3 (content): 500MB data → APK copies all to app_data? slow
                   → need efficient staging → app_data transfer
```

When the daemon becomes a compiled binary, the APK must gain the ability to copy files from `/data/local/tmp/` (staging, shell-owned) to `/data/data/com.emergency.nomad/` (app-owned). This is the trigger for the APK to grow beyond a pure service wrapper.

---

## Phase 1: Real Daemon

**Gate for all subsequent phases.** Everything is blocked until the daemon does real HTTP and accesses SQLite.

### Install Constraint

The daemon binary must install as reliably as the current shell script. This means:

- Cross-compiled static binary. No shared library dependencies on the device.
- No runtime that needs to be extracted or configured on first launch.
- If the binary fails to start, the installer must detect it and tell the user. Do not leave the user staring at a browser that says "connection refused" with no explanation.
- The binary must start in under 2 seconds on a 2014 device. Startup that takes 10 seconds on a slow phone looks like a failure.

### Architecture Decision: Single Binary with Embedded PWA

The daemon and PWA are **coupled into one binary**. Rationale:

- The daemon is the only server. There is no CDN, no separate hosting.
- The PWA works only with this daemon. There is no interoperability concern.
- Embedding via Go `embed.FS` eliminates file path issues, SELinux read permissions on PWA files, and deployment complexity.
- One binary = one file to push, one file to copy, one file to launch.
- One file that works or doesn't. No partial states where daemon runs but PWA is missing.

### Language: Go

| Criterion | Go | Rust | Shell |
|-----------|-----|------|-------|
| Binary size | 5-10 MB | 2-5 MB | 0 |
| HTTP concurrent | yes (stdlib) | yes | no |
| SQLite FTS | yes (CGo or pure-Go) | yes | no |
| Cross-compile arm64/v7 | `GOOS=linux GOARCH=arm64 go build` | medium | n/a |
| Build without IDE | yes | yes | n/a |
| Iteration speed | fast | slow | immediate |

Go has net/http and database/sql in the standard library. Cross-compilation is one environment variable. No Android Studio, no Gradle, no NDK.

### What the Daemon Must Do (v1)

Endpoints (from LOCAL_API.md):

- `GET /status` — runtime state, network mode, sync state
- `GET /mode` — current network policy
- `PUT /mode` — set ghost / always-listening / wait
- `POST /sync/oneshot` — arm or trigger bounded sync
- `GET /search?q=...` — local SQLite FTS search
- `GET /documents/:id` — local document content
- `GET /maps/tiles/...` — serve PMTiles
- `GET /s/:token/` — serve embedded PWA (static assets)

Storage:

- SQLite database for FTS index + installed resource registry
- PMTiles files served via range requests
- runtime.conf for config (token, network mode, profile)

### Deployment Change

When the daemon is a compiled binary:

```
current:  adb push script → /data/local/tmp/ → sh script (read OK)
phase 1:  adb push binary → /data/local/tmp/staging/ → APK copies to /data/data/.../daemon
          APK launches binary via ProcessBuilder (execute OK on app_data_file)
```

The APK gains a `copyFromStaging()` method. Called once after each install/update. ~20 lines of Java.

### Build Output

```
build-daemon.sh:
  Input:  daemon/ Go source + pwa/ HTML/JS/CSS
  Output: nomad-daemon-arm64, nomad-daemon-armv7 (static binaries)
  Method: GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build
```

These binaries go into the bundle zip as `payloads/daemon/arm64-v8a/nomad-daemon` and `payloads/daemon/armeabi-v7a/nomad-daemon`. The existing bundle format already supports this — no schema change needed.

---

## Phase 2: Functional PWA

Embedded in the Go daemon binary via `embed.FS`. No separate deployment.

### Install Constraint

The PWA must render immediately on first load. No loading spinner, no "downloading assets", no white screen. The daemon has everything embedded — the browser opens and the UI is there. If the PWA takes more than 1 second to become interactive on a 2014 phone, it is too heavy.

### UI Constraint: 4-Corner Layout

From UI_CORNERS.md: the UI has four tap zones, one per screen corner. Minimum 25% width, 15% height from physical edge. Designed for cracked/broken screens where only corners might still respond to touch.

```
┌──────────┬──────────┐
│          │          │
│  CERCA   │  MAPPA   │
│          │          │
├──────────┼──────────┤
│          │          │
│  STATO   │   SYNC   │
│          │          │
└──────────┴──────────┘
```

Each corner is a full view, not a button. Tapping enters that view. This limits UI complexity by design — embrace it, don't fight it.

### Dependencies

| Component | Library | Size | Notes |
|-----------|---------|------|-------|
| Maps | MapLibre GL JS | ~200 KB | Only way to render PMTiles/vector tiles in browser. Non-negotiable. |
| Search UI | Vanilla JS | < 10 KB | Simple query → results list |
| Status UI | Vanilla JS | < 5 KB | Read from /status endpoint |
| Sync UI | Vanilla JS | < 5 KB | Arm/disarm one-shot, show sync state |

No framework. The daemon is the server. Service workers, PWA manifest, caching — all irrelevant. MapLibre is the single large dependency.

### Build

PWA files (HTML/JS/CSS) are embedded into the Go binary at compile time:

```go
//go:embed pwa/*
var pwaFS embed.FS
```

No separate PWA build step unless using a JS bundler for MapLibre. Could also load MapLibre from a vendored copy in pwa/lib/.

---

## Phase 3: Content Pipeline

### Install Constraint

Bundle build must be deterministic and reproducible. Same inputs → same bundle → same SHA-256 hashes. If a bundle validates on the developer's machine, it must validate on any host. No "works on my machine" bundles.

The bundle MUST be buildable locally on the developer's machine. CI is a convenience, not a dependency. If the build requires CI, and CI is unreachable during the preparation window, the bundle can't be created.

### What Gets Built

| Content | Source | Tool | Output | Size |
|---------|--------|------|--------|------|
| Search index | Kiwix ZIM files | zimtools + custom indexer | SQLite FTS database | 10-200 MB |
| Map tiles | OpenStreetMap extracts | tippecanoe / planetiler | PMTiles | 50-500 MB |
| Document corpus | Kiwix ZIM | zimtools extract | HTML/text files | 50-500 MB |
| Collections metadata | upstream manifests | copy | JSON files | < 1 MB |

### Storage Profiles Become Real

| Profile | Total | Content | Build time | USB 2.0 install |
|---------|-------|---------|------------|-----------------|
| volatile (64 MB) | daemon + PWA + collection metadata | searchable metadata only, no documents | seconds | ~30s |
| reduced (256 MB) | + core FTS index + one map region | search works, one region of maps | ~10 min | ~2 min |
| full (512 MB) | + full FTS + wider maps + document corpus | full offline utility | ~30 min | ~4 min |

### The Download Bottleneck

The build itself is fast. The bottleneck is downloading source material:

- Italian Wikipedia ZIM: ~5 GB (one-time download)
- Regional map tiles: ~500 MB (one-time download)
- Subsequent builds are incremental (only re-index if source changes)

This is a peacetime-only activity. During preparation, the bundle is already built. During emergency, nothing is downloaded.

---

## Phase 4: Sync and Updates

### Install Constraint

No update mechanism may leave the device in a broken state. If an update is interrupted (cable pulled, phone dies, network drops), the device must still work with the previous version. This means:

- Keep the old runtime until the new one is fully verified.
- Atomic swap: old → new only after new is complete and checked.
- If swap fails, keep old. Never leave the device with neither.

### In-App Updates (Primary Path)

The phone is already bootstrapped. Updates happen via the network modes:

- **always listening**: daemon periodically checks upstream manifests, downloads new content when available
- **wait**: operator arms a bounded sync, daemon fetches when network appears

This is the primary update path. No cable, no computer. The daemon manages its own content lifecycle.

### Delta Updates via USB (Fallback)

When the phone can't reach the network (or shouldn't), updates can still happen via USB:

```
usb-push.sh --update bundle-v2.zip
  → compares installed manifest with new manifest
  → pushes only files with changed SHA-256
  → restarts daemon
```

This requires the daemon to expose its installed manifest (list of files + SHA-256) so the host can compute the delta.

### Priority Order

1. Make the daemon self-updating via always-listening mode (peacetime maintenance)
2. Add armed wait mode (pre-emergency last-update)
3. Add delta USB update (fallback for fully offline scenarios)

---

## Phase 5: Multi-Device (Eventuality)

Not an active phase. Documented for when it becomes relevant.

### Scenarios

- **Team preparation**: 10 phones for a response team, need batch setup
- **Community distribution**: non-technical operator sets up phones for others

### Options

| Strategy | Scale | Requires |
|----------|-------|----------|
| USB hub + parallel adb | 5-10 | hub, parallel script |
| WiFi ADB | unlimited on LAN | initial USB pairing, local network |
| SD card / USB OTG | unlimited, no computer | APK capable of self-install from SD |

SD card self-install is the most powerful option — eliminates the computer entirely. But it requires the APK to become a full app with file browser and self-install capability. This is a significant expansion of the APK's scope.

### Install Constraint for Multi-Device

If one phone in a batch fails, it must not block the others. Parallel install must be independent per device — no shared state, no shared staging directory, no shared adb session.

---

## APK Evolution Trajectory

The APK should stay as thin as possible for as long as possible. Every kilobyte added is a kilobyte that can contain a bug that breaks the install.

```
Phase 0 (now):     16 KB — service wrapper, boot receiver, invisible activity
                   Build: aapt2 + javac + d8 (no Android Studio, 2 seconds)

Phase 1 (binary):  ~20 KB — adds copyFromStaging() for compiled daemon
                   Build: same toolchain

Phase 4 (sync):    ~30 KB — adds network state management helpers
                   Build: same toolchain

Phase 5 (SD card): ?? — file browser, bundle validation, self-install UI
                   Build: probably needs Gradle at this point
```

The moment the APK needs a real UI (Phase 5), the build switches from aapt2/javac/d8 to Gradle. That's a significant complexity jump. Delay it as long as possible.

---

## Execution Order

```
 ✅ Phase 0: installer framework + APK service + test bundle
      │
      ▼
 → Phase 1: Go daemon (HTTP + SQLite + embedded PWA)
      │      APK gains copyFromStaging()
      │      SELinux: binary in app_data_file context
      │      GATE: install must be as reliable as Phase 0
      │
      ▼
   Phase 2: functional PWA (search + maps + status + sync UI)
      │      MapLibre GL JS for offline maps
      │      4-corner layout, vanilla JS
      │      GATE: first render under 1 second on old device
      │
      ▼
   Phase 3: content pipeline (ZIM → FTS, tiles → PMTiles)
      │      Real bundles with real content
      │      Storage profiles tested with real data
      │      GATE: bundle buildable locally, deterministic
      │
      ▼
   Phase 4: sync (always-listening + wait + delta USB)
      │      Daemon self-maintains content in peacetime
      │      USB update as fallback
      │      GATE: interrupted update never breaks device
      │
      ▼
   Phase 5: multi-device (eventual — SD card / batch)
            GATE: one failure doesn't block others
```

Phase 1 is the gate. Everything else builds on a daemon that does real HTTP and real storage.

Each phase has an install reliability gate. If the gate doesn't pass, the phase is not complete — regardless of how many features work.
