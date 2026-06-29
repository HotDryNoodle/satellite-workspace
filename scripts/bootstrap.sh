#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

git submodule update --init sdk task-manager plugins/mission-planer plugins/image-preprocess

if [[ ! -f "$ROOT/sdk/meson.build" ]]; then
  echo "error: sdk/meson.build missing after submodule init" >&2
  echo "hint: ensure sibling repos exist at paths declared in .gitmodules" >&2
  exit 1
fi

if [[ ! -f "$ROOT/plugins/mission-planer/meson.build" ]]; then
  echo "error: plugins/mission-planer not checked out" >&2
  exit 1
fi

echo "bootstrap complete"
