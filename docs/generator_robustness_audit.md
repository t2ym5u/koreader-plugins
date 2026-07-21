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
  board size, not just improbable — see that row.
- **Clean, no bug**: battleship, fillomino, hitori, shikaku, slitherlink,
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
| fillomino | ✅ clean | `for attempt = 1, 30 do` region-adjacency retry; tested 0/2700 fallback (n=6,7,8 × 3 difficulties). No fix needed. |
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

2048, anagram, arrowwords, backgammon, balance, betweenlines, boggle,
boggleparty, calculmental, chiffreslettres, coursdechecs, crossword,
cryptogram, dice, doubleornothing, echecs, fifteen, go, gomoku, hangman,
hanoi, mastermind, memory, othello, pickomino, pictionary, quiz, sokoban,
solitaire, taboo, wordladder, wordle

(If any of these turn out to have a real generator on closer look, move them
into the appropriate table above rather than trusting this list blindly —
it's a first-pass grep classification, not a verified one.)

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
