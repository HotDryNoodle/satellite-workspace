#!/usr/bin/env bash
# Verify install/ tree: binaries, plugin index, manifests.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$ROOT/install"
INDEX="$INSTALL/share/satellite/plugins.index.json"

required_bins=(
  task-client
  task-manager
  mission-planer
  image-preprocess
)

for bin in "${required_bins[@]}"; do
  path="$INSTALL/bin/$bin"
  if [[ ! -x "$path" ]]; then
    echo "error: missing executable $path" >&2
    exit 1
  fi
done

if [[ ! -f "$INDEX" ]]; then
  echo "error: missing plugin index $INDEX" >&2
  exit 1
fi

python3 - "$INDEX" <<'PY'
import json, pathlib, sys
index_path = pathlib.Path(sys.argv[1])
data = json.loads(index_path.read_text())
plugins = data.get("plugins", [])
if not plugins:
    print("error: plugins.index.json has no entries", file=sys.stderr)
    sys.exit(1)
for entry in plugins:
    for key in ("tool_name", "manifest_path", "executable_resolved"):
        if key not in entry:
            print(f"error: index entry missing {key}: {entry}", file=sys.stderr)
            sys.exit(1)
    manifest = pathlib.Path(entry["manifest_path"])
    exe = pathlib.Path(entry["executable_resolved"])
    if not manifest.is_file():
        print(f"error: manifest missing: {manifest}", file=sys.stderr)
        sys.exit(1)
    if not exe.is_file():
        print(f"error: executable missing: {exe}", file=sys.stderr)
        sys.exit(1)
print(f"OK install smoke: {len(plugins)} plugin(s)")
PY

echo "install smoke passed"
