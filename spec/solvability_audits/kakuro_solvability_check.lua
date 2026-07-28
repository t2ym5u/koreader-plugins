-- Uniqueness + human-solvability regression check for kakuro.koplugin.
--
-- This is NOT a busted spec -- see docs/generator_robustness_audit.md,
-- "Human-solvability audit" section, for why this class of check needs its
-- own tooling separate from `busted spec/`.
--
-- Run from the repo root:
--   luajit spec/solvability_audits/kakuro_solvability_check.lua
--
-- STATUS (2026-07-22): CONFIRMED BUG, NOT YET FIXED. This script is expected
-- to print [FAIL] for all 3 difficulties against the current board.lua --
-- that's not a regression, it's the known baseline. Keep it around so
-- whoever picks this back up can tell the moment a real fix lands (it'll
-- flip to [OK]), instead of re-discovering the bug from scratch.
--
-- The bug: kakuro's templates are solid rectangular blocks of white cells
-- (e.g. Easy = two independent 4x2 blocks). ANY such rectangular block
-- admits a "generalized rectangle swap" -- shift two cells in one row by
-- +d and the matching two cells in another row/column pair by -d, which
-- preserves every row and column sum -- so a clue set derived from one
-- random fill is (empirically, always) satisfied by another fill too.
-- Measured 0/45 unique solutions across all 3 difficulties, and even 500
-- retried random fills of the *same* template never found a unique one.
--
-- What was tried and reverted (all still ~0% unique, or otherwise broken):
--   1. Merging each template's 2 disconnected blocks into 1 bigger solid
--      block -- same rectangle-swap symmetry, just at a larger scale.
--   2. A pure "staircase" of 2-cell dominos (no 2 rows ever share both
--      columns of their across-run, which provably rules out the swap) --
--      but a linear domino chain's 2 endpoints always end up in a length-1
--      down-run, which the sanitiser strips, which cascades into stripping
--      the *entire* chain. Every attempt to terminate the chain safely
--      (wider end segments, L-shaped caps, extra anchor rows) either
--      reintroduced the swap symmetry at the join or reproduced the same
--      cascade one step further out -- this dichotomy is the core obstacle.
--   3. Random and periodic ("brick") black-cell patterns, verified via the
--      SAME code that's in this file: 0/60+ unique across many random
--      patterns and digit-fills at 9x10, even with retry budgets up to 500
--      fills per pattern. The swap turned out to be pervasive at this
--      grid scale, not specific to any one construction.
--   4. Shipped the width-2 staircase to board.lua at one point -- turned
--      out its two endpoints DO get sanitiser-stripped as predicted, which
--      collapsed every difficulty to the 5x5 emergency fallback puzzle
--      every single generation (worse than the original bug: always the
--      *same* tiny puzzle, no variety). Caught via this script + a
--      dimension check, and reverted immediately -- see git history around
--      2026-07-22 for the full (reverted) diff if picking this back up.
--
-- Untried directions worth exploring next: (a) a real constraint-directed
-- construction that builds the black-cell pattern and digit-fill jointly
-- with an explicit anti-swap heuristic (e.g. biasing toward near-extremal
-- run sums, which mathematically restricts the swap's degrees of freedom
-- the closer a run gets to using all or none of 1-9); (b) much larger grids
-- (15x15+) where swap opportunities might be rarer relative to grid area --
-- untested here because the search itself got too slow to iterate on before
-- reaching a verdict (worth profiling/optimizing countRunSolutions first).
--
-- Exit code is non-zero if either check drops below its threshold (expected
-- for now).

package.preload["gettext"] = function() return function(s) return s end end
package.path = "game-common/?.lua;kakuro.koplugin/?.lua;" .. package.path
local Board = require("board")

-- --- Part 1: uniqueness (independent counting solver, separate code from
-- board.lua's own countRunSolutions -- cross-checks the production gate
-- rather than testing a fix against itself) -----------------------------

local function countSolutions(b, limit, node_budget)
    local n_rows, n_cols = b.n_rows, b.n_cols
    local across_run, down_run = {}, {}
    for r = 1, n_rows do across_run[r] = {}; down_run[r] = {} end
    for r = 1, n_rows do
        local c = 1
        while c <= n_cols do
            if b.grid[r][c].type == "white" then
                local cells = {}
                local clue_cell = b:getCell(r, c - 1)
                local clue = clue_cell and clue_cell.across or 0
                while c <= n_cols and b.grid[r][c].type == "white" do
                    cells[#cells + 1] = { r = r, c = c }; c = c + 1
                end
                if #cells >= 2 then
                    for _, cell in ipairs(cells) do across_run[cell.r][cell.c] = { sum = clue, cells = cells } end
                end
            else c = c + 1 end
        end
    end
    for c = 1, n_cols do
        local r = 1
        while r <= n_rows do
            if b.grid[r][c].type == "white" then
                local cells = {}
                local clue_cell = b:getCell(r - 1, c)
                local clue = clue_cell and clue_cell.down or 0
                while r <= n_rows and b.grid[r][c].type == "white" do
                    cells[#cells + 1] = { r = r, c = c }; r = r + 1
                end
                if #cells >= 2 then
                    for _, cell in ipairs(cells) do down_run[cell.r][cell.c] = { sum = clue, cells = cells } end
                end
            else r = r + 1 end
        end
    end
    local white_cells = {}
    for r = 1, n_rows do for c = 1, n_cols do
        if b.grid[r][c].type == "white" then white_cells[#white_cells + 1] = { r = r, c = c } end
    end end
    local grid = {}
    for r = 1, n_rows do grid[r] = {}; for c = 1, n_cols do grid[r][c] = 0 end end
    local solutions, nodes, exhausted = 0, 0, false
    local function usedAndRemaining(run)
        local fs, fc = 0, 0
        for _, cell in ipairs(run.cells) do
            local v = grid[cell.r][cell.c]
            if v ~= 0 then fs = fs + v; fc = fc + 1 end
        end
        return fs, fc
    end
    local function candidatesFor(r, c)
        local arun, drun = across_run[r][c], down_run[r][c]
        local used = {}
        local function markUsed(run)
            if run then for _, cell in ipairs(run.cells) do
                local v = grid[cell.r][cell.c]
                if v ~= 0 then used[v] = true end
            end end
        end
        markUsed(arun); markUsed(drun)
        local cands = {}
        for v = 1, 9 do
            if not used[v] then
                local ok = true
                if arun then
                    local fs, fc = usedAndRemaining(arun)
                    local ra = #arun.cells - fc - 1
                    local rs = arun.sum - fs - v
                    if rs < 0 or (ra == 0 and rs ~= 0) then ok = false end
                    if ok and ra > 0 and (rs < ra or rs > ra * 9) then ok = false end
                end
                if ok and drun then
                    local fs, fc = usedAndRemaining(drun)
                    local ra = #drun.cells - fc - 1
                    local rs = drun.sum - fs - v
                    if rs < 0 or (ra == 0 and rs ~= 0) then ok = false end
                    if ok and ra > 0 and (rs < ra or rs > ra * 9) then ok = false end
                end
                if ok then cands[#cands + 1] = v end
            end
        end
        return cands
    end
    local function search(depth)
        if solutions >= limit or exhausted then return end
        nodes = nodes + 1
        if nodes > node_budget then exhausted = true; return end
        if depth > #white_cells then solutions = solutions + 1; return end
        local best_idx, best_cands, best_len = nil, nil, 1000
        for i, cell in ipairs(white_cells) do
            if grid[cell.r][cell.c] == 0 then
                local cands = candidatesFor(cell.r, cell.c)
                if #cands < best_len then
                    best_len, best_cands, best_idx = #cands, cands, i
                    if best_len <= 1 then break end
                end
            end
        end
        if best_idx == nil then solutions = solutions + 1; return end
        if best_len == 0 then return end
        local cell = white_cells[best_idx]
        for _, v in ipairs(best_cands) do
            grid[cell.r][cell.c] = v
            search(depth + 1)
            grid[cell.r][cell.c] = 0
            if solutions >= limit or exhausted then return end
        end
    end
    search(1)
    return solutions, exhausted, nodes
end

-- --- Part 2: human-solvability (naked/hidden singles + per-run combo
-- elimination, no backtracking) ------------------------------------------

local function combosFor(size, target)
    local combos = {}
    local function rec(start, chosen, remaining_sum, remaining_slots)
        if remaining_slots == 0 then
            if remaining_sum == 0 then
                local copy = {}
                for i = 1, #chosen do copy[i] = chosen[i] end
                combos[#combos + 1] = copy
            end
            return
        end
        for v = start, 9 do
            if remaining_sum - v >= 0 then
                chosen[#chosen + 1] = v
                rec(v + 1, chosen, remaining_sum - v, remaining_slots - 1)
                chosen[#chosen] = nil
            end
        end
    end
    rec(1, {}, target, size)
    return combos
end

local function humanSolve(b)
    local n_rows, n_cols = b.n_rows, b.n_cols
    local across_runs, down_runs = {}, {}
    for r = 1, n_rows do
        local c = 1
        while c <= n_cols do
            if b.grid[r][c].type == "white" then
                local cells = {}
                local clue_cell = b:getCell(r, c - 1)
                local clue = clue_cell and clue_cell.across or 0
                while c <= n_cols and b.grid[r][c].type == "white" do cells[#cells + 1] = { r = r, c = c }; c = c + 1 end
                if #cells >= 2 then across_runs[#across_runs + 1] = { sum = clue, cells = cells } end
            else c = c + 1 end
        end
    end
    for c = 1, n_cols do
        local r = 1
        while r <= n_rows do
            if b.grid[r][c].type == "white" then
                local cells = {}
                local clue_cell = b:getCell(r - 1, c)
                local clue = clue_cell and clue_cell.down or 0
                while r <= n_rows and b.grid[r][c].type == "white" do cells[#cells + 1] = { r = r, c = c }; r = r + 1 end
                if #cells >= 2 then down_runs[#down_runs + 1] = { sum = clue, cells = cells } end
            else r = r + 1 end
        end
    end

    local grid = {}
    for r = 1, n_rows do grid[r] = {}; for c = 1, n_cols do
        grid[r][c] = (b.grid[r][c].type == "white") and 0 or -1
    end end

    local progress, iterations = true, 0
    while progress do
        progress = false
        iterations = iterations + 1
        if iterations > 200 then break end

        local cand = {}
        for r = 1, n_rows do
            cand[r] = {}
            for c = 1, n_cols do
                if grid[r][c] == 0 then
                    local s = {}
                    for v = 1, 9 do s[v] = true end
                    cand[r][c] = s
                end
            end
        end

        local function narrowRun(run)
            local empties, filled_sum, filled_digits = {}, 0, {}
            for _, cell in ipairs(run.cells) do
                local v = grid[cell.r][cell.c]
                if v ~= 0 then filled_sum = filled_sum + v; filled_digits[v] = true
                else empties[#empties + 1] = cell end
            end
            if #empties == 0 then return end
            local target = run.sum - filled_sum
            local combos = combosFor(#empties, target)
            local possible = {}
            for i = 1, #empties do possible[i] = {} end
            for _, combo in ipairs(combos) do
                local ok = true
                for _, d in ipairs(combo) do if filled_digits[d] then ok = false break end end
                if ok then
                    local k = #empties
                    local used, order = {}, {}
                    local function permCheck(idx)
                        if idx > k then
                            for i = 1, k do possible[i][order[i]] = true end
                            return
                        end
                        for _, d in ipairs(combo) do
                            if not used[d] and cand[empties[idx].r][empties[idx].c][d] then
                                used[d] = true; order[idx] = d
                                permCheck(idx + 1)
                                used[d] = nil
                            end
                        end
                    end
                    permCheck(1)
                end
            end
            for i, cell in ipairs(empties) do
                local newset = {}
                for v = 1, 9 do if cand[cell.r][cell.c][v] and possible[i][v] then newset[v] = true end end
                cand[cell.r][cell.c] = newset
            end
        end
        for _, run in ipairs(across_runs) do narrowRun(run) end
        for _, run in ipairs(down_runs) do narrowRun(run) end

        for r = 1, n_rows do for c = 1, n_cols do
            if grid[r][c] == 0 then
                local s = cand[r][c]
                local only, count = nil, 0
                for v = 1, 9 do if s[v] then count = count + 1; only = v end end
                if count == 1 then grid[r][c] = only; progress = true
                elseif count == 0 then return 0, 1 end
            end
        end end
    end

    local solved, total = 0, 0
    for r = 1, n_rows do for c = 1, n_cols do
        if grid[r][c] ~= -1 then
            total = total + 1
            if grid[r][c] ~= 0 then solved = solved + 1 end
        end
    end end
    return solved, total
end

local THRESHOLDS = { unique = 0.9, solvable = 0.9 }
local ok = true

local function trial(difficulty, n_trials)
    local unique_count, solved_count, total_completion = 0, 0, 0
    for i = 1, n_trials do
        math.randomseed(i * 7919)
        local b = Board:new({ difficulty = difficulty })
        b:generate()
        local solutions, exhausted = countSolutions(b, 2, 300000)
        if not exhausted and solutions == 1 then unique_count = unique_count + 1 end
        local solved, total = humanSolve(b)
        total_completion = total_completion + solved / total
        if solved == total then solved_count = solved_count + 1 end
    end
    local unique_rate, solve_rate = unique_count / n_trials, solved_count / n_trials
    local status = "OK"
    if unique_rate < THRESHOLDS.unique or solve_rate < THRESHOLDS.solvable then
        status = "FAIL"; ok = false
    end
    print(string.format("[%s] %s: unique=%d/%d  fully-solved-by-logic=%d/%d  avg completion %.1f%%",
        status, difficulty, unique_count, n_trials, solved_count, n_trials, 100 * total_completion / n_trials))
    io.flush()
end

trial("easy", 20)
trial("medium", 15)
trial("hard", 10)

os.exit(ok and 0 or 1)
