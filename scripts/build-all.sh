#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT/scripts/lib/common.sh"

run_version_check
warn_dev_sdk
prepare_install_tree

sdk_install_args=(-Dinstall_sdk=false)
if [[ "${SATELLITE_INSTALL_SDK:-0}" == "1" ]]; then
  sdk_install_args=(-Dinstall_sdk=true)
fi
build_meson sdk "${sdk_install_args[@]}"
ensure_consumer_wraps
build_meson task-manager -Dzmq=enabled
build_meson plugins/mission-planer
build_meson plugins/image-preprocess

finalize_install

echo "install ready: $INSTALL"
echo "source $INSTALL/env.sh"
