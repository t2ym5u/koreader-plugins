#!/usr/bin/env bash
# Run the busted specs of plugins / shared libs, one summary line per dir.
#
#   scripts/dev/run_specs.sh 2048 sudokux game-common   # named dirs (.koplugin optional)
#   scripts/dev/run_specs.sh --changed                  # submodules with uncommitted changes
#   scripts/dev/run_specs.sh --all                      # every *.koplugin + game-common + sudoku-common
#   SPECS=test_difficulty_spec.lua scripts/dev/run_specs.sh --all   # only the difficulty specs
#
# Each dir runs `busted test_*_spec.lua` from inside that dir, with the `bit`
# shim on LUA_PATH (Homebrew busted is Lua 5.5, which has no `bit`; without
# the shim sudoku specs error out while busted still exits 0).
# Exit status: non-zero if any dir had a failure/error, or if busted printed
# no "N successes / ..." summary line (= it crashed before running).
# Env: REPO (monorepo root), BUSTED (default busted), VERBOSE=1 prints the
#      full busted output of failing dirs, SPECS a glob of spec files to run
#      instead of test_*_spec.lua (dirs without a match print "(no specs)").
set -uo pipefail
DEV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${REPO:-$(cd "$DEV_DIR/../.." && pwd -P)}"
BUSTED="${BUSTED:-busted}"
SPECS="${SPECS:-test_*_spec.lua}"
SKIP=" kakuro arrowwords startmenu boggleparty doubleornothing _skeleton "

usage() { sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
[[ $# -ge 1 ]] || usage

dirs=()
case "$1" in
  -h|--help) usage ;;
  --changed)
    while IFS= read -r name; do
      [[ -n "$name" ]] || continue
      id="${name%.koplugin}"
      [[ "$SKIP" == *" $id "* ]] && continue
      dirs+=("$name")
    done < <(git -C "$REPO" submodule foreach --quiet \
               'if [ -n "$(git status --porcelain)" ]; then echo "$name"; fi')
    ;;
  --all)
    for d in "$REPO"/*.koplugin; do
      n="$(basename "$d")"; id="${n%.koplugin}"
      [[ "$SKIP" == *" $id "* ]] && continue
      dirs+=("$n")
    done
    dirs+=("game-common" "sudoku-common")
    ;;
  *)
    for p in "$@"; do
      if [[ -d "$REPO/$p" ]]; then dirs+=("$p")
      elif [[ -d "$REPO/$p.koplugin" ]]; then dirs+=("$p.koplugin")
      else echo "$p: NO SUCH DIR"; dirs+=("!$p"); fi
    done
    ;;
esac

[[ ${#dirs[@]} -gt 0 ]] || { echo "(nothing to run)"; exit 0; }

bad=0
shopt -s nullglob
for d in "${dirs[@]}"; do
  if [[ "$d" == !* ]]; then bad=1; continue; fi
  label="${d%.koplugin}"
  specs=()
  for f in "$REPO/$d"/$SPECS; do [[ -f "$f" ]] && specs+=("$f"); done
  if [[ ${#specs[@]} -eq 0 ]]; then
    printf '%-18s (no specs)\n' "$label:"; continue
  fi
  out="$(cd "$REPO/$d" && LUA_PATH="$DEV_DIR/bitshim/?.lua;;" "$BUSTED" $SPECS 2>&1)"
  summary="$(printf '%s\n' "$out" | grep -E '^[0-9]+ success' | tail -1)"
  status=OK
  if [[ -z "$summary" ]]; then
    status="NO SUMMARY (busted crashed?)"; summary="$(printf '%s\n' "$out" | tail -3 | tr '\n' ' ')"
  else
    f="$(printf '%s' "$summary" | sed -nE 's/.* ([0-9]+) failures?.*/\1/p')"
    e="$(printf '%s' "$summary" | sed -nE 's/.* ([0-9]+) errors?.*/\1/p')"
    [[ "${f:-0}" != 0 || "${e:-0}" != 0 ]] && status=FAIL
  fi
  printf '%-18s %-4s %s\n' "$label:" "$status" "$summary"
  if [[ "$status" != OK ]]; then
    bad=1
    [[ -n "${VERBOSE:-}" ]] && printf '%s\n' "$out" | sed 's/^/    /'
  fi
done
exit "$bad"
