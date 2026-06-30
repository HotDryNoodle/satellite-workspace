#!/usr/bin/env python3
"""Generate plugins.index.json and install/env.sh after meson install."""
from __future__ import annotations

import argparse
import datetime
import json
import pathlib
import sys


def discover_installed_manifests(plugins_dir: pathlib.Path) -> list[pathlib.Path]:
    if not plugins_dir.is_dir():
        return []
    found: list[pathlib.Path] = []
    for manifest_path in sorted(plugins_dir.glob("*.json")):
        if manifest_path.name == "plugins.index.json":
            continue
        found.append(manifest_path)
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install", type=pathlib.Path, required=True)
    args = parser.parse_args()

    install = args.install.resolve()
    plugins_dir = install / "share" / "satellite" / "plugins"
    plugins_dir.mkdir(parents=True, exist_ok=True)

    entries = []
    for manifest_path in discover_installed_manifests(plugins_dir):
        manifest = json.loads(manifest_path.read_text())
        exe = install / "bin" / manifest["executable"]
        if not exe.is_file():
            print(f"error: executable not installed: {exe}", file=sys.stderr)
            return 1
        entries.append(
            {
                "tool_name": manifest["name"],
                "manifest_path": str(manifest_path.resolve()),
                "executable_resolved": str(exe.resolve()),
                "plugin_version": manifest.get("version", "0.1.0"),
                "schema_version": manifest.get("schema_version", "1.0"),
            }
        )

    if not entries:
        print(
            f"error: no plugin manifests in {plugins_dir} "
            "(expected Meson install_data to share/satellite/plugins/)",
            file=sys.stderr,
        )
        return 1

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
