#!/usr/bin/env bash
# Detect drift between sudoku-common/ (the canonical reference copy) and each
# sudoku-variant plugin's vendored common/ copy. Plugins are independent git
# submodules/repos, so common/ is a plain committed directory, not a symlink
# or submodule -- divergence can only be detected by diffing file contents.
#
# Usage:
#   ./scripts/check_sudoku_common_drift.sh
#
# Exit code is non-zero if any unexpected drift or missing file is found.
# Known-intentional divergences (documented below) are reported but do not
# fail the run.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CANON="$ROOT/sudoku-common"

PLUGINS=(sudoku arrowsudoku sandwichsudoku sudokukiller sudokux thermosudoku betweenlines windoku)
FILES=(base_board.lua base_board_widget.lua base_screen.lua puzzle_generator.lua sudoku_grid_utils.lua)

# Known-intentional divergences: "<plugin>:<canonical filename>".
# Confirmed via each plugin's own git history (feat: commits describing the
# variant-specific behavior), not just "it's different so it must be fine".
#   sudoku/puzzle_generator.lua       -- deliberately simpler classic-only
#                                         algorithm, no extra_regions needed.
#   sudoku/base_board_widget.lua      -- 3-line max_size clamp for its
#                                         portrait-layout sizing.
#   sudoku/base_screen.lua            -- generateWithProgress takes an extra
#                                         rng param (for Daily Challenge's
#                                         date-seeded generation), which no
#                                         other variant needs.
#   sudokukiller/base_board_widget.lua -- "single-cell cages as given values;
#                                         dashed 3x3 borders" rendering for
#                                         cage-sum clues.
#   betweenlines/base_board.lua        -- between-lines marker support.
#   betweenlines/base_screen.lua       -- between-lines marker support.
#   betweenlines/puzzle_generator.lua  -- generator for the between-lines
#                                         constraint, not expressible via the
#                                         canonical generator's extra_regions.
KNOWN_DIVERGENCES=(
  "sudoku:puzzle_generator.lua"
  "sudoku:base_board_widget.lua"
  "sudoku:base_screen.lua"
  "sudokukiller:base_board_widget.lua"
  "betweenlines:base_board.lua"
  "betweenlines:base_screen.lua"
  "betweenlines:puzzle_generator.lua"
)

# betweenlines vendors sudoku_grid_utils.lua under a different local
# filename (grid_utils.lua) -- content-identical as of this writing, just a
# naming difference, not tracked as a divergence.
local_filename() {
  local plugin="$1" canon_file="$2"
  if [[ "$plugin" == "betweenlines" && "$canon_file" == "sudoku_grid_utils.lua" ]]; then
    echo "grid_utils.lua"
  else
    echo "$canon_file"
  fi
}

is_known_divergence() {
  local needle="$1:$2"
  local k
  for k in "${KNOWN_DIVERGENCES[@]}"; do
    [[ "$k" == "$needle" ]] && return 0
  done
  return 1
}

clean=()
known=()
unexpected=()
missing=()

for plugin in "${PLUGINS[@]}"; do
  dir="$ROOT/$plugin.koplugin/common"
  if [ ! -d "$dir" ]; then
    missing+=("$plugin (no common/ dir)")
    continue
  fi
  for f in "${FILES[@]}"; do
    local_name="$(local_filename "$plugin" "$f")"
    local_path="$dir/$local_name"
    canon_path="$CANON/$f"

    if [ ! -f "$local_path" ]; then
      missing+=("$plugin/$local_name (expected, not found)")
      continue
    fi

    if cmp -s "$canon_path" "$local_path"; then
      clean+=("$plugin/$local_name")
      continue
    fi

    if is_known_divergence "$plugin" "$f"; then
      known+=("$plugin/$local_name")
    elif [[ "$plugin:$f" == "windoku:puzzle_generator.lua" ]]; then
      unexpected+=("$plugin/$local_name  <-- looks like a missing extra_regions feature, not an intentional fork; investigate before allowlisting")
    else
      unexpected+=("$plugin/$local_name")
    fi
  done
done

echo "=== sudoku-common drift check ==="
echo ""
printf "Clean (%d):\n" "${#clean[@]}"
for x in "${clean[@]:-}"; do [[ -n "$x" ]] && echo "  $x"; done
echo ""
printf "Known-intentional divergence (%d):\n" "${#known[@]}"
for x in "${known[@]:-}"; do [[ -n "$x" ]] && echo "  $x"; done
echo ""
printf "Missing (%d):\n" "${#missing[@]}"
for x in "${missing[@]:-}"; do [[ -n "$x" ]] && echo "  $x"; done
echo ""
printf "UNEXPECTED DRIFT (%d):\n" "${#unexpected[@]}"
for x in "${unexpected[@]:-}"; do [[ -n "$x" ]] && echo "  $x"; done
echo ""

if [ "${#unexpected[@]}" -gt 0 ] || [ "${#missing[@]}" -gt 0 ]; then
  echo "FAIL: unexpected drift or missing files detected."
  exit 1
fi

echo "OK: no unexpected drift."
exit 0
