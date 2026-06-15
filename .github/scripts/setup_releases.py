#!/usr/bin/env python3
"""Propagate release.yml workflow to all individual plugin repos and create
initial releases.

Usage:
    python3 .github/scripts/setup_releases.py [--releases-only] [--workflow-only]

Requires: gh CLI authenticated with repo scope.
"""

import base64
import json
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
WORKFLOW_SRC = ROOT / ".github" / "workflows" / "release-plugin.yml"
GAME_COMMON = ROOT / "game-common"
MANIFEST = ROOT / "manifest.json"


def gh(*args, input=None, check=True):
    result = subprocess.run(
        ["gh", *args],
        capture_output=True, text=True, input=input,
    )
    if check and result.returncode != 0:
        print(f"  gh error: {result.stderr.strip()}", file=sys.stderr)
    return result


def add_workflow(repo: str, workflow_content: str) -> bool:
    """Add release.yml to repo via GitHub API (creates or updates)."""
    encoded = base64.b64encode(workflow_content.encode()).decode()

    # Check if file already exists (need its SHA to update)
    check = gh("api", f"repos/{repo}/contents/.github/workflows/release.yml",
               check=False)
    sha_flag = []
    if check.returncode == 0:
        existing_sha = json.loads(check.stdout).get("sha", "")
        sha_flag = ["-f", f"sha={existing_sha}"]

    payload = json.dumps({
        "message": "ci: add release workflow",
        "content": encoded,
        "committer": {
            "name": "github-actions[bot]",
            "email": "github-actions[bot]@users.noreply.github.com",
        },
    })
    result = gh(
        "api", f"repos/{repo}/contents/.github/workflows/release.yml",
        "--method", "PUT",
        "--input", "-",
        *sha_flag,
        input=payload, check=False,
    )
    return result.returncode == 0


def release_exists(repo: str, tag: str) -> bool:
    r = gh("release", "view", tag, "--repo", repo, check=False)
    return r.returncode == 0


def create_release(repo: str, plugin_dir: Path, version: str) -> bool:
    """Build a self-contained ZIP and create a GitHub release."""
    plugin_name = plugin_dir.name
    tag = f"v{version}"

    with tempfile.TemporaryDirectory() as tmp:
        dest = Path(tmp) / plugin_name
        dest.mkdir()

        # Copy plugin files (skip symlinks and .git/.github)
        for item in plugin_dir.iterdir():
            if item.is_symlink() or item.name in (".git", ".github", "common"):
                continue
            if item.is_file():
                shutil.copy2(item, dest / item.name)

        # Bundle game-common into common/
        common_dest = dest / "common"
        common_dest.mkdir()
        for lua in GAME_COMMON.glob("*.lua"):
            shutil.copy2(lua, common_dest / lua.name)

        zip_path = Path(tmp) / f"{plugin_name}.zip"
        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            for f in sorted(dest.rglob("*")):
                if f.is_file():
                    zf.write(f, f.relative_to(Path(tmp)))

        notes = (
            f"Extract `{plugin_name}.zip` into your KOReader `plugins/` folder.\n"
            "The `common/` subdirectory (game-common) is bundled in the archive."
        )
        r = gh(
            "release", "create", tag,
            "--repo", repo,
            "--title", tag,
            "--notes", notes,
            str(zip_path),
            check=False,
        )
        return r.returncode == 0


def main():
    args = set(sys.argv[1:])
    do_workflow = "--releases-only" not in args
    do_releases = "--workflow-only" not in args

    manifest = json.loads(MANIFEST.read_text())
    plugins = manifest["plugins"]

    workflow_content = WORKFLOW_SRC.read_text()

    print(f"Processing {len(plugins)} plugins…\n")

    workflow_ok = workflow_fail = 0
    release_ok = release_skip = release_fail = 0

    for p in plugins:
        repo = f"t2ym5u/{p['dir']}"
        version = p["version"]
        plugin_dir = ROOT / p["dir"]
        print(f"  {repo}  v{version}")

        if do_workflow:
            if add_workflow(repo, workflow_content):
                print(f"    workflow: added")
                workflow_ok += 1
            else:
                print(f"    workflow: FAILED")
                workflow_fail += 1

        if do_releases:
            if release_exists(repo, f"v{version}"):
                print(f"    release:  already exists, skipping")
                release_skip += 1
            elif create_release(repo, plugin_dir, version):
                print(f"    release:  created v{version}")
                release_ok += 1
            else:
                print(f"    release:  FAILED")
                release_fail += 1

    print()
    if do_workflow:
        print(f"Workflows: {workflow_ok} added, {workflow_fail} failed")
    if do_releases:
        print(f"Releases:  {release_ok} created, {release_skip} skipped, {release_fail} failed")


if __name__ == "__main__":
    main()
