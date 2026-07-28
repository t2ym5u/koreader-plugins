-- Uniqueness regression check for skyscraper.koplugin.
--
-- This is NOT a busted spec -- see docs/generator_robustness_audit.md,
-- "Human-solvability audit" section, for why this class of check needs its
-- own tooling separate from `busted spec/`.
--
-- Run from the repo root:
--   luajit spec/solvability_audits/skyscraper_solvability_check.lua
--
-- Background: before 2026-07-22, skyscraper kept a flat CLUE_RATIOS ratio
-- of random visibility clues (its only clue type -- no cell givens at all)
-- with zero uniqueness verification (measured, original
-- `skyscraper_uniqueness_diagnostic.lua`: severe, near-0% unique even on
-- Easy). Digging clues one at a time (like sudoku-common's hole-digging)
-- alone wasn't enough to fix this: even the FULL 4n-clue set (before any
-- digging) isn't always unique for an arbitrary Latin square -- distinct
-- squares can produce identical visibility-clue vectors in all 4
-- directions (same structural shape as kakuro's "generalized rectangle
-- swap", just at these small grid sizes). Digging can only ever remove
-- information, so a Latin square whose full clue set is already ambiguous
-- can never be rescued by hiding clues. Fixed with two layers: (1) an
-- outer retry that regenerates the Latin square if its full clue set isn't
-- provably unique, then (2) the usual digging-with-verification down to
-- the difficulty's target clue count. Re-run this after any future change
-- to board.lua's `generate`/`countSolutions`/`computeAllClues` to catch a
-- regression.
--
-- Exit code is non-zero if any difficulty drops below its threshold.

package.preload["gettext"] = function() return function(s) return s end end
package.path = "game-common/?.lua;skyscraper.koplugin/?.lua;" .. package.path
local Board = require("board")

local function visibleCount(seq)
    local count, best = 0, 0
    for _, v in ipairs(seq) do
        if v > best then count = count + 1; best = v end
    end
    return count
end

-- Full Latin-square backtracking, checking exposed visibility clues once a
-- row/column is fully determined -- n is tiny (4-5) so this stays cheap.
-- Deliberately separate from board.lua's own countSolutions -- cross-checks
-- the production gate rather than testing a fix against itself.
local function countSolutions(b, limit, node_budget)
    local n = b.n
    local grid = {}
    for r = 1, n do grid[r] = {}; for c = 1, n do grid[r][c] = 0 end end
    local solutions, nodes, exhausted = 0, 0, false

    local function rowComplete(r)
        for c = 1, n do if grid[r][c] == 0 then return false end end
        return true
    end
    local function colComplete(c)
        for r = 1, n do if grid[r][c] == 0 then return false end end
        return true
    end
    local function checkRowClues(r)
        local seq = {}
        for c = 1, n do seq[c] = grid[r][c] end
        if b.clues.left[r] then
            if visibleCount(seq) ~= b.clues.left[r] then return false end
        end
        if b.clues.right[r] then
            local rev = {}
            for i = 1, n do rev[i] = seq[n - i + 1] end
            if visibleCount(rev) ~= b.clues.right[r] then return false end
        end
        return true
    end
    local function checkColClues(c)
        local seq = {}
        for r = 1, n do seq[r] = grid[r][c] end
        if b.clues.top[c] then
            if visibleCount(seq) ~= b.clues.top[c] then return false end
        end
        if b.clues.bottom[c] then
            local rev = {}
            for i = 1, n do rev[i] = seq[n - i + 1] end
            if visibleCount(rev) ~= b.clues.bottom[c] then return false end
        end
        return true
    end

    local function candidatesFor(r, c)
        local used = {}
        for cc = 1, n do if grid[r][cc] ~= 0 then used[grid[r][cc]] = true end end
        for rr = 1, n do if grid[rr][c] ~= 0 then used[grid[rr][c]] = true end end
        local cands = {}
        for v = 1, n do if not used[v] then cands[#cands+1] = v end end
        return cands
    end

    local cells = {}
    for r = 1, n do for c = 1, n do cells[#cells+1] = {r=r,c=c} end end

    local function search(depth)
        if solutions >= limit or exhausted then return end
        nodes = nodes + 1
        if nodes > node_budget then exhausted = true; return end
        if depth > #cells then solutions = solutions + 1; return end
        local best_idx, best_cands, best_len = nil, nil, n+1
        for i, cell in ipairs(cells) do
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
        local cell = cells[best_idx]
        for _, v in ipairs(best_cands) do
            grid[cell.r][cell.c] = v
            local ok = true
            if rowComplete(cell.r) and not checkRowClues(cell.r) then ok = false end
            if ok and colComplete(cell.c) and not checkColClues(cell.c) then ok = false end
            if ok then search(depth + 1) end
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
        local solutions, exhausted = countSolutions(b, 2, 500000)
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

for _, n in ipairs({4, 5}) do
    for _, diff in ipairs({"easy", "medium", "hard"}) do
        analyze(n, diff, 20)
    end
end

os.exit(ok and 0 or 1)
