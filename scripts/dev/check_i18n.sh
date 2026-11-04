#!/usr/bin/env bash
# Report English keys translated differently by two plugins (they all share
# one i18n slot at runtime, so the last one loaded wins on the device).
#   scripts/dev/check_i18n.sh            # exit 1 on any conflict
# Checks game-common/i18n.lua + every *.koplugin/i18n_fr.lua except the
# set-aside plugins and _skeleton. Runs with the emulator's LuaJIT (any
# LuaJIT/Lua 5.1 works: set LUAJIT to override).
# Env: REPO, KOREADER_EMU, LUAJIT.
set -euo pipefail
DEV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${REPO:-$(cd "$DEV_DIR/../.." && pwd -P)}"
# Default: a KOReader checkout next to this monorepo, with a built emulator
# (make emulator) -- koreader/koreader-emulator-<arch>/koreader.
if [ -z "${KOREADER_EMU:-}" ]; then
  KOREADER_EMU="$(ls -d "$REPO"/../koreader/koreader-emulator-*/koreader 2>/dev/null | head -1)"
fi
LUAJIT="${LUAJIT:-$KOREADER_EMU/luajit}"
SKIP=" kakuro arrowwords startmenu boggleparty doubleornothing _skeleton "
command -v "$LUAJIT" >/dev/null 2>&1 || [[ -x "$LUAJIT" ]] || {
  echo "error: no LuaJIT at $LUAJIT (set KOREADER_EMU or LUAJIT)" >&2; exit 2; }
files=("$REPO/game-common/i18n.lua")
for f in "$REPO"/*.koplugin/i18n_fr.lua; do
  id="$(basename "$(dirname "$f")" .koplugin)"
  [[ "$SKIP" == *" $id "* ]] && continue
  files+=("$f")
done
cd "$REPO"
# relative paths keep the report readable
rel=()
for f in "${files[@]}"; do rel+=("${f#"$REPO"/}"); done
"$LUAJIT" "$DEV_DIR/i18n_conflicts.lua" "${rel[@]}"
