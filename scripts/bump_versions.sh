#!/usr/bin/env bash
# Bump version in every plugin submodule, commit, tag and push.
# Usage: ./bump_versions.sh [--dry-run]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DRY="${1:-}"

failed=()
skipped=()
bumped=()

# Python helper: reads _meta.lua, returns "cur|new|tag|mode" or "skip:<reason>"
# mode = bump (replace existing) | add (insert new field)
parse_version() {
    local meta="$1"
    python3 - "$meta" <<'PYEOF'
import re, sys
src = open(sys.argv[1]).read()

# Try quoted string first
m = re.search(r'version\s*=\s*"([^"]+)"', src)
if m:
    cur = m.group(1)
    parts = [int(x) for x in cur.split('.')]
    while len(parts) < 3:
        parts.append(0)
    parts[-1] += 1
    new = '.'.join(str(x) for x in parts)
    print(f"{cur}|{new}|v{new}|bump")
    sys.exit(0)

# Try integer
m = re.search(r'version\s*=\s*(\d+)\b', src)
if m:
    cur = m.group(1)
    print(f"{cur}|1.0.1|v1.0.1|bump")
    sys.exit(0)

# No version at all — need to add it
# Check that this looks like a valid _meta.lua (has an id field)
if re.search(r'id\s*=\s*"[^"]+"', src):
    print(f"none|1.0.1|v1.0.1|add")
    sys.exit(0)

print("skip:no version and no id field")
PYEOF
}

# Python helper: replace or add version in _meta.lua in-place
apply_version() {
    local meta="$1" cur="$2" new="$3" mode="$4"
    python3 - "$meta" "$cur" "$new" "$mode" <<'PYEOF'
import re, sys
meta, cur, new, mode = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
src = open(meta).read()

if mode == "bump":
    # Replace quoted string version
    out = re.sub(
        r'(version\s*=\s*)"' + re.escape(cur) + r'"',
        r'\g<1>"' + new + '"',
        src
    )
    # Replace integer version (only if quoted replacement didn't fire)
    if out == src:
        out = re.sub(
            r'(version\s*=\s*)' + re.escape(cur) + r'\b',
            r'\g<1>"' + new + '"',
            src
        )
elif mode == "add":
    # Insert version after the description line (or after id if no description)
    out = re.sub(
        r'((?:description|id)\s*=\s*(?:_\()?(?:"[^"]*"|\[\[[^\]]*\]\])\)?),?\s*\n',
        lambda m: m.group(0).rstrip(',\n').rstrip() + ',\n    version     = "' + new + '",\n',
        src,
        count=1
    )

if out == src:
    print(f"ERROR: no replacement made in {meta}", file=__import__('sys').stderr)
    sys.exit(1)

open(meta, 'w').write(out)
PYEOF
}

bump_plugin() {
    local dir="$1"
    local full="$ROOT/$dir"
    local meta="$full/_meta.lua"

    [[ -f "$meta" ]] || { skipped+=("$dir (no _meta.lua)"); return; }

    local result
    result=$(parse_version "$meta")

    if [[ "$result" == skip:* ]]; then
        skipped+=("$dir (${result#skip:})")
        return
    fi

    local cur new_ver tag mode
    IFS='|' read -r cur new_ver tag mode <<< "$result"

    # Check if tag already exists in the submodule
    if git -C "$full" tag -l "$tag" | grep -q "^${tag}$" 2>/dev/null; then
        skipped+=("$dir (tag $tag already exists)")
        return
    fi

    if [[ "$mode" == "add" ]]; then
        echo "  $dir: (none) → $new_ver [add]"
    else
        echo "  $dir: $cur → $new_ver"
    fi

    if [[ "$DRY" == "--dry-run" ]]; then
        bumped+=("$dir ($cur → $new_ver)")
        return
    fi

    apply_version "$meta" "$cur" "$new_ver" "$mode"

    # Verify
    if ! grep -q "\"${new_ver}\"" "$meta"; then
        echo "    ERROR: version not found after edit in $dir" >&2
        git -C "$full" checkout -- _meta.lua
        failed+=("$dir (edit verification failed)")
        return
    fi

    local branch
    branch=$(git -C "$full" rev-parse --abbrev-ref HEAD)

    git -C "$full" add _meta.lua
    git -C "$full" commit -m "chore: bump version to ${new_ver}"
    git -C "$full" tag "$tag"
    git -C "$full" push origin "HEAD:${branch}"
    git -C "$full" push origin "$tag"

    bumped+=("$dir ($cur → $new_ver)")
}

echo "Bumping plugin versions in $ROOT"
echo ""

while IFS= read -r dir; do
    [[ "$dir" == "game-common" || "$dir" == "sudoku-common" ]] && continue
    bump_plugin "$dir"
done < <(git -C "$ROOT" submodule status | awk '{print $2}')

echo ""
echo "=== Summary ==="
printf "Bumped  (%d):\n" "${#bumped[@]}"
for x in "${bumped[@]:-}"; do [[ -n "$x" ]] && echo "  $x"; done
printf "Skipped (%d):\n" "${#skipped[@]}"
for x in "${skipped[@]:-}"; do [[ -n "$x" ]] && echo "  $x"; done
printf "Failed  (%d):\n" "${#failed[@]}"
for x in "${failed[@]:-}"; do [[ -n "$x" ]] && echo "  $x"; done
echo ""

if [[ "$DRY" != "--dry-run" && ${#bumped[@]} -gt 0 ]]; then
    echo "Updating parent repo submodule references..."
    git -C "$ROOT" add $(git -C "$ROOT" submodule status | awk '{print $2}')
    git -C "$ROOT" commit -m "chore: bump plugin versions across the fleet (${#bumped[@]} plugins)"
    echo ""
    echo "Rebuilding manifest and dist..."
    python3 "$ROOT/.github/scripts/update_manifest.py"
    bash "$ROOT/scripts/build_release.sh"
    git -C "$ROOT" add manifest.json dist/
    git -C "$ROOT" commit -m "chore: regenerate manifest + rebuild dist after version bump"
fi
