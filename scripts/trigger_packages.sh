#!/usr/bin/env bash
# Trigger workflow_dispatch on every plugin repo to publish GHCR packages
# for the current release (retroactive publishing).
# Requires: gh CLI authenticated, sync_workflow.sh already run.
# Usage:
#   ./trigger_packages.sh            # trigger all
#   ./trigger_packages.sh --dry-run  # preview without triggering

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DRY="${1:-}"

triggered=()
failed=()

trigger_plugin() {
  local dir="$1"
  local full="$ROOT/$dir"

  [ -f "$full/.github/workflows/release.yml" ] || return

  local repo
  repo=$(git -C "$full" remote get-url origin | sed 's|.*github.com[:/]\(.*\)\.git|\1|;s|.*github.com[:/]\(.*\)|\1|')

  local branch
  branch=$(git -C "$full" rev-parse --abbrev-ref HEAD)

  echo "  Triggering: $repo ($branch)"

  if [[ "$DRY" == "--dry-run" ]]; then
    triggered+=("$repo (dry-run)")
    return
  fi

  if gh workflow run release.yml --repo "$repo" --ref "$branch" 2>/dev/null; then
    triggered+=("$repo")
  else
    failed+=("$repo")
    echo "    WARNING: trigger failed for $repo" >&2
  fi

  # Avoid hitting GitHub API rate limits
  sleep 1
}

echo "Triggering workflow_dispatch on all plugin repos..."
echo ""

while IFS= read -r dir; do
  [[ "$dir" == "game-common" || "$dir" == "sudoku-common" ]] && continue
  trigger_plugin "$dir"
done < <(git -C "$ROOT" submodule status | awk '{print $2}')

echo ""
echo "=== Summary ==="
printf "Triggered (%d):\n" "${#triggered[@]}"
for x in "${triggered[@]:-}"; do [[ -n "$x" ]] && echo "  $x"; done
printf "Failed    (%d):\n" "${#failed[@]}"
for x in "${failed[@]:-}"; do [[ -n "$x" ]] && echo "  $x"; done
