#!/usr/bin/env bash
# Build an OLD release of a plugin from git, as a device would still have it
# installed: <out_dir>/<plugin>.koplugin with a real common/ dir holding an
# old shared library. Used by realinstall_test.sh --stale to check that an
# outdated plugin sharing the device can't break current ones.
#
#   scripts/dev/make_stale_plugin.sh <out_dir> [plugin] [plugin_tag] [lib] [lib_tag]
#   defaults: arrowwords v1.2.11 game-common v1.6.0
#   (arrowwords 1.2.11 shipped game-common before the module guard, ~1.6)
# Only *.lua files are kept (no specs, docs, .github), like a release zip.
set -euo pipefail
DEV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${REPO:-$(cd "$DEV_DIR/../.." && pwd -P)}"
[[ $# -ge 1 ]] || { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
OUT="$1"; P="${2:-arrowwords}"; PTAG="${3:-v1.2.11}"; LIB="${4:-game-common}"; LTAG="${5:-v1.6.0}"
src="$REPO/$P.koplugin"
[[ -d "$src" ]] || { echo "error: $src not checked out" >&2; exit 1; }
git -C "$src" rev-parse -q --verify "refs/tags/$PTAG" >/dev/null || { echo "error: no tag $PTAG in $P.koplugin" >&2; exit 1; }
git -C "$REPO/$LIB" rev-parse -q --verify "refs/tags/$LTAG" >/dev/null || { echo "error: no tag $LTAG in $LIB" >&2; exit 1; }
dst="$OUT/$P.koplugin"
rm -rf "$dst"; mkdir -p "$dst"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
git -C "$src" archive "$PTAG" | tar -x -C "$tmp"
find "$tmp" -maxdepth 1 -name '*.lua' ! -name 'test_*' -exec cp {} "$dst/" \;
shopt -s nullglob
for sub in "$tmp"/*/; do  # data subdirs (word lists...), not common/ (a symlink in git)
  n="$(basename "$sub")"; [[ "$n" == common || "$n" == .github ]] && continue
  [[ -L "${sub%/}" ]] && continue
  cp -R "$sub" "$dst/$n"
done
mkdir -p "$dst/common" "$tmp/lib"
git -C "$REPO/$LIB" archive "$LTAG" | tar -x -C "$tmp/lib"
find "$tmp/lib" -maxdepth 1 -name '*.lua' ! -name 'test_*' -exec cp {} "$dst/common/" \;
ver="$(sed -nE 's/.*version *= *"([^"]+)".*/\1/p' "$dst/_meta.lua" | head -1)"
echo "stale $P $ver ($PTAG) + $LIB $LTAG -> $dst ($(ls "$dst/common" | wc -l | tr -d ' ') common files)"
