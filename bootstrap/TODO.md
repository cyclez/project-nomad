# Bootstrap TODO

Working backlog for the emergency Android bootstrap in this fork.

This `bootstrap/` tree is the bounded emergency-owned surface.
Keep changes here install-reliability-first, zero-network, and easy to verify on real devices.

## Public Install Taxonomy

These are the names the user should see:

- `NORMAL`
  Install or repair Emergency Nomad without wiping useful data that should survive.
  If the phone reboots, the user unlocks it manually with their PIN.

- `NO SCREEN`
  Headless variant of `NORMAL` for broken displays.
  Requires USB debugging to already be enabled and this computer to already be authorized.
  Optional PIN-assisted unlock may exist later, but it must remain best-effort until proven on multiple devices.

- `NUKE`
  Remove the Emergency Nomad footprint and perform a clean install from scratch.

## Internal / Technical Modes

These names can stay internal unless they become necessary in tooling or docs:

- `RESTART`
  Relaunch the already-installed daemon only.
  No reinstall.

- `REPAIR`
  Future selective repair path used under `NORMAL`.
  Must preserve useful public and personal data.

- `CLEAN`
  Remove runtime only, keep helper APK if present.

- `ERASE`
  Remove runtime plus helper APK.

## Current Reality As Of 2026-03-30

- Current `Install` behaves like `NUKE`.
  Reason: the on-device installer deletes the previous runtime tree before moving the staged runtime into place.

- Current `Restart` is only `RESTART`.
  It relaunches the daemon and reopens access.
  It does not reinstall payloads.

- Current `Emergency Uninstall` behaves like `CLEAN`.

- Current `Emergency Uninstall (full)` behaves like `ERASE`.

- A true `NORMAL` path does not exist yet.
  Today there is no clean storage split between shipped runtime, public data, and personal data.

## Storage Taxonomy Needed

We need an explicit contract for what lives where and what can be wiped:

- `runtime/`
  Shipped runtime assets and helper-managed binaries.

- `public/`
  Replaceable public data that can be refreshed or restored from bundle content.
  Examples: cached public feeds, public map data, public reference content.

- `personal/`
  User-created or user-specific data that must survive `NORMAL`.

- `config/`
  Small install metadata, tokens, flags, timestamps, and wipe policy markers.

## Rules To Make The Taxonomy Real

- `NORMAL` must never silently wipe `personal/`.
- `NO SCREEN` should be `NORMAL` plus headless transport, not a separate destructive path.
- `NUKE` must be explicit and unmistakable in wording.
- `RESTART` must stay non-destructive.
- Every mode must state exactly what it deletes and what it preserves.

## Next Slices

1. Define on-device path layout for `runtime`, `public`, `personal`, and `config`.
2. Decide which data classes survive `NORMAL`, `NO SCREEN`, and `NUKE`.
3. Add wipe-policy fields to the install contract if needed.
4. Implement `REPAIR` as the engine behind `NORMAL`.
5. Keep `NO SCREEN` as headless `NORMAL` first.
6. Treat PIN-assisted unlock as dev-only / best-effort until verified on multiple OEMs.
7. Rename launchers and user docs only after the behavior matches the names.
