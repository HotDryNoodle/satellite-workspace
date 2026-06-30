#!/usr/bin/env bash
# Ensure satellite-plugin-sdk.wrap uses a cloneable git URL (GitHub or local bare mirror).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK="$ROOT/VERSIONS.lock"
CACHE="$ROOT/.cache/satellite-plugin-sdk.git"

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

remote_has_commit() {
  local url="$1" commit="$2"
  git ls-remote "$url" 2>/dev/null | awk -v c="$commit" '$1 == c { found=1 } END { exit !found }'
}

ensure_local_mirror() {
  mkdir -p "$ROOT/.cache"
  if [[ ! -d "$CACHE" ]]; then
    echo "==> creating local bare mirror at $CACHE"
    git clone --bare "$ROOT/sdk" "$CACHE"
  else
    git -C "$CACHE" fetch "$ROOT/sdk" "+refs/heads/*:refs/heads/*" 2>/dev/null || \
      git -C "$CACHE" fetch "$ROOT/sdk" "$SDK_COMMIT" 2>/dev/null || true
  fi
}

SDK_COMMIT=$(read_lock_field satellite-plugin-sdk commit)
CANONICAL_URL=$(read_lock_field satellite-plugin-sdk wrap_url)
WRAP_URL="${SATELLITE_SDK_WRAP_URL:-$CANONICAL_URL}"

if [[ -z "$SDK_COMMIT" ]]; then
  echo "error: satellite-plugin-sdk commit missing in VERSIONS.lock" >&2
  exit 1
fi

if [[ -z "${SATELLITE_SDK_WRAP_URL:-}" ]]; then
  if remote_has_commit "$CANONICAL_URL" "$SDK_COMMIT"; then
    WRAP_URL="$CANONICAL_URL"
  else
    echo "warn: $CANONICAL_URL does not advertise commit $SDK_COMMIT (push SDK or set SATELLITE_SDK_WRAP_URL)" >&2
    ensure_local_mirror
    WRAP_URL="file://$CACHE"
    echo "==> local mirror available at $WRAP_URL"
    echo "warn: not rewriting committed consumer .wrap files (use SATELLITE_DEV_SDK=1 or push SDK)" >&2
    export SATELLITE_SDK_WRAP_URL="$WRAP_URL"
    export SATELLITE_SDK_WRAP_COMMIT="$SDK_COMMIT"
    exit 0
  fi
fi

export SATELLITE_SDK_WRAP_URL="$WRAP_URL"
export SATELLITE_SDK_WRAP_COMMIT="$SDK_COMMIT"
"$ROOT/scripts/sync-wrap-revisions.sh"
