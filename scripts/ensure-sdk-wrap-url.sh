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

SDK_COMMIT=$(read_lock_field satellite-plugin-sdk commit)
CANONICAL_URL=$(read_lock_field satellite-plugin-sdk wrap_url)
WRAP_URL="${SATELLITE_SDK_WRAP_URL:-$CANONICAL_URL}"

if [[ -z "$SDK_COMMIT" ]]; then
  echo "error: satellite-plugin-sdk commit missing in VERSIONS.lock" >&2
  exit 1
fi

if [[ -z "${SATELLITE_SDK_WRAP_URL:-}" ]] && ! git ls-remote --heads "$CANONICAL_URL" "$SDK_COMMIT" &>/dev/null; then
  echo "warn: cannot reach $CANONICAL_URL (push repos to GitHub or set SATELLITE_SDK_WRAP_URL)" >&2
  mkdir -p "$ROOT/.cache"
  if [[ ! -d "$CACHE" ]]; then
    echo "==> creating local bare mirror at $CACHE"
    git clone --bare "$ROOT/sdk" "$CACHE"
  else
    git -C "$CACHE" fetch "$ROOT/sdk" "+refs/heads/*:refs/heads/*" 2>/dev/null || \
      git -C "$CACHE" fetch "$ROOT/sdk" "$SDK_COMMIT" 2>/dev/null || true
  fi
  WRAP_URL="file://$CACHE"
  echo "==> using local wrap URL: $WRAP_URL"
fi

export SATELLITE_SDK_WRAP_URL="$WRAP_URL"
export SATELLITE_SDK_WRAP_COMMIT="$SDK_COMMIT"
"$ROOT/scripts/sync-wrap-revisions.sh"
