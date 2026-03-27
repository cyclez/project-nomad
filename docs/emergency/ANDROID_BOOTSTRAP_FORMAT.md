# Android Bootstrap Bundle Format

## Goal

Define the simplest possible install artifact for the emergency Android runtime.

The format must:

- work with side-loaded installs on older Android devices
- seed a hard-offline local runtime with no mandatory first-run network
- let the installer scale persistent storage down without changing the compute/runtime contract
- stay compatible with the emergency fork's loopback API and upstream collections seam

This document does not choose the compute stack or model runtime.

## Decision

Use one boring file-based artifact:

- container: standard `.zip`
- root manifest: `bootstrap.json`
- payload directory: `payloads/`
- canonical upstream seed inputs: `collections/*.json`

No OCI image.
No Docker layer.
No split-package graph.
No symlinks or special filesystem semantics.

Suggested filename:

- `emergency-bootstrap-<bundle_id>-<bundle_version>.zip`

## Required archive layout

```text
bootstrap.json
payloads/
  pwa-shell.tar
  daemon/
    arm64-v8a/nomad-daemon.tar
    armeabi-v7a/nomad-daemon.tar
  indexes/core-search.sqlite
  maps/base.pmtiles
  content/core-docs.pack
collections/
  kiwix-categories.json
  maps.json
  wikipedia.json
```

Rules:

- paths are lowercase ASCII
- no path may escape bundle root
- no symlinks, xattrs, hard links, device files, or sparse files
- archive mode bits are ignored; daemon executables are determined by manifest kind, not preserved ZIP permissions

## Manifest contract

`bootstrap.json` is UTF-8 JSON and follows [`bootstrap/android/bootstrap-manifest.schema.json`](../../bootstrap/android/bootstrap-manifest.schema.json).

Top-level sections:

- `bundle`: identity and human label
- `compatibility`: minimum Android API and supported ABIs
- `defaults`: initial network policy, default storage profile, loopback base URL
- `runtime`: selected PWA payload and ABI-specific daemon payload mapping
- `storage_profiles`: `full`, `reduced`, `volatile`, or other profile ids
- `payloads`: file descriptors with `kind`, `abi`, checksum, retention, and install tags
- `upstream_inputs`: canonical `collections/*.json` seeds reused from upstream

## Storage degradation model

The format scales down persistence, not runtime semantics.

Retention classes:

- `required`: always installed
- `rebuildable`: may be omitted on tight storage because the installer or runtime can rebuild or reimport it later
- `evictable`: optional data that can be skipped or removed first under low space

Recommended profiles:

- `full`: keep selected content, maps, and indexes
- `reduced`: keep UI, daemon, upstream manifests, and small core indexes
- `volatile`: keep only what is needed to boot the local runtime and read the minimum local corpus

Profile selection rule:

1. always install payloads where `required = true`
2. otherwise keep a payload when at least one of its `install_tags` appears in `keep_tags`
3. if a payload matches both `keep_tags` and `drop_tags`, `drop_tags` wins

`upstream_inputs` are seeded independently from storage-profile selection.
They are part of the minimum bootstrap contract, not optional payloads.

`seed_network_policy` must remain `OFF` in bootstrap bundles.
Connectivity is not part of first-run success.

## Installer behavior

A conforming Android bootstrap installer should:

1. open the local ZIP from app-private storage, shared storage, SD card, USB OTG, ADB, or preload media
2. parse `bootstrap.json`
3. verify `seed_network_policy = OFF` and `loopback_base_url = http://127.0.0.1:1234/api/v1`
4. choose the first compatible daemon payload for the device ABI
5. choose the requested or default storage profile
6. install all `required` payloads plus payloads retained by the chosen profile
7. verify SHA-256 for every selected payload
8. extract files into device-local storage
9. seed `collections/*.json` and runtime defaults
10. start the daemon bound to loopback only and serve the local PWA from local files

## Why this is compatible with older devices

- one normal ZIP is easier than split APKs or container images
- no dependency on Docker, Play services, or network during first run
- archive permissions do not matter
- bundle rules avoid filesystem features that break on FAT or shared external media
- low-storage devices can select `reduced` or `volatile` profiles without changing the bundle format

## Upstream reuse

This format deliberately reuses the existing Project N.O.M.A.D. collections seam:

- `collections/kiwix-categories.json`
- `collections/maps.json`
- `collections/wikipedia.json`

The emergency fork owns bootstrap and install behavior, but it stays aligned to upstream content-selection contracts.

## Repo artifacts

- schema: [`bootstrap/android/bootstrap-manifest.schema.json`](../../bootstrap/android/bootstrap-manifest.schema.json)
- validator: [`bootstrap/android/validate-bootstrap-manifest.mjs`](../../bootstrap/android/validate-bootstrap-manifest.mjs)
- example: [`bootstrap/android/examples/minimal/bootstrap.json`](../../bootstrap/android/examples/minimal/bootstrap.json)
