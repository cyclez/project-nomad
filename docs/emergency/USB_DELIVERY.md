# USB Delivery Mechanism

Host-to-device bootstrap push via USB/ADB.

## Overview

The delivery mechanism moves a bootstrap bundle (.zip) from a Mac/PC to an
Android device over a USB cable. All heavy work runs on the host. The device
only needs a minimal shell (API 21+, Android 5.0, 2014).

After install, the daemon runs on the device at http://127.0.0.1:1234.
The user opens a browser to that address. The install path may also sideload
the bundled helper APK (`com.emergency.nomad`) via ADB. No Play Store and no
network fetch are involved.

## Modes

### Install (default)

Push bundle, install runtime, launch daemon, open browser.

```bash
./bootstrap/usb-push.sh bundle.zip
./bootstrap/usb-push.sh -s SERIAL -p reduced bundle.zip
```

### Restart

Relaunch daemon on a device that already has the runtime installed.
Use this only if the phone does not come back by itself after reboot.

```bash
./bootstrap/usb-push.sh --restart
./bootstrap/usb-push.sh --restart -s SERIAL
```

### Headless (broken screen)

Keep cable attached, forward port to the host computer.
Use the browser on the computer instead of on the phone.

```bash
./bootstrap/usb-push.sh --headless bundle.zip
./bootstrap/usb-push.sh --restart --headless
```

## Flow

```
host (Mac/Linux/WSL)                         device (Android)
─────────────────────                        ────────────────
1. extract bootstrap.json from zip
2. detect device ABI + API via adb
3. resolve install plan (python3, on host)
4. extract all payloads from zip (on host)
5. untar tar payloads (on host)
6. verify SHA-256 checksums (on host)
7. assemble runtime tree locally
8. show DECLARATION.md, ask consent
9. adb push runtime tree ─────────────────→  /data/local/tmp/emergency-nomad-staging/
10. adb push on-device-install.sh ─────────→ staging/on-device-install.sh
11. adb shell sh on-device-install.sh
                                              12. mv staging/runtime → /data/local/tmp/emergency-nomad/
                                              13. chmod +x daemon
                                              14. write runtime.conf
                                              15. rm -rf staging
16. adb install -r helper APK ─────────────→ com.emergency.nomad (when bundled)
17. adb shell am start StartActivity ──────→ APK launches/supervises daemon
    (fallback: direct daemon launch if APK missing)
18. adb shell am start chrome ─────────────→ browser opens to localhost
    (or: adb forward for --headless)
19. disconnect cable                          daemon keeps running
```

## Options

| Flag | Purpose |
|------|---------|
| `-s SERIAL` | Select device when multiple are connected |
| `-p PROFILE` | Override storage profile (full, reduced, volatile) |
| `--headless` | Port forward to host, for broken screens |
| `--restart` | Relaunch daemon only, skip install |

## Device paths

| Path | Purpose | Lifecycle |
|------|---------|-----------|
| `/data/local/tmp/emergency-nomad-staging/` | Temporary staging | Removed after install |
| `/data/local/tmp/emergency-nomad/` | Permanent runtime | Survives reboot, removed on reinstall |

Runtime directory after install:

```
/data/local/tmp/emergency-nomad/
  pwa/            — local UI assets
  daemon/         — executable daemon binary (ABI-matched)
  index/          — search indexes (SQLite)
  content/        — document corpus (profile-dependent)
  map/            — offline map tiles (profile-dependent)
  collections/    — upstream manifest seeds
  config/
    runtime.conf  — loopback URL, network policy, profile, timestamps
```

## Daemon lifecycle

The daemon is launched by the helper APK when it is bundled, or by direct
shell fallback when the APK is missing. It survives USB cable disconnect.

The intended path is: helper APK starts and supervises the daemon, including
after phone reboot. Verified on the Samsung SM-G970F burner used for this
repo: after reboot, the local runtime came back without USB, but Android did
not deliver `BOOT_COMPLETED` to the app immediately. Treat up to 2 minutes as
normal recovery time after a reboot before assuming it failed.

If a given device does not come back cleanly after that wait:

1. Reconnect the USB cable.
2. Run `./bootstrap/usb-push.sh --restart`
3. Disconnect.

The installed files and data are not lost on reboot — only the daemon process
may need relaunching.

## Host dependencies

| Tool | Why | macOS | Linux |
|------|-----|-------|-------|
| adb | push files, run shell | Android platform-tools | android-tools-adb |
| python3 | resolve install plan + read manifest fields | Xcode CLT / Homebrew python | python3 package |
| unzip | extract from bundle zip | built-in | built-in |
| tar | extract tar payloads | built-in | built-in |
| sha256sum / shasum | verify checksums | shasum (built-in) | sha256sum (coreutils) |

## Device dependencies

None beyond the default Android shell. The on-device script uses only:
`sh`, `mv`, `rm`, `mkdir`, `chmod`, `echo`, `cat`, `date`.

Target: API 21+ (Android 5.0, 2014).

## What it does not do

- Does not root the device
- Does not fetch an APK from the network or Play Store
- Does not use the network
- Does not require Docker or Google Play
- Does not modify bootloader or system partition
- Does not expose services beyond loopback

## Broken screen support

If the phone screen is broken but touch/display is partially or fully dead:

- **Pre-requirement**: "Always allow from this computer" must have been
  authorized BEFORE the screen broke (during device preparation).
- **Install**: use `--headless` flag. Port is forwarded to the host computer.
- **Use**: open browser on the computer at http://127.0.0.1:1234.
- **Cable**: must stay connected in headless mode.

## Known limitations

- `adb push` of large trees is slow over USB 2.0
- Reboot recovery still needs broader device coverage; use `--restart` if needed
- No incremental update — reinstall pushes the full runtime tree
- No rollback — previous install is removed before placing the new one
- Xiaomi/Redmi devices may require extra developer settings (see INSTALL_GUIDE.md)

## Files

| File | Runs on | Purpose |
|------|---------|---------|
| `bootstrap/usb-push.sh` | Host | Main entry point |
| `bootstrap/DECLARATION.md` | Host (displayed) | What the software does |
| `bootstrap/android/resolve-install-plan.py` | Host | Resolves bootstrap.json into flat plan |
| `bootstrap/android/on-device-install.sh` | Device | Moves staged tree, sets permissions |
