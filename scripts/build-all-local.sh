#!/usr/bin/env bash
# Build using sibling repos under ~/projects (no submodule checkout required).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECTS="$(cd "$ROOT/.." && pwd)"
INSTALL="$ROOT/install"
PREFIX="$INSTALL"

build_at() {
  echo "==> $1"
  (cd "$2" && meson subprojects download && meson setup build ${3:-} && meson compile -C build && meson install -C build --prefix "$PREFIX")
}

rm -rf "$INSTALL"
mkdir -p "$INSTALL/share/satellite/plugins"

build_at sdk "$PROJECTS/satellite-plugin-sdk"
build_at task-manager "$PROJECTS/task-manager" "-Dzmq=enabled"
build_at mission-planer "$PROJECTS/mission-planer"
build_at image-preprocess "$PROJECTS/image-preprocess"

python3 - "$PROJECTS" "$INSTALL" <<'PY'
import json, pathlib, datetime
projects, install = pathlib.Path(__import__('sys').argv[1]), pathlib.Path(__import__('sys').argv[2])
plugins_dir = install / 'share/satellite/plugins'
plugins_dir.mkdir(parents=True, exist_ok=True)
entries = []
for repo, fname in [('mission-planer','mission-planer.json'),('image-preprocess','image-preprocess.json')]:
    src = projects / repo / 'configs/plugins' / fname
    manifest = json.loads(src.read_text())
    dest = plugins_dir / fname
    dest.write_text(json.dumps(manifest, indent=2)+'\n')
    exe = install / 'bin' / manifest['executable']
    entries.append({
        'tool_name': manifest['name'],
        'manifest_path': str(dest.resolve()),
        'executable_resolved': str(exe.resolve()),
        'plugin_version': manifest.get('version','0.1.0'),
        'schema_version': manifest.get('schema_version','1.0'),
        'repo': repo,
    })
idx = install / 'share/satellite/plugins.index.json'
idx.write_text(json.dumps({
    'schema_version':'1.0',
    'generated_at_utc': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
    'plugins': entries,
}, indent=2)+'\n')
open(install/'env.sh','w').write(f'''export SATELLITE_PLUGIN_INDEX="{idx}"
export SATELLITE_PLUGIN_BIN="{install / 'bin'}"
export SATELLITE_TASK_WORK_ROOT="/tmp/satellite/tasks"
export PATH="{install / 'bin'}:$PATH"
''')
print('wrote', idx)
PY
