# Pitfalls (each one was hit for real)

## Loading and shared code

- **One `package.loaded` slot per shared module.** The first copy loaded
  wins. An outdated plugin left on the device (it can stay even after Plugin
  Manager's "remove") imposed its old `screen_base` on every game.
  - Fixed by `module_guard` (game-common 1.14.0).
  - Never load shared modules any other way. Test with
    `scripts/dev/realinstall_test.sh` plus a stale plugin.
- **Plugin-own modules must use `lrequire`, never `require("board")`.** The
  names collide across plugins.
- **KOReader restores `package.path` after loading plugins.** Any module
  loaded later (lazily) needs the plugin's own dirs prepended, which
  `lazyrequire` does.
- **Shared-lib files are listed from the lib's committed HEAD.** An
  uncommitted new module (for example `keyboard_widget.lua` in 2026-10)
  never ships, and Wordle/Hangman crashed on the device.
- **`_meta.lua` must not set `name`** (deprecated since KOReader 2026.03).
  KOReader keys a plugin on its directory name, which must equal
  `main.lua`'s `name`, or settings and stats go to the wrong file.
- **A field named like a method hides the method.** `self.undo = UndoStack`
  hides `Board:undo()`, so screens must call `Board.undo(self.board)`.
  nonogram, numberlink and slitherlink crashed on Undo because of this.
- **The i18n table is global.** One key, one translation fleet-wide, so keep
  `scripts/dev/check_i18n.sh` at 0. "Classic" in one plugin is « Classiques »
  in another: use whole-phrase keys.

## Releases

- `bump_versions.sh` and the fleet bump re-bump plugins you just committed:
  they are no longer dirty, so run the fleet bump FIRST.
- `git push --follow-tags` does not push lib tags. Push tags explicitly.
- The manifest CI may push a `chore: regenerate manifest.json [skip ci]`
  commit. Fetch and rebase, keeping your manifest.
- `dist/` is gitignored, so use `git add -f dist/*.zip`. build_release does
  not delete zips of removed plugins.
- `raw_base_url` is manual. GitHub's raw CDN answers 200 even for a wrong
  branch, so check it.
- Archived repos cannot be pushed: unarchive through REST, push, then
  archive again. The release CI of a just-unarchived repo may fail on a tag
  race, which is harmless for a retired plugin.
- Forks have Actions and Issues disabled by default.
- A commit made in an archived plugin's checkout cannot be pushed, and a
  monorepo pointer to it breaks `git submodule update` on every fresh clone.
  arrowwords stayed that way from 2026-08 to 2026-11-12 (pointer to a commit
  that was never on GitHub): push first, then move the pointer.
- A category change makes update_manifest.py rewrite
  `game-common/game_categories.lua` without committing it, and
  `build_release.sh` packs that working copy into every zip it builds, while
  the manifest keeps the sha of the committed file. Unless you release
  game-common in the same batch, run `git -C game-common checkout --
  game_categories.lua` before building, and again after the second
  update_manifest pass (2026-11-19, Letter Pyramid: the new plugin passes
  its category to `GamesMenu.add` itself, so it did not need the new table).
  Commit the new table in the next game-common release: Letter Pyramid's
  was left out until 1.19.1 (2026-11-24), so every run rewrote it.
- For a release of one or a few plugins, build only them
  (`./scripts/build_release.sh <id>`). A full build rezips every plugin and
  changes every zip's sha256 in the manifest without changing a single
  version (Spelling Bee 1.2.11, 2026-11-24).
- A parallel Claude session may work in the same tree. Never commit its work
  in progress.
- The reverse also happens: a parallel release can reset your uncommitted
  `manifest.json` and `dist/` changes. On 2026-11-13, Book Drop 1.0.2 got its
  pointer on master while the manifest still said 1.0.1, so the Plugin Manager
  offered no update. Run update_manifest, build and commit in one go, then
  check the pushed manifest (`git show origin/master:manifest.json`).
- A build zips the working tree, not the commits: a parallel session's build
  ships your uncommitted files. On 2026-11-24 a fleet-wide build packed
  Spelling Bee's unreleased French word list into the zip published as
  1.2.12, until 1.3.0 replaced it 25 minutes later. Before building, check
  `git status` in every submodule you build and leave out any plugin with
  someone else's changes; build only the plugins you release (above).

## Generators and gameplay

- **French word lists have two sources (2026-11-24).**
  `boggle.koplugin/words_fr.lua` keeps its original list in its first
  `[[...]]` block, and the Grammalecte lexicon's forms in a second one
  (`boggle.koplugin/tools/lexicon_fr.py`). The build scripts of anagram,
  letterpyramid and spellingbee take their drawn and common words from the
  first block only, and the lexicon only for accepted words. Merging the two
  blocks would change their puzzles and the Daily Challenge. Additions go
  through `lexicon_fr.py`'s family filter; a bad word found later goes in
  `boggle.koplugin/tools/lexicon_blocklist_fr.txt` (its lemma is enough).
- **Spelling Bee's puzzle banks are not reproducible.** They were pruned by
  hand after generation (1.1.0, 1.2.3), so `build_words.py` keeps them unless
  given `--new-puzzles`, which adds sets back and changes the Daily Challenge.

- **Uniqueness checks:**
  - Check clues as early as possible: skyscraper's cell-by-cell check
    took 6 s, and row-at-a-time takes 0.02 s.
  - Count each solution once: nurikabe counted island growth orders.
  - Apply the rules exactly as the game states them. cave assumed "black
    cells form one group", while the in-game rule is "reach the edge".
- **No guessing.** The owner rejects puzzles that need "assume X, find a
  contradiction". Use a no-trial solver to grade difficulty. Nonogram now
  requires pure line logic.
- **Difficulty must really differ.** Measure clue counts and the deduction
  depth needed per level. These were all caught:
  - shikaku's three levels produced identical puzzles;
  - cave Hard was no harder than Medium;
  - nurikabe 15×15 Hard degenerated to one island.
- **Throwaway or double generation.** `Board:new()` generating, then the
  screen loading the save, or generating again. Use `Board:new{ empty = true }`.
- **Two readers must deal the same game from one code.** Two Kobos may run
  different KOReader (and LuaJIT) builds. Detective shuffled its clue lists
  in `pairs()` order, which a build may change (fixed 2026-11-10). Draw from
  `Duo.rng`, iterate in a fixed order, sort with no ties, compare strings by
  bytes (Lua's `<` follows the locale), and pin a few draws in a spec.
- **Generators must not use time budgets.** That breaks the Daily Challenge
  across devices.
- **Daily Challenge:** any change to a generator's random draws changes the
  daily puzzle once. Say so in the CHANGELOG.
- **Dashboard tiles:** call `showGame("solo")` explicitly for party-capable
  games. PluginBase remembers the last mode.

## UI on e-ink

- Big touch targets, minimal repaints (`"ui"`/`"fast"` refresh of the changed
  widget only), no animations. Cap live updates at 1 per second (stopwatch).
- `UIManager:setDirty(widget, ...)` only repaints top-level widgets (the
  screen). On a child board it just refreshes the old pixels: the tap seems
  ignored, unless something else (`updateStatus`) also dirties the screen.
  Pass the screen and keep the board's rectangle as the region
  (spellingbee 2026-11-18: letter taps showed nothing until Enter).
- KOReader's Button shrinks wide letters or wraps them, so keyboards set one
  font size for every key.
- In landscape the side panel is narrow. Keyboard games opt into
  `landscape_controls_ratio`.
- Long tile and menu labels: let them wrap onto two lines instead of "…".
  Party tiles use two lines.
- Never `UIManager:scheduleIn` from a game screen: the callback runs even
  after the screen closed or "New game" replaced the game (Othello's AI
  moved twice, Memory flipped back cards of the next grid). Use
  `self:schedule` and call `self:cancelScheduled()` when a new game starts
  (2026-11-24, game-common 1.20.0).
- The Kobo Aura has no sound. Alerts are screen flashes plus a frontlight
  blink.

## Device and environment

- Do not write the settings file after every move: a write is a full dump,
  a backup and an fsync (13-170 ms of CPU a move on the Kobo, measured
  2026-11-24). `saveState` defers it; code that calls `self.settings:flush()`
  itself on every move brings the cost back.

- Kobo Aura: 256 MB RAM, single core, landscape possible, an accelerometer
  that KOReader does not use, no physical page-turn buttons.
- A Kobo may not know its time zone, so converter / almanac offer a home
  city.
- Plugin Manager left Wi-Fi on after downloading (no `afterWifiAction`) up to
  1.7.4; since 1.7.5 closing its home screen hands Wi-Fi back to KOReader's
  setting. Suspected cause of the "sluggish until restart" report; not confirmed.
- In this sandbox, foreground `sleep` is blocked. Use `until …; do sleep 5; done`
  or background runs.
