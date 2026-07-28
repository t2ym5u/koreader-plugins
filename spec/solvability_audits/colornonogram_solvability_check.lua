-- Uniqueness regression check for colornonogram.koplugin.
--
-- This is NOT a busted spec -- see docs/generator_robustness_audit.md,
-- "Human-solvability audit" section, for why this class of check needs its
-- own tooling separate from `busted spec/`.
--
-- Run from the repo root:
--   luajit spec/solvability_audits/colornonogram_solvability_check.lua
--
-- Background: same shape as nonogram.koplugin (see that check's header for
-- the full methodology writeup) -- there's no "given" mask, the row/col
-- run clues ARE the entire puzzle, and `generate()` built a random
-- per-cell color fill with only a "no empty row/column" check, zero
-- uniqueness verification. Measured pre-fix: real, graduated ambiguity
-- (n=6 easy 6/15, n=8 easy 5/15 unique, better at higher density).
--
-- The uniqueness counter generalizes nonogram's line-propagation technique
-- from boolean cells to {0=empty, 1..NUM_COLORS}, with one genre-specific
-- wrinkle: two consecutive clue runs need a mandatory >=1-cell gap between
-- them ONLY if they're the SAME color -- board.lua's own `computeClues`
-- only starts a new run when the color actually changes (or drops to
-- empty), so two DIFFERENT-colored runs can sit directly adjacent with
-- zero gap between them (they'd never have merged into one run in the
-- first place). Getting the line-enumeration's minimum-length/gap budget
-- calculation right for this rule is the one place this solver actually
-- differs from nonogram's.
--
-- Fixed the same way as nonogram/hitori/nurikabe (generate+verify whole
-- candidates, since there's nothing to dig): retry a random fill up to 400
-- times, deriving clues and checking uniqueness each time, keeping the
-- first provably-unique one.
--
-- Exit code is non-zero if any size/difficulty drops below its threshold.

package.preload["gettext"] = function() return function(s) return s end end
package.path = "game-common/?.lua;colornonogram.koplugin/?.lua;" .. package.path
local Board = require("board")

local NUM_VALUES = 4 -- 0 (empty), 1, 2, 3

-- Independent cross-check counter (deliberately separate from board.lua's
-- own copy).
local function enumerateLines(clue, n)
    if #clue == 1 and clue[1].len == 0 then
        local empty = {}
        for i = 1, n do empty[i] = 0 end
        return { empty }
    end
    local m, minlen = #clue, 0
    for i, seg in ipairs(clue) do
        minlen = minlen + seg.len
        if i < m and clue[i].color == clue[i + 1].color then minlen = minlen + 1 end
    end
    if minlen > n then return {} end
    local slack = n - minlen
    local results, line = {}, {}
    for i = 1, n do line[i] = 0 end
    local function place(i, pos, gaps_left)
        if i > m then
            local copy = {}
            for j = 1, n do copy[j] = line[j] end
            results[#results + 1] = copy
            return
        end
        for extra = 0, gaps_left do
            local start = pos + extra
            local finish = start + clue[i].len - 1
            if finish > n then break end
            for j = start, finish do line[j] = clue[i].color end
            local mandatory = (i < m and clue[i].color == clue[i + 1].color) and 1 or 0
            place(i + 1, finish + 1 + mandatory, gaps_left - extra)
            for j = start, finish do line[j] = 0 end
        end
    end
    place(1, 1, slack)
    return results
end

local function achievableSetAt(lines, pos)
    local seen, count = {}, 0
    for _, line in ipairs(lines) do
        local v = line[pos]
        if not seen[v] then seen[v] = true; count = count + 1 end
        if count == NUM_VALUES then break end
    end
    return seen
end

local function filterByAchievable(lines, achievable, n)
    local out = {}
    for _, line in ipairs(lines) do
        local ok = true
        for pos = 1, n do
            if not achievable[pos][line[pos]] then ok = false; break end
        end
        if ok then out[#out + 1] = line end
    end
    return out
end

local function propagate(row_live, col_live, n)
    local changed = true
    while changed do
        changed = false
        for r = 1, n do
            local achievable = {}
            for c = 1, n do achievable[c] = achievableSetAt(col_live[c], r) end
            local filtered = filterByAchievable(row_live[r], achievable, n)
            if #filtered == 0 then return false end
            if #filtered < #row_live[r] then changed = true end
            row_live[r] = filtered
        end
        for c = 1, n do
            local achievable = {}
            for r = 1, n do achievable[r] = achievableSetAt(row_live[r], c) end
            local filtered = filterByAchievable(col_live[c], achievable, n)
            if #filtered == 0 then return false end
            if #filtered < #col_live[c] then changed = true end
            col_live[c] = filtered
        end
    end
    return true
end

local function copyLiveState(row_live, col_live, n)
    local r2, c2 = {}, {}
    for r = 1, n do r2[r] = row_live[r] end
    for c = 1, n do c2[c] = col_live[c] end
    return r2, c2
end

local function countSolutions(row_clues, col_clues, n, limit, node_budget)
    local row_live, col_live = {}, {}
    for r = 1, n do row_live[r] = enumerateLines(row_clues[r], n) end
    for c = 1, n do col_live[c] = enumerateLines(col_clues[c], n) end
    local solutions, nodes, exhausted = 0, 0, false
    local function search(row_live, col_live)
        if solutions >= limit or exhausted then return end
        nodes = nodes + 1
        if nodes > node_budget then exhausted = true; return end
        if not propagate(row_live, col_live, n) then return end
        local all_singletons = true
        for r = 1, n do
            if #row_live[r] ~= 1 then all_singletons = false; break end
        end
        if all_singletons then solutions = solutions + 1; return end
        local best_is_row, best_idx, best_len = true, nil, math.huge
        for r = 1, n do
            if #row_live[r] >= 2 and #row_live[r] < best_len then
                best_len, best_idx, best_is_row = #row_live[r], r, true
            end
        end
        for c = 1, n do
            if #col_live[c] >= 2 and #col_live[c] < best_len then
                best_len, best_idx, best_is_row = #col_live[c], c, false
            end
        end
        local live = best_is_row and row_live[best_idx] or col_live[best_idx]
        for _, candidate in ipairs(live) do
            local r2, c2 = copyLiveState(row_live, col_live, n)
            if best_is_row then r2[best_idx] = { candidate } else c2[best_idx] = { candidate } end
            search(r2, c2)
            if solutions >= limit or exhausted then return end
        end
    end
    search(row_live, col_live)
    return solutions, exhausted
end

local ok = true

local function sanityCheckFullClues(n_trials)
    for i = 1, n_trials do
        math.randomseed(i * 104729)
        local b = Board:new({ n = 8, difficulty = "medium" })
        local solutions, exhausted = countSolutions(b.row_clues, b.col_clues, b.n, 2, 200000)
        if solutions < 1 or exhausted then
            print(string.format("[FAIL] sanity check trial %d: solutions=%d exhausted=%s (solver itself is broken)",
                i, solutions, tostring(exhausted)))
            ok = false
        end
    end
    if ok then print(string.format("[OK] sanity check: solver finds >=1 solution for %d known-good clue sets", n_trials)) end
end

local function analyze(n, difficulty, n_trials, node_budget, threshold)
    local unique, ambiguous, inconclusive = 0, 0, 0
    for i = 1, n_trials do
        math.randomseed(i * 7919)
        local b = Board:new({ n = n, difficulty = difficulty })
        local solutions, exhausted = countSolutions(b.row_clues, b.col_clues, n, 2, node_budget)
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

sanityCheckFullClues(10)

analyze(6, "easy", 20, 300000, 0.90)
analyze(6, "medium", 20, 300000, 0.90)
analyze(6, "hard", 20, 300000, 0.90)
analyze(8, "easy", 20, 300000, 0.90)
analyze(8, "medium", 20, 300000, 0.90)
analyze(8, "hard", 20, 300000, 0.90)

os.exit(ok and 0 or 1)
