#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK="$ROOT/VERSIONS.lock"
fail=0
strict=0

usage() {
  echo "Usage: $0 [--strict]" >&2
  echo "  default: warn on mismatch (exit 0)" >&2
  echo "  --strict or SATELLITE_STRICT_VERSIONS=1: fail on mismatch" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict) strict=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ "${SATELLITE_STRICT_VERSIONS:-0}" == "1" ]]; then
  strict=1
fi

read_lock_field() {
  local section="$1"
  local key="$2"
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

report_mismatch() {
  local msg="$1"
  if [[ "$strict" -eq 1 ]]; then
    echo "MISMATCH $msg"
    fail=1
  else
    echo "WARN $msg"
  fi
}

report_ok() {
  echo "OK $*"
}

check_commit() {
  local name="$1" workspace_path="$2" key="$3"
  local expected actual repo_path="$ROOT/$workspace_path"
  expected=$(read_lock_field "$key" commit)
  if [[ -z "$expected" || "$expected" == "0000000" ]]; then
    echo "skip $name (lock commit not pinned)"
    return
  fi
  if [[ ! -e "$repo_path/.git" ]]; then
    echo "skip $name (submodule not checked out at $workspace_path)"
    return
  fi
  actual=$(git -C "$repo_path" rev-parse HEAD)
  if [[ "$expected" != "$actual" ]]; then
    report_mismatch "$name: lock=$expected head=$actual"
  else
    report_ok "$name $actual"
  fi
}

check_sdk_version() {
  local expected sdk_ver=""
  expected=$(read_lock_field satellite-plugin-sdk version)
  if [[ -z "$expected" ]]; then
    echo "skip SDK version (not in lock)"
    return
  fi
  if [[ ! -f "$ROOT/sdk/VERSION" ]]; then
    echo "skip SDK version (sdk/VERSION missing)"
    return
  fi
  sdk_ver=$(cat "$ROOT/sdk/VERSION")
  if [[ "$expected" != "$sdk_ver" ]]; then
    report_mismatch "SDK VERSION: lock=$expected file=$sdk_ver"
  else
    report_ok "SDK VERSION $sdk_ver"
  fi
}

read_wrap_field() {
  local wrap_file="$1"
  local key="$2"
  awk -v key="$key" -F= '
    $1 ~ "^" key "[[:space:]]*$" {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
      print $2
      exit
    }
  ' "$wrap_file"
}

check_sdk_wrap() {
  local expected_rev expected_url
  expected_rev=$(read_lock_field satellite-plugin-sdk wrap_revision)
  expected_url=$(read_lock_field satellite-plugin-sdk wrap_url)
  if [[ -z "$expected_rev" ]]; then
    expected_rev=$(read_lock_field satellite-plugin-sdk commit)
  fi

  local repos=(task-manager plugins/mission-planer plugins/image-preprocess)
  local any=0
  for ws_path in "${repos[@]}"; do
    local wrap_file="$ROOT/$ws_path/subprojects/satellite-plugin-sdk.wrap"
    if [[ ! -f "$wrap_file" ]]; then
      continue
    fi
    any=1
    local actual_rev actual_url
    actual_rev=$(read_wrap_field "$wrap_file" revision)
    actual_url=$(read_wrap_field "$wrap_file" url)
    if [[ -n "$expected_rev" && "$expected_rev" != "$actual_rev" ]]; then
      report_mismatch "$ws_path wrap revision: lock=$expected_rev wrap=$actual_rev"
    else
      report_ok "$ws_path wrap revision $actual_rev"
    fi
    if [[ "$actual_url" == file://* ]]; then
      echo "OK $ws_path wrap url (local file mirror for build)"
    elif [[ -n "$expected_url" && "$expected_url" != "$actual_url" ]]; then
      report_mismatch "$ws_path wrap url: lock=$expected_url wrap=$actual_url"
    elif [[ -n "$expected_url" ]]; then
      report_ok "$ws_path wrap url"
    fi
  done
  if [[ "$any" -eq 0 ]]; then
    echo "skip SDK wrap (no consumer wrap files)"
  fi
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
  if [[ ! -f "$wrap" ]]; then
    return 1
  fi
  if grep -q '^\[wrap-redirect\]' "$wrap" 2>/dev/null; then
    local target
    target=$(awk -F= '/^filename/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit }' "$wrap")
    wrap="$repo_path/subprojects/$target"
  fi
  [[ -f "$wrap" ]] && echo "$wrap"
}

check_nlohmann_wrap_hash() {
  local expected
  expected=$(read_lock_field third_party.nlohmann_json wrap_hash)
  if [[ -z "$expected" ]]; then
    echo "skip nlohmann_json wrap_hash (not in lock)"
    return
  fi

  local repos=(task-manager plugins/mission-planer plugins/image-preprocess)
  local any=0
  for ws_path in "${repos[@]}"; do
    local wrap_file=""
    if resolve_nlohmann_wrap "$ROOT/$ws_path" >/dev/null 2>&1; then
      wrap_file=$(resolve_nlohmann_wrap "$ROOT/$ws_path")
    else
      continue
    fi
    any=1
    local actual
    actual=$(read_wrap_source_hash "$wrap_file")
    if [[ "$expected" != "$actual" ]]; then
      report_mismatch "$ws_path nlohmann_json hash: lock=$expected wrap=$actual"
    else
      report_ok "$ws_path nlohmann_json hash"
    fi
  done
  if [[ "$any" -eq 0 ]]; then
    echo "skip nlohmann_json wrap_hash (no wrap files found)"
  fi
}

check_commit satellite-plugin-sdk sdk satellite-plugin-sdk
check_commit task-manager task-manager task-manager
check_commit mission-planer plugins/mission-planer plugins.mission-planer
check_commit image-preprocess plugins/image-preprocess plugins.image-preprocess
check_sdk_version
check_sdk_wrap
check_nlohmann_wrap_hash

exit $fail
