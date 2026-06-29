#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT/scripts/lib/common.sh"

run_version_check
prepare_install_tree

build_meson sdk
ensure_consumer_wraps
build_meson task-manager -Dzmq=enabled
build_meson plugins/mission-planer
build_meson plugins/image-preprocess

finalize_install

echo "install ready: $INSTALL"
echo "source $INSTALL/env.sh"
