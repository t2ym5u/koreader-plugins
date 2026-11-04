#!/usr/bin/env bash
# Run a scripts/dev Lua tool with the KOReader emulator's LuaJIT, from the
# emulator dir (required: setupkoenv.lua, frontend/, plugins/ are relative).
#   scripts/dev/kolua.sh render_screen.lua 2048 /tmp/2048.png 758 1024
# Env: KOREADER_EMU (emulator dir), REPO, WORK (see README.md), KOLUA_RAW=1.
set -euo pipefail
DEV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO="${REPO:-$(cd "$DEV_DIR/../.." && pwd -P)}"
_tmp="${TMPDIR:-/tmp}"
export WORK="${WORK:-${_tmp%/}/koplugins-dev}"
# Default: a KOReader checkout next to this monorepo, with a built emulator
# (make emulator) -- koreader/koreader-emulator-<arch>/koreader.
if [ -z "${KOREADER_EMU:-}" ]; then
  KOREADER_EMU="$(ls -d "$REPO"/../koreader/koreader-emulator-*/koreader 2>/dev/null | head -1)"
fi
[[ $# -ge 1 ]] || { echo "usage: $0 <tool.lua> [args...]" >&2; exit 2; }
tool="$1"; shift
[[ -f "$tool" ]] || tool="$DEV_DIR/$tool"
[[ -x "$KOREADER_EMU/luajit" ]] || { echo "error: no luajit in KOREADER_EMU=$KOREADER_EMU" >&2; exit 2; }
tool="$(cd "$(dirname "$tool")" && pwd)/$(basename "$tool")"
mkdir -p "$WORK"
cd "$KOREADER_EMU"
# The debug emulator build logs every ffi.load to stdout: drop those lines
# (KOLUA_RAW=1 keeps them). pipefail keeps luajit's exit status.
if [[ -n "${KOLUA_RAW:-}" ]]; then exec ./luajit "$tool" "$@"; fi
./luajit "$tool" "$@" | { grep -v -E '^(ffi\.(findlib|load):|lib_(search_path|basic_format|version_format):|has monolibtic\?)' || true; }
