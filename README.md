# satellite-workspace

Integration envelope for satellite embodied-intelligence repos. No product code here — only submodules, `VERSIONS.lock`, and build scripts.

## Layout

- `sdk/` → satellite-plugin-sdk
- `task-manager/` → task-manager
- `plugins/mission-planer/` → GMAT planning plugin
- `plugins/image-preprocess/` → placeholder plugin

## Quick start

```bash
./scripts/bootstrap.sh
./scripts/build-all.sh
source install/env.sh
./scripts/smoke-integration.sh
```

## Environment (generated)

- `SATELLITE_PLUGIN_INDEX` → `install/share/satellite/plugins.index.json`
- `SATELLITE_PLUGIN_BIN` → `install/bin`
