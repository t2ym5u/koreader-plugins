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
- Never stage arrowwords or kakuro. They are archived and dirty locally.
  arrowwords holds a stranded i18n fix.
- A parallel Claude session may work in the same tree. Never commit its work
  in progress.

## Generators and gameplay

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
- **Generators must not use time budgets.** That breaks the Daily Challenge
  across devices.
- **Daily Challenge:** any change to a generator's random draws changes the
  daily puzzle once. Say so in the CHANGELOG.
- **Dashboard tiles:** call `showGame("solo")` explicitly for party-capable
  games. PluginBase remembers the last mode.

## UI on e-ink

- Big touch targets, minimal repaints (`"ui"`/`"fast"` refresh of the changed
  widget only), no animations. Cap live updates at 1 per second (stopwatch).
- KOReader's Button shrinks wide letters or wraps them, so keyboards set one
  font size for every key.
- In landscape the side panel is narrow. Keyboard games opt into
  `landscape_controls_ratio`.
- Long tile and menu labels: let them wrap onto two lines instead of "…".
  Party tiles use two lines.
- The Kobo Aura has no sound. Alerts are screen flashes plus a frontlight
  blink.

## Device and environment

- Kobo Aura: 256 MB RAM, single core, landscape possible, an accelerometer
  that KOReader does not use, no physical page-turn buttons.
- A Kobo may not know its time zone, so converter / almanac offer a home
  city.
- Plugin Manager leaves Wi-Fi on after downloading (no `afterWifiAction`).
  Suspected cause of the "sluggish until restart" report; not confirmed.
- In this sandbox, foreground `sleep` is blocked. Use `until …; do sleep 5; done`
  or background runs.
