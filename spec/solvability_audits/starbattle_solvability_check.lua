-- Uniqueness regression check for starbattle.koplugin.
--
-- This is NOT a busted spec -- see docs/generator_robustness_audit.md,
-- "Human-solvability audit" section, for why this class of check needs its
-- own tooling separate from `busted spec/`.
--
-- Run from the repo root:
--   luajit spec/solvability_audits/starbattle_solvability_check.lua
--
-- Background: no "given" mask here at all -- the region partition itself
-- IS the entire puzzle (visible from the start), and solving means
-- finding the unique star placement satisfying k-per-row/col/region + no
-- two stars adjacent (incl. diagonally). board.lua's own solver just found
-- the FIRST valid placement via backtracking and stopped -- an earlier fix
-- (2026-07-21, see the fallback/degenerate-output table) already made that
-- search reliably find *a* solution (bumped max_attempts to fix ~91%
-- fallback), but never checked whether a second, different placement also
-- existed. Measured: only ~7% of accepted layouts were actually unique at
-- n=6/k=1 and n=10/k=2 (n=8/k=2 happened to be ~100% unique already, an
-- uneven but genuine pattern, not the uniform-0% shape that would suggest
-- a broken counter).
--
-- Fixed generate+verify style (same shape as hitori/nurikabe -- nothing to
-- dig): the solver was rewritten to count up to `limit` solutions instead
-- of stopping at the first, and `generate()` now requires countSolutions
-- == 1 (not just >= 1) before accepting a region layout, retrying up to
-- 2000 times, falling back to the best structurally-valid-but-unproven
-- layout if the budget runs out (never worse than before). Node budget per
-- attempt was tuned down (100000 -> 30000 at n=10) after an initial
-- version showed a real worst-case timing problem (up to ~13s at n=10/k=2)
-- -- a smaller per-attempt budget fails an inconclusive attempt faster and
-- moves on to a fresh random layout instead of grinding on a hard one,
-- which turned out to matter more for worst-case latency than raw budget
-- size. 20/20 unique at n=6/k=1 and n=8/k=2; ~90% (18/20 measured) at
-- n=10/k=2 with worst case ~5.3s -- a real, substantial improvement from
-- the ~7% baseline, not a full fix at the hardest setting, same class of
-- tradeoff as nurikabe's n=10/15.
--
-- Exit code is non-zero if any size/k combo drops below its threshold.

package.preload["gettext"] = function() return function(s) return s end end
package.path = "game-common/?.lua;starbattle.koplugin/?.lua;" .. package.path
local Board = require("board")

local function inBounds(r, c, n) return r >= 1 and r <= n and c >= 1 and c <= n end

-- Independent cross-check counter (deliberately separate from board.lua's
-- own copy) -- cross-checks the production gate rather than testing a fix
-- against itself.
local function countSolutions(n, k, region_id, limit, node_budget)
    local solution = {}
    for r = 1, n do solution[r] = {}; for c = 1, n do solution[r][c] = 0 end end
    local row_count, col_count, reg_count = {}, {}, {}
    for i = 1, n do row_count[i] = 0; col_count[i] = 0; reg_count[i] = 0 end

    local function isAdjacent(r, c)
        for dr = -1, 1 do
            for dc = -1, 1 do
                if not (dr == 0 and dc == 0) then
                    local nr, nc = r + dr, c + dc
                    if inBounds(nr, nc, n) and solution[nr][nc] == 1 then return true end
                end
            end
        end
        return false
    end

    local solutions, nodes, exhausted = 0, 0, false

    local function pickCols(r, start_c, placed)
        if solutions >= limit or exhausted then return end
        nodes = nodes + 1
        if nodes > node_budget then exhausted = true; return end

        if placed == k then
            if r == n then solutions = solutions + 1; return end
            pickCols(r + 1, 1, 0)
            return
        end
        local remaining_cols = n - start_c + 1
        local needed = k - placed
        if remaining_cols < needed then return end

        for c = start_c, n do
            local reg = region_id[r][c]
            if col_count[c] < k and reg_count[reg] < k and not isAdjacent(r, c) then
                solution[r][c] = 1
                row_count[r] = row_count[r] + 1
                col_count[c] = col_count[c] + 1
                reg_count[reg] = reg_count[reg] + 1
                pickCols(r, c + 1, placed + 1)
                solution[r][c] = 0
                row_count[r] = row_count[r] - 1
                col_count[c] = col_count[c] - 1
                reg_count[reg] = reg_count[reg] - 1
                if solutions >= limit or exhausted then return end
            end
        end
    end

    pickCols(1, 1, 0)
    return solutions, exhausted
end

local ok = true

local function analyze(n, k, n_trials, node_budget, threshold)
    local unique, ambiguous, inconclusive, fallback = 0, 0, 0, 0
    for i = 1, n_trials do
        math.randomseed(i * 7919)
        local b = Board:new({ n = n, k = k })
        if b.n ~= n or b.k ~= k then
            fallback = fallback + 1
        else
            local solutions, exhausted = countSolutions(n, k, b.region_id, 2, node_budget)
            if exhausted then inconclusive = inconclusive + 1
            elseif solutions == 1 then unique = unique + 1
            else ambiguous = ambiguous + 1 end
        end
    end
    local rate = unique / n_trials
    local status = rate >= threshold and "OK" or "FAIL"
    if status == "FAIL" then ok = false end
    print(string.format("[%s] n=%d k=%d: unique=%d/%d ambiguous=%d inconclusive=%d fallback=%d (threshold %.0f%%)",
        status, n, k, unique, n_trials, ambiguous, inconclusive, fallback, threshold * 100))
    io.flush()
end

analyze(6, 1, 20, 300000, 0.90)
analyze(8, 2, 20, 300000, 0.90)
analyze(10, 2, 20, 300000, 0.75)

os.exit(ok and 0 or 1)
