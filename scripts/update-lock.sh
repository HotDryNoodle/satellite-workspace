#!/usr/bin/env bash
# Generate VERSIONS.lock from current submodule HEADs and sync consumer SDK wraps.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK="$ROOT/VERSIONS.lock"

SUBMODULES=(
  sdk
  task-manager
  plugins/mission-planer
  plugins/image-preprocess
)

read_existing_lock_field() {
  local section="$1" key="$2"
  [[ -f "$LOCK" ]] || return 0
  awk -v section="[$section]" -v key="$key" '
    $0 == section { in_section=1; next }
    /^\[/ { in_section=0 }
    in_section && $0 ~ "^" key "[[:space:]]*=" {
      match($0, /"([^"]+)"/, m)
      print m[1]
      exit
    }
  ' "$LOCK"
}

require_clean_submodule() {
  local path="$1"
  if [[ -n "$(git -C "$ROOT/$path" status --porcelain)" ]]; then
    echo "error: submodule $path is dirty (commit or stash before update-lock.sh)" >&2
    exit 1
  fi
}

submodule_head() {
  local path="$1"
  if [[ ! -e "$ROOT/$path/.git" ]]; then
    echo "error: submodule not checked out: $path" >&2
    exit 1
  fi
  git -C "$ROOT/$path" rev-parse HEAD
}

submodule_tag() {
  local path="$1"
  if [[ "${SATELLITE_RELEASE_LOCK:-0}" == "1" ]]; then
    if ! git -C "$ROOT/$path" describe --tags --exact-match >/dev/null 2>&1; then
      echo "error: $path HEAD is not an exact tag (required for SATELLITE_RELEASE_LOCK=1)" >&2
      exit 1
    fi
    git -C "$ROOT/$path" describe --tags --exact-match
    return
  fi
  if git -C "$ROOT/$path" describe --tags --exact-match >/dev/null 2>&1; then
    git -C "$ROOT/$path" describe --tags --exact-match
    return
  fi
  if [[ -f "$ROOT/$path/VERSION" ]]; then
    echo "v$(tr -d '[:space:]' < "$ROOT/$path/VERSION")"
    return
  fi
  echo "v0.1.0"
}

read_wrap_source_hash() {
  local wrap_file="$1"
  awk -F= '
    /^source_hash[[:space:]]*=/ {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
      print $2
      exit
    }
  ' "$wrap_file"
}

resolve_nlohmann_wrap() {
  local repo_path="$1"
  local wrap="$repo_path/subprojects/nlohmann_json.wrap"
  [[ -f "$wrap" ]] || return 1
  if grep -q '^\[wrap-redirect\]' "$wrap" 2>/dev/null; then
    local target
    target=$(awk -F= '/^filename/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit }' "$wrap")
    wrap="$repo_path/subprojects/$target"
  fi
  [[ -f "$wrap" ]] && echo "$wrap"
}

for path in "${SUBMODULES[@]}"; do
  require_clean_submodule "$path"
done

SDK_COMMIT=$(submodule_head sdk)
SDK_VERSION=$(tr -d '[:space:]' < "$ROOT/sdk/VERSION")
SDK_TAG=$(submodule_tag sdk)
SDK_SCHEMA_VERSION="${SATELLITE_LOCK_SCHEMA_VERSION:-$(read_existing_lock_field satellite-plugin-sdk schema_version)}"
SDK_SCHEMA_VERSION="${SDK_SCHEMA_VERSION:-1.0}"
SDK_WRAP_URL="${SATELLITE_SDK_WRAP_URL:-$(read_existing_lock_field satellite-plugin-sdk wrap_url)}"
SDK_WRAP_URL="${SDK_WRAP_URL:-https://github.com/HotDryNoodle/satellite-plugin-sdk.git}"

TM_COMMIT=$(submodule_head task-manager)
TM_TAG=$(submodule_tag task-manager)
MP_COMMIT=$(submodule_head plugins/mission-planer)
MP_TAG=$(submodule_tag plugins/mission-planer)
IP_COMMIT=$(submodule_head plugins/image-preprocess)
IP_TAG=$(submodule_tag plugins/image-preprocess)

NL_WRAP=""
for candidate in task-manager plugins/mission-planer plugins/image-preprocess; do
  if NL_WRAP=$(resolve_nlohmann_wrap "$ROOT/$candidate"); then
    break
  fi
done
if [[ -z "$NL_WRAP" ]]; then
  echo "error: no nlohmann_json.wrap found in consumer submodules" >&2
  exit 1
fi
NL_HASH=$(read_wrap_source_hash "$NL_WRAP")
NL_VERSION=$(awk -F= '/^wrapdb_version/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit }' "$NL_WRAP" | sed 's/-[0-9]*$//')
NL_VERSION="${NL_VERSION:-3.12.0}"

cat > "$LOCK" <<EOF
[satellite-plugin-sdk]
tag = "$SDK_TAG"
commit = "$SDK_COMMIT"
wrap_url = "$SDK_WRAP_URL"
wrap_revision = "$SDK_COMMIT"
schema_version = "$SDK_SCHEMA_VERSION"
version = "$SDK_VERSION"

[task-manager]
tag = "$TM_TAG"
commit = "$TM_COMMIT"

[plugins.mission-planer]
tag = "$MP_TAG"
commit = "$MP_COMMIT"

[plugins.image-preprocess]
tag = "$IP_TAG"
commit = "$IP_COMMIT"

[third_party.nlohmann_json]
version = "$NL_VERSION"
wrap_hash = "$NL_HASH"
EOF

echo "wrote $LOCK"
export SATELLITE_SDK_WRAP_URL="$SDK_WRAP_URL"
export SATELLITE_SDK_WRAP_COMMIT="$SDK_COMMIT"
"$ROOT/scripts/sync-wrap-revisions.sh"

if [[ "${SATELLITE_RELEASE_LOCK:-0}" == "1" ]]; then
  echo "release lock: all submodules pinned to exact tags"
else
  echo "integration lock: tags may be inferred from VERSION when HEAD is not tagged"
fi
echo "lock updated from submodule HEADs; commit VERSIONS.lock and consumer wrap changes in submodules"
