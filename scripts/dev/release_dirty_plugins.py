#!/usr/bin/env python3
"""Commit, tag and push every plugin submodule that has uncommitted changes.

    scripts/dev/release_dirty_plugins.py            # dry run (default): show the plan
    scripts/dev/release_dirty_plugins.py --apply    # commit + tag + push
    scripts/dev/release_dirty_plugins.py --apply --only 2048 wordle

For each dirty <id>.koplugin submodule (set-aside plugins, boggleparty and
doubleornothing excluded): version from _meta.lua, summary = first bullet of
that version's CHANGELOG.md entry, then
    git add -A; git commit -m "release: <ver> -- <summary>" (+ Co-Authored-By trailer)
    git tag v<ver>; git push origin HEAD:<branch>; git push origin v<ver>
<branch> is the submodule's current branch (main or master; refuses a
detached HEAD). Pushing a v* tag triggers the plugin's release CI.

Refuses (whole run, before touching anything) when a plugin:
  - has the same _meta.lua version as its HEAD commit (not bumped),
  - has a CHANGELOG.md whose top "## [x.y.z]" entry is not the _meta version,
  - already has the tag v<ver>,
  - is on a detached HEAD.
Shared libs (game-common, sudoku-common) are NOT handled: release them first,
by hand (see README.md).  Env: REPO (monorepo root).
"""
import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(os.environ.get("REPO") or Path(__file__).resolve().parents[2])
EXCLUDED = {"kakuro", "arrowwords", "startmenu", "boggleparty", "doubleornothing", "_skeleton"}
TRAILER = "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
VERSION_RE = re.compile(r'version\s*=\s*"([\d.]+)"')


def git(d, *a, check=True):
    r = subprocess.run(["git", "-C", str(d), *a], capture_output=True, text=True)
    if check and r.returncode != 0:
        raise RuntimeError(f"git -C {d} {' '.join(a)} failed: {r.stderr.strip()}")
    return r.stdout.strip()


def dirty_plugins():
    out = git(REPO, "submodule", "foreach", "--quiet",
              'if [ -n "$(git status --porcelain)" ]; then echo "$name"; fi')
    return [n for n in out.split() if n.endswith(".koplugin") and n[:-9] not in EXCLUDED]


def plan_one(name):
    d = REPO / name
    meta = (d / "_meta.lua").read_text()
    m = VERSION_RE.search(meta)
    if not m:
        return None, f"{name}: no version in _meta.lua"
    ver = m[1]
    head_meta = git(d, "show", "HEAD:_meta.lua", check=False)
    hm = VERSION_RE.search(head_meta or "")
    if hm and hm[1] == ver:
        return None, f"{name}: _meta.lua version {ver} == HEAD's (not bumped)"
    ch_path = d / "CHANGELOG.md"
    if not ch_path.exists():
        return None, f"{name}: no CHANGELOG.md"
    ch = ch_path.read_text()
    top = re.search(r"^## \[([^\]]+)\]", ch, re.M)
    if not top or top[1] != ver:
        return None, f"{name}: CHANGELOG top entry {top[1] if top else '(none)'} != _meta version {ver}"
    body = ch[top.start():].split("\n## [", 1)[0]
    bullet = next((l[2:].strip() for l in body.splitlines() if l.startswith("- ")), "release")
    bullet = re.sub(r"\*\*|`", "", bullet)
    summ = bullet if len(bullet) <= 70 else bullet[:67].rsplit(" ", 1)[0] + "…"
    if git(d, "tag", "-l", f"v{ver}"):
        return None, f"{name}: tag v{ver} already exists"
    br = git(d, "rev-parse", "--abbrev-ref", "HEAD")
    if br == "HEAD":
        return None, f"{name}: detached HEAD"
    files = git(d, "status", "--porcelain").splitlines()
    return {"name": name, "dir": d, "ver": ver, "summary": summ, "branch": br,
            "prev": hm[1] if hm else "?", "nfiles": len(files)}, None


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--dry-run", action="store_true", help="show the plan only (default)")
    g.add_argument("--apply", action="store_true", help="commit, tag and push")
    ap.add_argument("--no-push", action="store_true", help="with --apply: commit + tag locally only")
    ap.add_argument("--only", nargs="+", metavar="ID", help="restrict to these plugin ids")
    a = ap.parse_args()

    names = dirty_plugins()
    if a.only:
        want = {i.removesuffix(".koplugin") for i in a.only}
        names = [n for n in names if n[:-9] in want]
    if not names:
        print("no dirty plugin submodule")
        return 0
    plans, errors = [], []
    for n in names:
        p, err = plan_one(n)
        (errors.append(err) if err else plans.append(p))
    for p in plans:
        print(f"{p['name'][:-9]:16} {p['prev']} -> {p['ver']}  [{p['branch']}, {p['nfiles']} changed]  "
              f"release: {p['ver']} -- {p['summary']}")
    if errors:
        print("\nREFUSED:", file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    if not a.apply:
        print(f"\n{len(plans)} plugin(s) to release. Dry run: nothing done (use --apply).")
        return 0
    done = []
    for p in plans:
        d, ver = p["dir"], p["ver"]
        git(d, "add", "-A")
        git(d, "commit", "-q", "-m", f"release: {ver} -- {p['summary']}\n\nSee CHANGELOG.md.\n\n{TRAILER}")
        git(d, "tag", f"v{ver}")
        if not a.no_push:
            git(d, "push", "-q", "origin", f"HEAD:{p['branch']}")
            git(d, "push", "-q", "origin", f"v{ver}")
        done.append(f"{p['name'][:-9]} {ver}")
        print("released" if not a.no_push else "committed+tagged", p["name"][:-9], ver, flush=True)
    print(f"\n{len(done)}: {', '.join(done)}")
    print("Next: python3 .github/scripts/update_manifest.py && ./scripts/build_release.sh, "
          "then commit the monorepo (submodule pointers, manifest.json).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
