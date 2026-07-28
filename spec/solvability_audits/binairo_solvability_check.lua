-- Uniqueness regression check for binairo.koplugin.
--
-- This is NOT a busted spec -- see docs/generator_robustness_audit.md,
-- "Human-solvability audit" section, for why this class of check needs its
-- own tooling separate from `busted spec/`.
--
-- Run from the repo root:
--   luajit spec/solvability_audits/binairo_solvability_check.lua
--
-- Background: before 2026-07-22, binairo revealed a flat REVEAL ratio of
-- random cells with zero uniqueness verification. The *original* diagnostic
-- script used to measure this (now deleted) had its own bug -- a full-row
-- "run tracker" that incorrectly treated undetermined cells as transparent
-- to a run-of-3 check, over-rejecting valid partial grids and inflating
-- the apparent ambiguity to 0% unique at every setting. Re-measuring with
-- this file's correct local-adjacency check (matching board.lua's own
-- `_canPlace`) shows the original bug was real but less uniform: moderate
-- on Easy, severe on Hard (same shape as numbrix/rippleeffect, not a flat
-- 0%) -- see docs/generator_robustness_audit.md's Tier 2 table for the
-- corrected numbers.
--
-- A second, deeper bug surfaced while fixing this: `_fill` (the solution
-- builder) never enforced "all rows distinct, all columns distinct" (rule 3
-- in the module doc comment, previously flagged "soft -- not enforced").
-- Since `checkErrors`/`_isComplete` compare a player's answer directly
-- against the stored `solution` (not general rule-validity), a stored
-- solution that itself violated rule 3 could make the uniqueness counter
-- report 0 solutions for its own clue set -- fixed by enforcing rule 3 in
-- `_fill` too, and adding matching distinct-row/col checks to the digging
-- loop's own `countSolutions`.
--
-- Fixed by digging cells one at a time (like sudoku-common's hole-digging):
-- start fully revealed, tentatively hide each cell in random order, verify
-- with `countSolutions` (an independent MRV backtracking counter, separate
-- code from board.lua's own copy) after each removal, put the cell back if
-- that broke uniqueness. Re-run this after any future change to
-- board.lua's `generate`/`_fill`/`countSolutions` to catch a regression.
--
-- Exit code is non-zero if any difficulty drops below its threshold.

package.preload["gettext"] = function() return function(s) return s end end
package.path = "game-common/?.lua;binairo.koplugin/?.lua;" .. package.path
local Board = require("board")

-- Deliberately separate from board.lua's own countSolutions -- cross-checks
-- the production gate rather than testing a fix against itself.
local function countSolutions(b, limit, node_budget)
    local n = b.n
    local grid = {}
    for r = 1, n do
        grid[r] = {}
        for c = 1, n do grid[r][c] = b.given[r][c] and b.cells[r][c] or -1 end
    end
    local solutions, nodes, exhausted = 0, 0, false

    local function canPlace(r, c, v)
        local left = 0
        for j = c - 1, math.max(1, c - 2), -1 do
            if grid[r][j] == v then left = left + 1 else break end
        end
        local right = 0
        for j = c + 1, math.min(n, c + 2) do
            if grid[r][j] == v then right = right + 1 else break end
        end
        if left + right >= 2 then return false end
        local up = 0
        for i = r - 1, math.max(1, r - 2), -1 do
            if grid[i][c] == v then up = up + 1 else break end
        end
        local down = 0
        for i = r + 1, math.min(n, r + 2) do
            if grid[i][c] == v then down = down + 1 else break end
        end
        if up + down >= 2 then return false end
        local rc = 0
        for j = 1, n do if grid[r][j] == v then rc = rc + 1 end end
        if rc >= n / 2 then return false end
        local cc = 0
        for i = 1, n do if grid[i][c] == v then cc = cc + 1 end end
        if cc >= n / 2 then return false end
        return true
    end

    local function rowFull(r) for c = 1, n do if grid[r][c] == -1 then return false end end return true end
    local function colFull(c) for r = 1, n do if grid[r][c] == -1 then return false end end return true end
    local function rowDistinct(r)
        for r2 = 1, r - 1 do
            local same = true
            for c = 1, n do if grid[r2][c] ~= grid[r][c] then same = false; break end end
            if same then return false end
        end
        return true
    end
    local function colDistinct(c)
        for c2 = 1, c - 1 do
            local same = true
            for r = 1, n do if grid[r][c2] ~= grid[r][c] then same = false; break end end
            if same then return false end
        end
        return true
    end

    local empties = {}
    for r = 1, n do for c = 1, n do if grid[r][c] == -1 then empties[#empties + 1] = { r = r, c = c } end end end

    local function candidatesFor(r, c)
        local cands = {}
        for _, v in ipairs({ 0, 1 }) do if canPlace(r, c, v) then cands[#cands + 1] = v end end
        return cands
    end

    local function search(depth)
        if solutions >= limit or exhausted then return end
        nodes = nodes + 1
        if nodes > node_budget then exhausted = true; return end
        if depth > #empties then solutions = solutions + 1; return end
        local best_idx, best_cands, best_len = nil, nil, 3
        for i, cell in ipairs(empties) do
            if grid[cell.r][cell.c] == -1 then
                local cands = candidatesFor(cell.r, cell.c)
                if #cands < best_len then
                    best_len, best_cands, best_idx = #cands, cands, i
                    if best_len <= 1 then break end
                end
            end
        end
        if best_idx == nil then solutions = solutions + 1; return end
        if best_len == 0 then return end
        local cell = empties[best_idx]
        for _, v in ipairs(best_cands) do
            grid[cell.r][cell.c] = v
            local ok = true
            if rowFull(cell.r) and not rowDistinct(cell.r) then ok = false end
            if ok and colFull(cell.c) and not colDistinct(cell.c) then ok = false end
            if ok then search(depth + 1) end
            grid[cell.r][cell.c] = -1
            if solutions >= limit or exhausted then return end
        end
    end
    search(1)
    return solutions, exhausted
end

local THRESHOLD = 0.95
local ok = true

local function analyze(n, difficulty, n_trials)
    local unique, ambiguous, inconclusive = 0, 0, 0
    for i = 1, n_trials do
        math.randomseed(i * 7919)
        local b = Board:new({ n = n, difficulty = difficulty })
        b:generate(n, difficulty)
        local solutions, exhausted = countSolutions(b, 2, 300000)
        if exhausted then inconclusive = inconclusive + 1
        elseif solutions == 1 then unique = unique + 1
        else ambiguous = ambiguous + 1 end
    end
    local rate = unique / n_trials
    local status = rate >= THRESHOLD and "OK" or "FAIL"
    if status == "FAIL" then ok = false end
    print(string.format("[%s] n=%d %s: unique=%d/%d ambiguous=%d inconclusive=%d",
        status, n, difficulty, unique, n_trials, ambiguous, inconclusive))
    io.flush()
end

for _, n in ipairs({6, 8}) do
    for _, diff in ipairs({"easy", "medium", "hard"}) do
        analyze(n, diff, 20)
    end
end

os.exit(ok and 0 or 1)
