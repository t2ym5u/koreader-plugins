#!/usr/bin/env bash
# Run the busted specs of plugins / shared libs, one summary line per dir.
#
#   scripts/dev/run_specs.sh 2048 sudokux game-common   # named dirs (.koplugin optional)
#   scripts/dev/run_specs.sh --changed                  # submodules with uncommitted changes
#   scripts/dev/run_specs.sh --all                      # every *.koplugin + game-common + sudoku-common
#   SPECS=test_difficulty_spec.lua scripts/dev/run_specs.sh --all   # only the difficulty specs
#   JOBS=1 scripts/dev/run_specs.sh --all               # one dir at a time
#
# Each dir runs `busted test_*_spec.lua` from inside that dir, with the `bit`
# shim on LUA_PATH (Homebrew busted is Lua 5.5, which has no `bit`; without
# the shim sudoku specs error out while busted still exits 0).
# Exit status: non-zero if any dir had a failure/error, or if busted printed
# no "N successes / ..." summary line (= it crashed before running).
# Env: REPO (monorepo root), BUSTED (default busted), VERBOSE=1 prints the
#      full busted output of failing dirs, SPECS a glob of spec files to run
#      instead of test_*_spec.lua (dirs without a match print "(no specs)"),
#      JOBS how many dirs run at once (default: the CPU count; output stays
#      in the same order, printed once all are done).
set -uo pipefail
DEV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${REPO:-$(cd "$DEV_DIR/../.." && pwd -P)}"
BUSTED="${BUSTED:-busted}"
SPECS="${SPECS:-test_*_spec.lua}"
SKIP=" kakuro arrowwords startmenu boggleparty doubleornothing chesscourse _skeleton "
JOBS="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 1)}"

usage() { sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
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

# Run one dir; print its summary line (and, with VERBOSE, the failing output).
# Returns 1 on failure.
run_one() {
  local d="$1" label specs f e out summary status
  if [[ "$d" == !* ]]; then return 1; fi
  label="${d%.koplugin}"
  specs=()
  for f in "$REPO/$d"/$SPECS; do [[ -f "$f" ]] && specs+=("$f"); done
  if [[ ${#specs[@]} -eq 0 ]]; then
    printf '%-18s (no specs)\n' "$label:"; return 0
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
    [[ -n "${VERBOSE:-}" ]] && printf '%s\n' "$out" | sed 's/^/    /'
    return 1
  fi
  return 0
}

shopt -s nullglob
bad=0
if [[ "$JOBS" -le 1 || ${#dirs[@]} -eq 1 ]]; then
  for d in "${dirs[@]}"; do run_one "$d" || bad=1; done
  exit "$bad"
fi

# Parallel: each dir writes its own file, then they are printed in order.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
i=0; running=0
for d in "${dirs[@]}"; do
  i=$((i + 1))
  ( run_one "$d" > "$tmp/$i.out"; echo $? > "$tmp/$i.rc" ) &
  running=$((running + 1))
  if [[ $running -ge $JOBS ]]; then wait -n 2>/dev/null || wait; running=$((running - 1)); fi
done
wait
for ((k = 1; k <= i; k++)); do
  cat "$tmp/$k.out"
  [[ "$(cat "$tmp/$k.rc")" == 0 ]] || bad=1
done
exit "$bad"
