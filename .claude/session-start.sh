#!/usr/bin/env bash
# Project additions to agent-kit's session start (after HANDOFF.md and git status).
# Read-only, fast, never fails: its output goes into the agent's context.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Archived submodules: a change there cannot be pushed without unarchiving.
dirty="$(git -C "$ROOT" status --porcelain=v1 -- arrowwords.koplugin kakuro.koplugin 2>/dev/null | cut -c4- | paste -sd ' ' -)"
[ -n "$dirty" ] && echo "- Archived plugin modified: $dirty (push it via unarchive/archive before moving its pointer, docs/dev/PITFALLS.md)"

# Shared libraries ahead of manifest.json: a fleet bump is needed before the next release.
libs="$("$ROOT/scripts/check_shared_libs.sh" 2>/dev/null)" || {
  printf '\n### Shared libraries ahead of manifest.json\n\n%s\n' "$libs"
}
exit 0
