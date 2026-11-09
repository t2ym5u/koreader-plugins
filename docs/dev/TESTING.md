# Testing

The tools live in `scripts/dev/`; see its README for env vars and options.
Run every step below before showing a change to the owner.

## 1. Specs (busted)

```bash
scripts/dev/run_specs.sh <plugin> ...        # or --changed / --all
```

- Homebrew busted runs Lua 5.5, which has no `bit` module. Without the shim
  in `scripts/dev/bitshim/`, the sudoku specs error out and busted **still
  exits 0**, so always read the summary line.
- Run each plugin's specs from its own directory. Some specs open files
  relative to the current directory, so a single root-level busted run
  reports false errors.
- zsh does not word-split `$VAR`. Write multi-plugin loops as bash scripts,
  and use `for x in $(cat file)`, never `while read < file`, which hangs in
  this sandbox.
- Pure-logic modules (generators, solvers, scoring, formatting) must have
  specs. Typical regression specs:
  - uniqueness on N seeds per size and difficulty;
  - no guessing needed;
  - determinism (same seed gives the same puzzle);
  - a generous timing bound;
  - save/load round-trip, including old saves;
  - nothing heavy at startup (`test_startup_spec.lua`).

### Difficulty specs (`test_difficulty_spec.lua`)

Every game with levels, sizes that change the difficulty, or a computer
opponent has one `test_difficulty_spec.lua`, which holds its difficulty
guarantees (moved there from other specs, not duplicated). Run them all with:

```bash
SPECS=test_difficulty_spec.lua scripts/dev/run_specs.sh --all
```

What it checks, as far as the game allows:

- **Generated puzzles**, for each size × level, on a few fixed seeds:
  - the puzzle builds, within a generous time bound;
  - it is unique and solved by the game's own solver **without trial**
    (single-cell "assume X, find a contradiction"), within the level's
    technique cap; enumerating the ways to fill one region/line is allowed;
  - Easy needs only the basic techniques;
  - the levels are **distinct and in order** on the game's own measure
    (hard steps, tier, givens, path length...): Easy < Medium < Hard, on
    averages over the seeds, never on a single grid;
  - the same seed gives the same puzzle, and generation never reads the
    clock.
- **Computer opponents:** the level table is ordered (depth, budget, noise),
  each level plays legal moves, takes an immediate win and blocks an
  immediate loss where the game has them, plays the same game for the same
  seed, and stays within its time budget at Kobo scale. No full matches:
  they are too slow and too noisy for a spec.
- **Level banks and word lists** (sokoban, klotski, chess puzzles, word
  games...): each level's entries sit in its documented band (moves, word
  length, distance...) and the bands are ordered.

Keep each file under about 30 s with Homebrew busted: few seeds, small
sizes first. Use counts, never the clock, to bound the work.

## 2. Translations

```bash
scripts/dev/check_i18n.sh      # must report 0 conflicts
```

## 3. Headless renders, and look at them

```bash
cd "$KOREADER_EMU" && SP=... RENDER_DPI=212 ./luajit "$REPO/scripts/dev/render_screen.lua" <id> out.png 758 1024 fr
```

- Render at 212 dpi, the Kobo Aura's, in portrait 758×1024 and landscape
  1024×758, in FR and EN.
- Then open the PNG. Check for cut-off text, untranslated strings, cramped
  keys, and uneven fonts. KOReader's own widgets (for example the "Page 1 of
  N" pagination) stay English in the emulator, which has no l10n.
- README screenshots are 1080×1440 (or 1072×1448), 8-bit greyscale.

## 4. Speed

- Rule of thumb: **Kobo Aura ≈ Mac × 25** for pure Lua. A single-core
  Cortex-A9 runs at about 2–3 s of wall time per 100 ms on the Mac.
- Measure the WORST case over ≥ 30 seeds for every size × difficulty, cap each
  run with `timeout`, and use `io.stdout:setvbuf("no")`.
- Targets:
  - generation ≤ ~40 ms on the Mac (≈ 1 s on the Kobo); above ~20 ms, show
    `gen_progress`;
  - AI moves ≤ ~2.5 s on the Kobo, using iterative deepening under a CPU
    budget (see awale/morris).
- **Generators never read the clock.** Cap work with node or attempt counts
  so a seed gives the same puzzle on every device; the Daily Challenge relies
  on this. masyu once had an `os.clock` cap, so its output depended on the
  device.
- When you rewrite a solver, keep the old one in a spec or scratch script and
  cross-check it on thousands of random instances. Report the number of
  mismatches (must be 0).
- After a solver change, AI changes need measured matches with randomised
  openings, comparing new and old at the Kobo-scaled budget.

## 5. Memory and startup

```bash
cd "$KOREADER_EMU" && ./luajit "$REPO/scripts/dev/startup_cost.lua"        # per-plugin heap+ms at load/init, totals
cd "$KOREADER_EMU" && ./luajit "$REPO/scripts/dev/open_close_probe.lua" <id> fr   # open/new/close/reopen, retained after close
```

Reference values from 2026-11-04, with all plugins: about 11 MB heap at
startup, against 8.35 MB with KOReader's own plugins only.

## 6. Real install, including an outdated plugin

This catches load-order and shared-module bugs that a symlinked dev tree
hides.

```bash
scripts/dev/make_stale_plugin.sh          # builds an old plugin with an ancient common/
scripts/dev/realinstall_test.sh            # installs dist/*.zip copies (+ optional stale), opens games via
                                           # Tools→Games, Tools entries, Dashboard launchGame, Daily
```

Do this whenever you change WHEN or HOW shared modules or screens load.

## 7. On the device

- With the Kobo connected over USB and "Connect" chosen on the device, it
  mounts at `/Volumes/KOBOeReader/.adds/koreader/`.
- The files to check there:
  - `crash.log`: read it before guessing;
  - `plugins/`: what is really installed;
  - `git-rev`: the KOReader version;
  - `patches/`: the user patches.
- Ask the owner before changing anything there. To take a plugin out, MOVE it
  into `plugins_retired/`; that stays reversible.
- Hidden folders: in KOReader's file browser use Settings → Show hidden
  files; in Finder press Cmd+Shift+.
