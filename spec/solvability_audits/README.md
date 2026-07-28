# solvability_audits

Standalone Lua drivers checking that a plugin's generated puzzles are
actually solvable — uniquely, and/or by a human without guessing — as
opposed to `spec/*_spec.lua`'s fast deterministic unit tests. See
`docs/generator_robustness_audit.md`, "Human-solvability audit" section, for
the bug class these exist to catch and the methodology behind them.

These are **not** run by `busted spec/`: they drive many random generations
per difficulty and measure a statistical completion rate, which is slower
and noisier than a unit test. Run each one directly from the repo root:

```sh
luajit spec/solvability_audits/<script>.lua
```

Two kinds of script live here:
- **`*_solvability_check.lua`** — post-fix regression checks with pass/fail
  thresholds and a non-zero exit code on failure (wireable into CI). Only
  exist for plugins that got an actual fix.
- **`*_uniqueness_diagnostic.lua`** — pre-fix measurement only, no
  assertions, just prints the ambiguity rate found. Written during the
  Tier 2 diagnostic pass (2026-07-22) to triage severity *before* spending
  fix time — see `docs/generator_robustness_audit.md`'s Tier 2 table for
  the full write-up. Re-run one of these after attempting a fix to confirm
  it actually moved the needle; consider promoting it to a
  `*_solvability_check.lua` with real thresholds once a fix lands.

| Script | Plugin | Status |
|---|---|---|
| `sudokukiller_solvability_check.lua` | sudokukiller | **Fixed** — Easy/Medium fully solvable via naked/hidden singles + cage-combo elimination + 45-rule, no backtracking |
| `kakuro_solvability_check.lua` | kakuro | **Confirmed broken, unfixed** — 0/45 unique across all difficulties; extensively attempted, reverted (see file header for the full list of what was tried) |
| `kakuro_construction_attempts.lua` | kakuro | Reusable builder code from the fix attempts (staircase/brick/random layouts + an independent uniqueness counter) — not wired into anything, kept for whoever resumes this |
| `kakuro_size_experiment.lua` | kakuro | Tested whether larger grids (12x12+) dodge the ambiguity — inconclusive, hit a solver-performance ceiling before getting a real answer (see file header + `docs/generator_robustness_audit.md`'s "Kakuro follow-up" section) |
| `kakuro_external_research_sources.md` | kakuro | Reference list of external Kakuro generators/papers/puzzle-sources checked — `ChrisMoutsos/kakuro`'s "guaranteed unique" claim doesn't hold up under scrutiny; separately, every "free grids online" source found (krazydad, GitHub scrape dumps) has a licensing problem for redistribution, see file for why |
| `numbrix_solvability_check.lua` | numbrix | **Fixed** — dig-with-verification retrofit (sudoku-common pattern), 20/20 unique at every size/difficulty after the fix |
| `rippleeffect_solvability_check.lua` | rippleeffect | **Fixed** — same dig-with-verification retrofit, 20/20 unique at every size/difficulty after the fix |
| `suguru_solvability_check.lua` | suguru | **Fixed** — same dig-with-verification retrofit (code shape identical to rippleeffect minus the ripple rule), 20/20 unique after the fix |
| `binairo_solvability_check.lua` | binairo | **Fixed** — dig-with-verification retrofit + `_fill` now also enforces distinct rows/columns (a real rule it previously skipped). See file header: the *original diagnostic* also had its own bug that overstated the pre-fix severity — corrected there. 20/20 unique after the fix. |
| `futoshiki_solvability_check.lua` | futoshiki | **Fixed** — same dig-with-verification retrofit (constraint set chosen first and held fixed while digging givens), 20/20 unique after the fix |
| `skyscraper_solvability_check.lua` | skyscraper | **Fixed** — needed an extra layer beyond digging: an outer retry regenerates the Latin square itself if its *full* clue set isn't provably unique (digging alone can only remove information, so it can't rescue an already-ambiguous full clue set), then digs down to the target clue count as usual. 20/20 unique after the fix. |
| `hidato_solvability_check.lua` | hidato | **Fixed** — exact sibling of the numbrix fix (king-move `DIRS` instead of orthogonal), 20/20 unique after the fix |
| `hitori_solvability_check.lua` | hitori | **Fixed** — no "reveal a subset" mechanic exists here (every number visible from the start, puzzle = a shading), so instead of digging this generates+verifies whole candidate puzzles, escalating black-cell density in bounded steps when the nominal difficulty density keeps coming back ambiguous. 20/20 unique after the fix (n=7/easy up to 2.6s worst case). |
| `nurikabe_solvability_check.lua` | nurikabe | **Fixed at n=5, partial at n=10/15** — clues are structurally 1-per-island, so like hitori this generates+verifies whole candidate layouts instead of digging, using a region-tiling CSP counter. n=5: 13/15, 15/15, 15/15 unique (easy/med/hard). At n=10/15, proving uniqueness is usually computationally infeasible within a fast time budget (0/5 trials in 150 attempts at n=10) — falls back to the pre-fix behavior there (best structurally-valid, unproven), never worse. See file header for a real solver bug found and fixed along the way. |
| `fillomino_solvability_check.lua` | fillomino | **Fixed (2026-07-27)** — turned out to have two bugs stacked. First, `generateSolution` itself could produce self-contradictory grids (not just ambiguous ones): its leftover-cell fill and its `checkAdjacency` safety net were both broken (the latter was vacuous by construction — see file header). Fixed with `normalizeToValid`, a fixpoint relabeling pass that mathematically guarantees a valid grid, which also let the old retry-loop-with-degenerate-fallback be deleted. Second, once solutions were valid, `createPuzzle` had the same zero-uniqueness-verification bug as the rest of this tier — fixed with the usual dig-with-verification retrofit, using an MRV-over-regions counter (mirrors nurikabe's island-growing solver; a first attempt at raw per-cell value-guessing was sound but far too slow once regions exceed size ~20). 20/20 unique at every size/difficulty after the fix, generation still near-instant. |
| `tier4_sudoku_variants_check.lua` | sudoku, windoku, hypersudoku, sudokux, arrowsudoku, thermosudoku, betweenlines, sandwichsudoku | **Audited (2026-07-27), 2 fixed, 6 clean** — a different investigation shape than Tier 2: this tier's shared digging mechanism already checks uniqueness, so the real questions were (1) does each variant's *extra* rule actually get enforced during generation, and (2) does each plugin's own win-check accept its own true solution. windoku/hypersudoku/sudokux thread their extra rule through the shared module's `extra_regions` parameter correctly (0/60 violations each). arrowsudoku/thermosudoku/betweenlines derive their clue from the fixed solution (correctness-safe by construction) but via a bounded-retry placement loop — betweenlines and thermosudoku both had a real, low-severity clue-count shortfall (3/100 and 1/100 trials respectively), fixed by raising the attempt budget, the same fix pattern as bridges/starbattle/tapa. arrowsudoku and sandwichsudoku were never at risk (confirmed empirically). All 8 variants' win-checks confirmed to accept their own true solution (0/20 each) — rules out the hidato/numbrix/tatami class of bug. Also corrected a misclassification: `betweenlines` was wrongly listed as having no procedural generator at all. |
| `nonogram_solvability_check.lua` | nonogram | **Fixed (2026-07-27)** — Tier 3, Phase 2 of the remaining-audits roadmap. No "given" mask at all (row/col run clues ARE the puzzle); `generate()` had zero uniqueness verification, measured real graduated severity (n=15/easy 2/15 unique, n=5/hard 15/15). Fixed generate+verify style (nothing to dig): retry a random fill up to 400 times against a line-propagation uniqueness solver, keep the first provably-unique one. 20/20 unique after the fix. See file header: a first attempt at the solver tried MRV over row placement order on top of a left-to-right column state machine — not just slow, actually **wrong** (a column's clue depends on the true top-to-bottom sequence), caught by the standard sanity check. |
| `colornonogram_solvability_check.lua` | colornonogram | **Fixed (2026-07-27)** — same shape as nonogram, generalized to multi-color cells plus a color-dependent gap rule (mandatory gap between same-color runs only). Measured pre-fix: n=6/easy 6/15, n=8/easy 5/15 unique. Fixed the same generate+verify way, 20/20 unique after. |
| `starbattle_solvability_check.lua` | starbattle | **Fixed (2026-07-27)** — the existing solver only found the *first* valid star placement, never checked for a second. Measured pre-fix: only ~7% of accepted region layouts were actually unique at n=6/k=1 and n=10/k=2 (n=8/k=2 was already ~100%). Fixed generate+verify style: counts up to 2 solutions, `generate()` requires exactly 1, retrying up to 2000 times with a tuned-down per-attempt budget (an initial larger budget caused a real worst-case latency problem, ~13s, before tuning). 20/20 unique at n=6/n=8; ~90% at n=10/k=2 (worst ~5.3s) — real, substantial, not a full fix at the hardest setting. |
| `shikaku_solvability_check.lua` | shikaku | **Fixed (2026-07-27)** — one random clue-cell position per rectangle, zero uniqueness verification, severe pre-fix (0/15 unique at n=8/n=10). Fixed generate+verify style, cheaply: repicking which cell within a fixed rectangle holds the clue (up to 25 times) is far cheaper than re-splitting the grid and mostly sufficient on its own before falling back to a fresh partition. 20/20 unique after, worst case ~0.15s avg. |
| `tents_solvability_check.lua` | tents | **Fixed (2026-07-27)** — tree positions + row/col tent-count clues shown, unknown is which adjacent cell is each tree's tent. Win-check is literal comparison but the real ruleset (one tent per tree, no two tents touching, counts matching) needed its own MRV solver. Measured pre-fix: real, moderate ambiguity (60-87% unique, worse at hard). Fixed generate+verify style: retry the pairing up to 60 times. 20/20 unique after, still near-instant. |
| `lightup_solvability_check.lua` | lightup | **Fixed (2026-07-27)** — genuinely rule-based win-check (any bulb placement satisfying the rules is accepted, not literal comparison). Needed real constraint propagation (wall-forcing + illumination-forcing) to be tractable; a real solver bug (failed placement left corrupted state that `undo()` then used to wipe out a *different* cell's legitimate registration) was caught via the sanity check. Fixed generation via hitori-style reveal-ratio escalation (0.6→0.8→1.0) instead of blindly retrying the nominal ~60%. n=7/n=10 close to fully fixed (67-100%); n=14 only meaningfully improved at hard/medium — real partial fix, same shape as nurikabe's hardest sizes, but generation is fast everywhere now (worst ~4.8s, was occasionally 10s+ for zero benefit before tuning). |
| `bridges_solvability_check.lua` | bridges | **Fixed (2026-07-27)** — simpler than classic Hashiwokakero: `tapBridge` only adjusts bridge counts on connection slots the generator already chose (clamped to that slot's solution count), never invents a new connection, so the graph topology is fixed and already crossing-free by construction. Turned out to already be ~93-100% unique by construction once the counter's own forward-checking bug was fixed (see its file header — even a 20-million-node budget couldn't find the one known solution before that fix). Verify-and-retry closes the remaining gap: 20/20 unique after, still near-instant. |
| `tapa_solvability_check.lua` | tapa | **Fixed (2026-07-27)** — the hardest of this whole batch. No "given" mask, win-check is literal comparison. Needed incremental connectivity pruning to be tractable at all — a first version of that pruning was itself unsound (required the entire "maybe-shaded" region to stay one piece, wrongly rejecting valid states where an isolated pocket of undecided cells was always going to resolve to nothing; fixed by only rejecting when 2+ components each anchor a *confirmed* member). Also needed hitori-style clue-density escalation to actually fix generation (a first attempt just retrying the nominal ratio left it at ~0% unique even after 3000 tries). 20/20 unique at every size/difficulty after both fixes, worst case ~0.8s avg. |
| `slitherlink_solvability_check.lua` | slitherlink | **Fixed (2026-07-28)** — literal comparison to a stored loop; zero uniqueness verification pre-fix (n=5/easy 9/10 down to n=10/hard 1/10 unique). A first counter attempt used unsound incremental "no premature sub-loop" pruning via union-find — caught by the sanity check, dropped for clue-forcing + vertex-degree-forcing propagation with a final-only single-loop check. Fixed generate+verify style: escalates the clue-keep ratio in bounded steps per loop shape, with the node budget scaled down at n=20 to avoid a ~45s worst case. 15/15 unique at every size/difficulty after, worst case ~6.65s at n=20/hard. |
| `masyu_solvability_check.lua` | masyu | **Fixed (2026-07-28), partial at n=8** — the deepest bug of the whole audit: the rule-based win-check never required the marked cells to form a *single* loop, only that they satisfy the local degree/clue rules as a union of cycles, so almost any generated puzzle admitted a completely unrelated valid marking elsewhere on the grid — this held even at maximum clue reveal (a missing-rule bug, not a clue-density one). Fixed both `_checkWin` (added single-loop-connectivity) and the generator (always reveals every available clue candidate, retries with a fresh loop shape up to 40 times). n=6: 20/20 unique, ~instant. n=8: ~10-20% unique (up from an effectively-always-broken baseline), capped at a 2s wall-clock budget per attempt since proving uniqueness there requires exhausting the whole remaining search space and only a minority of shapes achieve that regardless of node budget (tested 20000 through 400000 — no material quality gain, just longer waits). Real, bounded improvement, not a full fix at that size. |
| `numberlink_solvability_check.lua` | numberlink | **Fixed (2026-07-28)** — win-check is a literal comparison to a full-grid path partition (not just "a connecting path exists"). The original generator sliced one serpentine Hamiltonian path into n_colors contiguous segments at a density (8/12/16 colors per 100 cells) far too low to be unique — confirmed severe (0% unique even after hundreds of retries at n=5). A first uniqueness-counter attempt had a real soundness bug: the cell-availability check let one color's path walk through *another* color's reserved clue endpoint, silently corrupting the search into false "unique" verdicts (caught by cross-checking against a second, unpruned reference solver — a new failure direction for this audit, an overly permissive prune producing false positives rather than false negatives). Once fixed, swept color density directly and found the real cause: per-attempt success only becomes reliable (>90%) around a 30%+ colors-per-cell ratio, roughly double the original. Fixed by raising `N_COLORS_PER_100` (25/32/40 instead of 8/12/16) plus the usual generate+verify retry loop with randomized segment-length jitter (the plain floor-division split is fully deterministic given n and n_colors, so retrying without varying the split could never explore anything new). **20/20 unique at every size (5/7/9/10) and difficulty**, worst case ~0.02s — a full fix, not partial, once the actual bug (density) was identified instead of assumed to be "just needs more verification." |

**Tier 2 diagnostic + fix pass is complete: all 10/10 plugins had a real bug,
all 10 addressed** (9 fully, 1 partially — nurikabe at n=5 only).

numbrix, rippleeffect, suguru, binairo, futoshiki, skyscraper, hidato,
hitori, and fillomino are fully fixed (confirmed hypothesis: a sudoku-
common-style dig-with-verification retrofit generalizes cleanly to Tier 2's
generous clue ratios, unlike kakuro's structural dead end). nurikabe is
fixed at its default size (n=5) but only partially at n=10/15 (see its row
— genuine computational hardness, not a bug left unfixed).

Six are plain dig-with-verification retrofits: dig cells/clues one at a time
from a fully-revealed state, verifying with an independent MRV/backtracking
uniqueness counter after each tentative removal, putting it back if removal
broke uniqueness. Four needed more:
- **skyscraper**: an outer retry regenerating the Latin square itself when
  digging alone can't fix an already-ambiguous full clue set.
- **hitori**: no "reveal a subset" mechanic exists at all, so it
  generates+verifies whole candidate puzzles with escalating density
  instead of digging.
- **nurikabe**: same shape as hitori (nothing to dig), plus its own solver
  had a real, separate bug (see its row) that made proving uniqueness both
  wrong and pathologically slow before the MRV-over-islands rewrite.
- **fillomino**: needed a fix to the *solution generator itself* before
  digging could even apply (see its row — a vacuous adjacency check let
  self-contradictory solutions through), and its uniqueness counter needed
  the same "rewrite as MRV-over-regions" lesson as nurikabe once raw
  per-cell value-guessing proved intractably slow.

**Lesson from the binairo fix**: don't trust a solvability counter without
cross-checking it against a second, differently-written implementation —
binairo's original diagnostic had a real bug (a full-row run-tracker that
treated undetermined cells as transparent to a run-of-3 check) that
inflated a real-but-moderate bug into an apparent 0%-unique-everywhere
failure. An unusually *uniform* bad result across every size/difficulty is
itself worth a second look before trusting it. **Same lesson recurred with
nurikabe's own solver** (row-major join-via-neighbor order-dependency bug)
— when a "fixed" plugin still shows `sol=0` or pathological slowness after
wiring in a uniqueness gate, suspect the counter itself before concluding
the puzzle is just hard.

**Tier 4 (sudoku-variant siblings) audited and complete, 2026-07-27** — see
`tier4_sudoku_variants_check.lua`'s row above and its file header. Unlike
every tier above, this one was never suspected of the "zero uniqueness
check" bug (the shared digging module already verifies uniqueness at every
step) — the actual bugs found here were in the *older* fallback/degenerate-
output bug class from this repo's very first robustness sweep (a
bounded-retry clue-placement loop with too tight a budget), just showing up
in a tier that hadn't been swept for it yet. Worth remembering: a tier being
"lower suspected risk" for one bug class doesn't mean it's risk-free for a
different, older bug class that simply hadn't been checked there yet.

**Tier 3, Phase 2 (nonogram + colornonogram) fixed 2026-07-27** — see their
rows above. Both have no "given" mask at all (the row/col clues ARE the
puzzle), so both needed the standard nonogram line-solving technique built
from scratch: enumerate every valid full line per row/column clue, then
propagate row/column candidate sets against each other to a fixed point,
branching only on genuine choice points (size >= 2). **Real lesson from
building this solver**: a first attempt applied MRV over *which row to
place next* on top of a left-to-right incremental per-column state
machine — this isn't just slow, it's wrong, since a column's run-length
clue is defined by the true top-to-bottom sequence, and letting rows get
placed in an arbitrary (most-constrained-first) order silently feeds the
column state machine cells in the wrong sequence. Caught immediately by
the standard sanity check (solver returned 0 solutions for the generator's
own known-good clues) — yet another instance of the recurring lesson in
this file: when a "fixed" plugin's solver returns `sol=0` for known-good
input, suspect the solver's own order-dependence before concluding
anything about the puzzle.

**Tier 3, Phase 3 (bridges, shikaku, starbattle, tents, lightup, tapa)
fixed 2026-07-27** — see their rows above and each plugin's own check file
header for the full writeup. Severity varied more across this batch than
any tier before it — bridges was already ~93-100% unique by construction
once its counter's forward-checking bug was fixed, while the rest showed
the usual 0%-everywhere severity. Two lessons worth carrying forward:
- **Forward-checking, not just bound-checking, matters for degree-
  constrained CSPs.** bridges' first counter only checked that a candidate
  edge value didn't exceed what a vertex had left, never that the
  leftover was actually reachable by that vertex's other undecided edges
  — even 20 million nodes couldn't find its one known solution before
  this was fixed, wasting nearly all effort on combinations that only
  fail the final exact-degree check once everything is decided.
- **Retrying the same nominal setting doesn't help when that setting is
  itself rarely unique.** lightup and tapa both needed hitori's fix
  pattern — escalate a density/reveal parameter in bounded steps — rather
  than blindly repeating identical-distribution attempts. As first
  shipped for both, a plain retry loop left the "fix" doing nothing (0%
  unique even after thousands of attempts) while adding pure latency (up
  to 10s+ for zero benefit) — a good reminder to actually re-measure after
  a fix lands, not just assume "more retries" worked.

tapa also needed incremental connectivity pruning to be tractable at all
(without it, only ~6-15 clue cells govern 50-90+ free cells — far too
little local structure to prune a naive backtracking search). The first
version of that pruning was itself unsound: requiring the ENTIRE
"maybe-shaded" region to stay one connected piece wrongly rejects valid
states where an isolated pocket of merely-undecided cells was always
going to resolve to nothing. Fixed by only rejecting when 2+ components
each already anchor a *confirmed* shaded cell — caught, like every other
solver bug in this audit, by the standard sanity check against the
generator's own known-good output.

**Tier 3, Phase 4 (slitherlink, masyu, numberlink) fixed 2026-07-28 —
Phase 4 is now complete.** slitherlink was the routine case: literal
comparison, zero uniqueness check, fixed the standard generate+verify way
(15/15 unique after, worst ~6.65s at n=20/hard). masyu was the deepest bug
of the whole audit — a *missing rule* in the win-check itself (no
single-loop-connectivity requirement), not just under-verified clue
placement; see its row above and file header. numberlink surfaced two
lessons worth remembering for any future puzzle that partitions a whole
grid into several interacting pieces rather than having one independent
shape:
- **An overly permissive "is this cell free" check can silently corrupt
  shared mutable state and produce FALSE POSITIVES for uniqueness** — the
  opposite failure direction from every prior solver bug in this audit
  (which all *undercounted* wrongly, reporting ambiguous puzzles as
  needing more search, or reported 0 solutions for known-good input).
  Here, letting one color's path walk through *another* color's reserved
  clue endpoint let the search silently steal that cell, corrupting the
  ownership bookkeeping in a way that made the counter wrongly conclude a
  puzzle was uniquely solvable. Caught the same way as every other bug in
  this audit — cross-checking against a second, independently-written
  solver on a fixed seed — but the failure direction (false "unique," not
  false "ambiguous" or a `sol=0` sanity-check failure) is new; worth
  explicitly checking for whenever a solver's pruning depends on shared
  state that multiple sub-searches read and write.
- **Not every "0% unique" result is a missing-verification bug — sometimes
  the underlying density genuinely is too low, and no amount of retrying
  the same construction fixes it.** Once the soundness bug above was
  fixed, numberlink still measured 0% unique even after hundreds of retries
  at the game's original color density (2-4 colors on a 25-cell grid at
  n=5). Sweeping color count directly (bypassing `generate()` entirely)
  showed per-attempt success only becomes reliable past roughly a 30%
  colors-per-cell ratio — about double what the original difficulty
  tuning used. Raising the density fixed it completely: 20/20 unique at
  every size and difficulty, and *faster* than before (more, shorter paths
  are cheaper to verify than fewer, longer ones) — one of the fastest,
  most complete fixes in the whole audit, but only findable by measuring
  the true relationship between a tunable generation parameter and
  uniqueness, rather than assuming a verify-and-retry gate alone would
  eventually succeed.
