# satellite-workspace

Integration envelope for satellite embodied-intelligence repos. No product code here — only submodules, `VERSIONS.lock`, and build scripts.

## Layout

| Path | Repository |
|------|------------|
| `sdk/` | satellite-plugin-sdk |
| `task-manager/` | task-manager |
| `plugins/mission-planer/` | GMAT planning plugin |
| `plugins/image-preprocess/` | placeholder plugin |

## Quick start

```bash
./scripts/bootstrap.sh
./scripts/build-all.sh
source install/env.sh
./scripts/smoke-integration.sh
```

Requires git submodules (see `.gitmodules`). Consumer repos pull **satellite-plugin-sdk** via Meson `[wrap-git]` using `wrap_url` + `revision` from `VERSIONS.lock` — not via local path patching at build time.

## Version checks (warn vs strict)

`VERSIONS.lock` is a **generated index** of submodule HEADs — not a second source of truth. Regenerate it after bumping submodules:

```bash
./scripts/update-lock.sh
```

`check-versions.sh` verifies:

- submodule HEAD == `VERSIONS.lock` commit
- consumer `satellite-plugin-sdk.wrap` revision == SDK lock commit
- `sdk/VERSION` == lock version

| Mode | How | On mismatch |
|------|-----|-------------|
| **warn** (default) | `./scripts/check-versions.sh` | prints `WARN`, exit 0 |
| **strict** | `--strict` or `SATELLITE_STRICT_VERSIONS=1` | prints `MISMATCH`, exit 1 |

Before committing integration updates:

```bash
./scripts/update-lock.sh
SATELLITE_STRICT_VERSIONS=1 ./scripts/check-versions.sh --strict
SATELLITE_STRICT_VERSIONS=1 ./scripts/build-all.sh
```

CI sets `SATELLITE_STRICT_VERSIONS=1` automatically and never uses dev overrides.

### Dev override (local SDK)

Use unpublished `sdk/` changes without touching lock or committed wrap files:

```bash
SATELLITE_DEV_SDK=1 ./scripts/build-all.sh
```

This symlinks `subprojects/satellite-plugin-sdk` → workspace `sdk/` in each consumer. Do not commit those symlinks or run `update-lock.sh` from a dev build.

### Integration promotion flow

1. Change `sdk` / `task-manager` / plugins in their repos; commit each submodule.
2. In parent workspace: `git submodule update` to new HEADs (or checkout commits).
3. `./scripts/update-lock.sh` — writes `VERSIONS.lock` and syncs consumer SDK wrap revisions.
4. Commit wrap changes in consumer submodules if `update-lock.sh` modified them.
5. Parent commit: submodule gitlinks + `VERSIONS.lock` + workspace scripts.
6. `SATELLITE_STRICT_VERSIONS=1 ./scripts/check-versions.sh --strict` and smoke tests.

Primary version lock: **submodule gitlinks** in the parent commit. `git submodule update --init --recursive` must be sufficient to reproduce CI.

## Generated environment

| Variable | Value |
|----------|-------|
| `SATELLITE_PLUGIN_INDEX` | `install/share/satellite/plugins.index.json` |
| `SATELLITE_PLUGIN_BIN` | `install/bin` |
| `SATELLITE_TASK_WORK_ROOT` | `/tmp/satellite/tasks` |

## install/ contents

The unified prefix is for **running the integrated stack**:

```
install/
  bin/                          # task-manager, task-client, plugins
  env.sh                        # SATELLITE_* environment
  share/satellite/
    plugins.index.json          # plugin discovery for TaskManager
    plugins/*.json              # plugin manifests (single install location)
  share/mission-planer/
    samples/ schemas/ templates/
```

- Plugin manifests install to `install/share/satellite/plugins/` via each plugin's Meson `install_data`; `scripts/finalize-install.py` scans that directory and writes `plugins.index.json` (workspace-only index generator).
- Contract schemas (`task_envelope`, `task_result`, `plugin_manifest`) live in **satellite-plugin-sdk** only. TaskManager validates via the SDK compile-time schema dir, not a separate install copy.
- `install/include/`, `install/lib64/`, and `install/share/satellite-plugin-sdk/` appear only when the SDK is built with `-Dinstall_sdk=true`. Workspace `build-all.sh` defaults to `-Dinstall_sdk=false`; set `SATELLITE_INSTALL_SDK=1` for a local SDK prefix.
- Consumers still compile SDK via Meson subproject (`subprojects/satellite-plugin-sdk/` is **not** committed — only `*.wrap`).

## Meson `subprojects/` policy

In each consumer repository, git tracks **only**:

- `subprojects/*.wrap` (including `satellite-plugin-sdk.wrap` with git URL + revision)
- `subprojects/packagefiles/` (overlays, if any)
- `subprojects/README.md` (optional)

Downloaded trees (`satellite-plugin-sdk/`, `nlohmann_json-*/`, `libzmq-*/`, `packagecache/`) are **ignored** and recreated by `meson subprojects download`.

See `scripts/lib/subprojects.gitignore.snippet` for the standard block.

## Smoke tests

```bash
source install/env.sh
./scripts/smoke-install.sh      # binaries + plugins.index integrity
./scripts/smoke-integration.sh  # task-client end-to-end
```

`task_submit_short.json` sets `"dry_run": true` so smoke passes without GMAT. For a full GMAT run, use a sample without `dry_run` and install GMAT locally.

Strict GMAT mode (fail on exit 4 when GMAT returns no windows):

```bash
RUN_GMAT_INTEGRATION=1 ./scripts/smoke-integration.sh
```

## VERSIONS.lock

Generated by `./scripts/update-lock.sh` from current submodule HEADs. Records:

- `commit` / `tag` per submodule
- SDK `wrap_url`, `wrap_revision` (same as SDK commit), `version`, `schema_version`
- third-party `nlohmann_json` wrap hash

When bumping satellite-plugin-sdk:

```bash
# 1. Commit and push sdk submodule
# 2. In workspace:
./scripts/update-lock.sh
# 3. Commit wrap changes in task-manager / plugins/* if updated
# 4. Parent commit: gitlinks + VERSIONS.lock
```

CI clones with `submodules: recursive` and builds locked revisions only. For offline SDK development before push, use `SATELLITE_DEV_SDK=1` (not used in CI).
