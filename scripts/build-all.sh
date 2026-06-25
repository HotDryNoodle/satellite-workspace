#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$ROOT/install"
PREFIX="$INSTALL"

build_repo() {
  local dir="$1"
  shift
  echo "==> building $dir"
  (cd "$ROOT/$dir" && meson subprojects download && meson setup build "$@" && meson compile -C build && meson install -C build --prefix "$PREFIX")
}

rm -rf "$INSTALL"
mkdir -p "$INSTALL/bin" "$INSTALL/share/satellite/plugins"

build_repo sdk
build_repo task-manager -Dzmq=enabled
build_repo plugins/mission-planer
build_repo plugins/image-preprocess

python3 - "$ROOT" "$INSTALL" <<'PY'
import json, pathlib, datetime
root = pathlib.Path(__import__('sys').argv[1])
install = pathlib.Path(__import__('sys').argv[2])
plugins_dir = install / 'share/satellite/plugins'
plugins_dir.mkdir(parents=True, exist_ok=True)
entries = []
for repo, manifest_glob in [
    ('mission-planer', 'plugins/mission-planer/configs/plugins/*.json'),
    ('image-preprocess', 'plugins/image-preprocess/configs/plugins/*.json'),
]:
    for src in (root / manifest_glob).parent.parent.glob('configs/plugins/*.json'):
        pass
for name, rel_manifest in [
    ('mission.remote_sensing_access', 'plugins/mission-planer/configs/plugins/mission-planer.json'),
    ('image.preprocess', 'plugins/image-preprocess/configs/plugins/image-preprocess.json'),
]:
    src = root / rel_manifest
    if not src.exists():
        continue
    manifest = json.loads(src.read_text())
    dest_manifest = plugins_dir / src.name
    dest_manifest.write_text(json.dumps(manifest, indent=2) + '\n')
    exe = install / 'bin' / manifest['executable']
    entries.append({
        'tool_name': manifest['name'],
        'manifest_path': str(dest_manifest.resolve()),
        'executable_resolved': str(exe.resolve()) if exe.exists() else str(exe),
        'plugin_version': manifest.get('version', '0.0.0'),
        'schema_version': manifest.get('schema_version', '1.0'),
        'repo': src.parts[-3],
    })
index_path = install / 'share/satellite/plugins.index.json'
index_path.write_text(json.dumps({
    'schema_version': '1.0',
    'generated_at_utc': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
    'plugins': entries,
}, indent=2) + '\n')
print(f'wrote {index_path}')
PY

cat > "$INSTALL/env.sh" <<ENVEOF
export SATELLITE_PLUGIN_INDEX="$INSTALL/share/satellite/plugins.index.json"
export SATELLITE_PLUGIN_BIN="$INSTALL/bin"
export SATELLITE_TASK_WORK_ROOT="/tmp/satellite/tasks"
export PATH="$INSTALL/bin:\$PATH"
ENVEOF

echo "install ready: $INSTALL"
echo "source $INSTALL/env.sh"
