#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK="$ROOT/VERSIONS.lock"
fail=0

check_commit() {
  local name="$1" path="$2" key="$3"
  local expected actual
  expected=$(grep -A5 "^\[$key\]" "$LOCK" | grep '^commit' | sed 's/.*"\(.*\)".*/\1/')
  if [[ ! -d "$ROOT/$path/.git" ]]; then
    echo "skip $name (submodule not checked out)"
    return
  fi
  actual=$(git -C "$ROOT/$path" rev-parse HEAD)
  if [[ "$expected" != "$actual" ]]; then
    echo "MISMATCH $name: lock=$expected head=$actual"
    fail=1
  else
    echo "OK $name $actual"
  fi
}

check_commit sdk sdk satellite-plugin-sdk
check_commit task-manager task-manager task-manager
check_commit mission-planer plugins/mission-planer plugins.mission-planer
check_commit image-preprocess plugins/image-preprocess plugins.image-preprocess

SDK_VER=$(cat "$ROOT/sdk/VERSION" 2>/dev/null || echo missing)
if [[ "$SDK_VER" != "0.1.0" ]]; then
  echo "SDK VERSION mismatch: $SDK_VER"
  fail=1
fi

exit $fail
