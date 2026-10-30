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
raw_base_url) and updates: plugins[], updated, and each shared library's
version (common.version from game-common, sudoku_common.version from
sudoku-common — both derived from that library's own git tag, see
shared_lib_version()) and sha256 map.

Per plugin it also writes:
  - category      from categories.json next to this script (a missing id is
                  warned about and left without one: PluginManager files it
                  under "Other");
  - min_koreader  from an optional `min_koreader = "2026.03"` line in the
                  plugin's _meta.lua (absent -> field absent);
  - sha256        {file: hex digest} for every entry in `files`, hashed from
                  the committed (HEAD) blob of the plugin's repo, i.e. what
                  raw.githubusercontent serves once that commit is pushed.

`--output PATH` writes the result somewhere other than manifest.json (the
input is still the repo's manifest.json), for checking a change to this
script without touching the real file.
"""

import argparse
import hashlib
import json
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
CATEGORIES_PATH = Path(__file__).resolve().parent / "categories.json"

# Field order in each plugin entry.
FIELD_ORDER = ["id", "dir", "fullname", "description", "category", "version",
               "min_koreader", "files", "sha256", "common_lib"]

# Plugins deliberately set aside (broken/unpublished), excluded from the
# manifest even though their submodule is still checked out locally. See
# docs/generator_robustness_audit.md for kakuro/galaxies (confirmed generator
# bugs, unfixed); arrowwords was set aside by user request (2026-08-05).
EXCLUDED_PLUGINS = {"kakuro", "arrowwords", "startmenu"}


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
        "version":     get(r'version\s*=\s*"([^"]+)"'),
        "min_koreader": get(r'min_koreader\s*=\s*"([^"]+)"'),
        "fullname":    (get(r'fullname\s*=\s*_\("([^"]+)"\)')
                     or get(r'fullname\s*=\s*_\(\[\[([^\]]+)\]\]\)')
                     or get(r'fullname\s*=\s*"([^"]+)"')),
        "description": (get(r'description\s*=\s*_\("([^"]+)"\)')
                     or get(r'description\s*=\s*_\(\[\[([^\]]+)\]\]\)')
                     or get(r'description\s*=\s*"([^"]+)"')),
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
    vendors its own shared code, so they ship as regular downloadable files
    instead of via the shared-library mechanism."""
    common = plugin_dir / "common"
    files = []
    for f in sorted(common.iterdir()):
        if f.is_file() and f.suffix == ".lua" and not f.name.startswith("test_"):
            files.append(f"common/{f.name}")
    return files


ASSET_EXTENSIONS = {".png"}


def list_asset_files(plugin_dir: Path) -> list[str]:
    """List static asset files (e.g. piece/tile PNGs) a plugin loads at
    runtime from its own subdirectories, such as
    chess.koplugin/chess_pieces_img/, checkers.koplugin/pieces_img/, and
    fifteen.koplugin/images/.

    Without this, list_plugin_files() (top-level .lua only) never surfaces
    them, PluginManager never downloads them, and installed plugins are
    silently stuck on their code's built-in fallback rendering forever.
    `common/` is excluded since it ships via the separate common_lib path.
    """
    files = []
    for sub in sorted(plugin_dir.iterdir()):
        if not sub.is_dir() or sub.name == "common" or sub.name.startswith("."):
            continue
        for f in sorted(sub.rglob("*")):
            if f.is_file() and f.suffix.lower() in ASSET_EXTENSIONS:
                files.append(str(f.relative_to(plugin_dir)))
    return files


def matches_canonical(plugin_dir: Path, canonical_dir: Path) -> bool:
    """True if this plugin's common/*.lua is safe to serve from the shared
    library instead of vendoring: every file it has also exists in
    canonical_dir with byte-identical content, and it has no uniquely-named
    file of its own.

    Several sudoku-family plugins have deliberately diverged from
    sudoku-common (a hand-optimized puzzle_generator.lua for large grids, a
    renamed grid_utils.lua, a refactored base_screen.lua — see the
    project-sudoku-common-architecture memory). Pointing those at the shared
    library would silently replace their real behavior with the generic
    version, so they must keep shipping their own vendored files instead.
    """
    common = plugin_dir / "common"
    if not canonical_dir.is_dir():
        return False
    for f in common.iterdir():
        if not (f.is_file() and f.suffix == ".lua"):
            continue
        ref = canonical_dir / f.name
        if not ref.is_file() or f.read_bytes() != ref.read_bytes():
            return False
    return True


def shared_lib_version(lib_dir: Path) -> str | None:
    """Derive a shared library's version from its own git tags.

    Bumping manifest.json's version fields by hand is exactly what let
    common.version drift stale at "1.0.0" while game-common moved on to
    v1.2.0+ (adding buildTitleBar) — PluginManager's version-gated fetch
    (main.lua's ensureCommon) never re-downloaded the updated files. Deriving
    it from `git describe` each run keeps it truthful automatically.
    """
    if not (lib_dir / ".git").exists():
        return None
    result = subprocess.run(
        ["git", "describe", "--tags"],
        capture_output=True, cwd=lib_dir, text=True,
    )
    if result.returncode != 0:
        return None
    return result.stdout.strip().lstrip("v")


def load_categories() -> dict[str, str]:
    """Plugin id -> category id, from categories.json (see its _comment for
    the ids and their labels; PluginManager carries the translated labels)."""
    if not CATEGORIES_PATH.exists():
        print(f"WARN: {CATEGORIES_PATH.name} not found, no categories written", file=sys.stderr)
        return {}
    data = json.loads(CATEGORIES_PATH.read_text(encoding="utf-8"))
    known = set(data.get("categories", []))
    mapping = {}
    for plugin_id, cat in data.get("plugins", {}).items():
        if cat not in known:
            print(f"WARN: {plugin_id}: unknown category {cat!r} in {CATEGORIES_PATH.name}", file=sys.stderr)
            continue
        mapping[plugin_id] = cat
    return mapping


def committed_blobs(repo_dir: Path, rel_paths: list[str]) -> dict[str, bytes]:
    """HEAD content of each path in the git repo at repo_dir, in one
    `git cat-file --batch` call. Paths missing from HEAD (new, uncommitted
    files) are simply absent from the result."""
    if not rel_paths or not (repo_dir / ".git").exists():
        return {}
    request = "".join(f"HEAD:{p}\n" for p in rel_paths).encode()
    result = subprocess.run(["git", "cat-file", "--batch"], input=request,
                            capture_output=True, cwd=repo_dir)
    if result.returncode != 0:
        return {}
    out, pos, blobs = result.stdout, 0, {}
    for p in rel_paths:
        nl = out.index(b"\n", pos)
        header = out[pos:nl].decode(errors="replace").split()
        pos = nl + 1
        if not header or header[-1] in ("missing", "ambiguous"):
            continue
        size = int(header[2])
        if header[1] == "blob":
            blobs[p] = out[pos:pos + size]
        pos += size + 1  # content + trailing LF
    return blobs


def file_hashes(base_dir: Path, files: list[str]) -> dict[str, str]:
    """sha256 of each of `files` (paths relative to base_dir).

    Hashed from the committed blob, not the working tree: PluginManager
    downloads from raw.githubusercontent, which serves commits, so an
    uncommitted local edit must not leak into the manifest's hashes. A plugin
    that is its own submodule is looked up in its own repo; one tracked
    directly by the monorepo (opdsdir, dashboard) in the monorepo. A file not
    in HEAD yet falls back to the working tree.

    On device a mismatch is not fatal by itself: the branch head can be ahead
    of the commit hashed here (pushed, manifest not yet regenerated), and
    PluginManager accepts that drift when the downloaded _meta.lua is at
    least the manifest's version. See installPlugin() in main.lua.
    """
    if (base_dir / ".git").exists():
        repo, prefix = base_dir, ""
    else:
        repo, prefix = ROOT, base_dir.relative_to(ROOT).as_posix() + "/"
    blobs = committed_blobs(repo, [prefix + f for f in files])
    hashes = {}
    for f in files:
        data = blobs.get(prefix + f)
        if data is None:
            path = base_dir / f
            if not path.is_file():
                print(f"WARN: {base_dir.name}/{f}: listed but not found, no sha256", file=sys.stderr)
                continue
            data = path.read_bytes()
        hashes[f] = hashlib.sha256(data).hexdigest()
    return hashes


def apply_category(entry: dict, categories: dict[str, str], missing: list[str]) -> None:
    cat = categories.get(entry["id"])
    if cat:
        entry["category"] = cat
    else:
        entry.pop("category", None)
        missing.append(entry["id"])


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
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--output", type=Path, default=None,
                        help="write here instead of manifest.json (input is still manifest.json)")
    args = parser.parse_args()

    manifest_path = ROOT / "manifest.json"
    if not manifest_path.exists():
        print("ERROR: manifest.json not found at", manifest_path, file=sys.stderr)
        return 1
    output_path = args.output or manifest_path

    current  = json.loads(manifest_path.read_text(encoding="utf-8"))
    existing = {p["id"]: p for p in current.get("plugins", [])}
    categories = load_categories()
    no_category: list[str] = []

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
        # KOReader's PluginLoader now derives a plugin's id from its
        # directory name (stripping ".koplugin") and ignores/warns on any
        # "name" field in _meta.lua -- match that here instead of trusting
        # the (now-removed) _meta.lua field, so ids stay in sync with what
        # KOReader actually uses at runtime.
        plugin_id = koplugin_dir.stem

        if plugin_id in EXCLUDED_PLUGINS:
            skipped.append(f"{koplugin_dir.name}: excluded (EXCLUDED_PLUGINS)")
            continue

        if not meta.get("version"):
            # Stub without version — intentionally omitted.
            continue

        files  = list_plugin_files(koplugin_dir) + list_asset_files(koplugin_dir)
        family = common_family(koplugin_dir)
        common_lib = None
        if family == "game-common":
            common_lib = "common"
        elif family == "sudoku-common":
            if matches_canonical(koplugin_dir, ROOT / "sudoku-common"):
                common_lib = "sudoku_common"
            else:
                files = files + list_vendored_common_files(koplugin_dir)

        entry = dict(existing.get(plugin_id, {}))
        entry.pop("has_common", None)
        entry.update({
            "id":          plugin_id,
            "dir":         koplugin_dir.name,
            "fullname":    meta["fullname"] or entry.get("fullname", plugin_id),
            "description": meta["description"] or entry.get("description", ""),
            "version":     meta["version"],
            "files":       files,
            "sha256":      file_hashes(koplugin_dir, files),
        })
        if common_lib:
            entry["common_lib"] = common_lib
        else:
            entry.pop("common_lib", None)
        if meta.get("min_koreader"):
            entry["min_koreader"] = meta["min_koreader"]
        else:
            entry.pop("min_koreader", None)
        apply_category(entry, categories, no_category)
        plugins.append(ordered_entry(entry))

    if skipped:
        for msg in skipped:
            print("SKIP:", msg, file=sys.stderr)

    # Preserve existing entries for plugins not found locally (unchecked-out
    # submodules). Without `submodules: true` in the CI checkout, submodule
    # directories are empty so their _meta.lua is unreadable — keep the last
    # known manifest entry instead of silently dropping them.
    # Their sha256 maps are kept as they were (nothing on disk to hash), but
    # the category still follows categories.json.
    found_ids = {p["id"] for p in plugins}
    for old_entry in current.get("plugins", []):
        if old_entry["id"] not in found_ids and old_entry["id"] not in EXCLUDED_PLUGINS:
            old_entry = dict(old_entry)
            apply_category(old_entry, categories, no_category)
            plugins.append(ordered_entry(old_entry))
    plugins.sort(key=lambda p: p.get("id", ""))

    if no_category:
        print(f"WARN: no category in {CATEGORIES_PATH.name} for: {', '.join(sorted(no_category))}",
              file=sys.stderr)

    for lib_key, dir_name in (("common", "game-common"), ("sudoku_common", "sudoku-common")):
        version = shared_lib_version(ROOT / dir_name)
        if version and current.get(lib_key, {}).get("version") != version:
            print(f"{lib_key}.version: {current.get(lib_key, {}).get('version')} -> {version}")
            current.setdefault(lib_key, {})["version"] = version
        # The `files` list stays hand-maintained (see the
        # project-manifest-shared-lib-files-manual memory); only its hashes
        # are derived here. Not checked out (CI without submodules): keep
        # whatever map was there.
        lib = current.get(lib_key)
        if lib and lib.get("files") and (ROOT / dir_name).is_dir() and any((ROOT / dir_name).iterdir()):
            lib["sha256"] = file_hashes(ROOT / dir_name, lib["files"])

    current["updated"] = date.today().isoformat()
    current["plugins"] = plugins

    output_path.write_text(
        json.dumps(current, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"{output_path.name} updated: {len(plugins)} plugins, date={current['updated']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
