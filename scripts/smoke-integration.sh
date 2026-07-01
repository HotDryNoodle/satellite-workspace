#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$ROOT/install"

"$ROOT/scripts/smoke-install.sh"

# shellcheck source=/dev/null
source "$ROOT/install/env.sh"

SAMPLE="$ROOT/scripts/integration-samples/task_submit_short.json"
if [[ ! -f "$SAMPLE" ]]; then
  echo "missing integration sample: $SAMPLE" >&2
  exit 1
fi

"$ROOT/install/bin/task-client" \
  --plugin-index "$SATELLITE_PLUGIN_INDEX" \
  --plugin-bin "$SATELLITE_PLUGIN_BIN" \
  --work-root "$SATELLITE_TASK_WORK_ROOT" \
  "$SAMPLE" >/dev/null || {
  code=$?
  if [[ "$code" -eq 4 ]]; then
    if [[ "${RUN_GMAT_INTEGRATION:-0}" == "1" ]]; then
      echo "integration smoke failed: exit 4 (no_result) with RUN_GMAT_INTEGRATION=1" >&2
      exit 4
    fi
    echo "integration smoke passed (no_result exit 4 — expected without GMAT)"
    exit 0
  fi
  exit "$code"
}

echo "integration smoke passed"
