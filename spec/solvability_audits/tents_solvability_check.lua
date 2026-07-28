-- Uniqueness regression check for tents.koplugin.
--
-- This is NOT a busted spec -- see docs/generator_robustness_audit.md,
-- "Human-solvability audit" section, for why this class of check needs its
-- own tooling separate from `busted spec/`.
--
-- Run from the repo root:
--   luajit spec/solvability_audits/tents_solvability_check.lua
--
-- Background: no "given" mask on the unknown (tent) layer -- the puzzle's
-- visible state is tree positions (shown directly) plus row/col tent-count
-- clues. The win-check compares literally against the stored solution, but
-- the REAL constraint set a human solver reasons about (and that
-- `generateSolution` builds its solution to satisfy) is: each tree gets
-- exactly one tent, orthogonally adjacent, no two tents adjacent to each
-- other (incl. diagonally), and the resulting per-row/col tent counts
-- match the shown clues. `generate()` had zero verification that this
-- combination of tree positions + clues pins down a unique tent placement.
-- Measured pre-fix: real, moderate ambiguity (roughly 60-87% unique across
-- sizes/difficulties, worse at hard -- graduated, not the flat-0% shape
-- that would suggest a broken counter instead of a real bug).
--
-- Fixed generate+verify style (nothing to dig, same shape as hitori/
-- nurikabe/starbattle/shikaku): retry the tree/tent pairing up to 60 times,
-- checking uniqueness with an MRV backtracking counter each time (each
-- tree picks one of its up-to-4 orthogonal empty neighbors as its tent, no
-- two trees claim the same cell, no two tents adjacent, final counts must
-- match exactly), keeping the first provably-unique pairing. Falls back to
-- the first structurally-valid pairing if the budget runs out (never
-- worse than before, though in practice this essentially never triggers --
-- see below). 20/20 unique at every size/difficulty after the fix,
-- generation still near-instant (worst case ~17ms avg at n=12/hard).
--
-- Exit code is non-zero if any size/difficulty drops below its threshold.

package.preload["gettext"] = function() return function(s) return s end end
package.path = "game-common/?.lua;tents.koplugin/?.lua;" .. package.path
local Board = require("board")

local DIR4 = { {-1,0},{1,0},{0,-1},{0,1} }
local function inBounds(r, c, n) return r >= 1 and r <= n and c >= 1 and c <= n end

-- Independent cross-check counter (deliberately separate from board.lua's
-- own copy) -- cross-checks the production gate rather than testing a fix
-- against itself.
local function countSolutions(trees, row_clues, col_clues, n, limit, node_budget)
    local tree_list = {}
    for r = 1, n do
        for c = 1, n do
            if trees[r][c] then tree_list[#tree_list + 1] = { r = r, c = c } end
        end
    end

    local tent_at = {}
    for r = 1, n do tent_at[r] = {}; for c = 1, n do tent_at[r][c] = false end end
    local claimed_by = {}
    local row_count, col_count = {}, {}
    for i = 1, n do row_count[i] = 0; col_count[i] = 0 end

    local placed = {}
    for i = 1, #tree_list do placed[i] = false end

    local solutions, nodes, exhausted = 0, 0, false
    local function cellKey(r, c) return r * 1000 + c end

    local function tentsTouching(r, c)
        for dr = -1, 1 do
            for dc = -1, 1 do
                if not (dr == 0 and dc == 0) then
                    local nr, nc = r + dr, c + dc
                    if inBounds(nr, nc, n) and tent_at[nr][nc] then return true end
                end
            end
        end
        return false
    end

    local function candidatesFor(tree)
        local cands = {}
        for _, d in ipairs(DIR4) do
            local nr, nc = tree.r + d[1], tree.c + d[2]
            if inBounds(nr, nc, n) and not trees[nr][nc]
                and not claimed_by[cellKey(nr, nc)]
                and not tentsTouching(nr, nc) then
                cands[#cands + 1] = { nr, nc }
            end
        end
        return cands
    end

    local function search()
        if solutions >= limit or exhausted then return end
        nodes = nodes + 1
        if nodes > node_budget then exhausted = true; return end

        local best_i, best_cands, best_len = nil, nil, math.huge
        for i = 1, #tree_list do
            if not placed[i] then
                local cands = candidatesFor(tree_list[i])
                if #cands < best_len then
                    best_len, best_cands, best_i = #cands, cands, i
                    if best_len == 0 then break end
                end
            end
        end

        if not best_i then
            for r = 1, n do if row_count[r] ~= row_clues[r] then return end end
            for c = 1, n do if col_count[c] ~= col_clues[c] then return end end
            solutions = solutions + 1
            return
        end
        if best_len == 0 then return end

        placed[best_i] = true
        for _, cell in ipairs(best_cands) do
            local r, c = cell[1], cell[2]
            tent_at[r][c] = true
            claimed_by[cellKey(r, c)] = true
            row_count[r] = row_count[r] + 1
            col_count[c] = col_count[c] + 1
            search()
            tent_at[r][c] = false
            claimed_by[cellKey(r, c)] = nil
            row_count[r] = row_count[r] - 1
            col_count[c] = col_count[c] - 1
            if solutions >= limit or exhausted then break end
        end
        placed[best_i] = false
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
        local solutions, exhausted = countSolutions(b.trees, b.row_clues, b.col_clues, n, 2, node_budget)
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

for _, n in ipairs({6, 8, 10, 12}) do
    for _, diff in ipairs({"easy", "medium", "hard"}) do
        analyze(n, diff, 20, 300000, 0.90)
    end
end

os.exit(ok and 0 or 1)
