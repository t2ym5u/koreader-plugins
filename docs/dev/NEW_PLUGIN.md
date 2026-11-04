# Writing a new plugin: checklist

Start from an existing plugin of the same kind, not from `_skeleton`. The
skeleton has no lazyrequire and no module guard.

| Kind | Good reference |
|---|---|
| logic puzzle with generator | `tracks.koplugin`, `skyscraper.koplugin`, `nurikabe.koplugin` |
| level-bank puzzle with progress ✓/★ | `trafficjam.koplugin`, `sokoban.koplugin`, `klotski.koplugin` |
| word game with dictionary + keyboard | `wordle.koplugin`, `hangman.koplugin` |
| board game with AI | `othello.koplugin`, `connect4.koplugin`, `awale.koplugin` (time-budget AI) |
| party game (reader on the table) | `boggle.koplugin` (party_mode), `werewolf.koplugin`, `quiz.koplugin` |
| utility (own Tools entry) | `quickcalc.koplugin`, `converter.koplugin` |

## Must have

- [ ] A unique id that doesn't collide with community plugins (check with
      `gh search repos "<id>.koplugin in:name"`), and a generic display name
      with no trademarks.
- [ ] `main.lua` with the same header as the references: `_dir`,
      `lrequire`, the **module guard block**, and `lazyrequire("screen")` in
      `createScreen`. Nothing heavy at load or init, checked by
      `test_startup_spec.lua`.
- [ ] Data loads on open, for the current language only, with `release()` on
      close.
- [ ] A screen built on ScreenBase:
  - title bar (☰ menu, ✕ close), status line;
  - "New game" in the action bar once the round is over;
  - menu in the fleet order: New game, Daily, Difficulty, Size…, Rules;
  - rules popup in EN and FR.
- [ ] `i18n_fr.lua` with fr/es/de, and 0 conflicts.
- [ ] Generator:
  - deterministic per seed, capped by counts only;
  - unique solution, no guessing;
  - difficulties that measurably differ;
  - ≤ ~40 ms worst case on the Mac, otherwise `gen_progress`.
- [ ] Saves through `plugin:saveState/loadState`, restored without
      regenerating (`Board:new{ empty = true }`). Old save formats are read or
      ignored safely.
- [ ] Specs for the logic, saves and determinism, plus timing bounds.
- [ ] Renders checked in portrait and landscape, FR and EN, at 212 dpi.
- [ ] `_meta.lua` (no `name`), `CHANGELOG.md`, `README.md` in fleet style with
      `images/<id>.png`, `LICENSE`, `CONTRIBUTING.md`, `.busted`.
- [ ] Category in `.github/scripts/categories.json`; utilities also go in
      dashboard `NON_GAME_IDS`.
- [ ] Onboarding and release as in RELEASE.md, after the owner's GO.

## Content rules (owner)

- Family-friendly. No figures known mainly for genocide, terrorism or
  dictatorship (for example "pas de Hitler"), no serial killers, no living
  private persons.
- Avoid trademarks in names and in generated content where possible. For
  example "Word tile game", not Scrabble.
- French first-class: French UI strings and French content banks where the
  game has text.
