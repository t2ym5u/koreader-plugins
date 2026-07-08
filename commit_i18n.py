#!/usr/bin/env python3
"""
Commit, tag and push the i18n feature across all submodules and the parent repo.
"""

import re
import subprocess
import sys
import os
import glob

ROOT = os.path.dirname(os.path.abspath(__file__))

def run(cmd, cwd=None, check=True):
    cwd = cwd or ROOT
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if check and r.returncode != 0:
        print(f"ERROR running {cmd}:\n{r.stderr}", file=sys.stderr)
        sys.exit(1)
    return r.stdout.strip(), r.stderr.strip()

def has_changes(repo_dir):
    out, _ = run(["git", "status", "--short"], cwd=repo_dir)
    return bool(out.strip())

def minor_bump(version_str):
    """1.0.1 -> 1.1.0, 2.0.1 -> 2.1.0, 1.0.0 -> 1.1.0"""
    parts = [int(x) for x in version_str.split(".")]
    while len(parts) < 3:
        parts.append(0)
    parts[1] += 1
    parts[2] = 0
    return ".".join(str(x) for x in parts)

def bump_meta(meta_path, new_ver):
    with open(meta_path) as f:
        src = f.read()
    out = re.sub(
        r'(version\s*=\s*)"([^"]+)"',
        lambda m: m.group(0).replace(m.group(2), new_ver),
        src,
    )
    if out == src:
        return False
    with open(meta_path, "w") as f:
        f.write(out)
    return True

def get_current_version(meta_path):
    with open(meta_path) as f:
        src = f.read()
    m = re.search(r'version\s*=\s*"([^"]+)"', src)
    return m.group(1) if m else None

def commit_all(repo_dir, msg):
    run(["git", "add", "-A"], cwd=repo_dir)
    run(["git", "commit", "-m", msg], cwd=repo_dir)

def tag_and_push(repo_dir, tag):
    branch, _ = run(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=repo_dir)
    run(["git", "tag", tag], cwd=repo_dir)
    run(["git", "push", "origin", f"HEAD:{branch}"], cwd=repo_dir)
    run(["git", "push", "origin", tag], cwd=repo_dir)

# ---------------------------------------------------------------------------
# 1. game-common
# ---------------------------------------------------------------------------
gc_dir = os.path.join(ROOT, "game-common")
print("=== game-common ===")
if has_changes(gc_dir):
    commit_all(gc_dir, "feat: add i18n module for FR/EN translation\n\n- New i18n.lua: 350+ translated strings, drop-in for gettext, extensible to any language\n- Switch all modules (screen_base, menu_helper, plugin_base, settings_dialog, undo_stack) to require(\"i18n\")\n- screen_base: makeRulesButtonConfig uses _.lang() from i18n module\n- Add CHANGELOG.md and update README.md")
    tag_and_push(gc_dir, "v1.1.0")
    print("  committed + tagged v1.1.0 + pushed")
else:
    print("  no changes")

# ---------------------------------------------------------------------------
# 2. sudoku-common
# ---------------------------------------------------------------------------
sc_dir = os.path.join(ROOT, "sudoku-common")
print("=== sudoku-common ===")
if has_changes(sc_dir):
    commit_all(sc_dir, "feat: switch to i18n module for FR/EN translation")
    tag_and_push(sc_dir, "v1.0.1")
    print("  committed + tagged v1.0.1 + pushed")
else:
    print("  no changes")

# ---------------------------------------------------------------------------
# 3. Each plugin submodule
# ---------------------------------------------------------------------------
out, _ = run(["git", "submodule", "status"], cwd=ROOT)
plugin_dirs = []
for line in out.splitlines():
    parts = line.split()
    name = parts[1] if len(parts) >= 2 else None
    if name and name not in ("game-common", "sudoku-common"):
        plugin_dirs.append(name)

skipped = []
bumped = []
failed = []

for name in sorted(plugin_dirs):
    d = os.path.join(ROOT, name)
    if not has_changes(d):
        skipped.append(f"{name} (no changes)")
        continue

    meta = os.path.join(d, "_meta.lua")
    if not os.path.exists(meta):
        skipped.append(f"{name} (no _meta.lua)")
        continue

    cur = get_current_version(meta)
    if not cur:
        skipped.append(f"{name} (no version field)")
        continue

    new_ver = minor_bump(cur)
    tag = f"v{new_ver}"

    # Check tag doesn't already exist
    existing_tags, _ = run(["git", "tag", "-l", tag], cwd=d)
    if existing_tags.strip():
        skipped.append(f"{name} (tag {tag} already exists)")
        continue

    print(f"  {name}: {cur} → {new_ver}")

    # Detect what kind of change this is
    status_out, _ = run(["git", "status", "--short"], cwd=d)
    has_base_screen = "base_screen.lua" in status_out

    # Commit the feature changes
    if has_base_screen:
        feat_msg = "feat: add FR/EN translation via i18n module + fix rules in base_screen"
    else:
        feat_msg = "feat: add FR/EN translation via i18n module"

    # Bump version
    if not bump_meta(meta, new_ver):
        failed.append(f"{name} (version bump failed)")
        continue

    # Single commit: feature + version bump
    try:
        run(["git", "add", "-A"], cwd=d)
        run(["git", "commit", "-m", f"feat: i18n FR/EN translation + bump to {new_ver}"], cwd=d)
    except SystemExit:
        failed.append(f"{name} (commit failed)")
        # restore meta
        run(["git", "checkout", "--", "_meta.lua"], cwd=d)
        continue

    try:
        tag_and_push(d, tag)
        bumped.append(f"{name}: {cur} → {new_ver}")
    except SystemExit:
        failed.append(f"{name} (push/tag failed)")

print("\n=== Summary ===")
print(f"Bumped  ({len(bumped)}):")
for x in bumped:
    print(f"  {x}")
print(f"Skipped ({len(skipped)}):")
for x in skipped:
    print(f"  {x}")
print(f"Failed  ({len(failed)}):")
for x in failed:
    print(f"  {x}")

# ---------------------------------------------------------------------------
# 4. Parent repo: update submodule pointers + push
# ---------------------------------------------------------------------------
print("\n=== Parent repo ===")
out, _ = run(["git", "status", "--short"], cwd=ROOT)
if out.strip():
    run(["git", "add", "-A"], cwd=ROOT)
    run(["git", "commit", "-m", "feat: i18n FR/EN translation across all plugins (v1.1.0)\n\n- All plugins bumped to x.1.0 minor version\n- game-common v1.1.0: new i18n.lua module with 350+ FR translations\n- README: add Language support section"], cwd=ROOT)
    run(["git", "push", "origin", "HEAD:master"], cwd=ROOT)
    print("  parent committed + pushed")
else:
    print("  no changes in parent repo")

print("\nDone.")
