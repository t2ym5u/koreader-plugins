#!/usr/bin/env bash
# Verify that every sudoku-variant plugin still reaches sudoku-common through a
# committed symlink, rather than a copy that can quietly drift.
#
# This script used to diff each plugin's vendored common/*.lua against the
# canonical copy, because common/ was a plain committed directory per plugin.
# It is not any more: all eight variants carry `common -> ../sudoku-common` as
# a committed symlink (git mode 120000), dereferenced into a real directory at
# zip time by scripts/build_release.sh. There is therefore nothing left to
# drift -- unless someone replaces a symlink with a copy, which is exactly what
# this now checks.
#
# Read-only: makes no changes, no commits, no pushes.
# Usage:
#   ./check_sudoku_common_drift.sh
#
# Exit code is non-zero if any plugin has stopped pointing at sudoku-common.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGINS=(sudoku arrowsudoku sandwichsudoku sudokukiller sudokux thermosudoku betweenlines windoku)
EXPECTED="../sudoku-common"

problems=0

for name in "${PLUGINS[@]}"; do
  dir="$ROOT/$name.koplugin"
  link="$dir/common"

  if [ ! -e "$link" ]; then
    echo "FAIL $name: no common/ at all"
    problems=$((problems + 1))
    continue
  fi

  if [ ! -L "$link" ]; then
    echo "FAIL $name: common/ is a real directory, not a symlink to sudoku-common."
    echo "     It will drift. Replace it: rm -rf '$link' && ln -s '$EXPECTED' '$link'"
    problems=$((problems + 1))
    continue
  fi

  target="$(readlink "$link")"
  if [ "$target" != "$EXPECTED" ]; then
    echo "FAIL $name: common/ points at '$target', expected '$EXPECTED'"
    problems=$((problems + 1))
    continue
  fi

  # The symlink must be committed, not just present locally -- see the
  # local-symlink-vs-deploy trap: a working-tree-only symlink ships nothing.
  mode="$(git -C "$dir" ls-files -s common | awk '{print $1}')"
  if [ "$mode" != "120000" ]; then
    echo "FAIL $name: common/ is not a committed symlink (git mode '${mode:-untracked}')"
    problems=$((problems + 1))
    continue
  fi

  echo "OK   $name: common -> $target (committed symlink)"
done

echo
if [ "$problems" -eq 0 ]; then
  echo "All ${#PLUGINS[@]} sudoku variants share sudoku-common. Nothing can drift."
  exit 0
fi

echo "$problems plugin(s) no longer share sudoku-common -- fix before releasing." >&2
exit 1
