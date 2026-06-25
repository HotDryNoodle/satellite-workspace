#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/install/env.sh"

"$ROOT/install/bin/task-client" \
  --plugin-index "$SATELLITE_PLUGIN_INDEX" \
  --plugin-bin "$SATELLITE_PLUGIN_BIN" \
  --work-root "$SATELLITE_TASK_WORK_ROOT" \
  "$ROOT/plugins/mission-planer/samples/task_submit_short.json"

echo "integration smoke passed"
