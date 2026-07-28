-- Uniqueness regression check for nonogram.koplugin.
--
-- This is NOT a busted spec -- see docs/generator_robustness_audit.md,
-- "Human-solvability audit" section, for why this class of check needs its
-- own tooling separate from `busted spec/`.
--
-- Run from the repo root:
--   luajit spec/solvability_audits/nonogram_solvability_check.lua
--
-- Background: unlike every plugin audited before this one, there's no
-- "given" mask at all here -- the row/col run-length clues ARE the entire
-- puzzle, deduced from nothing else. `generate()` built a random density
-- fill and derived clues from it with only a "no empty row/column" sanity
-- check -- zero uniqueness verification. Measured pre-fix: a real,
-- graduated severity pattern (worse at lower density/larger n, exactly the
-- shape expected of a real bug, not a flat suspicious 0%) -- n=15/easy
-- 2/15 unique, n=5/hard 15/15 unique (denser puzzles are naturally more
-- constrained).
--
-- Fixed with the same shape as hitori/nurikabe (generate+verify whole
-- candidates, since there's nothing to dig): retry a random density fill
-- up to 400 times, deriving clues and checking uniqueness with an
-- independent line-solver counter each time, keeping the first provably
-- unique one (falling back to the first structurally-valid candidate if
-- the budget is exhausted, never worse than pre-fix).
--
-- The uniqueness counter itself needed real care to get right and fast:
-- the standard nonogram-solving technique is to enumerate every valid full
-- line for each row/column clue, then iteratively filter row and column
-- candidate-line sets against each other (a cell's value is only
-- achievable if some remaining row candidate AND some remaining column
-- candidate agree on it) until a fixed point, branching only on whichever
-- row/column still has more than one candidate. A first attempt processed
-- rows in naive top-to-bottom order with per-row MRV filtering only
-- against static candidates -- correct but too slow (row 5 alone can have
-- ~500 static candidates at n=15, causing massive branching before column
-- constraints narrow anything). A second attempt tried MRV over *which
-- row to place next* atop a left-to-right incremental per-column state
-- machine -- this is WRONG, not just slow: a column's run-length clue
-- depends on the true top-to-bottom sequence, and reordering which row
-- gets fed to the state machine first silently breaks it. Caught via the
-- standard sanity check (solver returned solutions=0 for the generator's
-- own known-good clues). The propagation-based rewrite above is both
-- correct (passes the sanity check) and fast (worst case ~7ms per call at
-- n=15/easy, the hardest setting) because it's inherently order-
-- independent -- rows/columns get resolved in whatever order propagation
-- naturally determines, never an assumed physical sequence.
--
-- Exit code is non-zero if any size/difficulty drops below its threshold.

package.preload["gettext"] = function() return function(s) return s end end
package.path = "game-common/?.lua;nonogram.koplugin/?.lua;" .. package.path
local Board = require("board").NonogramBoard

-- Independent cross-check counter (deliberately separate from board.lua's
-- own copy) -- cross-checks the production gate rather than testing a fix
-- against itself.
local function enumerateLines(clue, n)
    if #clue == 1 and clue[1] == 0 then
        local empty = {}
        for i = 1, n do empty[i] = false end
        return { empty }
    end
    local m = #clue
    local minlen = 0
    for _, k in ipairs(clue) do minlen = minlen + k end
    minlen = minlen + (m - 1)
    if minlen > n then return {} end
    local slack = n - minlen
    local results, line = {}, {}
    for i = 1, n do line[i] = false end
    local function place(i, pos, gaps_left)
        if i > m then
            local copy = {}
            for j = 1, n do copy[j] = line[j] end
            results[#results + 1] = copy
            return
        end
        for extra = 0, gaps_left do
            local start = pos + extra
            local finish = start + clue[i] - 1
            if finish > n then break end
            for j = start, finish do line[j] = true end
            place(i + 1, finish + 2, gaps_left - extra)
            for j = start, finish do line[j] = false end
        end
    end
    place(1, 1, slack)
    return results
end

local function achievableAt(lines, pos)
    local t, f = false, false
    for _, line in ipairs(lines) do
        if line[pos] then t = true else f = true end
        if t and f then break end
    end
    return t, f
end

local function filterByAchievable(lines, achievable, n)
    local out = {}
    for _, line in ipairs(lines) do
        local ok = true
        for pos = 1, n do
            local v, a = line[pos], achievable[pos]
            if (v and not a.t) or ((not v) and not a.f) then ok = false; break end
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
            for c = 1, n do
                local t, f = achievableAt(col_live[c], r)
                achievable[c] = { t = t, f = f }
            end
            local filtered = filterByAchievable(row_live[r], achievable, n)
            if #filtered == 0 then return false end
            if #filtered < #row_live[r] then changed = true end
            row_live[r] = filtered
        end
        for c = 1, n do
            local achievable = {}
            for r = 1, n do
                local t, f = achievableAt(row_live[r], c)
                achievable[r] = { t = t, f = f }
            end
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
        local b = Board:new({ n = 10, difficulty = "medium" })
        b:generate("medium")
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
        b:generate(difficulty)
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

analyze(5, "easy", 20, 300000, 0.90)
analyze(5, "medium", 20, 300000, 0.90)
analyze(5, "hard", 20, 300000, 0.90)
analyze(10, "easy", 20, 300000, 0.90)
analyze(10, "medium", 20, 300000, 0.90)
analyze(10, "hard", 20, 300000, 0.90)
analyze(15, "easy", 20, 300000, 0.90)
analyze(15, "medium", 20, 300000, 0.90)
analyze(15, "hard", 20, 300000, 0.90)

os.exit(ok and 0 or 1)
