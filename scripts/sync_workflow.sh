#!/usr/bin/env bash
# Sync the release workflow template to every plugin submodule.
# Usage:
#   ./sync_workflow.sh            # sync all submodules
#   ./sync_workflow.sh --dry-run  # preview without pushing

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$ROOT/.github/workflows/release-plugin.yml"
DRY="${1:-}"

if [ ! -f "$TEMPLATE" ]; then
  echo "Error: template not found: $TEMPLATE" >&2; exit 1
fi

synced=()
skipped=()
failed=()

sync_plugin() {
  local dir="$1"
  local full="$ROOT/$dir"

  [ -d "$full/.github/workflows" ] || { skipped+=("$dir (no .github/workflows)"); return; }

  local target="$full/.github/workflows/release.yml"

  # Check if update is needed
  if cmp -s "$TEMPLATE" "$target" 2>/dev/null; then
    skipped+=("$dir (up to date)")
    return
  fi

  echo "  Syncing: $dir"

  if [[ "$DRY" == "--dry-run" ]]; then
    synced+=("$dir (dry-run)")
    return
  fi

  cp "$TEMPLATE" "$target"

  local branch
  branch=$(git -C "$full" rev-parse --abbrev-ref HEAD)

  git -C "$full" add .github/workflows/release.yml
  if ! git -C "$full" diff --cached --quiet; then
    git -C "$full" commit -m "ci: add GHCR package publishing to release workflow"
    git -C "$full" push origin "HEAD:${branch}" && synced+=("$dir") || failed+=("$dir (push failed)")
  else
    skipped+=("$dir (no change after copy)")
  fi
}

echo "Syncing release workflow to all plugin submodules..."
echo ""

while IFS= read -r dir; do
  [[ "$dir" == "game-common" || "$dir" == "sudoku-common" ]] && continue
  sync_plugin "$dir" || failed+=("$dir (error)")
done < <(git -C "$ROOT" submodule status | awk '{print $2}')

echo ""
echo "=== Summary ==="
printf "Synced  (%d):\n" "${#synced[@]}"
for x in "${synced[@]:-}"; do [[ -n "$x" ]] && echo "  $x"; done
printf "Skipped (%d):\n" "${#skipped[@]}"
for x in "${skipped[@]:-}"; do [[ -n "$x" ]] && echo "  $x"; done
printf "Failed  (%d):\n" "${#failed[@]}"
for x in "${failed[@]:-}"; do [[ -n "$x" ]] && echo "  $x"; done
