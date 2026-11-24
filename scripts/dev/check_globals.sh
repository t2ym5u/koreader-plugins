#!/usr/bin/env bash
# Every global a plugin or shared lib reads or writes, from LuaJIT bytecode
# (GGET/GSET), against the names Lua, LuaJIT and KOReader really provide.
# Catches a misspelt local ("bord" for "board") read as an always-nil global,
# and a forgotten `local` leaking a global into every other plugin.
#
#   scripts/dev/check_globals.sh            # all released plugins + both libs
#   scripts/dev/check_globals.sh 2048 hex   # some dirs (.koplugin optional)
#
# Specs and test_*.lua scripts, dev/generator scripts (gen/, tools/) and common/ symlinks are
# skipped. Exit status 1 when an unknown global is found. A name that is
# meant to be global goes into ALLOWED below, with the reason.
set -uo pipefail
export LC_ALL=C   # bytecode listings hold raw bytes of non-ASCII strings
DEV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${REPO:-$(cd "$DEV_DIR/../.." && pwd -P)}"
LUAJIT="${LUAJIT:-luajit}"
SKIP=" kakuro arrowwords startmenu boggleparty doubleornothing chesscourse _skeleton "

# Lua 5.1 / LuaJIT
ALLOWED=" _G _VERSION assert collectgarbage coroutine debug dofile error getfenv
getmetatable io ipairs load loadfile loadstring math module next os package
pairs pcall print rawequal rawget rawlen rawset require select setfenv
setmetatable string table tonumber tostring type unpack xpcall bit jit
"
# KOReader
ALLOWED+=" G_reader_settings G_defaults "
# pluginmanager: parse_json is shared with manager.lua on purpose (main.lua).
ALLOWED+=" parse_json "

dirs=()
if [[ $# -eq 0 ]]; then
  for d in "$REPO"/*.koplugin; do
    n="$(basename "$d")"; id="${n%.koplugin}"
    [[ "$SKIP" == *" $id "* ]] && continue
    dirs+=("$n")
  done
  dirs+=("game-common" "sudoku-common")
else
  for p in "$@"; do
    if [[ -d "$REPO/$p" ]]; then dirs+=("$p"); else dirs+=("$p.koplugin"); fi
  done
fi

bad=0
for d in "${dirs[@]}"; do
  while IFS= read -r f; do
    while IFS= read -r line; do
      op="${line%% *}"; name="${line#* }"
      [[ "$ALLOWED" == *[[:space:]]"$name"[[:space:]]* ]] && continue
      printf '%s: %s %s\n' "${f#"$REPO"/}" "$op" "$name"
      bad=1
    done < <("$LUAJIT" -bl "$f" 2>/dev/null \
               | sed -nE 's/.*(GGET|GSET) .*; "([^"]+)".*/\1 \2/p' | sort -u)
  done < <(find "$REPO/$d" -name '*.lua' -not -name 'test_*.lua' -not -name '*_spec.lua' \
             -not -path '*/common/*' -not -path '*/spec/*' -not -path '*/gen/*' \
             -not -path '*/tools/*' -not -path '*/data/*' | sort)
done
[[ $bad -eq 0 ]] && echo "globals: OK (${#dirs[@]} dirs)"
exit "$bad"
