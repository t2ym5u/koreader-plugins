#!/usr/bin/env bash
# Onboard a new plugin: create its GitHub repo, push the initial content,
# register it as a submodule of this monorepo, wire up its release CI, and
# regenerate manifest.json.
#
# Usage:
#   ./scripts/new_plugin.sh <name>
#
# Prerequisites:
#   - <name>.koplugin/ must already exist at the monorepo root as a PLAIN
#     directory (not a submodule) containing the finished plugin: at minimum
#     _meta.lua, main.lua, board.lua, board_widget.lua, screen.lua, and a
#     `common` symlink to ../game-common (see othello.koplugin/ or
#     memory.koplugin/ for reference structure).
#   - `gh` must be authenticated (`gh auth status`) with repo/workflow scopes.
#
# What this script does NOT do (still manual, on purpose):
#   - Write the game itself.
#   - Add `raw_base_url` to the new manifest.json entry (update_manifest.py
#     never sets it -- see project memory on the manifest raw_base_url pitfall).
#   - Update docs/README.md's plugin table.
#   - Cut the plugin's first GitHub release (run
#     `.github/scripts/setup_releases.py --releases-only` once it's in
#     manifest.json, or just push a version bump later).
#
# This performs real, hard-to-reverse actions (creates a public GitHub repo,
# pushes commits, rewrites .gitmodules) -- review the printed plan before
# confirming.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME="${1:-}"
OWNER="t2ym5u"

if [ -z "$NAME" ]; then
  echo "Usage: $0 <name>" >&2
  exit 1
fi

PLUGIN_DIR="$ROOT/${NAME}.koplugin"
REPO="${OWNER}/${NAME}.koplugin"
REMOTE_URL="https://github.com/${REPO}.git"

if [ ! -d "$PLUGIN_DIR" ]; then
  echo "Error: $PLUGIN_DIR does not exist. Create the plugin locally first." >&2
  exit 1
fi

if [ -f "$ROOT/.gitmodules" ] && grep -q "\"${NAME}.koplugin\"" "$ROOT/.gitmodules"; then
  echo "Error: ${NAME}.koplugin is already registered in .gitmodules." >&2
  exit 1
fi

if [ -d "$PLUGIN_DIR/.git" ]; then
  echo "Error: $PLUGIN_DIR already has its own .git -- looks already onboarded." >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: gh CLI not found." >&2
  exit 1
fi
gh auth status >/dev/null 2>&1 || { echo "Error: gh is not authenticated (run: gh auth login)." >&2; exit 1; }

for required in _meta.lua main.lua board.lua; do
  if [ ! -f "$PLUGIN_DIR/$required" ]; then
    echo "Error: $PLUGIN_DIR/$required is missing -- plugin looks incomplete." >&2
    exit 1
  fi
done

echo "=== new_plugin.sh: ${NAME}.koplugin ==="
echo "  Repo to create : $REPO"
echo "  Local dir      : $PLUGIN_DIR"
echo ""
read -r -p "Create this public GitHub repo and push? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted."
  exit 1
fi

if gh repo view "$REPO" >/dev/null 2>&1; then
  echo "Error: $REPO already exists on GitHub." >&2
  exit 1
fi

echo "Creating GitHub repo..."
gh repo create "$REPO" --public --description "KOReader plugin: ${NAME}"

echo "Wiring up release CI..."
mkdir -p "$PLUGIN_DIR/.github/workflows"
cp "$ROOT/.github/workflows/release-plugin.yml" "$PLUGIN_DIR/.github/workflows/release.yml"

echo "Pushing initial content..."
git -C "$PLUGIN_DIR" init -b main
git -C "$PLUGIN_DIR" add .
git -C "$PLUGIN_DIR" commit -m "Initial commit"
git -C "$PLUGIN_DIR" remote add origin "$REMOTE_URL"
git -C "$PLUGIN_DIR" push -u origin main

echo "Registering as a submodule of the monorepo..."
rm -rf "$PLUGIN_DIR/.git"
rm -rf "$PLUGIN_DIR"
git -C "$ROOT" submodule add -b main "$REMOTE_URL" "${NAME}.koplugin"
git -C "$ROOT" submodule update --init "${NAME}.koplugin"

echo "Regenerating manifest.json..."
python3 "$ROOT/.github/scripts/update_manifest.py"

cat <<EOF

=== Done ===
${NAME}.koplugin is now a submodule of the monorepo and pushed to
https://github.com/${REPO}

Remaining manual steps:
  1. Add "raw_base_url": "https://raw.githubusercontent.com/${REPO}/main/"
     to its entry in manifest.json (update_manifest.py never sets this).
  2. Add ${NAME}.koplugin to docs/README.md's plugin table.
  3. Review + commit the .gitmodules / manifest.json changes here in the
     monorepo (not done automatically by this script).
  4. Run ./scripts/build_release.sh ${NAME} once ready to cut a release.
EOF
