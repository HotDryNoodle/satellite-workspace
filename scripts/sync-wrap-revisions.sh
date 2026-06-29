#!/usr/bin/env bash
# Sync satellite-plugin-sdk.wrap url+revision in consumer submodules from VERSIONS.lock.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK="$ROOT/VERSIONS.lock"

read_lock_field() {
  awk -v section="[$1]" -v key="$2" '
    $0 == section { in_section=1; next }
    /^\[/ { in_section=0 }
    in_section && $0 ~ "^" key "[[:space:]]*=" {
      match($0, /"([^"]+)"/, m)
      print m[1]
      exit
    }
  ' "$LOCK"
}

SDK_URL="${SATELLITE_SDK_WRAP_URL:-$(read_lock_field satellite-plugin-sdk wrap_url)}"
SDK_COMMIT="${SATELLITE_SDK_WRAP_COMMIT:-$(read_lock_field satellite-plugin-sdk commit)}"
if [[ -z "$SDK_URL" ]]; then
  echo "error: satellite-plugin-sdk wrap_url not set in VERSIONS.lock" >&2
  exit 1
fi
if [[ -z "$SDK_COMMIT" || "$SDK_COMMIT" == "0000000" ]]; then
  echo "error: satellite-plugin-sdk commit not pinned in VERSIONS.lock" >&2
  exit 1
fi

update_wrap() {
  local wrap_file="$1"
  [[ -f "$wrap_file" ]] || return 0
  python3 - "$wrap_file" "$SDK_URL" "$SDK_COMMIT" <<'PY'
import pathlib, sys
wrap_path, url, commit = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
lines = [
    "[wrap-git]",
    f"url = {url}",
    f"revision = {commit}",
    "directory = satellite-plugin-sdk",
    "",
]
wrap_path.write_text("\n".join(lines))
print(f"updated {wrap_path}")
PY
}

for ws_path in task-manager plugins/mission-planer plugins/image-preprocess; do
  update_wrap "$ROOT/$ws_path/subprojects/satellite-plugin-sdk.wrap"
done

# Keep wrap_revision in lock aligned with commit
if grep -q '^wrap_revision' "$LOCK"; then
  sed -i "s/^wrap_revision = .*/wrap_revision = \"$SDK_COMMIT\"/" "$LOCK"
fi

echo "sync complete: url=$SDK_URL revision=$SDK_COMMIT"
