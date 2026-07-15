#!/usr/bin/env python3
"""Regenerate manifest.json from the current state of the repository.

Plugins are included when their _meta.lua is either:
  - Directly tracked by git in the parent repo (e.g. opdsdir, dashboard), or
  - Inside a registered git submodule (plugin lives in its own repo).

Stubs (no version field) are always excluded. pluginmanager is included
like any other plugin: PluginManager's own install flow self-updates by
comparing its installed version against its manifest entry, so that entry
must track its real version too.

Run from any directory; the script locates the repo root via its own path.
Preserves fields not managed here (schema_version, repo, branch,
raw_base_url) and updates: plugins[], updated, common.version (derived
from game-common's own git tag, see game_common_version()).
"""

import json
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent

# Field order in each plugin entry.
FIELD_ORDER = ["id", "dir", "fullname", "description", "version", "files", "has_common"]


def is_git_tracked(path: Path) -> bool:
    """Return True if `path` is directly tracked by the parent git repo."""
    result = subprocess.run(
        ["git", "ls-files", "--error-unmatch", str(path)],
        capture_output=True,
        cwd=ROOT,
    )
    return result.returncode == 0


def is_git_submodule(plugin_dir: Path) -> bool:
    """Return True if `plugin_dir` is a checked-out git submodule.

    Git submodules contain a `.git` file (not a directory) that points to
    the real git dir inside the parent's .git/modules/.
    """
    git_entry = plugin_dir / ".git"
    return git_entry.is_file()


def is_publishable(plugin_dir: Path, meta_path: Path) -> bool:
    """Return True if this plugin should appear in the manifest."""
    return is_git_tracked(meta_path) or is_git_submodule(plugin_dir)


def read_meta(meta_path: Path) -> dict:
    """Extract fields from _meta.lua by regex (does not execute Lua)."""
    src = meta_path.read_text(encoding="utf-8")

    def get(pattern):
        m = re.search(pattern, src)
        return m.group(1) if m else None

    return {
        # (?<!\w) keeps this from matching "name" inside "fullname".
        "name":        get(r'(?<!\w)name\s*=\s*"([^"]+)"'),
        "version":     get(r'version\s*=\s*"([^"]+)"'),
        "fullname":    (get(r'fullname\s*=\s*_\("([^"]+)"\)')
                     or get(r'fullname\s*=\s*_\(\[\[([^\]]+)\]\]\)')),
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


# Files that only ever appear in the sudoku-common family's vendored copy
# (base_board.lua, base_screen.lua, puzzle_generator.lua, ...) — never part
# of game-common. Their presence is what distinguishes the two families.
SUDOKU_COMMON_MARKERS = {"base_board.lua", "base_screen.lua", "puzzle_generator.lua", "base_board_widget.lua"}


def common_family(plugin_dir: Path) -> str | None:
    """Identify which shared-code family a plugin's common/ dir belongs to.

    Two mutually exclusive families exist in this repo (see the
    project-sudoku-common-architecture memory):
    - "game-common": ScreenBase-based games/tools. common/ holds a vendored
      copy of some subset of the generic shared library (screen_base.lua,
      i18n.lua, ...) that PluginManager fetches once into a single shared
      game-common/ dir on-device. Some plugins (e.g. dashboard) only vendor
      a single file like i18n.lua, with no screen_base.lua at all.
    - "sudoku-common": BaseScreen-based sudoku variants. common/base_screen.lua
      (plus base_board.lua, puzzle_generator.lua, ...) is a plugin-specific,
      already-diverged copy — NOT interchangeable with game-common's files.
      These must ship as regular per-plugin files, not via the has_common
      shared-fetch mechanism (which only knows about game-common and would
      silently install the wrong files, crashing the plugin at runtime).
    Returns None if the plugin has no common/ dir at all.
    """
    common = plugin_dir / "common"
    if not common.is_dir():
        return None
    names = {f.name for f in common.iterdir() if f.is_file()}
    if names & SUDOKU_COMMON_MARKERS:
        return "sudoku-common"
    if names:
        return "game-common"
    return None


def list_vendored_common_files(plugin_dir: Path) -> list[str]:
    """List common/*.lua files (as 'common/<name>.lua') for a plugin that
    vendors its own shared code (sudoku-common family), so they ship as
    regular downloadable files instead of via the has_common mechanism."""
    common = plugin_dir / "common"
    files = []
    for f in sorted(common.iterdir()):
        if f.is_file() and f.suffix == ".lua" and not f.name.startswith("test_"):
            files.append(f"common/{f.name}")
    return files


def game_common_version(root: Path) -> str | None:
    """Derive game-common's shared-lib version from its own git tags.

    Bumping manifest.json's common.version by hand is exactly what let it
    drift stale at "1.0.0" while game-common moved on to v1.2.0+ (adding
    buildTitleBar) — PluginManager's version-gated fetch (main.lua's
    ensureCommon) never re-downloaded the updated files. Deriving it from
    `git describe` each run keeps it truthful automatically.
    """
    gc_dir = root / "game-common"
    if not (gc_dir / ".git").exists():
        return None
    result = subprocess.run(
        ["git", "describe", "--tags"],
        capture_output=True, cwd=gc_dir, text=True,
    )
    if result.returncode != 0:
        return None
    return result.stdout.strip().lstrip("v")


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

        # Only include plugins whose _meta.lua is tracked by git (directly in
        # the parent repo) or lives inside a checked-out git submodule.
        if not is_publishable(koplugin_dir, meta_path):
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

        files  = list_plugin_files(koplugin_dir)
        family = common_family(koplugin_dir)
        if family == "sudoku-common":
            has_common = False
            files = files + list_vendored_common_files(koplugin_dir)
        else:
            has_common = family == "game-common"

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

    # Preserve existing entries for plugins not found locally (unchecked-out
    # submodules). Without `submodules: true` in the CI checkout, submodule
    # directories are empty so their _meta.lua is unreadable — keep the last
    # known manifest entry instead of silently dropping them.
    found_ids = {p["id"] for p in plugins}
    for old_entry in current.get("plugins", []):
        if old_entry["id"] not in found_ids:
            plugins.append(old_entry)
    plugins.sort(key=lambda p: p.get("id", ""))

    gc_version = game_common_version(ROOT)
    if gc_version and current.get("common", {}).get("version") != gc_version:
        print(f"common.version: {current.get('common', {}).get('version')} -> {gc_version}")
        current.setdefault("common", {})["version"] = gc_version

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
