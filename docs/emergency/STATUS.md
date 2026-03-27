# Emergency Runtime Status

Last updated: 2026-03-27

## Summary

Current status for the Android bootstrap install path:

- **Maturity:** operational (test bundle)
- **Verdict:** install path works end-to-end on real hardware
- **Truth:** the repo can build a test bundle, push it to a real phone, and serve a PWA on localhost — repeatably

## Smoke Test Record

**2026-03-27** — Samsung Galaxy S10e (SM-G970F), API 31, arm64-v8a

| Step | Result |
|------|--------|
| `build-test-bundle.sh` | OK — 12K zip, validator pass |
| Preflight (adb, node, unzip, tar) | OK |
| Device detect + compat check | OK |
| Install plan resolve (arm64, reduced) | OK — 2 extract, 3 seed |
| Declaration + consent | OK |
| Host assembly + SHA-256 verify | OK — 2/2 checksums |
| ADB push (51KB runtime) | OK |
| On-device install (mv + chmod) | OK |
| Daemon launch (nc-based, setsid) | OK |
| Browser open via `am start` | OK |
| Daemon serves PWA HTML on :1234 | OK — HTTP 200 |
| 5x install-clean loop | 5/5 pass, 0 fail |

## What Exists Already

These pieces are real, tested, and materially useful:

- test bundle builder via `bootstrap/build-test-bundle.sh`
- host-side USB push flow via `bootstrap/usb-push.sh`
- on-device installer via `bootstrap/android/on-device-install.sh`
- bootstrap bundle schema via `bootstrap/android/bootstrap-manifest.schema.json`
- host-side manifest validator via `bootstrap/android/validate-bootstrap-manifest.mjs`
- host-side install-plan resolver via `bootstrap/android/resolve-install-plan.mjs`
- auto-watcher via `bootstrap/emergency-watch.sh` (polls for device, auto-installs)
- simple desktop launchers in `bootstrap/*.command` (install, restart, headless)
- user-facing install guidance in `INSTALL_GUIDE.md`
- random access token per installation (prevents other apps from reaching localhost)
- broken-screen support via `--headless` port forwarding
- `--restart` mode for daemon relaunch after reboot without reinstall
- `--yes` flag for non-interactive / automated installs
- explicit hard-offline defaults in the bootstrap manifest contract:
  - seed network policy stays `OFF`
  - loopback base URL stays `http://127.0.0.1:1234/api/v1`
  - one-shot is seeded as enabled, not background sync

## Exit Criteria For "Easy Install"

| # | Criterion | Status |
|---|-----------|--------|
| 1 | Build a known-good bundle from the repo | DONE (test bundle) |
| 2 | Bundle validates against manifest contract | DONE |
| 3 | USB push works on at least one real device | DONE (S10e) |
| 4 | Daemon starts reliably after install | DONE (5/5) |
| 5 | Restart flow works after reboot | untested |
| 6 | Install guide matches actual steps | partial — needs review after path changes |

## What This Means In Practice

Today, the install path is:

> one cable, one ZIP, one command, for a prepared operator on a prepared device

The test bundle proves the flow works. The next step is replacing the test daemon (nc shell script) and test PWA (4-corner placeholder) with real implementations.

## Device Compatibility Notes

Discovered during real-device testing:

- `/data/local/` is NOT writable by shell user on Android 12 — runtime lives in `/data/local/tmp/emergency-nomad/`
- Toybox `nc` (Android 12) does not forward piped stdin to socket — daemon must write response to a temp file and use `< file` redirect
- `pkill -f pattern` matches its own adb shell command line — use `[n]` regex trick to exclude self
- `adb shell "nohup cmd &"` hangs — use `sh -c '... & exit 0'` to force shell exit after fork
- Samsung S10e after hard reset: ADB authorization popup may be hidden — lock+unlock cycle surfaces it

## Why It Is Not Easy Yet

The main reasons are concrete:

- requires `adb` and `node` on the host
- requires USB debugging to be enabled in advance
- requires the device to have already authorized the host computer
- reinstall path is destructive: previous runtime is removed before replacement
- there is no rollback path
- daemon is a test placeholder (nc loop), not a real HTTP server
- PWA is a 4-corner placeholder, not a real interface

## Recommended Next Steps

1. Build the real daemon (compiled binary or better shell httpd)
2. Build the real PWA with search, maps, status, sync corners
3. Test `--restart` mode after phone reboot
4. Test on a second device (different vendor / older API)
5. Test `--headless` mode for broken screen
