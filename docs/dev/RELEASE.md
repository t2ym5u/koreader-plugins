# Release procedure

**The owner validates before anything is published.** Show results (versions,
test counts, renders) and get an explicit GO before you push, tag, create
repos, archive or delete. A GO for one batch does not cover the next.

## Order (always)

1. **Shared libraries first.** This applies to game-common, then
   sudoku-common, whichever changed.
   - Commit, then tag `vX.Y.Z`, then push the branch and the tag
     explicitly. `--follow-tags` leaves lib tags local.
   - Bump `game_common_version.lua` / `sudoku_common_version.lua` and add new
     modules to their `modules` list.
   - New lib files must be **committed** before running update_manifest.py,
     because it lists them from `git ls-tree HEAD`.
2. **Plugins.** In each changed submodule:
   - Check that `_meta.lua` and the CHANGELOG top entry agree.
   - Then `git add -A`, commit, tag `v<ver>`, and push the branch from
     `git rev-parse --abbrev-ref HEAD` (main or master, never assume) plus
     the tag.
   - Use `scripts/dev/release_dirty_plugins.py` (dry run by default).
   - Commit new runtime files too (e.g. `progress.lua`, `manager.lua`, data
     files). update_manifest lists committed `.lua` files only, so an
     uncommitted file never ships.
3. **Consumers of a lib change** need a version bump, or devices keep the old
   `common/`. Use `scripts/dev/fleet_patch_bump.py`, and run it BEFORE
   committing plugins that carry their own bump. Otherwise it re-bumps them,
   because they are no longer dirty.
4. **Monorepo:**
   ```bash
   git fetch && git log HEAD..origin/master   # CI may have pushed "chore: regenerate manifest.json [skip ci]"
   python3 .github/scripts/update_manifest.py
   ./scripts/build_release.sh
   python3 .github/scripts/update_manifest.py   # second pass writes zip sha256/size
   ```
   Then verify:
   - every manifest `zip.sha256` matches `dist/`;
   - new files are present in the zips (`unzip -l`);
   - `common.version` / `sudoku_common.version` are right.

   Then stage submodule pointers, `manifest.json`, docs and scripts, run
   `git add -f dist/*.zip`, commit, and push.
   - **Never stage** `arrowwords.koplugin` or `kakuro.koplugin`: they show as
     modified locally and are archived.
   - Never commit a parallel session's work in progress. Check `git status`
     and diffs, and look for foreign `Claude-Session:` trailers.
5. **CI:** watch "Release plugins" and "Update manifest.json" with
   `gh run watch <id> --exit-status`. Then check that every
   `gh release view v<ver> -R t2ym5u/<id>.koplugin` exists.
6. Update the docs (`README.md` plugin count, `docs/README.md` table, games
   count) and your memory notes.

## New plugin onboarding

1. Write the plugin as a PLAIN directory (no `.git`), with the `common`
   symlink. Its `main.lua` `name` must equal the directory name. Don't set
   `name` in `_meta.lua`.
2. Add it to `.github/scripts/categories.json`, and to dashboard
   `NON_GAME_IDS` if it is a utility.
3. Run `echo y | ./scripts/new_plugin.sh <id>`. It creates the public repo,
   pushes, registers the submodule, and regenerates the manifest.
4. Set the topic with
   `gh api -X PUT repos/t2ym5u/<id>.koplugin/topics -f "names[]=koreader-plugins"`.
   Set branch protection (see CLAUDE.md), then run
   `./scripts/sync_community_files.sh`.
5. Set `raw_base_url` in the manifest entry:
   `https://raw.githubusercontent.com/t2ym5u/<id>.koplugin/main/`.
   update_manifest never sets it.
6. Add a row to the `docs/README.md` table, update the counts, then release
   the monorepo as above.
7. Check community plugin names first:
   `gh search repos "<id>.koplugin in:name"`. Avoid colliding ids such as
   calculator or calendar, and avoid trademarks in display names.

## Retiring a plugin (absorbed or set aside)

1. Give it a final release with a "merged into X" note, if it is absorbed.
   The absorbing plugin migrates its settings and stats.
2. Add it to `EXCLUDED_PLUGINS` in update_manifest.py. It feeds both loops
   and the manifest `retired` key, which Plugin Manager uses to offer
   removal.
3. Also add it to the exclusion lists in `scripts/bump_versions.sh` and
   `scripts/sync_community_files.sh`.
4. `rm dist/<id>.zip` (build_release does not delete stale zips), then run
   `git rm --cached` on it.
5. Update the counts and the docs table, and the set-aside paragraph in
   CLAUDE.md.
6. Run `gh repo archive t2ym5u/<id>.koplugin --yes`, after its release CI
   has finished.
   - To push to an archived repo later, run
     `gh api -X PATCH repos/t2ym5u/<id>.koplugin -F archived=false`, push,
     then set `archived=true` again.
   - `gh repo unarchive` sometimes fails with a GraphQL error. The REST call
     above works.

## Forks (checkers)

- `origin` is `t2ym5u/checkers.koplugin` and `upstream` is kbarni.
- GitHub disables Issues and Actions on forks by default. Enable both, or no
  release is ever created:
  ```bash
  gh api -X PATCH repos/<r> -F has_issues=true
  gh api -X PUT repos/<r>/actions/permissions -F enabled=true -f allowed_actions=all
  ```

## User patches repo

The user patches (`2-*.lua`, repo `t2ym5u/koreader-user-patches`, usually checked out next to this monorepo) are a separate
repo with its own README. It is committed and pushed separately.
