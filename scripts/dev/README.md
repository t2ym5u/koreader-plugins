# scripts/dev — developer tools

Local tools for testing, measuring and releasing the fleet. None of them is
used by CI. The full release procedure is in `docs/dev/RELEASE.md`; this file
documents the tools it relies on.

| Tool | What it does | Destructive? |
|---|---|---|
| `bitshim/bit.lua` | LuaJIT `bit` API for busted under Lua 5.4+ | no |
| `run_specs.sh` | busted specs, one line per plugin/lib, strict exit code | no |
| `check_i18n.sh` (+ `i18n_conflicts.lua`) | English keys translated differently by two plugins | no |
| `render_screen.lua` | headless render of a game screen to PNG | no |
| `startup_cost.lua` | heap/time each plugin costs at KOReader startup | no |
| `open_close_probe.lua` | open / new game / close / reopen smoke test + memory retained after close | no |
| `realinstall_test.sh` (+ `.lua`, `make_stale_plugin.sh`) | real (non-symlinked) install, every game opened through every entry point, optional stale plugin | no (scratch dir only) |
| `release_dirty_plugins.py` | commit + tag + push each dirty plugin submodule | **yes** with `--apply` |
| `fleet_patch_bump.py` | patch-bump every lib consumer with no change of its own | **yes** with `--apply` |
| `kolua.sh` | run a Lua tool with the emulator's LuaJIT from the emulator dir | no |
| `headless.lua` | shared bootstrap of the Lua tools (not run directly) | — |

## Environment

All tools work from any directory, and from zsh (bash scripts use
`#!/usr/bin/env bash`).

| Var | Default | Used by |
|---|---|---|
| `REPO` | monorepo root (`scripts/dev/../..`) | all |
| `KOREADER_EMU` | first `../koreader/koreader-emulator-*/koreader` next to the monorepo | Lua tools, `check_i18n.sh` |
| `WORK` | `${TMPDIR:-/tmp}/koplugins-dev` | Lua tools (settings, outputs) |

`KOREADER_EMU` is the dir of a KOReader emulator build: the one holding
`./luajit`, `setupkoenv.lua`, `frontend/` and `plugins/`. Build it from a
KOReader checkout with `./kodev build`; the dir is
`koreader-emulator-<triple>-debug/koreader`. Its `plugins/` must contain the
dev symlinks to this repo, made by `scripts/link_plugins.sh <koreader>/plugins`.

The Lua tools must run under that LuaJIT, from that dir. `kolua.sh` does the
`cd`, exports `REPO`/`WORK`, and filters the debug build's `ffi.load` noise
from stdout (`KOLUA_RAW=1` keeps it):

```bash
scripts/dev/kolua.sh render_screen.lua 2048 /tmp/2048.png 758 1024 fr
# same as: cd "$KOREADER_EMU" && ./luajit "$REPO/scripts/dev/render_screen.lua" 2048 /tmp/2048.png 758 1024 fr
```

Nothing below writes into the repo except the two release scripts with
`--apply`. Settings and outputs go to `$WORK/<tool>/`.

## Tests

### bitshim/bit.lua

Homebrew busted runs on Lua 5.5, which has no `bit` module. Sudoku specs need
it, and without it they error out while busted still **exits 0**. The shim
implements `bit` (32-bit, LuaJIT semantics) with native operators:

```bash
cd sudokux.koplugin && LUA_PATH="$REPO/scripts/dev/bitshim/?.lua;;" busted test_*_spec.lua
```

### run_specs.sh

```bash
scripts/dev/run_specs.sh 2048 sudokux game-common   # named dirs (.koplugin suffix optional)
scripts/dev/run_specs.sh --changed                  # submodules with uncommitted changes
scripts/dev/run_specs.sh --all                      # every *.koplugin + game-common + sudoku-common
```

- Runs `busted test_*_spec.lua` from inside each dir, with the shim.
- Prints `<dir>: OK|FAIL|NO SUMMARY <busted summary>` per dir, or
  `(no specs)` for a dir without specs.
- Exits 1 if any dir had failures or errors, or printed no
  `N successes / ...` line (busted crashed before running).
- Never runs kakuro, arrowwords, startmenu, boggleparty, doubleornothing or
  `_skeleton`.
- `VERBOSE=1` dumps the full output of failing dirs. `BUSTED=` overrides the
  binary.

### check_i18n.sh

All plugins share one `require("i18n")` slot at runtime: game-common's table,
extended by every plugin's `i18n_fr.lua`. So an English key has only one
translation per language fleet-wide, and the last plugin loaded wins.

```bash
scripts/dev/check_i18n.sh          # prints CONFLICT lines + "conflicts: N", exit 1 if N > 0
```

It checks `game-common/i18n.lua` plus every `*.koplugin/i18n_fr.lua`, except
the set-aside plugins and `_skeleton`. `i18n_conflicts.lua` is pure Lua 5.1,
and `LUAJIT=` can point at any LuaJIT.

### render_screen.lua: screenshots without a window

```bash
scripts/dev/kolua.sh render_screen.lua <plugin_id> <out.png> <w> <h> [lang]
RENDER_DPI=300 scripts/dev/kolua.sh render_screen.lua sudoku /tmp/s.png 1264 1680 fr   # Libra 2
```

- Loads `$REPO/<id>.koplugin` the way PluginLoader does, calls
  `createScreen()` (or `showGame(MODE)`), paints on a white 8-bit page, and
  writes the PNG.
- Each run uses fresh settings in `$WORK/render/<id>_<lang>/`. `KEEP=1`
  keeps them.
- Defaults: `RENDER_DPI=212` (Kobo Aura, 758x1024) and `SEED=7`. No
  keyboard is emulated, so menus show no Q/W/E shortcut boxes.

**Extra states.** Drive them through Lua hooks:

- `SETUP='<lua>'` runs before the screen exists, with locals `p` (plugin)
  and `H` (headless.lua). Use it to seed settings, e.g.
  `SETUP='p:saveSetting("solved_easy", "1101")'`.
- `STATE='<lua>'` runs after the screen exists, with locals `scr`, `p`,
  `shown` (widgets passed to `UIManager:show`) and `H`. A widget it
  `return`s is painted centred on top.
  ```bash
  STATE='scr:onNewGame()' ...
  STATE='scr:openDifficultyMenu(); return shown[#shown]' scripts/dev/kolua.sh render_screen.lua trafficjam /tmp/tj.png 758 1024
  STATE='scr:onStartTurn(); scr:onReveal()' ...                                   # quiz
  ```
- `STATE_FILE=scene.lua` handles multi-step scenes. The file's chunk gets
  `scr, p, shown, H` as `...` and may return an overlay. Keep one file per
  screenshot next to the README images, e.g. one that plays the hint path to
  a win.
- `TAP="x,y;x,y"` sends tap gestures after a first paint.
- `OVERLAY=last` paints the last shown widget on top.
- `CAT=<cat>` saves the word games' `category_<lang>` setting.

When the screen's API is too specific for one-liners (whole scripted games,
fake progress), copy `render_screen.lua` next to your work and edit the
middle section. `headless.lua` keeps the boilerplate out of it.

### startup_cost.lua

```bash
scripts/dev/kolua.sh startup_cost.lua                            # per-plugin rows, sorted by KB, + SUM
OUT=/tmp/cost.tsv scripts/dev/kolua.sh startup_cost.lua          # + TSV
TOTALS=1 scripts/dev/kolua.sh startup_cost.lua                   # real totals, all plugins
TOTALS=1 ONLY_BUILTIN=1 scripts/dev/kolua.sh startup_cost.lua    # baseline: KOReader's own plugins only
```

- A headless FileManager start with ALL plugins enabled, like a device.
- Per plugin it reports module load (`PluginLoader._load`) and init
  (`createPluginInstance`). For each: KB retained after a full GC, and ms.
  `re-ms` is the init time of a second FileManager.
- Per-row ms include a GC per step, so use them only for ranking. Use the
  difference between the two `TOTALS=1` runs for the real fleet cost.
- Repo plugins that are not linked in the emulator's `plugins/` are linked in
  `$WORK/startup/extra`. Set-aside plugins and simpleui are disabled.
- PluginManager gets the local `manifest.json` as its cache, so there is no
  network access.
- `UILANG=fr` sets the UI language.

### open_close_probe.lua

```bash
scripts/dev/kolua.sh open_close_probe.lua anagram fr
scripts/dev/kolua.sh open_close_probe.lua quiz en party           # 3rd arg: showGame(mode)
SWITCH='p:saveSetting("lang","fr"); scr:onNewGame()' scripts/dev/kolua.sh open_close_probe.lua wordle en
FINDREF=1 scripts/dev/kolua.sh open_close_probe.lua <id>           # who still holds a closed screen
```

- Steps: load, init, open, new game, optional `SWITCH`, close, reopen,
  close.
- Prints heap deltas against "init", the number of modules added, and
  `plugin modules hold ~N KB after close`. That last figure is the data
  reachable only from the plugin's own `package.loaded` entries: word lists,
  banks, caches that a close should release.
- Any error prints `FAIL <id> <step>: <traceback>` and exits 1.
- `WARM=hanoi` (the default) probes another plugin first, so shared modules
  are not charged to the probed one. `WARM=` disables it.

To probe many plugins in parallel:

```bash
for id in anagram wordle hangman; do echo $id; done |
  xargs -P 8 -I{} sh -c 'scripts/dev/kolua.sh open_close_probe.lua {} fr > "$WORK/probe_{}.txt" 2>&1'
```

### realinstall_test.sh (+ make_stale_plugin.sh)

This is what a device sees: real copies, a `common/` dir per plugin, and
possibly an outdated plugin next to them.

```bash
scripts/dev/realinstall_test.sh                          # dist/*.zip of the default set
scripts/dev/realinstall_test.sh --source tree            # working tree instead (common/ dereferenced)
scripts/dev/realinstall_test.sh --stale gen              # + arrowwords 1.2.11 with game-common 1.6.0
scripts/dev/realinstall_test.sh --stale gen --stale-first   # stale path loads first
scripts/dev/realinstall_test.sh --stale /some/dir 2048 wordle dashboard
```

- Installs into `$WORK/realinstall/<tag>/real` and refuses if any symlink
  ends up there.
- Default set: 2048 converter quickcalc trafficjam dashboard wordle sudoku
  sudokux quiz hangman minesweeper.
- Starts a headless FileManager with only KOReader's own plugins from the
  emulator's `plugins/`. Every symlink there is hidden by an `lfs.dir`
  filter, and nothing is moved. The copies load through
  `extra_plugin_paths`.
- Prints which plugin's copy holds each shared module slot (`slot i18n
  real/2048.koplugin/common/i18n.lua`), the game-common module registry, and
  the Tools → Games categories.
- Then, twice per plugin, it opens each game every way a user can: Tools →
  Games (`menu`), its own Tools entry (`tools`), Dashboard `launchGame`
  (`dash`), and Dashboard `launchDaily` (`daily`) for games with a daily
  challenge (same detection as the Dashboard).
- Each open paints the screen to `$WORK/realinstall/<tag>/<tag>_<label>.png`
  and closes it.
- Prints `<label> OK|FAIL <error>`, a few fr translations through the shared
  slot, and `RESULT <tag>: N ok, M failed`. It exits 1 on any failure;
  `TRACE=1` adds tracebacks. Emulator stderr goes to
  `$WORK/realinstall/<tag>/stderr.log`.

`make_stale_plugin.sh <out_dir> [plugin tag lib lib_tag]` builds an old
release from git (`git archive` of the plugin tag, plus the lib tag's `*.lua`
in a real `common/`). The default is arrowwords v1.2.11 with game-common
v1.6.0, released before the module guard. With today's zips, all runs are
green with or without it. Against zips built before game-common 1.14 (the
module guard), the stale plugin took over the shared slots: 2 ok / 32 failed
with the stale path first, 6 / 28 with it last.

## Release scripts

Both release scripts are dry runs unless `--apply` is given. Read the plan
before applying.

### release_dirty_plugins.py

```bash
python3 scripts/dev/release_dirty_plugins.py                 # plan
python3 scripts/dev/release_dirty_plugins.py --apply         # commit, tag, push
python3 scripts/dev/release_dirty_plugins.py --apply --no-push --only 2048 wordle
```

For each `*.koplugin` submodule with uncommitted changes (set-aside plugins,
boggleparty and doubleornothing are excluded):

1. Reads the version from `_meta.lua`.
2. Takes the first bullet of that version's CHANGELOG entry as the summary.
3. Runs `git add -A` and commits `release: <ver> -- <summary>`, with no
   attribution trailer.
4. Tags `v<ver>`.
5. Pushes `HEAD:<current branch>` and the tag. The tag triggers the plugin's
   release CI.

It refuses the whole run, before touching anything, if a plugin:

- has the same `_meta` version as HEAD (not bumped);
- has a CHANGELOG top entry that is not the `_meta` version;
- already has the tag;
- is on a detached HEAD.

### fleet_patch_bump.py

```bash
python3 scripts/dev/fleet_patch_bump.py --message "Picks up game-common 1.15.0: <what users get>." \
    --subject "picks up game-common 1.15.0"            # plan + entry preview
python3 scripts/dev/fleet_patch_bump.py --message "..." --subject "..." --apply   # local commits + tags
python3 scripts/dev/fleet_patch_bump.py --push                                    # what would be pushed
python3 scripts/dev/fleet_patch_bump.py --push --apply                            # push branch + tag
```

**Bump step.** It covers every manifest plugin with `common_lib` `common`
(`--lib sudoku_common` for the other family) that has no uncommitted change.
For each one it:

1. Bumps the patch version in `_meta.lua`.
2. Adds a CHANGELOG entry `## [<new>] - <--date, default today>` /
   `### <--section, default Changed>`, built from the `--message` bullet(s).
   A plain text becomes one bullet; `- ` lines become several.
3. Commits `release: <new> -- <subject>` with the trailer.
4. Tags `v<new>`, locally only.

`--only` and `--skip` restrict the set.

**Push step.** It pushes each consumer whose HEAD carries `v<_meta version>`
and is ahead of its upstream.

## Full release sequence these tools support

1. **Test**:
   ```bash
   scripts/dev/run_specs.sh --changed game-common
   scripts/dev/check_i18n.sh
   scripts/dev/kolua.sh open_close_probe.lua <each changed game> fr
   ```
   Render the screens that changed (`render_screen.lua`), and show them for
   validation.
2. **Real-install check**, if shared code or loading changed:
   ```bash
   ./scripts/build_release.sh
   scripts/dev/realinstall_test.sh --source tree
   scripts/dev/realinstall_test.sh --source tree --stale gen --stale-first
   ```
3. **Shared libs first**, by hand. Commit game-common/sudoku-common, then:
   ```bash
   git tag vX.Y.Z
   git push origin HEAD:<branch>
   git push origin vX.Y.Z
   ```
   `--follow-tags` leaves lib tags local, so push the tag explicitly.
4. **Lib consumers**:
   ```bash
   fleet_patch_bump.py --message ... --apply
   ```
   Run it BEFORE step 5. Once the dirty plugins are committed they look
   clean and would be bumped twice.
5. **Changed plugins**:
   ```bash
   release_dirty_plugins.py
   release_dirty_plugins.py --apply
   ```
6. `fleet_patch_bump.py --push --apply`.
7. **Monorepo**:
   ```bash
   python3 .github/scripts/update_manifest.py
   ./scripts/build_release.sh
   python3 .github/scripts/update_manifest.py
   ```
   Then commit the submodule pointers, `manifest.json` and `dist/`, push, and
   watch CI. See `docs/dev/RELEASE.md`.
