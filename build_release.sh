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
#   game-common/              ← shared library, useful when installing several plugins
#
# The full bundle extracts game-common/ once alongside all plugins.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
COMMON_SRC="$SCRIPT_DIR/game-common"
MANIFEST="$SCRIPT_DIR/manifest.json"
FILTER="${1:-}"

if [ ! -f "$MANIFEST" ]; then
  echo "Error: manifest.json not found" >&2; exit 1
fi
if [ ! -d "$COMMON_SRC" ]; then
  echo "Error: game-common/ not found" >&2; exit 1
fi

mkdir -p "$DIST_DIR"

# Parse manifest: emit lines  plugin_dir|has_common|common_files|plugin_files
# common_files: space-separated list from manifest.common.files
# plugin_files: space-separated list from plugin.files
PARSED=$(python3 - "$MANIFEST" "$FILTER" <<'PYEOF'
import json, sys
manifest = json.load(open(sys.argv[1]))
filt = sys.argv[2]
common_files = " ".join(manifest.get("common", {}).get("files", []))
for p in manifest["plugins"]:
    if not filt or p["id"] == filt or p["dir"] == filt:
        has_c = "1" if p.get("has_common") else "0"
        pfiles = " ".join(p["files"])
        print(f'{p["dir"]}|{has_c}|{common_files}|{pfiles}')
PYEOF
)

if [ -z "$PARSED" ]; then
  echo "No plugins matched '${FILTER}'" >&2; exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Build full bundle's game-common once (only the files listed in manifest)
BUNDLE_DIR="$TMPDIR/bundle"
BUNDLE_COMMON="$BUNDLE_DIR/game-common"
mkdir -p "$BUNDLE_COMMON"

built=0
while IFS='|' read -r plugin_dir has_common common_files_str plugin_files_str; do
  plugin_src="$SCRIPT_DIR/$plugin_dir"
  if [ ! -d "$plugin_src" ]; then
    echo "Warning: $plugin_dir not found, skipping" >&2
    continue
  fi

  WORK="$TMPDIR/$plugin_dir"
  mkdir -p "$WORK"

  # Copy game-common files first (plugin files may override them)
  if [ "$has_common" = "1" ]; then
    mkdir -p "$WORK/common"
    for fname in $common_files_str; do
      src_file="$COMMON_SRC/$fname"
      if [ -f "$src_file" ]; then
        cp "$src_file" "$WORK/common/$fname"
        # Populate bundle's game-common lazily
        [ -f "$BUNDLE_COMMON/$fname" ] || cp "$src_file" "$BUNDLE_COMMON/$fname"
      else
        echo "Warning: game-common/$fname not found" >&2
      fi
    done
  fi

  # Copy plugin source files (may override game-common files in common/)
  for fname in $plugin_files_str; do
    src_file="$plugin_src/$fname"
    if [ ! -f "$src_file" ]; then
      echo "Warning: $plugin_dir/$fname not found" >&2
      continue
    fi
    mkdir -p "$WORK/$(dirname "$fname")"
    cp "$src_file" "$WORK/$fname"
  done

  # Individual plugin zip: plugin_dir/ + game-common/ side by side
  INSTALL_DIR="$TMPDIR/install_$plugin_dir"
  mkdir -p "$INSTALL_DIR"
  cp -r "$WORK" "$INSTALL_DIR/$plugin_dir"
  if [ "$has_common" = "1" ]; then
    mkdir -p "$INSTALL_DIR/game-common"
    for fname in $common_files_str; do
      [ -f "$COMMON_SRC/$fname" ] && cp "$COMMON_SRC/$fname" "$INSTALL_DIR/game-common/$fname"
    done
  fi

  zip_name="${plugin_dir%.koplugin}.zip"
  (cd "$INSTALL_DIR" && zip -r "$DIST_DIR/$zip_name" . -x "*.DS_Store" -q)

  cp -r "$WORK" "$BUNDLE_DIR/$plugin_dir"

  echo "  Built: $zip_name"
  built=$((built + 1))
done <<< "$PARSED"

# Full bundle (only when no filter)
if [ -z "$FILTER" ]; then
  (cd "$BUNDLE_DIR" && zip -r "$DIST_DIR/koreader-games-full.zip" . -x "*.DS_Store" -q)
  echo "  Built: koreader-games-full.zip"
fi

echo ""
echo "Done: $built plugin(s) built in dist/"
