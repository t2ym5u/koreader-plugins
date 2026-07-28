# Generator robustness audit

Triggered by a real bug found 2026-07-20 in `bridges.koplugin`: its generator
retried a bounded number of times, then silently degraded to a hardcoded
"emergency fallback" puzzle (2 islands) when generation kept failing —
14-83% of the time depending on grid size. Not caught by `spec/bridges_spec.lua`
because unit tests call `generate()` once/twice with fixed inputs; the bug
only shows up statistically across many random seeds. See
`git log --oneline -- bridges.koplugin/board.lua` around 2026-07-20 for the fix
(island density scaled with grid area instead of a fixed 8-14 count).

This doc tracks a systematic sweep: every plugin with a procedural generator
gets a standalone Lua driver script (`loadfile("board.lua")()`, call
`generate()` across hundreds of random seeds/sizes/difficulties, check for
the fallback marker / degenerate output / crashes / solvability). Method is
in **How to test a plugin** below.

## Status as of 2026-07-21 (updated: all 4 originally-deferred bugs now fixed)

All 19 plugins with a bounded-retry-loop generator pattern (the table below)
have been tested, and every bug found in this pass has now been fixed —
**10 real bugs found and fixed, 9 came back clean.**

- **Fixed**: bridges, cave, hidato, numbrix, kakuro, starbattle, tapa (first
  pass), then tatami, nurikabe, rippleeffect, suguru (follow-up pass, after
  initially being deferred as "deep/structural" — see each row for what
  actually unblocked them). The headline fix is **tatami**: its win
  condition was *mathematically impossible* to satisfy on either supported
  board size, not just improbable — see that row. **fillomino** was
  re-classified from "clean" to "fixed" later (2026-07-27), during the
  separate human-solvability audit below — its `checkAdjacency` fallback
  guard turned out to be vacuous (never actually rejected anything), so the
  30-attempt retry silently succeeded on essentially the first try even when
  producing a self-contradictory grid; see the Tier 2 table's fillomino row.
- **Clean, no bug**: battleship, hitori, shikaku, slitherlink,
  sudokukiller (different failure shape, already acceptable by precedent),
  tents, wordsearch
- **Session 2 (same day)**: all 17 "lower priority" plugins tested/reviewed
  — 0 bugs found (2 of the 17, dames/puissance4, turned out to have no
  procedural generator at all). Regression specs added for the 7 plugins
  fixed in session 1 that had zero test coverage (cave, hidato, numbrix,
  starbattle, rippleeffect, suguru, tatami). See the lower-priority table
  below for details.
- **Still open**: galaxies/masyu (already tracked in
  [[project_generator_bugs_2026-07-17]], deep structural issues, not
  re-tested here) — the only remaining known generator bugs in the repo.

## Status legend
- ⬜ not started
- 🔄 in progress
- ✅ tested, no bug found (or bug found+fixed, low residual risk)
- 🐛 bug found, fixed
- ⚠️ bug found, NOT fixed (deferred — see notes)
- ➖ no procedural generator, out of scope

## High-priority: has a bounded retry-loop + fallback/degrade pattern
(this is the exact shape of the bridges bug — grep hit for `for attempt`/
`for _attempt`/`MAX_ATTEMPTS` + a hardcoded fallback puzzle)

| Plugin | Status | Notes |
|---|---|---|
| bridges | ✅ fixed | island density was fixed at 8-14 regardless of n; scaled with n² instead. 0/2700 fallback after fix (was up to 83% on 11×11). |
| battleship | ✅ clean | `for _ = 1, 50 do` ship placement retry; tested 0/1000 fallback (n=8,10). No fix needed. |
| cave | 🐛 fixed | 100% fallback (not a fluke — every generation hit the ring fallback) on all sizes/difficulties. Two stacked bugs: (1) per-step excavation gated on `has2x2Shaded` over the **whole grid** instead of locally — since un-shading a cell can only ever clear 2x2 violations, never create one, this check was backwards and deadlocked excavation at 1 cell. (2) even after removing that check, random-walk-from-center excavation rarely reaches the corners/edges of the interior, so border-adjacent 2x2 violations remained at the end almost every time. Added a deterministic repair pass after excavation that unshades one interior cell per remaining violating 2x2 block (always possible since the border ring is only 1 cell thick). 0/2700 fallback after fix; sample boards look like real cave puzzles, not degenerate. `busted spec/` (367 tests, cave has no dedicated spec) still green. |
| fillomino | 🐛 **fixed (2026-07-27)** | The original "clean" verdict here only checked for the *degenerate-fallback* symptom, not correctness — see the Tier 2 human-solvability table below for the real bug (generator could produce self-contradictory grids) and its fix. |
| hidato | 🐛 fixed (critical) | Two bugs, the first much worse than a "fallback rate": the Warnsdorff-DFS success check was `if step > total then return true end`, but `dfs` is only ever called with `step` up to `total` (there's no "cell total+1" to recurse into) — so the search could **never** recognize success and always backtracked the very last placement, guaranteeing 100% failure on every attempt/every size. For n≥5 the resulting full-tree exhaustive search is combinatorially huge: reproduced a single `generate()` call hanging 15+ seconds (killed it; true worst case is likely far longer) before falling back. Fixed the base case to `if step == total then return true end` (checked right after marking the cell visited) — now succeeds instantly (0.000s, 0/300 fallback, n=5/6) and every generated solution was verified to be a genuine valid king-move Hamiltonian path (200 samples/size). Also added a `NODE_BUDGET_PER_START` cap as defense-in-depth against any future pathological seed, and fixed the *fallback itself*: it used straight row-major order, which is not actually a valid king-move path (the jump from column n to column 1 between rows isn't adjacent) — replaced with a proper boustrophedon/snake order, which is always genuinely valid. `busted spec/` (no dedicated hidato spec) still green. |
| hitori | ✅ clean | `for attempt = 1, 50 do`; tested 0/600 fallback (n=5,7 × 3 difficulties), sub-millisecond timing throughout. No fix needed. |
| kakuro | 🐛 fixed | 99.7% fallback on "easy" (medium/hard so slow the 300-trial test didn't finish in 60s) — every generation landed on the *same* hardcoded 5×5 emergency puzzle. Cause: `generateFromTemplate` picked a random target **sum** per run independently, *then* asked `solveGrid` to find digit placements hitting all those targets simultaneously — for runs sharing cells (any real kakuro grid) that's almost always mutually infeasible, and only 10 retries. But the target was never actually needed: the puzzle's displayed clue numbers are computed from whatever `sol` the solver lands on (`acl`/`dcl`), not from `run.target` — so the sum-matching constraint in `bt()` was pure self-sabotage. Removed the pre-assigned targets and the sum-feasibility pruning in `bt()`, leaving only the real constraint (no repeated digit within a run); clues are still derived from the solved grid afterward, unchanged. 0/900 fallback after fix (all 3 difficulties), and `spec/kakuro_spec.lua` (16 tests) still green. Also deleted the now-dead `minSum`/`maxSum`/`curSumRem` helpers. |
| lightup | ✅ clean | `for _ = 1, 20 do`; tested 0/1800 fallback (n=7,10,14 × 3 difficulties). No fix needed. |
| numbrix | 🐛 fixed | Exact sibling of the hidato bug (this file's DFS is a near-identical copy with orthogonal instead of king-move `DIRS`): `if step > total then return true end` was unreachable. Fixed the same way (`step == total` check right after marking visited, plus a node budget for defense-in-depth). Unlike hidato, this one's fallback (snake pattern) was *already* correct since orthogonal adjacency doesn't have the diagonal-jump problem. 0/600 fallback after fix, all 200 sampled solutions verified as genuine valid orthogonal Hamiltonian paths. |
| nurikabe | 🐛 **fixed (2026-07-21, follow-up session)** | Root cause was confirmed to be exactly the "constraints checked only after the fact" issue described below, but the actual fix didn't need a full constructive rewrite: (1) growth is now round-robin (one cell per island per round, not fully growing island 1 before starting island 2) **and** each candidate cell is only accepted if a full black-connectivity BFS confirms removing it wouldn't disconnect the rest of black — i.e. connectivity is enforced incrementally during growth instead of checked once at the end and discarded on failure; (2) added a repair pass after growth that fixes any remaining 2x2-black violations by carving one cell from each violating block into an existing (or brand-new size-1) island, using the same connectivity check, and skipping the carve if it would ambiguously merge two different islands. Verified 0/700 fallback (n=5/10/15 × all 3 difficulties, sampled), `spec/nurikabe_spec.lua` (16 tests) still green, and an end-to-end test reconstructing 20 full solutions via `setCellState` + `validateRules()` all pass with zero rule violations. **Performance note**: the O(n²) connectivity check per candidate makes the most extreme setting (n=15/hard = 40 islands) slow — 0.5-4.2s per generation, sampled 12 times, no outliers beyond that range. Smaller sizes/easier difficulties are fast (n=15/medium avg 0.37s, n=10 any difficulty well under 0.25s). Consistent with this repo's existing accepted tradeoff for expensive-but-bounded generation (see [[project_sudoku_generator_perf]]) — not treated as a new bug, but worth a progress indicator if it's reported as feeling slow in practice. *(Original finding: 47-69% fallback at n=5, 100% at n=10/n=15, overwhelmingly due to `black not connected`; an in-session attempt at plain round-robin growth without the connectivity check had negligible effect, confirming the fix needed to be connectivity-*aware*, not just differently-ordered.)* |
| rippleeffect | 🐛 **fixed (2026-07-21, follow-up session)** | Replaced the whole "generate a blind random room layout, then run a full backtracking solve, retry from scratch on failure" approach with a constructive one: `tryGenerateRoomsAndValues` grows each room one cell at a time, assigning the next value (1, 2, 3, ...) immediately and checking it against every value already placed anywhere on the board — a room simply stops growing early if no neighbour can validly take the next value, instead of committing to a shape that might turn out unsatisfiable. A repair pass handles any cells the main growth never reached (extend an adjacent room, or start a fresh size-1 room); returns nil only if that's impossible, letting the caller retry cheaply since there's no search involved. Bumped the retry cap from 15 to 100000 — safe because each attempt is now genuinely cheap (no solve). Verified 0/220 fallback across n=5 (fast, <0.02s), n=6 (<0.44s), and n=7 (the hardest size: 0/60 across all 3 difficulties, avg ~1.7s, worst case ~5.6s — bounded but on the slow side, consistent with this repo's existing tolerance for expensive generation, see [[project_sudoku_generator_perf]]). `check()`-based end-to-end reconstruction test (10 full solutions) all pass with `won=true`. No dedicated spec file exists yet. *(Original finding: "just retry more" alone didn't work here even at 400 attempts — confirmed exhaustively that per-attempt success probability was too low, ~0.05-0.1% at n=6 and worse at n=7, even 30000 attempts left n=7 mostly failing; the fix had to change **how** attempts are generated, not just how many.)* |
| shikaku | ✅ clean | Constructive `splitRect` partition (always valid by construction, not random-placement-then-validate), so this class of bug doesn't apply. Tested 0/2700 degenerate output; `spec/shikaku_spec.lua` (19 tests) green. |
| slitherlink | ✅ clean | Region-growth-then-boundary-extraction approach; `isSingleLoop` correctly rejects growth that creates a hole (multi-loop). Tested 0/800 fallback (n=5,10,15,20), sub-millisecond timing; `spec/slitherlink_spec.lua` (17 tests) green. |
| starbattle | 🐛 fixed | 91% fallback at n=8/k=2 (0% at n=6/k=1, 6% at n=10/k=2) to the trivial 6×6 diagonal layout, discarding the requested size/k entirely. Each failed attempt (region generation + a 200000-iteration-capped backtracking solve) was fast to fail — mostly proven-infeasible region layouts, not the solver timing out — so the fix was simply raising `max_attempts` from 10 to 500: cheap per attempt (~0.00009s at n=8) means even a ~1%-per-attempt success rate clears up reliably well within a second. 0/300 fallback after fix (all 3 size/k combos), n=10/k=2 worst-case ~1.7s which is on the high side but bounded and one-time (comparable to precedent for other slow generators in this repo, see [[project_sudoku_generator_perf]]). |
| suguru | 🐛 **fixed (2026-07-21, follow-up session)** | Same fix pattern as rippleeffect: replaced blind "generate cage layout, then full backtracking solve, retry from scratch" with `tryGenerateCagesAndValues` — grows each cage one cell at a time, assigning the next value immediately and checking it against the 8-neighbour rule everywhere already placed on the board, stopping a cage's growth early rather than committing to an unsatisfiable shape. A repair pass handles cells the main growth never reached. Bumped `MAX_ATTEMPTS` from 20 to 100000 (safe since each attempt is now cheap, no solve). Verified 0/240 fallback (n=5 fast, <0.04s; n=6 the hardest size, 0/40 avg 0.61s / worst 1.8s — bounded, consistent with this repo's tolerance for expensive generation). End-to-end reconstruction test (10 full solutions via `setCell` + `check()`) all pass clean. No dedicated spec file exists yet. *(Original finding: bumping the old solve-based `MAX_ATTEMPTS` from 20→500 didn't help at all, still 96.7% fallback — confirming, like rippleeffect, that the fix had to change the generation strategy itself, not just retry more.)* |
| sudokukiller | ✅ clean (different failure shape by design) | This one's retry loop (`generateVerifiedCages`, `CAGE_GEN_MAX_ATTEMPTS`=5) already has thoughtful degrade-gracefully design: it never falls back to anything trivial/broken — worst case is a structurally valid cage partition whose solution-uniqueness is merely unproven or (rarely) not proven unique, never an empty/degenerate cage list (0/24 sampled). Generation takes ~1.5-2s per call (9×9), consistent with this repo's already-documented, deliberately-accepted sudoku-family generation cost (see [[project_sudoku_generator_perf]] — progress-bar-over-hard-cap was the chosen tradeoff project-wide), so not treated as a new bug. Couldn't run `spec/sudokukiller_spec.lua` here (needs `busted --lua=luajit` with a matching LuaJIT rocks tree, not installed in this sandbox — pre-existing environment gap, not something this pass introduced). |
| tapa | 🐛 fixed | 87-91% fallback at n=10 (0-3% at n=6/8) to the trivial "shade left half" board. Unlike cave, the per-cell 2×2 avoidance here was already correctly local (not the whole-grid bug), and there's already a connectivity-repair (`addBridge`) pass — the remaining issue was purely that 80 attempts isn't enough at n=10 for the random-shading + repair approach to land on a connected, 2×2-free region. Raised `GENERATE_MAX_ATTEMPTS` from 80 to 3000 (cheap per attempt): 0/100 fallback at n=10 with acceptable worst-case latency (~0.8s). Full 2700-case sweep (all sizes/difficulties) confirms ~0% (one residual 1/200 at n=10/easy, consistent with a very-low-but-nonzero rate rather than a bug). `spec/tapa_spec.lua` (14 tests) still green. |
| tatami | 🐛 **fixed (2026-07-21, follow-up session)** | Root cause confirmed: the implemented rule was checking the wrong thing (see original finding below) — the real historical Tatami rule is "no four *distinct* tiles' corners meet at one interior point" (a "cross" junction), not "no 2×2 block filled by two parallel same-orientation dominoes". Implemented `countCrossViolations` with the correct rule and exhaustively re-verified: exactly 2 valid (0-violation) tilings exist for n=4 (out of 36 total) and exactly 2 for n=6 (out of 6728) — both are "pinwheel" patterns, transposes of each other. Replaced the entire generate-and-retry approach with a direct constructive `fillPinwheel`: tile the outer 1-cell frame in a pinwheel arrangement, recurse into the (n-2)×(n-2) core with the same orientation; this always succeeds by construction (no retry loop, no fallback needed at all) and randomly picks between the 2 valid orientations each game for some variety. Verified 0/1000 violations (n=4 and n=6, 500 trials each, both orientations observed), full-board coverage/symmetry sanity-checked, and an end-to-end gameplay test (reconstruct the solution via `tapCell` in solution order) confirms `won` is correctly set. No dedicated spec file exists yet.<br>*Original finding, now resolved:* 100% fallback at both supported sizes, and raising `MAX_ATTEMPTS` from 50 to 5000 made no difference — exhaustive enumeration proved **all 36 tilings of 4×4 and all 6728 tilings of 6×6 had ≥1 violation** under the old rule, including the hardcoded "fallback" itself (claimed 0 violations, actually had 3). The plugin had never generated more than one board, ever, on either size. |
| tents | ✅ clean | `for _ = 1, 30 do`; lenient acceptance (≥80% of target tent count) makes this easy to satisfy. Tested 0/2400 fallback (n=6,8,10,12 × 3 difficulties). No fix needed. |
| wordsearch | ✅ clean | `for _ = 1, 200 do` per-word placement retry; unplaced words are just skipped (no degenerate whole-board fallback). Tested 300 generations: avg 8.93 of 8-10 requested words placed, 0/300 fell below 6 placed words. No fix needed. |

## Already known (2026-07-17 pass), deferred — not re-testing, just tracking

| Plugin | Status | Notes |
|---|---|---|
| galaxies | ⚠️ deferred | generator produces non-symmetric "solution" ~100% of the time; root cause is structural (center-first + grow-and-hope has no guaranteed tiling). See memory `project_generator_bugs_2026-07-17`. |
| masyu | ⚠️ deferred | `perturbLoop`'s 2×2 segment-reversal has an off-by-one that can shatter the Hamiltonian loop. Needs careful case-by-case re-derivation. Same memory. |

## Lower priority: has a generator but no obvious retry/fallback pattern found by grep
(worth a lighter pass — mainly checking it doesn't hang or crash — but not the
proven bug shape above)

**Status as of 2026-07-21 (session 2): all 17 tested/reviewed, 0 bugs found.**
The 7 sudoku-family plugins (arrowsudoku/hypersudoku/sandwichsudoku/sudokux/
thermosudoku/windoku/sudoku) share `sudoku-common`'s `generateSolvedBoard`
(full backtracking construction, standard NxN sudoku always has a valid
fill — no attempt cap that can be exhausted) and `createPuzzle` (digs holes
one at a time, skips a cell rather than retrying/failing if removal would
break uniqueness — no fallback branch exists). Verified via the
`generateWithProgress` functional tests done the same session (0 crashes,
`extra_regions` constraints — hyper boxes, diagonals — still hold in
generated solutions across all 6 non-`sudoku` variants). `binairo`,
`colornonogram`, `kenken`, `nonogram`, `numberlink`, `skyscraper` were run
through a 50-trial-per-size/difficulty driver checking for crashes, hangs,
and (for `colornonogram`'s bounded 100-attempt retry and `nonogram`'s
unbounded `repeat...until` retry specifically) residual empty rows/columns
after generation — 0 errors, 0 suspect boards, worst-case timing well under
1s. `minesweeper` and `futoshiki` were code-reviewed (single-pass Fisher-Yates
mine placement; existing spec suite) rather than driven — both already
low-risk by construction, no retry/fallback pattern present. `dames` and
`puissance4` have **no procedural generator at all** — `generate()` is just
`self:reset()` to a fixed starting position (checkers/connect-4), so this
bug class doesn't apply to them.

| Plugin | Status | Notes |
|---|---|---|
| arrowsudoku | ✅ | shares sudoku-common (backtracking, no retry/fallback branch) |
| binairo | ✅ | backtracking `_fill`; 0/450 errors incl. worst case n=12, max 0.82s |
| colornonogram | ✅ | bounded 100-attempt retry; 0/300 residual-empty-line after fix window |
| dames | ➖ | no procedural generator — `generate()` is `self:reset()` |
| futoshiki | ✅ | has spec, passing; no retry pattern |
| hypersudoku | ✅ | shares sudoku-common; extra_regions (hyper boxes) verified valid |
| kenken | ✅ | constructive cage growth, gracefully truncates, no retry |
| minesweeper | ✅ | single-pass Fisher-Yates mine placement, can't fail |
| nonogram | ✅ | unbounded `repeat...until` at n=10/15; 0/540 hangs or residual empty lines |
| numberlink | ✅ | constructive serpentine path with a valid built-in fallback shape |
| puissance4 | ➖ | no procedural generator — `generate()` is `self:reset()` |
| sandwichsudoku | ✅ | shares sudoku-common (backtracking, no retry/fallback branch) |
| skyscraper | ✅ | constructive Latin square + deterministic clues, no retry |
| sudoku | ✅ | shares sudoku-common; own daily-challenge rng variant also verified |
| sudokux | ✅ | shares sudoku-common; extra_regions (diagonals) verified valid |
| thermosudoku | ✅ | shares sudoku-common (backtracking, no retry/fallback branch) |
| windoku | ✅ | shares sudoku-common; extra_regions (windows) verified valid, region-constraint bug from 2026-07-17 stays fixed |

## Out of scope: no procedural puzzle generator (shuffle/deal/word-list/interactive only)

2048, anagram, arrowwords, backgammon, balance, boggle,
boggleparty, calculmental, chiffreslettres, coursdechecs, crossword,
cryptogram, dice, doubleornothing, echecs, fifteen, go, gomoku, hangman,
hanoi, mastermind, memory, othello, pickomino, pictionary, quiz, sokoban,
solitaire, taboo, wordladder, wordle

**Correction (2026-07-27)**: `betweenlines` was listed here until this date —
wrong. It shares the same `puzzle_generator.lua` module as the other Tier 4
sudoku variants (real backtracking fill + dig-with-verification), it just
wasn't caught by whatever first-pass classification produced this list.
Moved to the Tier 4 table below, where it's now been audited. See that
table's row for what was found.

(If any of these turn out to have a real generator on closer look, move them
into the appropriate table above rather than trusting this list blindly —
it's a first-pass grep classification, not a verified one.)

## Human-solvability audit (triggered 2026-07-22 by the sudokukiller fix)

This is a **different bug class** from the fallback/degenerate-output sweep
above, and needs its own pass. That sweep asks "does generation ever crash,
hang, or silently degrade to a trivial fallback puzzle?". This one asks a
question none of those specs check: **once generation succeeds and produces
a structurally valid puzzle, can a human actually solve it from its clues
without guessing?** "A unique solution exists" (provable by brute-force
backtracking) and "a human can reach it by deduction" are different
guarantees, and a generator can satisfy the first while badly failing the
second.

Found in `sudokukiller.koplugin`: Easy/Medium killer-sudoku puzzles averaged
~2 pre-filled cells out of 81 (by design — cage sums alone are the intended
challenge, matching real Killer Sudoku convention), but the cage layout was
built by unconstrained random region growth with no regard for whether the
resulting geometry admits *any* deduction chain. An independent human-style
solver (naked/hidden singles + cage-sum combo elimination + the "45 rule")
could fully solve **0 of 15** generated Easy puzzles — every one required
guessing past the first couple of cells, regardless of difficulty. Fixed by
(1) adding a bounded number of deliberate single-cell "given" digits as
deduction anchors, and (2) gating generation on that same human-style solver
actually reaching 100% completion, retrying (bounded) until it does. See
`git log -- sudokukiller.koplugin/board.lua` around 2026-07-22, and
`spec/solvability_audits/sudokukiller_solvability_check.lua` for the
regression harness (kept for exactly this: re-running after any future
change to the cage generator, without waiting for a player to notice).

Checking `kakuro.koplugin` next (closest architectural sibling — also a
cage/run-sum puzzle with ~0 given digits by genre convention) turned up
something worse than the killer-sudoku case: `generateFromTemplate`'s `bt()`
does a single random backtracking fill and derives clue sums from whatever
it lands on, with **no uniqueness check at all** (not even the "search for a
2nd solution" check killer sudoku had before today). So beyond "can a human
deduce it", kakuro puzzles weren't even verified to have a single valid
answer.

### Why this wasn't caught by the earlier robustness sweep

The fallback-robustness sweep's method (call `generate()` hundreds of times,
check for a *fallback marker*/crash/hang) is blind to this bug class by
construction: a puzzle that's mathematically valid but logically undeducible
never trips a fallback marker, never crashes, never hangs — it just quietly
produces a puzzle no one can solve except by guessing. Detecting it requires
actually attempting to *solve* every generated puzzle with a plausible human
technique set, not just checking generation terminated cleanly.

### Methodology

1. Read the plugin's generator to find: how are clues/givens derived from
   the full solution, and does anything already check the puzzle is
   uniquely solvable (mathematically) or human-solvable (logically)?
2. If there's no existing uniqueness check, write one first (bitmask
   backtracking search, capped at "find 2 solutions or give up after N
   nodes" — see `sudokukiller.koplugin/board.lua`'s `countCageSolutions` for
   the reusable shape).
3. Write an **independent** human-technique solver (naked/hidden singles
   adapted to the puzzle's constraint type, plus whatever puzzle-specific
   deduction rule exists — e.g. the 45-rule for cage-sum puzzles) and run it
   against a batch of freshly generated puzzles per difficulty. Keep this
   solver deliberately separate from any solver already inside `board.lua`
   — the point is cross-validation, not testing a fix against itself.
4. Measure: average given/clue count, and the fraction of puzzles the
   independent solver can complete to 100% with **no backtracking**. A low
   completion rate on the easiest difficulty is the strongest signal —
   that's the tier where "logically solvable, no guessing" matters most.
5. If broken: prefer (a) adding deliberate anchor clues if the genre allows
   pre-filled cells, and/or (b) gating generation with a retry loop on the
   human-solver actually reaching completion, over loosening what counts as
   "solved". Re-verify timing (generation must stay within the fleet's
   existing multi-second budget, see [[project_sudoku_generator_perf]]) and
   re-run the plugin's existing `busted spec/<plugin>_spec.lua` suite.
6. **Persist the independent solver harness** under
   `spec/solvability_audits/<plugin>_solvability_check.lua` regardless of
   outcome (bug found or clean) — run with `luajit spec/solvability_audits/
   <name>.lua` directly (not part of the `busted spec/` suite; these are
   statistical/timing-sensitive drivers, not fast pass/fail unit tests).
   This is what makes the audit re-runnable as a regression check after any
   future change to a generator, instead of a one-off finding that rots.
7. Update the table below and this doc's changelog; add a memory entry if
   the finding changes how future generator work in this repo should be
   approached.

### Status

| Plugin | Status | Notes |
|---|---|---|
| sudokukiller | 🐛 fixed | See summary above. |
| kakuro | ⚠️ confirmed bug, fix attempted and reverted | `bt()` has no uniqueness check at all (worse than sudokukiller's pre-fix state) — measured 0/45 unique across all 3 difficulties. Turns out to be a genuinely hard construction problem, not a parameter tune: every geometry tried (merged rectangles, staircase domino chains, periodic "brick" patterns, random black-cell patterns, with retry budgets up to 500 fills per pattern and 60+ distinct patterns) stayed ~100% ambiguous, due to a "generalized rectangle swap" that's pervasive at these grid sizes. One attempted fix was actually shipped, then caught (via this section's own dimension-check step) collapsing every generation to the 5×5 emergency fallback puzzle — reverted immediately. Full writeup, all findings, and reusable builder code kept at `spec/solvability_audits/kakuro_solvability_check.lua` and `kakuro_construction_attempts.lua` for whoever picks this back up — don't restart from zero. |

#### Kakuro follow-up: existing generators researched, larger-grid test attempted (2026-07-22)

Before sinking more time into a from-scratch construction algorithm, checked
whether existing open-source Kakuro generators had already solved this.
Found several (sources below) and read the actual generation code of the one
claiming a guaranteed-unique generator (`ChrisMoutsos/kakuro`,
`puzzleboard.cpp`, `generateBoard()`). Its shape: random black/white layout →
random Latin-style digit fill → derive sums → run a *logic* solver; if stuck,
fix one low-candidate cell to a plausible value and re-run the solver,
repeating until it fully deduces, else discard the whole layout and restart.

**This doesn't actually prove uniqueness.** The "fix a cell, does logic
resume" step confirms *a* completion is reachable, not that no *other*
completion is — it's a plausibility heuristic, not an independent solution
count, and the trial fixes are discarded before the puzzle is returned (final
output is sums-only, same as ours). Its black/white layout generation
(per-cell random non-clue chance ~70-99%) is also the same *class* of
construction as `buildRandomGrid` in `kakuro_construction_attempts.lua`,
already measured 0/60+ unique at 9×10 in this repo's own audit. So porting
it isn't expected to fix anything that wasn't already ruled out — noted here
so nobody re-discovers this by re-porting it.

The one genuinely untested lead from the original writeup was grid *size*
(15×15+, where swap opportunities might be rarer relative to grid area).
Tried it (`kakuro_size_experiment.lua`, same random-grid + stabilize +
independent counter already in `kakuro_construction_attempts.lua`, nothing
new): at 12×12/density 0.75 (63 white cells), the existing `countSolutions`
counter didn't even confirm the *one already-known* valid solution within a
50,000-node budget — it's not a signal about uniqueness one way or the
other, it's the counter's naive min/max sum-range pruning (no real subset-sum
feasibility check, unlike the `combosFor`-based technique in
`kakuro_solvability_check.lua`'s `humanSolve`) getting lost long before that
scale. Confirms the original note that "countRunSolutions got too slow to
iterate on before reaching a verdict" — the counter itself needs a real
rewrite (proper per-run combo pruning) before size can be tested at all,
which is a dedicated task, not a quick check. Left undone.

**Net conclusion, unchanged from before this follow-up:** kakuro generation
is still an open problem here. Two possible next steps, neither started:
(a) rewrite the uniqueness counter with real combo-based pruning so size can
actually be tested, or (b) accept procedural generation is a poor fit at
small/medium grid sizes and pre-bake a bank of offline-verified static
puzzles instead (feasible precisely because it doesn't need to be fast).

Sources consulted: [ChrisMoutsos/kakuro](https://github.com/ChrisMoutsos/kakuro),
[Hafthor/Kakuro](https://github.com/Hafthor/Kakuro),
[itomi/kakuro](https://github.com/itomi/kakuro),
["Kakuro as a Constraint Problem" (ResearchGate)](https://www.researchgate.net/publication/228524341_Kakuro_as_a_Constraint_Problem).

### Tier 1 — near-identical architecture to killer sudoku (cage/run-sum, ~0 givens by genre convention)

Highest suspected risk: same failure shape already proven twice.

| Plugin | Status | Notes |
|---|---|---|
| kakuro | ⚠️ deferred (see Status table above) | Substantially harder than sudokukiller's fix — treat as a dedicated task, not a quick pass. |
| kenken | ⬜ not started | cage-based Latin square, typically few/no givens |

### Tier 2 — Latin square + sparse numeric/inequality clues

**Diagnostic pass done 2026-07-22 (uniqueness-counting only, no fixes yet —
see conversation/memory for the decision to check breadth before investing
fix time). Finding: this is systemic, not a handful of isolated bugs — 9 of
the 10 plugins in this tier were confirmed broken outright, and the 10th
(fillomino) was confirmed broken too once a working solver was built for it
(2026-07-27) — so all 10 of 10 had a real bug.** Every plugin here
(except sudoku-family, which digs holes with a live uniqueness check
already — see Tier 4) uses the same naive pattern: build a full solution,
`shuffle()` cell positions, keep the top `ratio * total` cells as
givens/clues, done — with **zero uniqueness verification at generation
time**. Measured via a from-scratch MRV backtracking counter per puzzle
type (same shape as `sudokukiller`'s `countCageSolutions`, capped at 2
solutions / a few hundred thousand search nodes), 15 trials per
size/difficulty; hitori/nurikabe needed a shading/region-tiling CSP solver
instead of a digit-filler. All counters are persisted under
`spec/solvability_audits/*_uniqueness_diagnostic.lua` (measurement only, no
pass/fail assertions yet — that comes with the fix pass).

| Plugin | Status | Notes |
|---|---|---|
| futoshiki | 🐛 **fixed** (2026-07-22) | Dig-with-verification retrofit: the visible-inequality-constraint set is chosen first and stays fixed (a fully-given grid is trivially unique regardless of which constraints are shown), then given cells are dug one at a time with uniqueness verification. 20/20 unique at every size/difficulty after the fix. |
| skyscraper | 🐛 **fixed** (2026-07-22) | Needed *two* layers, not just digging: even the FULL 4n-clue set (before any digging) isn't always unique for an arbitrary Latin square — distinct squares can produce identical visibility-clue vectors in all 4 directions (same structural shape as kakuro's "generalized rectangle swap", just at these small grid sizes — n=4 measured 6/15 trials stuck at 16/16 clues kept, i.e. digging couldn't safely remove *any* clue, yet still ambiguous). Digging can only remove information, so it can never rescue an already-ambiguous full clue set. Fixed with an outer retry that regenerates the Latin square until its full clue set is provably unique, *then* digs clues down to the difficulty's target count with the usual verify-and-revert. 20/20 unique at every size/difficulty after the fix (n=5/hard up to 2.6s worst case — within the fleet's existing tolerance for slow generation). |
| binairo | 🐛 **fixed** (2026-07-22) | Same dig-with-verification retrofit as numbrix/rippleeffect/suguru, 20/20 unique at every size/difficulty after the fix. **Correction to the original diagnosis**: the *diagnostic script* used to measure this had its own bug (a full-row "run tracker" that treated undetermined cells as transparent to a run-of-3 check, over-rejecting valid grids) — re-measured with a corrected counter, the real pre-fix picture was moderate-on-Easy/severe-on-Hard (n=6: 9/15, 4/15, 1/15; n=8: 4/15, 1/15, 0/15), not a flat 0% everywhere. The bug was still real, just less uniform than first reported. A second, deeper bug surfaced while fixing this: `_fill` never enforced "all rows distinct, all columns distinct" (documented as "soft — not enforced"), so the stored solution could itself violate that rule — fixed alongside the digging retrofit. See `spec/solvability_audits/binairo_solvability_check.lua`'s header for the full writeup. |
| suguru | 🐛 **fixed** (2026-07-22) | Same dig-with-verification retrofit (code shape identical to rippleeffect minus the ripple-separation rule), 20/20 unique at every size/difficulty after the fix. |
| rippleeffect | 🐛 **fixed** (2026-07-22) | Dig-with-verification retrofit (sudoku-common pattern): start fully revealed, dig cells one at a time verifying uniqueness after each removal. 20/20 unique at every size/difficulty after the fix, confirming the fix-phase hypothesis below. |
| numbrix | 🐛 **fixed** (2026-07-22) | Same dig-with-verification retrofit. 20/20 unique at every size/difficulty after the fix. |
| hidato | 🐛 **fixed** (2026-07-22) | Exact sibling of the numbrix fix (same retrofit, king-move `DIRS` instead of orthogonal). 20/20 unique at every size/difficulty after the fix. Given counts land somewhat above nominal on Medium/Hard (digging gets "stuck" more often thanks to king-move's extra adjacency freedom) — correctness took priority over hitting the exact target ratio, same tradeoff precedent as sudokukiller. |
| hitori | 🐛 **fixed** (2026-07) | Different mechanic (full number grid shown, solve = find the unique valid shading) — no "reveal a subset" mechanic to dig, so the fix generates+verifies whole candidate puzzles instead: try random black-pattern+number-assignment combos, check with the dedicated shading-CSP counter, and escalate density in bounded steps when the nominal difficulty density keeps coming back ambiguous (nominal density is essentially never unique; success climbs sharply past ~0.30). 20/20 unique at every size/difficulty after the fix (n=7/easy up to 2.6s worst case — within precedent, low density needs more escalation steps). |
| nurikabe | 🐛 **fixed at n=5, partial at n=10/15** | Needed a region-tiling CSP solver (island shapes are the unknown, not just digits) wired into a generate-and-verify retry, same shape as hitori/skyscraper (no "reveal a subset" mechanic to dig). The FIRST solver written (row-major, join-via-already-decided-neighbor) had a real bug — it silently missed any valid shape where an island's seed isn't the row-major-topmost-leftmost cell of that island (common, since islands grow in every direction from the seed), making it both wrong and pathologically slow. Rewritten as MRV-over-islands (always grow whichever incomplete island has the fewest legal frontier cells), matching how the generator itself constructs a solution. n=5: 13/15, 15/15, 15/15 unique (easy/med/hard) — real, verified fix. n=10/15: proving uniqueness is usually computationally infeasible within any time budget that keeps generation fast (0/5 trials succeeded in 150 attempts x 20k nodes at n=10) — falls back to the best structurally-valid (unproven) layout, same as pre-fix behavior, never worse. See `spec/solvability_audits/nurikabe_solvability_check.lua`'s header for the full writeup. |
| fillomino | 🐛 **fixed (2026-07-27)** | Turned out to have **two** separate bugs. (1) `generateSolution` could produce self-contradictory grids, not just ambiguous ones: its leftover-cell fill stamped every remaining free cell as a flat "1", and its `checkAdjacency` safety net was vacuous (it grouped cells into "regions" via a flood fill keyed on value-equality, which by construction always merges adjacent equal-value cells into the same region id — so its "do two different ids with equal size touch" check could never fire). Caught via the standard sanity check (solver returned 0 solutions even at full reveal of the generator's own output); confirmed by direct inspection (e.g. a 3-cell vertical run of adjacent cells all displaying "1"). Fixed by replacing the leftover-fill step with proper connected-component grouping, and replacing `checkAdjacency` with `normalizeToValid` — a fixpoint that repeatedly recomputes true connected components by value and relabels each to its own true size until stable, which *mathematically guarantees* a valid grid regardless of input. This let the retry loop and its degenerate whole-grid fallback (which the fixpoint made unnecessary, and which had actually been firing 90-100% of the time at n=7/8 — see the table above) be deleted entirely. (2) Once solutions were valid, `createPuzzle` still revealed a flat per-region ratio with zero uniqueness verification — 0% unique at every size/difficulty once correctly measured. Fixed with the standard dig-with-verification retrofit, using an MRV-over-regions uniqueness counter (mirrors nurikabe's island-growing solver — a first attempt at raw per-cell value-guessing was sound but far too slow once regions run past size 20 from merges). 20/20 unique at every size/difficulty after the fix, generation still near-instant (<0.02s). See `spec/solvability_audits/fillomino_solvability_check.lua`'s header for the full writeup. |

**Takeaway:** the fix that worked for `sudokukiller` (add deliberate givens +
gate on a human-solver) doesn't generalize as-is, but the *simpler* fix that
already exists in `sudoku-common` — dig cells one at a time, verify with a
uniqueness counter after each removal, put the cell back if it broke
uniqueness — likely does generalize across most of this tier (unlike
kakuro's structural dead end, these all have generous enough clue ratios,
25-55%, that a dig-with-verification approach should converge quickly).

**Fix-phase confirmation: the hypothesis held for all 10 of 10 (9 fully, 1
partially).** numbrix, rippleeffect, suguru, binairo, futoshiki,
skyscraper, hidato, hitori, and fillomino are fully fixed — 20/20 unique at
every size/difficulty for all nine, generation time from sub-millisecond up
to ~2.6s worst case (within the fleet's existing tolerance), existing spec
suites still green. nurikabe is fixed at its default size (n=5: 13/15,
15/15, 15/15 unique) but only partially at n=10/15, where proving
uniqueness is usually computationally infeasible within a time budget that
keeps generation fast — falls back to the pre-fix behavior there (best
structurally-valid, unproven layout), never worse, just not verifiably
better yet.

Four plugins needed something beyond plain digging:
- **skyscraper**: an outer retry regenerating the Latin square itself,
  since digging alone can't fix a full clue set that's already ambiguous
  before any hiding.
- **hitori**: no "reveal a subset" mechanic exists at all — every number is
  visible from the start and the puzzle is a *shading* — so the fix
  generates+verifies whole candidate puzzles instead, escalating density in
  bounded steps when nominal density keeps coming back ambiguous.
- **nurikabe**: same "no subset to reveal" shape as hitori (clues are
  1-per-island, not a partial reveal), generates+verifies whole candidate
  layouts with a region-tiling CSP solver. The first version of that solver
  had a real, separate bug (see its row above) — processing cells in fixed
  row-major order silently missed valid shapes and was pathologically slow;
  rewritten as MRV over which island to grow next.
- **fillomino**: needed a fix *before* the digging fix even applied — the
  solution generator itself could produce self-contradictory grids (see its
  row above for the vacuous-`checkAdjacency` root cause). Once solutions
  were genuinely valid, plain dig-with-verification worked, but the
  uniqueness counter itself needed the same lesson as nurikabe: a first
  attempt at raw per-cell value-guessing was sound but intractably slow, and
  had to be rewritten as MRV-over-regions (grow each given-clue-seeded
  region toward its known target size) to be fast enough to use.

**Process note from the binairo fix**: a "0% unique, every setting" result
that's *this* uniform is itself a signal to double-check the checker, not
just the generator — real bugs are rarely perfectly uniform across
sizes/difficulties (compare numbrix/rippleeffect's graduated numbers).
binairo's original diagnostic had a genuine bug in its own uniqueness
counter (see its row above) that inflated a real-but-moderate bug into an
apparent total failure. Before trusting a solvability counter's verdict,
sanity-check it against a *second*, differently-structured implementation
of the same rules (which is exactly what these `*_solvability_check.lua`
files do relative to board.lua's own copy — but the diagnostic-phase
throwaway scripts didn't get that same scrutiny, and one bug slipped
through as a result).

### Tier 3 — other clue-based deduction puzzles, risk not yet assessed

**nonogram + colornonogram audited and fixed 2026-07-27** (Phase 2 of the
remaining-audits roadmap) — see their rows below and
`spec/solvability_audits/nonogram_solvability_check.lua`'s header for the
full writeup. Both had zero uniqueness verification, same as every other
tier; both are now fixed with the standard nonogram line-solving technique
(enumerate valid full lines per row/column clue, propagate row/column
candidate sets against each other to a fixed point, branch only on genuine
choice points). Worth remembering for whoever picks up the rest of this
tier: a first attempt at the uniqueness counter used MRV over *which row to
place next* on top of a left-to-right incremental column state machine —
that's not just slow, it's **wrong**, since a column's clue depends on the
true top-to-bottom sequence and reordering rows silently breaks it. Caught
by the standard sanity check (solver returned 0 solutions for the
generator's own known-good output). The propagation-based rewrite is
correct precisely because it's order-independent.

**bridges, shikaku, starbattle, tents, lightup, tapa audited and fixed
2026-07-27** (Phase 3) — see their rows below and each plugin's
`spec/solvability_audits/<name>_solvability_check.lua` header for the full
writeup. All six had zero uniqueness verification. Severity varied more
than any tier so far — bridges turned out to already be ~93-100% unique by
construction (once its counter's own bug was fixed), while nonogram-class
severity (0% unique everywhere) showed up in starbattle, shikaku, tents,
lightup, and tapa. Two recurring lessons worth carrying into Tier 4:
- **Forward-checking, not just bound-checking, matters for degree-
  constrained CSPs** (bridges): a candidate value check that only prevents
  *overshooting* a vertex's remaining budget, without checking the
  leftover is actually *reachable* by that vertex's other undecided edges,
  wastes nearly all its effort on combinations that only fail once
  everything is decided — even 20 million nodes couldn't find bridges'
  one known solution before this was fixed.
- **A "retry the same nominal setting" loop doesn't help when the nominal
  setting is *itself* rarely unique** (lightup, tapa): both needed the
  hitori-style fix of escalating a density/reveal parameter in bounded
  steps (more revealed constraints can only help, never hurt) rather than
  just repeating identical-distribution attempts, which — as first
  shipped for both — left the fix doing nothing (0% unique even after
  thousands of retries) while adding pure latency.
- Incremental connectivity pruning (tapa) is easy to get *unsound*: the
  first version required the entire "maybe-shaded" region to stay one
  piece, wrongly rejecting valid states where an isolated pocket of
  merely-undecided cells was always going to resolve to nothing. The fix
  only rejects when 2+ components each already anchor a *confirmed*
  member — caught, like every other solver bug in this audit, by the
  standard sanity check against the generator's own known-good output.

**slitherlink, masyu, numberlink audited and fixed 2026-07-28** (Phase 4,
now complete). slitherlink was the "clean" case of this tier: literal-
comparison win-check, zero uniqueness verification as usual, fixed the
standard generate+verify way. masyu turned out to be the deepest bug of the
whole audit: its rule-based win-check didn't require the marked cells to
form a *single* loop, only that they satisfy the local degree/clue rules as
a union of cycles — meaning almost any generated puzzle admitted a
completely unrelated valid marking elsewhere on the grid, and this held even
when *every* available clue candidate was revealed (not a clue-density
problem, a missing-rule problem). Fixed the win-check itself (added
single-loop-connectivity, tracing from any marked cell and requiring the
whole marked set to be visited before returning to start) as well as the
generator. n=6 reaches 100% unique, fast. n=8 remains a **known, accepted
partial fix**: proving a shape uniquely solvable requires exhausting its
whole remaining search space, which only a minority of generated shapes
achieve regardless of node budget (tested 20000 through 400000 — no
material quality gain, just longer waits), so generate() there is capped by
a small wall-clock budget (2s) and falls back to the best structurally-valid
(not proven-unique) candidate if nothing verifies in time — real, positive,
and bounded, but not a full fix at that board size. See
`spec/solvability_audits/masyu_solvability_check.lua`'s header for the full
writeup.

numberlink turned out to be a genuine surprise, and a lesson worth
carrying forward on its own: a *different* generator+solver combination
than every other Tier 3 game, since paths jointly partition the whole grid
rather than each puzzle having one independent shape. Building the
uniqueness counter (grow each color's path as an actual ordered path via
DFS, MRV color ordering + BFS reachability pruning) surfaced a real
SOUNDNESS bug on the first pass: the "is this cell free to extend into"
check only tested `owner[cell] == 0`, which let one color's path walk
straight through *another* color's reserved clue endpoint and silently
consume it — corrupting the search into reporting false "unique" verdicts
(undercounting, not overcounting). Caught by cross-checking against a
second, plain unpruned reference solver on a fixed seed (it found 3
solutions where the buggy pruned counter claimed exactly 1) — a new entry
in this audit's running list of "an aggressive prune can corrupt shared
mutable state, not just cut dead branches, and that shows up as a FALSE
POSITIVE for uniqueness, the opposite failure direction from every other
solver bug found so far." Fixed by requiring a cell be both unclaimed *and*
not a differently-colored clue before a path may claim it. Once that was
fixed, measured severity honestly: at the *original* color density (8/12/16
colors per 100 cells) the puzzle is severely, structurally ambiguous — 400
fresh attempts at n=5 (24000+ underlying layouts via the retry loop) never
found one genuinely unique layout at any real difficulty. The real bug
wasn't a missing retry gate, it was that 2-4 colors on a 25-cell grid leaves
far too much room to shift a segment boundary by a cell or two and still
connect the same two endpoints a different way. Swept color density
directly and found per-attempt success only becomes reliable (>90%) around
a 30%+ colors-per-cell ratio — roughly double the original — so the real
fix raised `N_COLORS_PER_100` (25/32/40 instead of 8/12/16) on top of the
usual generate+verify retry loop (segment lengths are now randomly jittered
per attempt too, since the original floor-division split is fully
deterministic given n and n_colors — only 8 corner/orientation combinations
exist at all, so retrying without varying the split itself could never
explore anything new). At the corrected density, more (shorter) colors also
makes verification itself much cheaper, so every size ended up fully fixed,
not just the smallest: **20/20 unique at all 4 sizes × 3 difficulties**,
worst case ~0.02s — one of the fastest, most complete fixes in the whole
audit once the actual bug (density, not verification) was identified. See
`spec/solvability_audits/numberlink_solvability_check.lua`'s header for the
full writeup.

| Plugin | Status | Notes |
|---|---|---|
| slitherlink | 🐛 **fixed (2026-07-28)** | Literal comparison to a stored loop; `generate()` built a random loop shape then revealed a flat fraction of clue numbers, zero uniqueness check. Measured pre-fix: real, graduated ambiguity (n=5/easy 9/10 unique down to n=10/hard 1/10). A first uniqueness-counter attempt used unsound incremental "no premature sub-loop" pruning via union-find (compared against ALL decided edges, not just remaining line edges) — caught by the sanity check, dropped in favor of clue-forcing + vertex-degree-forcing propagation with a final-only single-loop check. Fixed generate+verify style: escalates the clue-keep ratio in bounded steps per loop shape before drawing a fresh one, with the node budget scaled down for the largest grid (n=20) to avoid a ~45s worst case. 15/15 unique at every size/difficulty after the fix, worst case ~6.65s at n=20/hard. |
| masyu | 🐛 **fixed (2026-07-28, partial at n=8)** | See the writeup above — the deepest bug in this audit: win-check was missing single-loop-connectivity entirely, not just under-verified clue placement. Fixed both the win-check (now requires the marked cells to form one connected loop, matching real Masyu rules) and the generator (always reveals every available clue candidate, since sparser ratios essentially never help; retries with a fresh loop shape up to 40 times). n=6: 20/20 unique, ~instant. n=8: ~10-20% unique (up from an effectively-always-wrong baseline), capped at a 2s wall-clock budget per `generate()` call — a real, bounded improvement, not a full fix at that size. |
| nonogram | 🐛 **fixed (2026-07-27)** | Row/col run-length clues are the entire puzzle (no "given" cells at all) — `generate()` built a random density fill with only a "no empty row/column" check, zero uniqueness verification. Measured pre-fix: real graduated severity (n=15/easy 2/15 unique, n=5/hard 15/15 unique — denser fills are naturally more constrained). Fixed generate+verify style (nothing to dig, same shape as hitori/nurikabe): retry a random fill up to 400 times, checking uniqueness with the line-propagation solver described above, keep the first provably-unique one. 20/20 unique at every size/difficulty after the fix, worst case ~0.22s avg (n=15/easy). |
| colornonogram | 🐛 **fixed (2026-07-27)** | Same shape as nonogram, generalized to per-cell values in {0=empty, 1..3} plus a color-dependent gap rule (two consecutive clue runs need a mandatory gap only if they're the *same* color — different-colored runs can sit directly adjacent). Measured pre-fix: n=6/easy 6/15, n=8/easy 5/15 unique. Fixed the same generate+verify way. 20/20 unique at every size/difficulty after the fix, sub-5ms avg. |
| lightup | 🐛 **fixed (2026-07-27)** | Genuinely rule-based win-check (not literal comparison) — any bulb placement lighting every white cell, with no two bulbs seeing each other and every numbered wall's count matching, is accepted. Needed real constraint propagation (wall-forcing + illumination-forcing) to be tractable at all; a real bug in the counter itself (a failed placement left corrupted state that its own `undo()` then used to wipe out a *different* cell's legitimate registration) was caught via the sanity check. Fixed generation the hitori way: escalate the wall-number reveal ratio (0.6→0.8→1.0) instead of blindly retrying the nominal ~60%. n=7/n=10 close to fully fixed (67-100%, up from 0%); n=14 only meaningfully improved at hard/medium (easy remains genuinely under-constrained at that density) — a real, partial fix, same shape as nurikabe's hardest sizes, but generation is fast everywhere now (worst ~4.8s, was occasionally 10s+ for zero benefit before tuning). |
| starbattle | 🐛 **fixed (2026-07-27)** | The existing solver only found the *first* valid star placement, never checked for a second. Measured pre-fix: only ~7% of accepted region layouts were actually unique at n=6/k=1 and n=10/k=2 (n=8/k=2 was already ~100%, a genuine if uneven pattern). Fixed generate+verify style: the solver now counts up to 2 solutions, and `generate()` requires exactly 1 before accepting a layout, retrying up to 2000 times with a tuned-down per-attempt node budget (an initial larger budget caused a real worst-case latency problem, up to ~13s — smaller budget + more attempts fails an inconclusive attempt faster and moves on). 20/20 unique at n=6/n=8; ~90% at n=10/k=2 (worst case ~5.3s) — real, substantial, not a full fix at the hardest setting. |
| tents | 🐛 **fixed (2026-07-27)** | Tree positions + row/col tent-count clues are shown; the unknown is where each tree's paired tent goes. Win-check is literal comparison, but the real constraint set (one tent per tree, orthogonally adjacent, no two tents touching, counts matching) needed its own solver. Measured pre-fix: real, moderate ambiguity (60-87% unique, worse at hard). Fixed generate+verify style: retry the tree/tent pairing up to 60 times, verifying with an MRV backtracking counter each time. 20/20 unique at every size/difficulty after the fix, still near-instant. |
| tapa | 🐛 **fixed (2026-07-27)** | The hardest of this whole batch. No "given" mask (clue cells ARE the puzzle); win-check is literal comparison. Needed incremental connectivity pruning to be tractable at all (see the unsound-first-attempt note above), and needed hitori-style clue-density escalation (not just retrying the nominal ~12-30% reveal) to actually fix generation rather than just adding latency. 20/20 unique at every size/difficulty after both fixes, worst case ~0.8s avg (n=10/hard). |
| numberlink | 🐛 **fixed (2026-07-28)** | See the writeup above — win-check is literal comparison to a full-grid partition (not just "a path exists"). The original generator sliced one serpentine Hamiltonian path into n_colors contiguous segments at a color density (8/12/16 per 100 cells) far too low to be unique — confirmed 0% unique even after hundreds of retries, a density bug not a verification-gate bug. Fixed by raising density to 25/32/40 per 100 cells plus the usual generate+verify retry loop (with randomized segment-length jitter, since the plain split is deterministic). **20/20 unique at every size (5/7/9/10) and difficulty**, worst case ~0.02s — a full fix, not partial. |
| bridges | 🐛 **fixed (2026-07-27)** | Simpler than classic Hashiwokakero here: `tapBridge` only lets the player adjust bridge counts on connection slots the generator already chose (clamped to that slot's solution count), never invent a new connection — so the graph topology is fixed and already crossing-free by construction, and solving is just "how many bridges (0-2) per fixed edge". Turned out to already be ~93-100% unique by construction once the counter's own forward-checking bug was fixed (see above) — much lower severity than the rest of this tier. Verify-and-retry closes the remaining gap: 20/20 unique after, still near-instant. |
| shikaku | 🐛 **fixed (2026-07-27)** | One random clue-cell position per rectangle, zero uniqueness verification — severe (0/15 unique at n=8/n=10, every difficulty). Fixed generate+verify style, but cheaply: repicking which cell within a fixed rectangle holds the clue (up to 25 times) is far cheaper than re-splitting the grid, and turned out to be enough on its own most of the time before falling back to a fresh partition (up to 40 times). 20/20 unique at every size/difficulty after the fix, worst case ~0.15s avg (n=10). |
| galaxies | ⬜ not started | already deferred for a structural generation bug — re-check this dimension once/if that's resolved |
| cave | ⬜ not started | need to read the ruleset first, unclear if "solvability" even applies the same way |
| tatami | ⬜ not started | now generated constructively (100% valid by construction per the robustness audit) — likely low risk, but the *puzzle-from-solution clue* step (if any) hasn't been checked for this dimension |

### Tier 4 — sudoku-variant siblings sharing `sudoku-common`

**Audited 2026-07-27: all 8 checked, 2 real (low-severity) bugs found and
fixed, 6 confirmed clean.** These keep classic Sudoku's ample-givens
convention (not killer sudoku's ~0-givens convention), and the shared
`puzzle_generator.lua`'s dig-holes generator already checks uniqueness at
each digging step — so, unlike Tier 2, this tier was never suspected of the
same "zero uniqueness check" bug. The real question turned out to be
different per variant (see `spec/solvability_audits/
tier4_sudoku_variants_check.lua`'s header for the full writeup):

- **windoku / hypersudoku / sudokux** thread their extra rule (windows,
  hyper boxes, diagonals) through the shared module's `extra_regions`
  parameter — a "no duplicate digit in this cell set" list passed to
  *both* `generateSolvedBoard` and `createPuzzle`, so the generated
  solution itself is guaranteed to respect the extra rule, not just the
  puzzle's clue count. All three derive `extra_regions` programmatically
  from a single region-definition table also used elsewhere in `board.lua`
  for conflict-checking, so there's no risk of the two drifting apart.
  Confirmed 0 duplicate-in-region violations across 60 generated solutions
  each — clean, no fix needed.
- **arrowsudoku / thermosudoku / betweenlines** can't use `extra_regions` at
  all — their constraint (arrow sum, strictly-increasing thermometer,
  strictly-between line) isn't a "no duplicate" rule. Instead each picks a
  random path on the *already-solved* grid and only keeps it if the
  existing values already happen to satisfy the constraint (same "derive a
  clue from the fixed solution" pattern as sudokukiller/fillomino) — this
  is correctness-safe by construction. But it's a bounded-retry loop with
  an implicit shortfall risk, the exact shape of the very first bug this
  whole audit ever found (bridges, 2026-07-20). Measured: `betweenlines`
  (target 4-6 lines, `max_attempts = 300`) landed at only 3 lines in 3/100
  trials; `thermosudoku` (target 5, `max_attempts = 200`) landed at only 3
  in 1/100 trials (its own comment claimed a "minimum 2" floor that nothing
  in the code actually enforced — removed along with the fix). Both
  low-severity but real, fixed the same way as bridges/starbattle/tapa:
  raised the attempt budget (300→3000, 200→2000). Re-measured 0/300
  shortfall for both after the fix, generation still ~0.003s avg.
  `arrowsudoku` has no value-relationship rejection filter (any two unused
  cells form a valid arrow), so it was never at real risk — confirmed
  0/300 shortfall even before any change, left as-is.
- **sandwichsudoku** computes its clues unconditionally from any solution
  (every row/column already contains 1..9, so the sandwich sum is always
  well-defined) — no placement step exists, so this bug class doesn't apply
  at all.
- **sudoku** (baseline) and all 7 variants: confirmed each plugin's own
  win-check (`isSolved()` via `recalcConflicts()`) correctly accepts the
  board's own true solution once filled in (0/20 trials rejected, each
  plugin) — ruling out the hidato/numbrix/tatami class of bug (a broken win
  condition) independent of anything about clue generation.

| Plugin | Status | Notes |
|---|---|---|
| sudoku | ✅ clean | baseline; win-check confirmed to accept its own solution |
| windoku | ✅ clean | `extra_regions` correctly enforced during generation, 0/60 violations |
| hypersudoku | ✅ clean | `extra_regions` correctly enforced during generation, 0/60 violations |
| sudokux | ✅ clean | `extra_regions` correctly enforced during generation, 0/60 violations |
| arrowsudoku | ✅ clean | no rejection filter on arrow placement, never at risk of shortfall; 0/300 confirmed |
| thermosudoku | 🐛 fixed | thermometer-count shortfall (1/100 trials landed at 3 instead of 5); bumped attempt budget 200→2000, removed a stale unenforced "minimum 2" comment/dead code |
| betweenlines | 🐛 fixed | between-line-count shortfall (3/100 trials landed at 3 instead of 4-6); bumped attempt budget 300→3000. Also: this plugin was previously misclassified as "no procedural generator" — corrected, see the note above the "Not applicable" list |
| sandwichsudoku | ✅ clean | clues always derivable from any solution, no placement step, no risk of this bug class |

### Not applicable — no full-solution-then-reveal-clues mechanic

2048, anagram, arrowwords, backgammon, balance, battleship, boggle,
boggleparty, calculmental, chiffreslettres, coursdechecs, crossword,
cryptogram, dames, dice, doubleornothing, echecs, fifteen, go, gomoku,
hangman, hanoi, mastermind, memory, minesweeper, othello, pickomino,
pictionary, puissance4, quiz, sokoban, solitaire, taboo, wordladder, wordle,
wordsearch

(Same caveat as the out-of-scope list above: first-pass classification by
what the plugin *is*, not independently re-verified for each one. Revisit if
any of these turn out to reveal a partial solution as solvable clues after
all.)

## How to test a plugin

1. Read `board.lua`, find the generator entry point (usually `:generate(...)`)
   and how it signals failure/fallback (a `_fallback()` method, a specific
   small island/clue count, a `pending`/`nil` solution, etc).
2. Write a throwaway driver in the scratchpad dir:
   ```lua
   local Board = loadfile(".../board.lua")()
   local fails = 0
   local N = 300
   for trial = 1, N do
       math.randomseed(trial * <big prime>)
       local b = Board:new({n = ..., difficulty = ...})
       b:generate(...)
       if <fallback marker> then fails = fails + 1 end
   end
   print(fails, N)
   ```
3. Run across every size/difficulty combo the UI actually exposes (check
   `screen.lua` for the real menu options — don't guess).
4. >0% fallback rate on realistic settings = confirmed bug. If the fix is a
   simple, low-risk mechanical change (like bridges' density scaling, or
   bumping an attempt cap), apply it and re-run the same driver to confirm
   ~0%. If it needs a structural rewrite (like galaxies/masyu), stop, document
   findings in this file's notes column, add a `pending()` spec if a spec file
   exists, and move on rather than rushing a risky fix.
5. Run `busted spec/<plugin>_spec.lua` if it exists, to make sure nothing
   broke.
6. Update the status cell and notes in this file, and update
   `MEMORY.md`/the generator-bugs memory file if the finding is worth
   carrying into future sessions.
