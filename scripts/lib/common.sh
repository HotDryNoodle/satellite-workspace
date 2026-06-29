#!/usr/bin/env bash
# Shared helpers for workspace build scripts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALL="$ROOT/install"
PREFIX="$INSTALL"

dev_sdk_enabled() {
  [[ "${SATELLITE_DEV_SDK:-0}" == "1" ]]
}

warn_dev_sdk() {
  if dev_sdk_enabled; then
    echo "WARN: SATELLITE_DEV_SDK=1 — consumers link workspace sdk/ (not VERSIONS.lock wrap revision)" >&2
    echo "WARN: do not commit consumer subprojects/ or VERSIONS.lock from this build" >&2
  fi
}

run_version_check() {
  if dev_sdk_enabled; then
    echo "skip version check (SATELLITE_DEV_SDK=1)" >&2
    return 0
  fi
  if [[ "${SATELLITE_STRICT_VERSIONS:-0}" == "1" ]]; then
    "$ROOT/scripts/check-versions.sh" --strict
  else
    "$ROOT/scripts/check-versions.sh"
  fi
}

link_local_sdk_subproject() {
  local consumer_dir="$1"
  local target="$ROOT/sdk"
  local link_path="$ROOT/$consumer_dir/subprojects/satellite-plugin-sdk"
  if [[ ! -f "$target/meson.build" ]]; then
    echo "error: SATELLITE_DEV_SDK=1 but $target/meson.build missing" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$link_path")"
  rm -rf "$link_path"
  ln -sfn "$target" "$link_path"
  echo "dev: linked $consumer_dir/subprojects/satellite-plugin-sdk -> $target"
}

prepare_sdk_subproject() {
  local consumer_dir="$1"
  if dev_sdk_enabled; then
    link_local_sdk_subproject "$consumer_dir"
    return 0
  fi
  (
    cd "$ROOT/$consumer_dir"
    meson subprojects download satellite-plugin-sdk
  )
}

build_meson() {
  local dir="$1"
  shift
  echo "==> building $dir"
  (
    cd "$ROOT/$dir"
    if [[ "$dir" != "sdk" ]]; then
      if dev_sdk_enabled; then
        meson subprojects download
        link_local_sdk_subproject "$dir"
      else
        meson subprojects download
      fi
    else
      meson subprojects download
    fi
    local setup_args=(--prefix "$PREFIX")
    if [[ -d build/meson-private ]]; then
      setup_args+=(--reconfigure)
    fi
    if ! meson setup build "${setup_args[@]}" "$@"; then
      meson setup build --prefix "$PREFIX" --wipe "$@"
    fi
    meson compile -C build
    meson install -C build
  )
}

prepare_install_tree() {
  rm -rf "$INSTALL"
  mkdir -p "$INSTALL/share/satellite/plugins"
}

ensure_consumer_wraps() {
  if dev_sdk_enabled; then
    return 0
  fi
  "$ROOT/scripts/ensure-sdk-wrap-url.sh"
}

finalize_install() {
  python3 "$ROOT/scripts/finalize-install.py" --install "$INSTALL"
}
