#!/usr/bin/env bash
# Shared helpers for workspace build scripts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALL="$ROOT/install"
PREFIX="$INSTALL"

run_version_check() {
  if [[ "${SATELLITE_STRICT_VERSIONS:-0}" == "1" ]]; then
    "$ROOT/scripts/check-versions.sh" --strict
  else
    "$ROOT/scripts/check-versions.sh"
  fi
}

build_meson() {
  local dir="$1"
  shift
  echo "==> building $dir"
  (
    cd "$ROOT/$dir"
    meson subprojects download
    if [[ -d build/meson-private ]]; then
      meson setup build --prefix "$PREFIX" --reconfigure "$@"
    else
      meson setup build --prefix "$PREFIX" "$@"
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
  "$ROOT/scripts/ensure-sdk-wrap-url.sh"
}

finalize_install() {
  python3 "$ROOT/scripts/finalize-install.py" \
    --root "$ROOT" \
    --install "$INSTALL"
}
