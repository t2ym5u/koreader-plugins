# koreader-plugins

Monorepo of ~70 KOReader game/utility plugins, one git submodule per
`*.koplugin` (plus `game-common`/`sudoku-common` shared-library submodules).
See `README.md` for build/release commands and `docs/README.md` for the
full plugin list.

## Set-aside plugins

`kakuro`, `galaxies`, `arrowwords` are deliberately excluded from
`manifest.json`/`dist/` and their GitHub repos (`t2ym5u/<name>.koplugin`)
are archived. kakuro and galaxies have confirmed, unfixed generator bugs
(see `docs/generator_robustness_audit.md`); arrowwords was set aside by
user request. Their submodules are still checked out locally — don't
assume presence in `manifest.json` means "not yet built", check
`EXCLUDED_PLUGINS` in `.github/scripts/update_manifest.py` first.

To set aside another plugin:
1. Add its id to `EXCLUDED_PLUGINS` in `.github/scripts/update_manifest.py`
   (it's checked in both the main discovery loop and the "preserve
   un-checked-out submodule entries" fallback loop — guard both, the
   second one will silently un-exclude it otherwise).
2. Run `python3 .github/scripts/update_manifest.py`, then
   `./scripts/build_release.sh` (this does NOT delete stale zips for
   removed plugins — `rm dist/<name>.zip` by hand).
3. Update plugin counts in `README.md` and `docs/README.md`, and remove
   the plugin's row from `docs/README.md`'s table.
4. `gh repo archive t2ym5u/<name>.koplugin --yes` (reversible via
   unarchive).

## GitHub topic convention

Every active `t2ym5u/*.koplugin` repo carries the topic
`koreader-plugins` (GitHub topics are lowercase-hyphenated only). Skip:
`_skeleton.koplugin` (template), `game-common`/`sudoku-common` (shared
libraries, not plugins), `checkers.koplugin` (external remote owned by
kbarni, not t2ym5u — see `.gitmodules`), and any set-aside plugin above.
`scripts/new_plugin.sh` does not add this topic automatically yet — add
it by hand when onboarding a new plugin:
```bash
gh api -X PUT "repos/t2ym5u/<name>.koplugin/topics" -f "names[]=koreader-plugins"
```
To audit topics across the whole account in one call instead of looping
`gh repo view` per repo (slow, hits transient TLS timeouts at scale):
```bash
gh api "users/t2ym5u/repos?per_page=100&type=owner" --paginate \
  --jq '.[] | "\(.name)\t\(.topics|join(","))"'
```
