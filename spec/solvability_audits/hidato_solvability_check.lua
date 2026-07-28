-- Uniqueness regression check for hidato.koplugin.
--
-- This is NOT a busted spec -- see docs/generator_robustness_audit.md,
-- "Human-solvability audit" section, for why this class of check needs its
-- own tooling separate from `busted spec/`.
--
-- Run from the repo root:
--   luajit spec/solvability_audits/hidato_solvability_check.lua
--
-- Background: before 2026-07-22, hidato revealed a flat `given_ratio` of
-- random intermediate cells with zero uniqueness verification (see the
-- original `hidato_uniqueness_diagnostic.lua` finding: 0% unique at every
-- size/difficulty, including Easy -- king-move (8-directional) adjacency
-- gives far more path-completion freedom than numbrix's orthogonal-only,
-- compounding the same missing-verification bug). Fixed the same way as
-- numbrix: dig cells one at a time (like sudoku-common's hole-digging) --
-- start fully revealed, tentatively hide each intermediate cell in random
-- order, verify with `countCompletions` (an independent king-move
-- Hamiltonian-path-completion counter, separate code from board.lua's own
-- copy) after each removal, put the cell back if that broke uniqueness.
-- Re-run this after any future change to board.lua's
-- `generate`/`countCompletions`/`GIVEN_RATIOS` to catch a regression.
--
-- Exit code is non-zero if any difficulty drops below its threshold.

package.preload["gettext"] = function() return function(s) return s end end
package.path = "game-common/?.lua;hidato.koplugin/?.lua;" .. package.path
local Board = require("board")

local DIRS = { {-1,-1},{-1,0},{-1,1},{0,-1},{0,1},{1,-1},{1,0},{1,1} }

-- Counts Hamiltonian-path completions (up to `limit`) consistent with the
-- given fixed cells, placing numbers 1..n*n in order (each must land on a
-- king-move-adjacent unoccupied cell, or the pre-fixed cell if given).
-- Deliberately separate from board.lua's own countCompletions -- cross-
-- checks the production gate rather than testing a fix against itself.
local function countCompletions(b, limit, node_budget)
    local n = b.n
    local total = n * n
    local cell_of_num = {}
    local num_of_cell = {}
    for r = 1, n do num_of_cell[r] = {} end

    local solutions, nodes, exhausted = 0, 0, false

    local function search(num)
        if solutions >= limit or exhausted then return end
        nodes = nodes + 1
        if nodes > node_budget then exhausted = true; return end
        if num > total then solutions = solutions + 1; return end

        local given_pos = nil
        for r = 1, n do
            for c = 1, n do
                if b.given[r][c] and b.puzzle[r][c] == num then given_pos = {r,c}; break end
            end
            if given_pos then break end
        end

        if num == 1 then
            if given_pos then
                cell_of_num[1] = given_pos
                num_of_cell[given_pos[1]][given_pos[2]] = 1
                search(2)
                num_of_cell[given_pos[1]][given_pos[2]] = nil
            else
                for r = 1, n do
                    for c = 1, n do
                        if not num_of_cell[r][c] then
                            cell_of_num[1] = {r,c}
                            num_of_cell[r][c] = 1
                            search(2)
                            num_of_cell[r][c] = nil
                            if solutions >= limit or exhausted then return end
                        end
                    end
                end
            end
            return
        end

        for r = 1, n do
            for c = 1, n do
                if b.given[r][c] and b.puzzle[r][c] == num then given_pos = {r,c}; break end
            end
            if given_pos then break end
        end

        local prev = cell_of_num[num - 1]
        local candidates = {}
        for _, d in ipairs(DIRS) do
            local nr, nc = prev[1] + d[1], prev[2] + d[2]
            if nr >= 1 and nr <= n and nc >= 1 and nc <= n and not num_of_cell[nr][nc] then
                candidates[#candidates+1] = {nr, nc}
            end
        end
        if given_pos then
            local ok = false
            for _, cand in ipairs(candidates) do
                if cand[1] == given_pos[1] and cand[2] == given_pos[2] then ok = true; break end
            end
            if ok then
                cell_of_num[num] = given_pos
                num_of_cell[given_pos[1]][given_pos[2]] = num
                search(num + 1)
                num_of_cell[given_pos[1]][given_pos[2]] = nil
            end
        else
            for _, cand in ipairs(candidates) do
                if not b.given[cand[1]][cand[2]] then
                    cell_of_num[num] = cand
                    num_of_cell[cand[1]][cand[2]] = num
                    search(num + 1)
                    num_of_cell[cand[1]][cand[2]] = nil
                    if solutions >= limit or exhausted then return end
                end
            end
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
        local solutions, exhausted = countCompletions(b, 2, 200000)
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
