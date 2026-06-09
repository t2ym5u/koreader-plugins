#!/usr/bin/env python3
"""Regenerate manifest.json from the current state of the repository.

Only plugins whose _meta.lua is tracked by git are included — this ensures
the manifest reflects what is actually published on GitHub, both locally and
in CI. Stubs and plugins from separate repositories (even if present as
local directories) are therefore automatically excluded.

Run from any directory; the script locates the repo root via its own path.
Preserves fields not managed here (schema_version, repo, branch,
raw_base_url, common) and updates: plugins[], updated.
"""

import json
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent

# Plugin IDs that are infrastructure, not distributable game plugins.
NON_PLUGIN_IDS = {"pluginmanager"}

# Field order in each plugin entry.
FIELD_ORDER = ["id", "dir", "fullname", "description", "version", "files", "has_common"]


def is_git_tracked(path: Path) -> bool:
    """Return True if `path` is tracked by git."""
    result = subprocess.run(
        ["git", "ls-files", "--error-unmatch", str(path)],
        capture_output=True,
        cwd=ROOT,
    )
    return result.returncode == 0


def read_meta(meta_path: Path) -> dict:
    """Extract fields from _meta.lua by regex (does not execute Lua)."""
    src = meta_path.read_text(encoding="utf-8")

    def get(pattern):
        m = re.search(pattern, src)
        return m.group(1) if m else None

    return {
        "name":        get(r'name\s*=\s*"([^"]+)"'),
        "version":     get(r'version\s*=\s*"([^"]+)"'),
        "fullname":    get(r'fullname\s*=\s*_\("([^"]+)"\)'),
        "description": (get(r'description\s*=\s*_\("([^"]+)"\)')
                     or get(r'description\s*=\s*_\(\[\[([^\]]+)\]\]\)')),
    }


def list_plugin_files(plugin_dir: Path) -> list[str]:
    """List .lua files directly in plugin_dir.

    Excludes:
    - symlinks (e.g. common/ -> ../game-common)
    - test files (test_*.lua)
    """
    files = []
    for f in sorted(plugin_dir.iterdir()):
        if f.is_symlink():
            continue
        if f.is_file() and f.suffix == ".lua" and not f.name.startswith("test_"):
            files.append(f.name)
    return files


def has_common_dep(plugin_dir: Path) -> bool:
    common = plugin_dir / "common"
    return common.is_symlink() or common.is_dir()


def ordered_entry(entry: dict) -> dict:
    result = {}
    for key in FIELD_ORDER:
        if key in entry:
            result[key] = entry[key]
    for key in entry:
        if key not in result:
            result[key] = entry[key]
    return result


def main() -> int:
    manifest_path = ROOT / "manifest.json"
    if not manifest_path.exists():
        print("ERROR: manifest.json not found at", manifest_path, file=sys.stderr)
        return 1

    current  = json.loads(manifest_path.read_text(encoding="utf-8"))
    existing = {p["id"]: p for p in current.get("plugins", [])}

    plugins = []
    skipped = []

    for koplugin_dir in sorted(ROOT.glob("*.koplugin")):
        # Skip template directories (e.g. _skeleton.koplugin).
        if koplugin_dir.name.startswith("_"):
            continue

        meta_path = koplugin_dir / "_meta.lua"
        if not meta_path.exists():
            continue

        # Only include plugins whose _meta.lua is tracked by git.
        # This filters out untracked stubs and plugins from separate repos.
        if not is_git_tracked(meta_path):
            skipped.append(f"{koplugin_dir.name}: _meta.lua not tracked by git")
            continue

        meta      = read_meta(meta_path)
        plugin_id = meta.get("name")

        if not plugin_id:
            skipped.append(f"{koplugin_dir.name}: no name in _meta.lua")
            continue
        if not meta.get("version"):
            # Stub without version — intentionally omitted.
            continue
        if plugin_id in NON_PLUGIN_IDS:
            continue

        files      = list_plugin_files(koplugin_dir)
        has_common = has_common_dep(koplugin_dir)

        entry = dict(existing.get(plugin_id, {}))
        entry.update({
            "id":          plugin_id,
            "dir":         koplugin_dir.name,
            "fullname":    meta["fullname"] or entry.get("fullname", plugin_id),
            "description": meta["description"] or entry.get("description", ""),
            "version":     meta["version"],
            "files":       files,
            "has_common":  has_common,
        })
        plugins.append(ordered_entry(entry))

    if skipped:
        for msg in skipped:
            print("SKIP:", msg, file=sys.stderr)

    current["updated"] = date.today().isoformat()
    current["plugins"] = plugins

    manifest_path.write_text(
        json.dumps(current, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"manifest.json updated: {len(plugins)} plugins, date={current['updated']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
