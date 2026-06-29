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

`check-versions.sh` compares **submodule** HEAD and consumer `.wrap` files against `VERSIONS.lock`.

| Mode | How | On mismatch |
|------|-----|-------------|
| **warn** (default) | `./scripts/check-versions.sh` | prints `WARN`, exit 0 |
| **strict** | `--strict` or `SATELLITE_STRICT_VERSIONS=1` | prints `MISMATCH`, exit 1 |

Before committing lock / submodule pointer updates:

```bash
SATELLITE_STRICT_VERSIONS=1 ./scripts/check-versions.sh --strict
SATELLITE_STRICT_VERSIONS=1 ./scripts/build-all.sh
```

CI sets `SATELLITE_STRICT_VERSIONS=1` automatically.

## Generated environment

| Variable | Value |
|----------|-------|
| `SATELLITE_PLUGIN_INDEX` | `install/share/satellite/plugins.index.json` |
| `SATELLITE_PLUGIN_BIN` | `install/bin` |
| `SATELLITE_TASK_WORK_ROOT` | `/tmp/satellite/tasks` |

## install/ contents

The unified prefix is for **running the integrated stack**:

- `install/bin/` — task-manager, task-client, plugins
- `install/share/satellite/plugins.index.json` — plugin discovery for TaskManager
- schemas, samples, templates from each component

Headers and `libsatellite_common.a` are installed by satellite-plugin-sdk for local development convenience; consumers still compile SDK via Meson subproject (`subprojects/satellite-plugin-sdk/` is **not** committed — only `*.wrap`).

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

Without GMAT installed, `task_submit_short.json` may exit **4** (`EXIT_NO_RESULT`) — smoke treats that as pass.

Strict GMAT mode (fail on exit 4):

```bash
RUN_GMAT_INTEGRATION=1 ./scripts/smoke-integration.sh
```

## VERSIONS.lock

Pins **commit SHA** per submodule. For SDK also records:

- `wrap_url` — git remote for Meson `[wrap-git]` (must be cloneable from CI)
- `wrap_revision` — same commit as `commit`, checked against consumer `.wrap` files
- `version`, `schema_version`, third-party `wrap_hash`

When bumping satellite-plugin-sdk:

```bash
# 1. Update [satellite-plugin-sdk] commit in VERSIONS.lock
# 2. Sync consumer wrap files (GitHub URL from lock):
./scripts/sync-wrap-revisions.sh
# 3. Commit wrap changes in task-manager / plugins/* submodules, update gitlinks here
```

Until SDK is pushed to GitHub, `build-all.sh` auto-creates a local bare mirror at `.cache/satellite-plugin-sdk.git` (gitignored). Override with `SATELLITE_SDK_WRAP_URL` if needed.
