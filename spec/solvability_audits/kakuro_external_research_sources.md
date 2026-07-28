# Kakuro external research — sources (2026-07-22)

Consulted while checking whether an existing open-source Kakuro generator
had already solved the uniqueness problem documented in
`kakuro_solvability_check.lua` / `kakuro_construction_attempts.lua`. See
`docs/generator_robustness_audit.md`'s "Kakuro follow-up" section for the
findings; this file is just the reference list.

- [ChrisMoutsos/kakuro](https://github.com/ChrisMoutsos/kakuro) — Qt GUI app,
  claims a generator "guaranteed to have a unique solution". Read
  `puzzleboard.cpp`'s `generateBoard()` in full: the uniqueness claim rests
  on a logic-solver-reaches-completion heuristic (fix an ambiguous cell,
  check if deduction then finishes the grid), not an independent solution
  count — doesn't actually prove uniqueness. Its black/white layout
  generation (per-cell random non-clue chance) is the same class already
  tried in `kakuro_construction_attempts.lua`'s `buildRandomGrid` (0/60+
  unique at 9x10 in this repo's own testing).
- [Hafthor/Kakuro](https://github.com/Hafthor/Kakuro) — solver/generator,
  not inspected in depth (found via search, not read).
- [itomi/kakuro](https://github.com/itomi/kakuro) — generator + solver, not
  inspected in depth.
- ["Kakuro as a Constraint Problem" (ResearchGate)](https://www.researchgate.net/publication/228524341_Kakuro_as_a_Constraint_Problem) —
  academic paper modelling Kakuro as a finite-domain CSP with `alldifferent`
  constraints; relevant to a future real fix (proper constraint propagation
  rather than backtracking + a naive sum-range prune) but not read in depth
  this session.

## Follow-up (2026-07-28): searched for ready-made puzzle *content* (not code) — licensing is the real blocker

User asked directly whether free, usable kakuro grids exist online to hardcode
(the original ask from the start of this whole investigation). Found plenty of
puzzle *content*, but every source has a licensing problem for embedding in a
redistributed, open-source plugin:

- [KrazyDad](https://krazydad.com/kakuro/) — thousands of puzzles with answer
  keys, PDF format. Checked the terms directly: *"Feel free to reproduce the
  puzzles for personal, church, school, hospital or institutional use... please
  do not use my puzzles in for-profit publications without my permission"* —
  explicitly excludes "app or website" use without buying a license. **Not
  usable as-is.**
- [ThePuzzleLabs](https://www.thepuzzlelabs.com/kakuro/printable),
  [puzzles-to-print.com](https://www.puzzles-to-print.com/number-puzzles/kakuros.shtml),
  [djape.net](https://djape.net/free-puzzles/), [mathequalslove.net](https://mathequalslove.net/kakuro-puzzles/) —
  same category of "free printable PDF" site; none state a redistribution/
  embedding license, all read as personal/classroom-use-only by convention in
  this space. Not checked term-by-term (krazydad's explicit refusal was
  enough of a pattern signal), but treat as **not usable** without contacting
  each site owner individually.
- [heetbeet/purge-and-merge](https://github.com/heetbeet/purge-and-merge) —
  GitHub repo, MIT-licensed *code*, but its `kakuro-collection/` (6360 puzzles)
  is explicitly "sourced from en.grandgames.net" — i.e. scraped from a
  commercial puzzle site. The repo carries no license grant *for the scraped
  content itself*, and grandgames.net's own terms were never checked/granted.
  Repackaging scraped third-party puzzle content this way doesn't launder the
  license. **Not safely usable.**
- [SmilingWayne/puzzlekit-dataset](https://github.com/SmilingWayne/puzzlekit-dataset) —
  48k+ instances across 130+ puzzle types, "mostly from Raetsel's Janko [janko.at]
  and puzz.link". No `LICENSE` file in the repo (confirmed via `gh api`,
  404). Same problem as above: crawled from third-party archives whose own
  reuse terms were never confirmed. **Not safely usable** without verifying
  janko.at/puzz.link's terms first (not resolved this session — janko.at's
  terms page wasn't findable via search).

**Conclusion carried forward**: every "free grids on the net" lead found so
far is free to *look at*, not free to *embed in redistributed software* —
either explicitly excluded (krazydad) or unlicensed-for-reuse (the two GitHub
scrape dumps). This is a different kind of dead end than the earlier
generator-algorithm research: it's not a technical gap, it's a licensing one,
and no amount of searching harder fixes it — it needs either (a) a source that
explicitly grants redistribution/commercial use (not found yet), (b) direct
permission from a site owner (krazydad explicitly invites this for "app or
website" use), or (c) generating puzzles ourselves, which sidesteps licensing
entirely since a procedurally-generated grid is original content — putting the
weight back on fixing/rewriting `countSolutions` rather than sourcing content.
