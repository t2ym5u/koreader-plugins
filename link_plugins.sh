#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: $0 <koreader-plugins-dir>"
    echo "  Creates symlinks from .koplugin dirs (and shared libs) into the given directory."
    echo "  Example: $0 ../koreader/plugins"
    exit 1
}

[[ $# -eq 1 ]] || usage

TARGET_DIR="$(cd "$1" && pwd)"

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: target directory '$1' does not exist." >&2
    exit 1
fi

link() {
    local name="$1"
    local src="$SCRIPT_DIR/$name"
    local dst="$TARGET_DIR/$name"

    if [[ ! -e "$src" ]]; then
        echo "  skip  $name (source not found)"
        return
    fi

    if [[ -L "$dst" ]]; then
        local existing
        existing="$(readlink "$dst")"
        if [[ "$existing" == "$src" ]]; then
            echo "  ok    $name (already linked)"
            return
        fi
        echo "  relink $name ($existing → $src)"
        rm "$dst"
    elif [[ -e "$dst" ]]; then
        echo "  skip  $name (exists and is not a symlink, leaving it alone)"
        return
    fi

    ln -s "$src" "$dst"
    echo "  linked $name"
}

echo "Linking plugins from:"
echo "  src: $SCRIPT_DIR"
echo "  dst: $TARGET_DIR"
echo ""

# game-common is referenced at runtime as ../game-common/ by plugins
# sudoku-common is already physically duplicated inside each plugin's common/ — no symlink needed
link "game-common"

# All .koplugin directories (excluding development templates)
EXCLUDE_PLUGINS=("_skeleton.koplugin")

for plugin_dir in "$SCRIPT_DIR"/*.koplugin; do
    [[ -d "$plugin_dir" ]] || continue
    name="$(basename "$plugin_dir")"
    skip=false
    for excl in "${EXCLUDE_PLUGINS[@]}"; do
        [[ "$name" == "$excl" ]] && skip=true && break
    done
    $skip && echo "  skip  $name (excluded)" && continue
    link "$name"
done

echo ""
echo "Done."
