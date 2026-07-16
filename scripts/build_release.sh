#!/usr/bin/env bash
# Build distributable zip archives for each plugin and a full bundle.
# Usage:
#   ./build_release.sh            # build all plugins in manifest.json
#   ./build_release.sh fifteen    # build only the 'fifteen' plugin
# Output: dist/ directory with one zip per plugin + koreader-games-full.zip
#
# Each individual zip extracts as:
#   <plugin>.koplugin/        ← drop into KOReader plugins/ folder
#     common/                 ← real directory, no symlink needed
#     *.lua
#   game-common/, sudoku-common/  ← shared libraries, useful when installing several plugins
#
# The full bundle extracts each shared library once alongside all plugins.
# Two mutually-incompatible shared-code families exist (see the
# project-sudoku-common-architecture memory) — manifest.json's top-level
# "common" (game-common) and "sudoku_common" (sudoku-common) sections, each
# plugin naming the one it needs via its "common_lib" field. A plugin with a
# common/ dir but no common_lib has genuinely diverged from its family's
# shared code and vendors its own files instead (already listed in its
# "files" array as "common/<name>.lua" by update_manifest.py).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
MANIFEST="$SCRIPT_DIR/manifest.json"
FILTER="${1:-}"

if [ ! -f "$MANIFEST" ]; then
  echo "Error: manifest.json not found" >&2; exit 1
fi

mkdir -p "$DIST_DIR"

# Parse manifest: emit a header line per shared lib, then one line per plugin.
#   LIB|<lib_key>|<dir>|<space-separated files>
#   PLUGIN|<plugin_dir>|<common_lib or empty>|<space-separated files>
PARSED=$(python3 - "$MANIFEST" "$FILTER" <<'PYEOF'
import json, sys
manifest = json.load(open(sys.argv[1]))
filt = sys.argv[2]
for lib_key in ("common", "sudoku_common"):
    spec = manifest.get(lib_key)
    if spec:
        print(f'LIB|{lib_key}|{spec["dir"]}|{" ".join(spec["files"])}')
for p in manifest["plugins"]:
    if not filt or p["id"] == filt or p["dir"] == filt:
        print(f'PLUGIN|{p["dir"]}|{p.get("common_lib", "")}|{" ".join(p["files"])}')
PYEOF
)

if [ -z "$PARSED" ]; then
  echo "No plugins matched '${FILTER}'" >&2; exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

BUNDLE_DIR="$TMPDIR/bundle"
mkdir -p "$BUNDLE_DIR"

# Resolve each shared lib's source dir + file list up front (associative
# arrays keyed by lib_key, e.g. "common" -> "game-common").
declare -A LIB_SRC LIB_FILES
while IFS='|' read -r kind a b c; do
  [ "$kind" = "LIB" ] || continue
  lib_key="$a" lib_dir="$b" lib_files="$c"
  src="$SCRIPT_DIR/$lib_dir"
  if [ ! -d "$src" ]; then
    echo "Error: $lib_dir/ not found (needed by common_lib=$lib_key)" >&2; exit 1
  fi
  LIB_SRC["$lib_key"]="$src"
  LIB_FILES["$lib_key"]="$lib_files"
done <<< "$PARSED"

built=0
while IFS='|' read -r kind plugin_dir common_lib plugin_files_str; do
  [ "$kind" = "PLUGIN" ] || continue
  plugin_src="$SCRIPT_DIR/$plugin_dir"
  if [ ! -d "$plugin_src" ]; then
    echo "Warning: $plugin_dir not found, skipping" >&2
    continue
  fi

  WORK="$TMPDIR/$plugin_dir"
  mkdir -p "$WORK"

  # Copy the plugin's shared-library files first (plugin files may override).
  if [ -n "$common_lib" ]; then
    lib_src="${LIB_SRC[$common_lib]}"
    lib_dir_name="$(basename "$lib_src")"
    mkdir -p "$WORK/common"
    for fname in ${LIB_FILES[$common_lib]}; do
      src_file="$lib_src/$fname"
      if [ -f "$src_file" ]; then
        cp "$src_file" "$WORK/common/$fname"
        mkdir -p "$BUNDLE_DIR/$lib_dir_name"
        [ -f "$BUNDLE_DIR/$lib_dir_name/$fname" ] || cp "$src_file" "$BUNDLE_DIR/$lib_dir_name/$fname"
      else
        echo "Warning: $lib_dir_name/$fname not found" >&2
      fi
    done
  fi

  # Copy plugin source files (may override shared-lib files in common/;
  # this also covers plugins that vendor their own diverged common/*.lua,
  # since update_manifest.py already listed those as common/<name>.lua here).
  for fname in $plugin_files_str; do
    src_file="$plugin_src/$fname"
    if [ ! -f "$src_file" ]; then
      echo "Warning: $plugin_dir/$fname not found" >&2
      continue
    fi
    mkdir -p "$WORK/$(dirname "$fname")"
    cp "$src_file" "$WORK/$fname"
  done

  # Individual plugin zip: plugin_dir/ + its shared lib dir side by side.
  INSTALL_DIR="$TMPDIR/install_$plugin_dir"
  mkdir -p "$INSTALL_DIR"
  cp -r "$WORK" "$INSTALL_DIR/$plugin_dir"
  if [ -n "$common_lib" ]; then
    lib_src="${LIB_SRC[$common_lib]}"
    lib_dir_name="$(basename "$lib_src")"
    mkdir -p "$INSTALL_DIR/$lib_dir_name"
    for fname in ${LIB_FILES[$common_lib]}; do
      [ -f "$lib_src/$fname" ] && cp "$lib_src/$fname" "$INSTALL_DIR/$lib_dir_name/$fname"
    done
  fi

  zip_name="${plugin_dir%.koplugin}.zip"
  rm -f "$DIST_DIR/$zip_name"   # ensure no stale entries from previous builds
  (cd "$INSTALL_DIR" && zip -r "$DIST_DIR/$zip_name" . -x "*.DS_Store" -q)

  cp -r "$WORK" "$BUNDLE_DIR/$plugin_dir"

  echo "  Built: $zip_name"
  built=$((built + 1))
done <<< "$PARSED"

# Full bundle (only when no filter)
if [ -z "$FILTER" ]; then
  rm -f "$DIST_DIR/koreader-games-full.zip"
  (cd "$BUNDLE_DIR" && zip -r "$DIST_DIR/koreader-games-full.zip" . -x "*.DS_Store" -q)
  echo "  Built: koreader-games-full.zip"
fi

echo ""
echo "Done: $built plugin(s) built in dist/"
