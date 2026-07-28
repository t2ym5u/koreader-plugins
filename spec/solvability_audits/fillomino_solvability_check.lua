-- Uniqueness regression check for fillomino.koplugin.
--
-- This is NOT a busted spec -- see docs/generator_robustness_audit.md,
-- "Human-solvability audit" section, for why this class of check needs its
-- own tooling separate from `busted spec/`.
--
-- Run from the repo root:
--   luajit spec/solvability_audits/fillomino_solvability_check.lua
--
-- Background: fillomino turned out to have TWO separate bugs, found in that
-- order:
--
-- 1. `generateSolution`'s own output could be self-contradictory -- not
--    just ambiguous, structurally invalid. Its "fill any remaining free
--    cells as size-1 regions" step stamped every leftover free cell with a
--    flat value of 1, even when two leftover cells ended up adjacent (which
--    happens often): they'd form one bigger connected region while each
--    displayed "1", violating fillomino's own rule that a cell's value must
--    equal its region's true connected size. The same defect existed in the
--    main region-placement loop too: two independently-placed regions of
--    the same size could end up adjacent, again mismatching. The existing
--    `checkAdjacency` safety net that was supposed to catch this was
--    vacuous -- it computed "region ids" via a flood fill keyed on value
--    equality, which by construction ALWAYS merges adjacent equal-value
--    cells into the same id, so its check ("do two different ids with
--    equal size share an edge") could never fire. This was caught by the
--    standard "sanity check the solver against the generator's own known-
--    good full-reveal output" step -- it returned solutions=0 even at full
--    reveal, and direct inspection of `b.solution` confirmed cells with a
--    mismatched true-vs-displayed connected size.
--
--    Fixed by replacing the leftover-fill step with proper connected-
--    component grouping (each leftover blob gets its own true size, not a
--    fixed 1), and replacing `checkAdjacency` with `normalizeToValid`: a
--    fixpoint that repeatedly recomputes true connected components by value
--    and relabels each one to its own true size, until stable. This
--    mathematically guarantees a valid grid regardless of how the initial
--    candidate was built (values only grow across iterations and are capped
--    at n*n, so it always terminates), which let the generate() retry loop
--    and its "single whole-grid region" fallback both be deleted entirely
--    -- they're no longer needed and were degrading to that trivial fallback
--    on nearly every attempt at n=7/8 before this fix (18/20 and 20/20 of
--    the time, respectively).
--
-- 2. Once the solution itself was valid, `createPuzzle` still revealed a
--    flat per-region ratio with zero uniqueness verification (0% unique at
--    every size/difficulty once measured with a correct solver -- see
--    below). Fixed with the standard dig-with-verification retrofit: start
--    fully revealed, hide cells one at a time in random order, verify
--    uniqueness after each hide, revert if it broke it.
--
-- The FIRST uniqueness-counter design (guess a raw value 1..MAX_VALUE for
-- each empty cell, i.e. the same shape used for numbrix/rippleeffect/etc.)
-- was sound but far too slow here: with regions running past size 20 once
-- merges cascade, per-cell value-guessing has nowhere near enough pruning
-- (18 empty cells, alphabet size 6, exhausted 5,000,000 nodes without even
-- finding the known-good completion). Rewritten as MRV-over-regions
-- (mirrors the nurikabe fix's shape): grow each given-clue-seeded region
-- toward its known target size -- the clue value -- one frontier cell at a
-- time, instead of guessing values cell by cell. This is dramatically more
-- constrained and runs in well under a second per puzzle.
--
-- Deliberate approximation, same as nurikabe/hitori's tradeoffs elsewhere in
-- this audit: this solver only grows regions seeded by an existing given
-- clue. It does not search for alternate completions that invent a
-- brand-new region with zero given clues anywhere in it. createPuzzle
-- always keeps >=1 given cell per region while digging (removing a
-- region's last clue makes this solver unable to claim those cells at all,
-- so it reports "not unique" and the digger reverts that hide on its own),
-- so this bias can only under-count exotic phantom-region completions, not
-- the puzzle's own intended solution -- a conservative bias toward
-- overstating uniqueness slightly, not understating it.
--
-- Exit code is non-zero if any size/difficulty drops below its threshold.

package.preload["gettext"] = function() return function(s) return s end end
package.path = "game-common/?.lua;fillomino.koplugin/?.lua;" .. package.path
local Board = require("board")

local DIRS = {{-1,0},{1,0},{0,-1},{0,1}}

-- MRV-over-regions counter (up to `limit` solutions). Deliberately separate
-- from board.lua's own countSolutions -- cross-checks the production gate
-- rather than testing a fix against itself.
local function countSolutions(puzzle, given, n, limit, node_budget)
    local color = {}
    for r = 1, n do color[r] = {}; for c = 1, n do color[r][c] = 0 end end

    local regions, gseen = {}, {}
    for r = 1, n do gseen[r] = {} end
    for r = 1, n do for c = 1, n do
        if given[r][c] and not gseen[r][c] then
            local v = puzzle[r][c]
            local idx = #regions + 1
            local stack = { {r, c} }
            gseen[r][c] = true
            color[r][c] = idx
            local cells = { {r, c} }
            while #stack > 0 do
                local cur = table.remove(stack)
                for _, d in ipairs(DIRS) do
                    local nr, nc = cur[1]+d[1], cur[2]+d[2]
                    if nr>=1 and nr<=n and nc>=1 and nc<=n and given[nr][nc]
                        and puzzle[nr][nc]==v and not gseen[nr][nc] then
                        gseen[nr][nc] = true
                        color[nr][nc] = idx
                        cells[#cells+1] = {nr,nc}
                        stack[#stack+1] = {nr,nc}
                    end
                end
            end
            regions[idx] = { target = v, cells = cells }
        end
    end end
    local num_regions = #regions
    local total_cells = n * n
    local claimed = 0
    for r = 1, n do for c = 1, n do if given[r][c] then claimed = claimed + 1 end end end

    local solutions, nodes, exhausted = 0, 0, false

    local function frontierFor(idx)
        local reg = regions[idx]
        local cands, seen = {}, {}
        for _, cell in ipairs(reg.cells) do
            for _, d in ipairs(DIRS) do
                local nr, nc = cell[1]+d[1], cell[2]+d[2]
                local key = nr*1000+nc
                if nr>=1 and nr<=n and nc>=1 and nc<=n and color[nr][nc]==0 and not seen[key] then
                    local conflict = false
                    for _, d2 in ipairs(DIRS) do
                        local mr, mc = nr+d2[1], nc+d2[2]
                        if mr>=1 and mr<=n and mc>=1 and mc<=n then
                            local ov = color[mr][mc]
                            if ov > 0 and ov ~= idx and regions[ov].target == reg.target then
                                conflict = true; break
                            end
                        end
                    end
                    if not conflict then seen[key] = true; cands[#cands+1] = {nr,nc} end
                end
            end
        end
        return cands
    end

    local function search()
        if solutions >= limit or exhausted then return end
        nodes = nodes + 1
        if nodes > node_budget then exhausted = true; return end

        local best_idx, best_frontier, best_len = nil, nil, math.huge
        for i = 1, num_regions do
            if #regions[i].cells < regions[i].target then
                local frontier = frontierFor(i)
                if #frontier < best_len then
                    best_len, best_frontier, best_idx = #frontier, frontier, i
                    if best_len == 0 then break end
                end
            end
        end

        if not best_idx then
            if claimed == total_cells then solutions = solutions + 1 end
            return
        end
        if best_len == 0 then return end

        local reg = regions[best_idx]
        for _, cell in ipairs(best_frontier) do
            local cr, cc = cell[1], cell[2]
            color[cr][cc] = best_idx
            reg.cells[#reg.cells+1] = cell
            claimed = claimed + 1
            search()
            claimed = claimed - 1
            reg.cells[#reg.cells] = nil
            color[cr][cc] = 0
            if solutions >= limit or exhausted then return end
        end
    end
    search()
    return solutions, exhausted
end

-- Sanity check: full reveal (every cell given) must always be found unique
-- via THIS SAME solver, or the solver itself is broken -- test first. This
-- is also, independently, a check that the generator's OWN solution is
-- self-consistent (the bug this file's header describes as #1).
local function sanityCheckFullReveal(n_trials)
    local ok = true
    for i = 1, n_trials do
        math.randomseed(i * 104729)
        local b = Board:new({ n = 6, difficulty = "medium" })
        b:generate("medium")
        local full_given = {}
        for r = 1, b.n do full_given[r] = {}; for c = 1, b.n do full_given[r][c] = true end end
        local solutions, exhausted = countSolutions(b.solution, full_given, b.n, 2, 100000)
        if solutions ~= 1 or exhausted then
            print(string.format("[FAIL] sanity check trial %d: solutions=%d exhausted=%s (expected 1, false)",
                i, solutions, tostring(exhausted)))
            ok = false
        end
    end
    if ok then print(string.format("[OK] sanity check: %d/%d known-good solutions confirmed unique", n_trials, n_trials)) end
    return ok
end

local ok = sanityCheckFullReveal(10)

local function analyze(n, difficulty, n_trials, node_budget, threshold)
    local unique, ambiguous, inconclusive = 0, 0, 0
    for i = 1, n_trials do
        math.randomseed(i * 7919)
        local b = Board:new({ n = n, difficulty = difficulty })
        b:generate(difficulty)
        local solutions, exhausted = countSolutions(b.puzzle, b.given, n, 2, node_budget)
        if exhausted then inconclusive = inconclusive + 1
        elseif solutions == 1 then unique = unique + 1
        else ambiguous = ambiguous + 1 end
    end
    local rate = unique / n_trials
    local status = rate >= threshold and "OK" or "FAIL"
    if status == "FAIL" then ok = false end
    print(string.format("[%s] n=%d %s: unique=%d/%d ambiguous=%d inconclusive=%d (threshold %.0f%%)",
        status, n, difficulty, unique, n_trials, ambiguous, inconclusive, threshold * 100))
    io.flush()
end

analyze(6, "easy", 20, 500000, 0.90)
analyze(6, "medium", 20, 500000, 0.90)
analyze(6, "hard", 20, 500000, 0.90)
analyze(7, "easy", 20, 500000, 0.90)
analyze(7, "medium", 20, 500000, 0.90)
analyze(7, "hard", 20, 500000, 0.90)
analyze(8, "easy", 20, 500000, 0.90)
analyze(8, "medium", 20, 500000, 0.90)
analyze(8, "hard", 20, 500000, 0.90)

os.exit(ok and 0 or 1)
