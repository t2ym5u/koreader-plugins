-- Uniqueness regression check for lightup.koplugin (Akari / Light Up).
--
-- This is NOT a busted spec -- see docs/generator_robustness_audit.md,
-- "Human-solvability audit" section, for why this class of check needs its
-- own tooling separate from `busted spec/`.
--
-- Run from the repo root:
--   luajit spec/solvability_audits/lightup_solvability_check.lua
--
-- Background: unlike most of this fleet, the win-check here is genuinely
-- RULE-based, not a literal comparison to a stored solution -- it accepts
-- ANY bulb placement where every white cell is lit, no two bulbs see each
-- other, and every numbered wall's adjacent-bulb count matches exactly.
-- `generate()` had zero verification that the black-cell/wall layout it
-- produced pinned down a unique such placement. Measured pre-fix: severe,
-- real ambiguity (0% unique at easy/medium across every size, ~13% even at
-- hard).
--
-- The uniqueness counter needed actual constraint propagation to be
-- tractable at all (a naive per-cell backtracking without it explores
-- enormous numbers of locally-valid-but-globally-unlit dead ends): before
-- every branch, propagate to a fixed point using the two classic Akari
-- deduction rules -- wall forcing (a numbered wall's remaining undecided
-- neighbors get forced to bulb/not-bulb once there's only one way left to
-- satisfy its count) and illumination forcing (a not-yet-lit cell with
-- exactly one remaining candidate across its row+col segments must be a
-- bulb) -- branching only when propagation alone can't finish.
--
-- A real bug was found and fixed in this counter while building it: an
-- earlier version of `setDecided` recorded the cell as decided (and, for a
-- bulb, marked its segments occupied) BEFORE checking whether that
-- segment already had a bulb from a different cell -- so a failed call
-- left `decided[r][c]` corrupted at `true` even though it returned false,
-- and the corresponding `undo()` (which decides whether to clear a
-- segment's bulb flag based on whether THIS cell is currently marked true)
-- would then wipe out the OTHER, legitimate cell's bulb registration in
-- that same segment. Caught via the standard sanity check (solver
-- returned solutions=0 for the generator's own known-good grid). Fixed by
-- checking the conflict before recording any state change at all.
--
-- Fixed generate+verify style (nothing to dig, same shape as hitori/
-- nurikabe/starbattle/shikaku/tents): repicking which black cells reveal
-- their wall number (for the SAME base black-cell+bulb layout) is much
-- cheaper than regenerating that layout from scratch, and more revealed
-- numbers can only add constraints -- same lever as shikaku's clue-cell
-- repositioning -- so the reveal ratio is escalated in bounded steps
-- (0.6 -> 0.8 -> 1.0, same shape as hitori's density escalation) before
-- falling back to a fresh base layout.
--
-- A real *performance* problem surfaced while tuning this (not a
-- correctness bug): an initial version retried the nominal ~60% reveal 20
-- times per base layout across 30 base layouts, with a large node budget
-- per attempt -- worst case over a MINUTE at n=14, because most of those
-- attempts were doomed from the start at low black-cell density ("easy")
-- and just burned through the whole budget without concluding anything,
-- every time. n=14/easy specifically: even a very generous budget mostly
-- just exhausts rather than resolving -- the underlying CSP is genuinely
-- under-constrained at that density, not a search-efficiency problem to
-- brute-force away. Retry effort is now scaled by size: n<=10 (fast enough
-- to spend real effort on, <5s worst case) gets the full escalation;
-- n=14 fails fast (few attempts, small budget) rather than grinding for
-- ~7s to land on the same ambiguous fallback it would have reached
-- immediately -- wasted latency, not improved quality.
--
-- Net result, matching nurikabe/starbattle's "partial fix, never worse"
-- shape: n=7 and n=10 are close to fully fixed at medium/hard (100%
-- measured), real improvement at easy (measured 67% and 47%
-- respectively, up from 0%). n=14 is only meaningfully improved at hard
-- (~80%) and medium (~33%) -- easy remains essentially unaddressed
-- (the CSP is too sparse to pin down quickly), same as before the fix,
-- but generation is fast everywhere now (worst case ~4.8s, at n=10/easy)
-- where it used to occasionally take 10s+ for zero benefit.
--
-- Exit code is non-zero if any size/difficulty drops below its threshold.

package.preload["gettext"] = function() return function(s) return s end end
package.path = "game-common/?.lua;lightup.koplugin/?.lua;" .. package.path
local Board = require("board")

local TYPE_WHITE, TYPE_BLACK_0, TYPE_BLACK_4 = 0, 2, 6
local DIR4 = { {-1,0},{1,0},{0,-1},{0,1} }
local function inBounds(r, c, n) return r >= 1 and r <= n and c >= 1 and c <= n end

-- Independent cross-check counter (deliberately separate from board.lua's
-- own copy) -- cross-checks the production gate rather than testing a fix
-- against itself.
local function buildSegments(grid, n)
    local row_seg, col_seg = {}, {}
    for r = 1, n do row_seg[r] = {}; col_seg[r] = {} end
    local row_cells, col_cells = {}, {}
    for r = 1, n do
        local c = 1
        while c <= n do
            if grid[r][c] == TYPE_WHITE then
                local id = "r" .. r .. "_" .. c
                local cells = {}
                while c <= n and grid[r][c] == TYPE_WHITE do
                    row_seg[r][c] = id; cells[#cells + 1] = { r, c }; c = c + 1
                end
                row_cells[id] = cells
            else
                c = c + 1
            end
        end
    end
    for c = 1, n do
        local r = 1
        while r <= n do
            if grid[r][c] == TYPE_WHITE then
                local id = "c" .. r .. "_" .. c
                local cells = {}
                while r <= n and grid[r][c] == TYPE_WHITE do
                    col_seg[r][c] = id; cells[#cells + 1] = { r, c }; r = r + 1
                end
                col_cells[id] = cells
            else
                r = r + 1
            end
        end
    end
    return row_seg, col_seg, row_cells, col_cells
end

local function countSolutions(grid, n, limit, node_budget)
    local row_seg, col_seg, row_cells, col_cells = buildSegments(grid, n)
    local decided = {}
    for r = 1, n do decided[r] = {} end
    local row_seg_bulb, col_seg_bulb = {}, {}
    local solutions, nodes, exhausted = 0, 0, false

    local function wallNeighbors(r, c)
        local nbrs = {}
        for _, d in ipairs(DIR4) do
            local nr, nc = r + d[1], c + d[2]
            if inBounds(nr, nc, n) and grid[nr][nc] == TYPE_WHITE then
                nbrs[#nbrs + 1] = { nr, nc }
            end
        end
        return nbrs
    end

    local function setDecided(r, c, val, changes)
        if decided[r][c] ~= nil then
            return decided[r][c] == val
        end
        if val then
            local rs, cs = row_seg[r][c], col_seg[r][c]
            if row_seg_bulb[rs] or col_seg_bulb[cs] then return false end
            row_seg_bulb[rs] = true
            col_seg_bulb[cs] = true
        end
        decided[r][c] = val
        changes[#changes + 1] = { r, c }
        return true
    end

    local function isLit(r, c)
        return row_seg_bulb[row_seg[r][c]] or col_seg_bulb[col_seg[r][c]]
    end

    local function propagate(changes)
        local progressed = true
        while progressed do
            progressed = false
            for r = 1, n do
                for c = 1, n do
                    local ct = grid[r][c]
                    if ct >= TYPE_BLACK_0 and ct <= TYPE_BLACK_4 then
                        local required = ct - TYPE_BLACK_0
                        local nbrs = wallNeighbors(r, c)
                        local have, undecided = 0, {}
                        for _, cell in ipairs(nbrs) do
                            local v = decided[cell[1]][cell[2]]
                            if v == true then have = have + 1
                            elseif v == nil then undecided[#undecided + 1] = cell end
                        end
                        if have > required or have + #undecided < required then
                            return false
                        end
                        if #undecided > 0 then
                            if have == required then
                                for _, cell in ipairs(undecided) do
                                    if not setDecided(cell[1], cell[2], false, changes) then return false end
                                end
                                progressed = true
                            elseif have + #undecided == required then
                                for _, cell in ipairs(undecided) do
                                    if not setDecided(cell[1], cell[2], true, changes) then return false end
                                end
                                progressed = true
                            end
                        end
                    end
                end
            end
            for r = 1, n do
                for c = 1, n do
                    if grid[r][c] == TYPE_WHITE and not isLit(r, c) then
                        local cand, seen = {}, {}
                        for _, cell in ipairs(row_cells[row_seg[r][c]]) do
                            local key = cell[1] * 1000 + cell[2]
                            if decided[cell[1]][cell[2]] == nil and not seen[key] then
                                seen[key] = true; cand[#cand + 1] = cell
                            end
                        end
                        for _, cell in ipairs(col_cells[col_seg[r][c]]) do
                            local key = cell[1] * 1000 + cell[2]
                            if decided[cell[1]][cell[2]] == nil and not seen[key] then
                                seen[key] = true; cand[#cand + 1] = cell
                            end
                        end
                        if #cand == 0 then return false end
                        if #cand == 1 then
                            if not setDecided(cand[1][1], cand[1][2], true, changes) then return false end
                            progressed = true
                        end
                    end
                end
            end
        end
        return true
    end

    local function undo(changes, from)
        for i = #changes, from, -1 do
            local r, c = changes[i][1], changes[i][2]
            if decided[r][c] == true then
                row_seg_bulb[row_seg[r][c]] = false
                col_seg_bulb[col_seg[r][c]] = false
            end
            decided[r][c] = nil
            changes[i] = nil
        end
    end

    local function allDecided()
        for r = 1, n do
            for c = 1, n do
                if grid[r][c] == TYPE_WHITE and decided[r][c] == nil then return false end
            end
        end
        return true
    end

    local function pickBranchCell()
        for r = 1, n do
            for c = 1, n do
                if grid[r][c] == TYPE_WHITE and not isLit(r, c) then
                    for _, cell in ipairs(row_cells[row_seg[r][c]]) do
                        if decided[cell[1]][cell[2]] == nil then return cell[1], cell[2] end
                    end
                    for _, cell in ipairs(col_cells[col_seg[r][c]]) do
                        if decided[cell[1]][cell[2]] == nil then return cell[1], cell[2] end
                    end
                end
            end
        end
        for r = 1, n do
            for c = 1, n do
                if grid[r][c] == TYPE_WHITE and decided[r][c] == nil then return r, c end
            end
        end
        return nil
    end

    local function search()
        if solutions >= limit or exhausted then return end
        nodes = nodes + 1
        if nodes > node_budget then exhausted = true; return end

        local changes = {}
        if not propagate(changes) then
            undo(changes, 1)
            return
        end

        if allDecided() then
            solutions = solutions + 1
            undo(changes, 1)
            return
        end

        local r, c = pickBranchCell()
        if not r then
            undo(changes, 1)
            return
        end

        for _, val in ipairs({ true, false }) do
            local branch_changes = {}
            if setDecided(r, c, val, branch_changes) then
                search()
            end
            undo(branch_changes, 1)
            if solutions >= limit or exhausted then break end
        end
        undo(changes, 1)
    end

    search()
    return solutions, exhausted
end

local ok = true

local function analyze(n, difficulty, n_trials, node_budget, threshold)
    local unique, ambiguous, inconclusive = 0, 0, 0
    for i = 1, n_trials do
        math.randomseed(i * 7919)
        local b = Board:new({ n = n, difficulty = difficulty })
        local solutions, exhausted = countSolutions(b.grid, n, 2, node_budget)
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

-- n=7/n=10: real, substantial fix, held to a meaningful bar.
analyze(7, "easy", 15, 150000, 0.50)
analyze(7, "medium", 15, 150000, 0.90)
analyze(7, "hard", 15, 150000, 0.90)
analyze(10, "easy", 15, 150000, 0.20)
analyze(10, "medium", 15, 150000, 0.90)
analyze(10, "hard", 15, 150000, 0.90)
-- n=14: genuinely too sparse a CSP to pin down quickly at low density --
-- thresholds here guard against regressing the *measured* rate, not a
-- correctness bar (same caveat as nurikabe's n=10/15 rows).
analyze(14, "easy", 15, 150000, 0.0)
analyze(14, "medium", 15, 150000, 0.15)
analyze(14, "hard", 15, 150000, 0.50)

os.exit(ok and 0 or 1)
