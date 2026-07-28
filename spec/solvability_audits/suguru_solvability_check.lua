-- Uniqueness regression check for suguru.koplugin.
--
-- This is NOT a busted spec -- see docs/generator_robustness_audit.md,
-- "Human-solvability audit" section, for why this class of check needs its
-- own tooling separate from `busted spec/`.
--
-- Run from the repo root:
--   luajit spec/solvability_audits/suguru_solvability_check.lua
--
-- Background: before 2026-07-22, suguru's `removeClues` kept a flat
-- `keep_ratio` of random cells with zero uniqueness verification (measured,
-- original `suguru_uniqueness_diagnostic.lua`: severe -- only Easy ever
-- produced a unique puzzle, and rarely). Fixed by digging cells one at a
-- time (like sudoku-common's hole-digging, and the same pattern applied to
-- rippleeffect the same session -- suguru's `isValid` is the same shape
-- minus the ripple-separation rule): tentatively remove each cell in random
-- order, verify with `countSolutions` (an independent MRV backtracking
-- counter, separate code from board.lua's own copy) after each removal, put
-- the cell back if that broke uniqueness. Re-run this after any future
-- change to board.lua's `removeClues`/`countSolutions` to catch a
-- regression.
--
-- Exit code is non-zero if any difficulty drops below its threshold.

package.preload["gettext"] = function() return function(s) return s end end
package.path = "game-common/?.lua;suguru.koplugin/?.lua;" .. package.path
local Board = require("board")

local DIR8 = {{-1,-1},{-1,0},{-1,1},{0,-1},{0,1},{1,-1},{1,0},{1,1}}

-- Deliberately separate from board.lua's own countSolutions -- cross-checks
-- the production gate rather than testing a fix against itself.
local function countSolutions(b, limit, node_budget)
    local n = b.n
    local grid = {}
    for r = 1, n do grid[r] = {}; for c = 1, n do grid[r][c] = b.puzzle[r][c] end end
    local solutions, nodes, exhausted = 0, 0, false

    local function isValid(r, c, v)
        local id = b.cage_id[r][c]
        local cage = b.cages[id]
        if v > cage.size then return false end
        for _, cell in ipairs(cage.cells) do
            local cr, cc = cell[1], cell[2]
            if not (cr == r and cc == c) and grid[cr][cc] == v then return false end
        end
        for _, d in ipairs(DIR8) do
            local nr, nc = r + d[1], c + d[2]
            if nr >= 1 and nr <= n and nc >= 1 and nc <= n and grid[nr][nc] == v then return false end
        end
        return true
    end

    local empties = {}
    for r = 1, n do for c = 1, n do if grid[r][c] == 0 then empties[#empties+1] = {r=r,c=c} end end end

    local function candidatesFor(r, c)
        local cage = b.cages[b.cage_id[r][c]]
        local cands = {}
        for v = 1, cage.size do if isValid(r, c, v) then cands[#cands+1] = v end end
        return cands
    end

    local function search(depth)
        if solutions >= limit or exhausted then return end
        nodes = nodes + 1
        if nodes > node_budget then exhausted = true; return end
        if depth > #empties then solutions = solutions + 1; return end
        local best_idx, best_cands, best_len = nil, nil, 1000
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
            search(depth + 1)
            grid[cell.r][cell.c] = 0
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

for _, n in ipairs({5, 6}) do
    for _, diff in ipairs({"easy", "medium", "hard"}) do
        analyze(n, diff, 20)
    end
end

os.exit(ok and 0 or 1)
