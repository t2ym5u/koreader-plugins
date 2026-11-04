#!/usr/bin/env bash
# Install REAL copies (no symlinks) of some plugins into a scratch KOReader
# env and open every game through Tools -> Games, Tools entries, Dashboard
# launchGame and the Daily Challenge (realinstall_test.lua, headless).
#
#   scripts/dev/realinstall_test.sh [options] [plugin...]
#     --source zip     install from dist/<id>.zip (default; run build_release.sh first)
#     --source tree    install from the working tree (common/ dereferenced)
#     --stale DIR      also install every *.koplugin found in DIR (e.g. made by
#                      make_stale_plugin.sh) as a separate extra plugin path
#     --stale gen      generate the default stale plugin (arrowwords v1.2.11 +
#                      game-common v1.6.0) with make_stale_plugin.sh
#     --stale-first    put the stale path BEFORE the real one (default after)
#     --lang L         UI language (default fr)
#     --tag NAME       run label: env dir $WORK/realinstall/NAME, PNG prefix
#   default plugins: 2048 converter quickcalc trafficjam dashboard wordle
#                    sudoku sudokux quiz hangman minesweeper
# Env: REPO, KOREADER_EMU, WORK, TRACE=1 (tracebacks), ROUNDS (default 2).
# Exit 1 if any open failed.
set -euo pipefail
DEV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${REPO:-$(cd "$DEV_DIR/../.." && pwd -P)}"
_tmp="${TMPDIR:-/tmp}"; WORK="${WORK:-${_tmp%/}/koplugins-dev}"
SOURCE=zip STALE="" STALE_FIRST="" LANG2=fr TAG=""
plugins=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --stale) STALE="$2"; shift 2 ;;
    --stale-first) STALE_FIRST=1; shift ;;
    --lang) LANG2="$2"; shift 2 ;;
    --tag) TAG="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "unknown option $1" >&2; exit 2 ;;
    *) plugins+=("$1"); shift ;;
  esac
done
[[ ${#plugins[@]} -gt 0 ]] || plugins=(2048 converter quickcalc trafficjam dashboard wordle sudoku sudokux quiz hangman minesweeper)
[[ "$SOURCE" == zip || "$SOURCE" == tree ]] || { echo "--source zip|tree" >&2; exit 2; }
TAG="${TAG:-$SOURCE${STALE:+_stale}${STALE_FIRST:+first}}"
ENV="$WORK/realinstall/$TAG"
rm -rf "$ENV"; mkdir -p "$ENV/real"

for p in "${plugins[@]}"; do
  if [[ "$SOURCE" == zip ]]; then
    z="$REPO/dist/$p.zip"
    [[ -f "$z" ]] || { echo "error: $z missing (scripts/build_release.sh $p)" >&2; exit 1; }
    mkdir -p "$ENV/unz/$p"
    unzip -q -o "$z" -d "$ENV/unz/$p"
    mv "$ENV/unz/$p/$p.koplugin" "$ENV/real/"
  else
    [[ -d "$REPO/$p.koplugin" ]] || { echo "error: no $p.koplugin" >&2; exit 1; }
    rsync -aL --exclude .git --exclude .github --exclude 'test_*' --exclude '*.md' \
      --exclude LICENSE --exclude .busted "$REPO/$p.koplugin/" "$ENV/real/$p.koplugin/"
  fi
done
rm -rf "$ENV/unz"

paths="$ENV/real"
if [[ -n "$STALE" ]]; then
  mkdir -p "$ENV/stale"
  if [[ "$STALE" == gen ]]; then
    "$DEV_DIR/make_stale_plugin.sh" "$ENV/stale"
  else
    found=0
    for d in "$STALE"/*.koplugin; do [[ -d "$d" ]] && cp -R "$d" "$ENV/stale/" && found=1; done
    [[ $found == 1 ]] || { echo "error: no *.koplugin in $STALE" >&2; exit 1; }
  fi
  if [[ -n "$STALE_FIRST" ]]; then paths="$ENV/stale:$ENV/real"; else paths="$ENV/real:$ENV/stale"; fi
fi
links="$(find "$ENV" -type l | head -3)"
[[ -z "$links" ]] || { echo "error: symlinks in the install:" >&2; echo "$links" >&2; exit 1; }
echo "installed ${#plugins[@]} plugins ($SOURCE) into $ENV; PATHS=$paths"
ENV="$ENV" PATHS="$paths" LANG2="$LANG2" TAG="$TAG" \
  "$DEV_DIR/kolua.sh" realinstall_test.lua 2> "$ENV/stderr.log"
