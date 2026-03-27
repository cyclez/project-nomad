# Android Bootstrap Assets

Machine-readable assets for [docs/emergency/ANDROID_BOOTSTRAP_FORMAT.md](../../docs/emergency/ANDROID_BOOTSTRAP_FORMAT.md).

Files:

- `bootstrap-manifest.schema.json` - JSON Schema for `bootstrap.json`
- `validate-bootstrap-manifest.mjs` - local validator with repo-specific portability checks
- `examples/minimal/bootstrap.json` - reduced-storage example bundle manifest

Usage:

```bash
node bootstrap/android/validate-bootstrap-manifest.mjs bootstrap/android/examples/minimal/bootstrap.json
```
