#!/usr/bin/env python3
"""Patch-bump every game-common consumer that has no unreleased change.

After a game-common release, the plugins that did not change themselves still
ship the old copy in their zip until they are released again. This bumps them
all (x.y.z -> x.y.z+1) with the same CHANGELOG entry.

    scripts/dev/fleet_patch_bump.py --message "Picks up game-common 1.15.0: ..."           # dry run
    scripts/dev/fleet_patch_bump.py --message "..." --subject "picks up game-common 1.15.0" --apply
    scripts/dev/fleet_patch_bump.py --push            # list what --push --apply would push
    scripts/dev/fleet_patch_bump.py --push --apply    # push branch + tag of each bumped plugin

Bump step (--apply): for each manifest.json plugin with common_lib "common"
(set-aside, boggleparty, doubleornothing excluded) whose submodule has NO
uncommitted changes (dirty ones carry their own release, see
release_dirty_plugins.py): _meta.lua version +0.0.1, a new top CHANGELOG.md
entry "## [<new>] - <date>" / "### <section>" / the --message bullet(s),
commit "release: <new> -- <subject>" (no attribution trailer), and
tag v<new>, all LOCAL. Nothing is pushed.

Push step (--push): for each consumer whose HEAD is tagged v<_meta version>
and is ahead of its upstream, `git push origin HEAD:<branch>` then the tag.
Run it once the local result looks right (git -C x.koplugin show).

Options: --date YYYY-MM-DD (default today), --section (default Changed),
--lib common|sudoku_common (default common), --only ID..., --skip ID...
Env: REPO (monorepo root).
"""
import argparse
import datetime
import json
import os
import re
import subprocess
import sys
import textwrap
from pathlib import Path

REPO = Path(os.environ.get("REPO") or Path(__file__).resolve().parents[2])
EXCLUDED = {"kakuro", "arrowwords", "startmenu", "boggleparty", "doubleornothing", "_skeleton"}
VER_RE = re.compile(r'(version\s*=\s*")(\d+)\.(\d+)\.(\d+)(")')


def git(d, *a, check=True):
    r = subprocess.run(["git", "-C", str(d), *a], capture_output=True, text=True)
    if check and r.returncode != 0:
        raise RuntimeError(f"git -C {d} {' '.join(a)} failed: {r.stderr.strip()}")
    return r.stdout.strip()


def bullets(message):
    """--message as CHANGELOG bullets: each paragraph/line starting with '- '
    stays a bullet, a plain text becomes one bullet; wrapped at 76 cols."""
    items = []
    for line in message.strip().splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("- ") or not items:
            items.append(line[2:] if line.startswith("- ") else line)
        else:
            items[-1] += " " + line
    return "\n".join(textwrap.fill(i, 76, initial_indent="- ", subsequent_indent="  ") for i in items)


def consumers(lib, only, skip):
    m = json.loads((REPO / "manifest.json").read_text())
    for p in m["plugins"]:
        if p.get("common_lib") != lib or p["id"] in EXCLUDED or p["id"] in skip:
            continue
        if only and p["id"] not in only:
            continue
        d = REPO / p["dir"]
        if d.is_dir():
            yield p["id"], d


def bump(a):
    if not a.message:
        sys.exit("--message is required for the bump step")
    entry_body = bullets(a.message)
    subject = a.subject or a.message.strip().splitlines()[0].lstrip("- ").rstrip(".")
    if len(subject) > 70:
        subject = subject[:67].rsplit(" ", 1)[0] + "…"
    todo, skipped = [], []
    for pid, d in consumers(a.lib, a.only, a.skip):
        if git(d, "status", "--porcelain"):
            skipped.append(pid + "(dirty)"); continue
        meta = (d / "_meta.lua").read_text()
        mm = VER_RE.search(meta)
        if not mm:
            skipped.append(pid + "(no version)"); continue
        cur = ".".join(mm.group(2, 3, 4))
        new = f"{mm[2]}.{mm[3]}.{int(mm[4]) + 1}"
        if git(d, "tag", "-l", f"v{new}"):
            skipped.append(f"{pid}(v{new} exists)"); continue
        todo.append((pid, d, meta, mm, cur, new))
    print(f"{len(todo)} to bump: " + " ".join(f"{t[0]} {t[4]}->{t[5]}" for t in todo))
    print("skipped: " + (" ".join(skipped) or "-"))
    entry = f"## [NEW] - {a.date}\n\n### {a.section}\n{entry_body}\n\n"
    print(f"\ncommit: release: NEW -- {subject}\nCHANGELOG entry:\n{textwrap.indent(entry, '  | ', lambda _: True)}")
    if not a.apply:
        print("Dry run: nothing changed (add --apply to bump, commit and tag locally).")
        return 0
    for pid, d, meta, mm, cur, new in todo:
        (d / "_meta.lua").write_text(meta[:mm.start()] + f"{mm[1]}{new}{mm[5]}" + meta[mm.end():])
        chp = d / "CHANGELOG.md"
        ch = chp.read_text() if chp.exists() else "# Changelog\n\n"
        e = entry.replace("NEW", new)
        i = ch.find("## [")
        ch = ch[:i] + e + ch[i:] if i >= 0 else ch.rstrip() + "\n\n" + e
        chp.write_text(ch)
        git(d, "add", "_meta.lua", "CHANGELOG.md")
        git(d, "commit", "-q", "-m", f"release: {new} -- {subject}")
        git(d, "tag", f"v{new}")
        print(f"bumped {pid} {cur} -> {new} (local commit + tag)", flush=True)
    print("\nCheck one (git -C <id>.koplugin show), then: fleet_patch_bump.py --push --apply")
    return 0


def push(a):
    todo = []
    for pid, d in consumers(a.lib, a.only, a.skip):
        mm = VER_RE.search((d / "_meta.lua").read_text())
        if not mm:
            continue
        ver = ".".join(mm.group(2, 3, 4))
        tag_sha = git(d, "rev-parse", "-q", "--verify", f"refs/tags/v{ver}^{{commit}}", check=False)
        if not tag_sha or tag_sha != git(d, "rev-parse", "HEAD"):
            continue
        br = git(d, "rev-parse", "--abbrev-ref", "HEAD")
        if br == "HEAD":
            print(f"skip {pid}: detached HEAD"); continue
        ahead = git(d, "rev-list", "--count", "@{u}..HEAD", check=False)
        if ahead in ("", "0"):
            continue  # already pushed (or no upstream)
        todo.append((pid, d, ver, br, ahead))
    print(f"{len(todo)} to push: " + " ".join(f"{t[0]} v{t[2]}->{t[3]}" for t in todo))
    if not a.apply:
        print("Dry run: nothing pushed (add --apply).")
        return 0
    failed = []
    for pid, d, ver, br, _ in todo:
        try:
            git(d, "push", "-q", "origin", f"HEAD:{br}")
            git(d, "push", "-q", "origin", f"v{ver}")
            print(f"pushed {pid} v{ver}", flush=True)
        except RuntimeError as e:
            failed.append(pid); print(f"FAILED {pid}: {e}", flush=True)
    if failed:
        print("failed: " + " ".join(failed)); return 1
    print("Next: update_manifest.py, build_release.sh, commit the monorepo.")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0],
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--message", help="CHANGELOG text (plain text = one bullet; '- ' lines = several)")
    ap.add_argument("--subject", help="commit subject after 'release: <ver> -- ' (default: 1st line of --message)")
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    ap.add_argument("--section", default="Changed")
    ap.add_argument("--lib", default="common", choices=["common", "sudoku_common"])
    ap.add_argument("--only", nargs="+", default=[], metavar="ID")
    ap.add_argument("--skip", nargs="+", default=[], metavar="ID")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--dry-run", action="store_true", help="default: show the plan only")
    g.add_argument("--apply", action="store_true", help="bump: commit+tag locally; with --push: push")
    ap.add_argument("--push", action="store_true", help="push step instead of bump step")
    a = ap.parse_args()
    a.only, a.skip = set(a.only), set(a.skip)
    return push(a) if a.push else bump(a)


if __name__ == "__main__":
    sys.exit(main())
