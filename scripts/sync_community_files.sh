#!/usr/bin/env bash
# Sync issue/PR templates + CONTRIBUTING.md to every plugin submodule.
# Source of truth: templates/plugin-repo/ (mirrors how sync_workflow.sh
# treats .github/workflows/release-plugin.yml as a template, not a file
# this monorepo itself uses).
# Usage:
#   ./sync_community_files.sh                    # sync all submodules
#   ./sync_community_files.sh --dry-run          # preview without pushing
#   COMMIT_MSG="..." ./sync_community_files.sh   # override the commit message

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE_DIR="$ROOT/templates/plugin-repo"
DRY="${1:-}"
COMMIT_MSG="${COMMIT_MSG:-docs: add issue/PR templates and CONTRIBUTING.md}"

# path-in-template -> path-in-target (identical here, kept explicit in case
# a future file needs to land somewhere else)
FILES=(
  "CONTRIBUTING.md:CONTRIBUTING.md"
  ".github/ISSUE_TEMPLATE/bug_report.md:.github/ISSUE_TEMPLATE/bug_report.md"
  ".github/ISSUE_TEMPLATE/feature_request.md:.github/ISSUE_TEMPLATE/feature_request.md"
  ".github/PULL_REQUEST_TEMPLATE.md:.github/PULL_REQUEST_TEMPLATE.md"
)

# Set aside / not ours to push to.
EXCLUDE=("_skeleton.koplugin" "game-common" "sudoku-common" "checkers.koplugin" \
         "kakuro.koplugin" "galaxies.koplugin" "arrowwords.koplugin")

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "Error: template dir not found: $TEMPLATE_DIR" >&2; exit 1
fi

is_excluded() {
  local dir="$1"
  for x in "${EXCLUDE[@]}"; do [[ "$dir" == "$x" ]] && return 0; done
  return 1
}

synced=()
skipped=()
failed=()

sync_plugin() {
  local dir="$1"
  local full="$ROOT/$dir"
  local changed=0

  for pair in "${FILES[@]}"; do
    local src="$TEMPLATE_DIR/${pair%%:*}"
    local rel="${pair##*:}"
    local target="$full/$rel"
    mkdir -p "$(dirname "$target")"
    if ! cmp -s "$src" "$target" 2>/dev/null; then
      changed=1
      [[ "$DRY" == "--dry-run" ]] || cp "$src" "$target"
    fi
  done

  if [ "$changed" -eq 0 ]; then
    skipped+=("$dir (up to date)")
    return
  fi

  echo "  Syncing: $dir"
  if [[ "$DRY" == "--dry-run" ]]; then
    synced+=("$dir (dry-run)")
    return
  fi

  for pair in "${FILES[@]}"; do
    git -C "$full" add "${pair##*:}"
  done

  local branch
  branch=$(git -C "$full" rev-parse --abbrev-ref HEAD)

  if ! git -C "$full" diff --cached --quiet; then
    git -C "$full" commit -m "$COMMIT_MSG"
    git -C "$full" push origin "HEAD:${branch}" && synced+=("$dir") || failed+=("$dir (push failed)")
  else
    skipped+=("$dir (no change after copy)")
  fi
}

echo "Syncing community files to all plugin submodules..."
echo ""

while IFS= read -r dir; do
  is_excluded "$dir" && continue
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
