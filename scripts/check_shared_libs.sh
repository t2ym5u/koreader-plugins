#!/usr/bin/env bash
# Check whether game-common/sudoku-common have moved past what manifest.json
# records — i.e. whether a fleet-wide bump_versions.sh run is needed to
# cascade a fresh release to every consuming plugin's zip.
#
# Read-only: makes no changes, no commits, no pushes.
# Usage:
#   ./check_shared_libs.sh
#
# Exit code: 0 if everything is up to date, 1 if any lib has drifted.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT/manifest.json"

if [ ! -f "$MANIFEST" ]; then
  echo "Error: manifest.json not found" >&2; exit 1
fi

python3 - "$ROOT" "$MANIFEST" <<'PYEOF'
import json, subprocess, sys

root, manifest_path = sys.argv[1], sys.argv[2]
manifest = json.load(open(manifest_path))

def live_version(lib_dir):
    result = subprocess.run(
        ["git", "describe", "--tags"],
        capture_output=True, cwd=lib_dir, text=True,
    )
    if result.returncode != 0:
        return None
    return result.stdout.strip().lstrip("v")

drifted = False
for lib_key, dir_name in (("common", "game-common"), ("sudoku_common", "sudoku-common")):
    spec = manifest.get(lib_key)
    if not spec:
        continue
    recorded = spec.get("version")
    live = live_version(f"{root}/{dir_name}")
    if live is None:
        print(f"?  {dir_name}: could not read a git tag locally, skipping")
        continue
    if live == recorded:
        print(f"OK {dir_name}: {recorded} (up to date)")
        continue

    drifted = True
    consumers = [p["id"] for p in manifest["plugins"] if p.get("common_lib") == lib_key]
    print(f"!! {dir_name}: manifest has {recorded}, local tag is {live}")
    print(f"   {len(consumers)} plugin(s) affected: {', '.join(consumers)}")

print()
if drifted:
    print("Some shared libraries have moved past manifest.json.")
    print("Run scripts/bump_versions.sh to cascade a fresh release to every affected plugin.")
    sys.exit(1)
else:
    print("All shared libraries are up to date.")
PYEOF
