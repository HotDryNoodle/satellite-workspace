#!/usr/bin/env python3
"""Generate plugins.index.json and install/env.sh after meson install."""
from __future__ import annotations

import argparse
import datetime
import json
import pathlib
import sys


def discover_plugin_manifests(root: pathlib.Path) -> list[tuple[str, pathlib.Path]]:
    found: list[tuple[str, pathlib.Path]] = []
    plugins_root = root / "plugins"
    if not plugins_root.is_dir():
        return found
    for plugin_dir in sorted(plugins_root.iterdir()):
        if not plugin_dir.is_dir():
            continue
        manifest_dir = plugin_dir / "configs" / "plugins"
        if not manifest_dir.is_dir():
            continue
        for manifest_path in sorted(manifest_dir.glob("*.json")):
            found.append((plugin_dir.name, manifest_path))
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=pathlib.Path, required=True)
    parser.add_argument("--install", type=pathlib.Path, required=True)
    args = parser.parse_args()

    root = args.root.resolve()
    install = args.install.resolve()
    plugins_dir = install / "share" / "satellite" / "plugins"
    plugins_dir.mkdir(parents=True, exist_ok=True)

    entries = []
    for repo_name, src in discover_plugin_manifests(root):
        if not src.is_file():
            print(f"warn: missing manifest {src}", file=sys.stderr)
            continue
        manifest = json.loads(src.read_text())
        fname = src.name
        dest = plugins_dir / fname
        dest.write_text(json.dumps(manifest, indent=2) + "\n")
        exe = install / "bin" / manifest["executable"]
        if not exe.is_file():
            print(f"error: executable not installed: {exe}", file=sys.stderr)
            return 1
        entries.append(
            {
                "tool_name": manifest["name"],
                "manifest_path": str(dest.resolve()),
                "executable_resolved": str(exe.resolve()),
                "plugin_version": manifest.get("version", "0.1.0"),
                "schema_version": manifest.get("schema_version", "1.0"),
                "repo": repo_name,
            }
        )

    index_path = install / "share" / "satellite" / "plugins.index.json"
    index_path.write_text(
        json.dumps(
            {
                "schema_version": "1.0",
                "generated_at_utc": datetime.datetime.now(datetime.timezone.utc).strftime(
                    "%Y-%m-%dT%H:%M:%SZ"
                ),
                "plugins": entries,
            },
            indent=2,
        )
        + "\n"
    )

    env_path = install / "env.sh"
    env_path.write_text(
        f'export SATELLITE_PLUGIN_INDEX="{index_path}"\n'
        f'export SATELLITE_PLUGIN_BIN="{install / "bin"}"\n'
        f'export SATELLITE_TASK_WORK_ROOT="/tmp/satellite/tasks"\n'
        f'export PATH="{install / "bin"}:$PATH"\n'
    )

    print(f"wrote {index_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
