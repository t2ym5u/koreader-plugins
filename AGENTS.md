# AGENTS.md — koreader-plugins

Monorepo of ~121 KOReader game/utility plugins for the owner's e-reader, one git submodule per
`*.koplugin` (repos `t2ym5u/<id>.koplugin`), plus the shared-library submodules `game-common`
and `sudoku-common`. Build and release commands: `README.md`; plugin list: `docs/README.md`.
General agent rules (GO before publishing, verification, `HANDOFF.md`) come from agent-kit and
are not repeated here.

## Non-negotiable

- **« Je valide avant ».** Show the results (versions, test counts, renders you looked at) and
  get an explicit GO before publishing anything: push, tag, repo creation, archive, delete,
  topic or protection change, or anything on the owner's e-reader. A GO for one batch does not
  cover the next. The scripts that publish are declared in `.claude/publish-scripts`.
- Talk to the owner in **French**. Code, comments, docs and CHANGELOGs stay in **English**.
- **Never stage `arrowwords.koplugin` or `kakuro.koplugin`**: they are archived and show as
  modified locally (arrowwords holds a stranded i18n fix).
- **Never commit another session's work in progress**: parallel sessions share this tree. Check
  `git status`, the diffs, and foreign `Claude-Session:` trailers.
- Commit trailer: the `Co-Authored-By` line your harness gives for the current model.

## 1. Constraints

- Target device: **Kobo Aura**, 758×1024 at 212 dpi, 256 MB RAM, single core (about 25× slower
  than this Mac for Lua), touch only, no sound. Hence: nothing heavy at load, specs with timing
  bounds, renders checked at 212 dpi.
- Content: family-friendly, no dictators, terrorists or serial killers, no trademarks in names;
  puzzles must never require guessing. Full rules: `docs/dev/NEW_PLUGIN.md`.

## 2. Workflow

- **Before non-trivial work**: `docs/dev/ARCHITECTURE.md`, and `docs/dev/PITFALLS.md` for the
  area you touch (loading, releases, generators, e-ink UI).
- **Before showing a change to the owner** (details and pitfalls: `docs/dev/TESTING.md`):
  ```bash
  scripts/dev/run_specs.sh <plugin> ...   # or --changed; busted can exit 0 on errors: read the summary
  scripts/dev/check_i18n.sh               # must stay at 0 conflicts
  ```
  plus headless renders you actually looked at, for any visible change.
- **Release**: only in the order of `docs/dev/RELEASE.md`, after the GO.
- **Set-aside plugins** (`kakuro`, `arrowwords`, `startmenu`, `boggleparty`, `doubleornothing`):
  excluded from `manifest.json`/`dist/`, repos archived, submodules still checked out. Presence
  in the tree does not mean "not yet built": `EXCLUDED_PLUGINS` in
  `.github/scripts/update_manifest.py` is the reference. Why each one and how to set one aside:
  `docs/dev/RELEASE.md` § Retiring a plugin.
- **Categories**: `.github/scripts/categories.json` is the only place a plugin's category is set
  (`docs/dev/ARCHITECTURE.md` § Menus and categories). A plugin missing from it lands in "Other".

## 3. Documentation map

| File | Read it when |
| --- | --- |
| `docs/dev/ARCHITECTURE.md` | before any non-trivial change: game-common, lazy loading, module guard, i18n, menus, Dashboard, Plugin Manager |
| `docs/dev/TESTING.md` | running or writing specs, renders, speed and memory probes, real-install test, device |
| `docs/dev/RELEASE.md` | releasing, onboarding or retiring a plugin, GitHub conventions (topics, community files, branch protection) |
| `docs/dev/PITFALLS.md` | before touching loading, releases, generators or e-ink UI |
| `docs/dev/NEW_PLUGIN.md` | writing a new plugin: checklist, reference plugins, content rules |
| `scripts/dev/README.md` | using the developer tools |
| `docs/ROADMAP.md` | planning: what is next, per phase |
| `HANDOFF.md` | resuming an interrupted session (git-ignored, if present) |
