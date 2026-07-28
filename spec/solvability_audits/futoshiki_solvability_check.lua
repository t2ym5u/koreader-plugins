-- Uniqueness regression check for futoshiki.koplugin.
--
-- This is NOT a busted spec -- see docs/generator_robustness_audit.md,
-- "Human-solvability audit" section, for why this class of check needs its
-- own tooling separate from `busted spec/`.
--
-- Run from the repo root:
--   luajit spec/solvability_audits/futoshiki_solvability_check.lua
--
-- Background: before 2026-07-22, futoshiki's given-cell selection kept a
-- flat GIVEN_RATIOS ratio of random cells with zero uniqueness
-- verification (measured, original `futoshiki_uniqueness_diagnostic.lua`:
-- fine at small sizes/easy, degrading to 0% unique at n=7/hard). Fixed by
-- digging cells one at a time (like sudoku-common's hole-digging): the
-- visible inequality constraint set is chosen first and stays fixed (a
-- fully-given grid is trivially unique regardless of which constraints are
-- shown, so it doesn't need separate verification), then start fully
-- revealed and tentatively hide each cell in random order, verify with
-- `countSolutions` (an independent MRV backtracking counter, separate code
-- from board.lua's own copy) after each removal, put the cell back if that
-- broke uniqueness. Re-run this after any future change to board.lua's
-- `generate`/`countSolutions` to catch a regression.
--
-- Exit code is non-zero if any difficulty drops below its threshold.

package.preload["gettext"] = function() return function(s) return s end end
package.path = "game-common/?.lua;futoshiki.koplugin/?.lua;" .. package.path
local Board = require("board")

-- Deliberately separate from board.lua's own countSolutions -- cross-checks
-- the production gate rather than testing a fix against itself.
local function countSolutions(b, limit, node_budget)
    local n = b.n
    local grid = {}
    for r = 1, n do
        grid[r] = {}
        for c = 1, n do grid[r][c] = b.given[r][c] and b.puzzle[r][c] or 0 end
    end
    local cons = {}
    for r = 1, n do cons[r] = {}; for c = 1, n do cons[r][c] = {} end end
    for _, con in ipairs(b.constraints) do
        table.insert(cons[con.r1][con.c1], { r = con.r2, c = con.c2, self_less = con.less })
        table.insert(cons[con.r2][con.c2], { r = con.r1, c = con.c1, self_less = not con.less })
    end

    local solutions, nodes, exhausted = 0, 0, false

    local function rowUsed(r)
        local u = {}
        for c = 1, n do if grid[r][c] ~= 0 then u[grid[r][c]] = true end end
        return u
    end
    local function colUsed(c)
        local u = {}
        for r = 1, n do if grid[r][c] ~= 0 then u[grid[r][c]] = true end end
        return u
    end

    local function candidatesFor(r, c)
        local ru, cu = rowUsed(r), colUsed(c)
        local cands = {}
        for v = 1, n do
            if not ru[v] and not cu[v] then
                local ok = true
                for _, con in ipairs(cons[r][c]) do
                    local ov = grid[con.r][con.c]
                    if ov ~= 0 then
                        if con.self_less and not (v < ov) then ok = false; break end
                        if not con.self_less and not (v > ov) then ok = false; break end
                    end
                end
                if ok then cands[#cands + 1] = v end
            end
        end
        return cands
    end

    local function search(depth, empties)
        if solutions >= limit or exhausted then return end
        nodes = nodes + 1
        if nodes > node_budget then exhausted = true; return end
        if depth > #empties then solutions = solutions + 1; return end
        local best_idx, best_cands, best_len = nil, nil, n + 1
        for i, cell in ipairs(empties) do
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
        local cell = empties[best_idx]
        for _, v in ipairs(best_cands) do
            grid[cell.r][cell.c] = v
            search(depth + 1, empties)
            grid[cell.r][cell.c] = 0
            if solutions >= limit or exhausted then return end
        end
    end

    local empties = {}
    for r = 1, n do for c = 1, n do if grid[r][c] == 0 then empties[#empties+1] = {r=r,c=c} end end end
    search(1, empties)
    return solutions, exhausted
end

local THRESHOLD = 0.95
local ok = true

local function analyze(n, difficulty, n_trials)
    local unique, ambiguous, inconclusive = 0, 0, 0
    for i = 1, n_trials do
        math.randomseed(i * 7919)
        local b = Board:new({ n = n, difficulty = difficulty })
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

for _, n in ipairs({5, 7}) do
    for _, diff in ipairs({"easy", "medium", "hard"}) do
        analyze(n, diff, 20)
    end
end

os.exit(ok and 0 or 1)
