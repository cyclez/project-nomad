---
slice: "android-bootstrap-format"
status: "built"
summary: "Defined a boring ZIP-based Android bootstrap bundle format, added schema and validator, and recorded the slice in pipeline-handheld state."
touched_paths:
  - "docs/emergency/README.md"
  - "docs/emergency/ANDROID_BOOTSTRAP_FORMAT.md"
  - "bootstrap/android/README.md"
  - "bootstrap/android/bootstrap-manifest.schema.json"
  - "bootstrap/android/examples/minimal/bootstrap.json"
  - "bootstrap/android/validate-bootstrap-manifest.mjs"
  - "pipeline-handheld/state/scope.yaml"
  - "pipeline-handheld/state/seams.yaml"
  - "pipeline-handheld/state/slices/android-bootstrap-format.yaml"
  - "pipeline-handheld/state/verification.yaml"
  - "pipeline-handheld/state/status.json"
tests:
  - path: "bootstrap/android/validate-bootstrap-manifest.mjs"
    purpose: "Validate the example bootstrap manifest against the Android bootstrap contract."
upstream_delta:
  - "Reuses collections/*.json as canonical bootstrap seed inputs instead of importing server-side collection services."
  - "Introduces bootstrap/android as a new additive path with no Docker or Adonis coupling."
destructive_actions_taken: []
vcs_actions_taken: []
network_fetches: []
---
# Delivery

## Patch Plan

- Add an emergency doc that defines the Android bootstrap bundle as a simple ZIP plus bootstrap.json manifest.
- Add machine-readable schema, local validator, and a reduced-storage example manifest.
- Record scope, seam, and verification artifacts in pipeline-handheld state.

## Files

### docs/emergency/ANDROID_BOOTSTRAP_FORMAT.md

Already applied in repo.
Defines bundle layout, compatibility rules, storage profiles, and installer behavior.

### bootstrap/android/bootstrap-manifest.schema.json

Already applied in repo.
Formalizes the structure of bootstrap.json.

### bootstrap/android/validate-bootstrap-manifest.mjs

Already applied in repo.
Checks OFF-by-default behavior, loopback URL, ABI coverage, portable paths, and canonical upstream collection inputs.

## Verification Notes

- `node bootstrap/android/validate-bootstrap-manifest.mjs bootstrap/android/examples/minimal/bootstrap.json`
- Bundle defaults keep `OFF` as the seeded network policy and the documented loopback base URL.
- The format remains additive and reuses upstream collection manifests instead of server runtime wiring.

## Rejection

- 
