-- Uniqueness regression check for shikaku.koplugin.
--
-- This is NOT a busted spec -- see docs/generator_robustness_audit.md,
-- "Human-solvability audit" section, for why this class of check needs its
-- own tooling separate from `busted spec/`.
--
-- Run from the repo root:
--   luajit spec/solvability_audits/shikaku_solvability_check.lua
--
-- Background: no "given" mask here -- the clue grid (one area number per
-- rectangle, placed at a single random cell within it) IS the entire
-- puzzle. `generate()` built a random rectangle partition (`splitRect`)
-- and picked one random clue cell per rectangle with zero uniqueness
-- verification. Measured pre-fix: severe, real ambiguity -- 0/15 unique at
-- n=8 and n=10 (every difficulty), even n=6 mostly ambiguous (3-5/15) --
-- matches this genre's well-known real risk (a naive single random clue
-- placement per rectangle very often leaves multiple valid tilings).
--
-- Fixed generate+verify style (nothing to dig, same shape as hitori/
-- nurikabe/starbattle/nonogram): for each candidate rectangle partition,
-- repick which cell holds each rectangle's clue up to 25 times (cheap --
-- no search, and a different clue-cell choice can turn an ambiguous
-- layout unique on its own) before falling back to a fresh partition (up
-- to 40 partition attempts). Falls back to the first structurally-valid
-- candidate if the whole budget is exhausted (never worse than before,
-- though in practice this never triggers -- see below).
--
-- The uniqueness counter: for each clue, enumerate every rectangle
-- containing it with the right area and no OTHER clue cell inside, then
-- backtrack (MRV: fewest currently-fitting candidates first) trying to
-- tile the whole grid with no gaps or overlaps. 20/20 unique at every
-- size/difficulty after the fix, worst case ~0.15s avg (n=10) -- fast
-- because repicking clue positions turns out to be a very effective lever
-- (this genre's ambiguity mostly comes from *where* the clue sits within
-- its rectangle, not from the partition shape itself).
--
-- Exit code is non-zero if any size/difficulty drops below its threshold.

package.preload["gettext"] = function() return function(s) return s end end
package.path = "game-common/?.lua;shikaku.koplugin/?.lua;" .. package.path
local Board = require("board")

-- Independent cross-check counter (deliberately separate from board.lua's
-- own copy) -- cross-checks the production gate rather than testing a fix
-- against itself.
local function candidateRectsFor(clues, n, cr, cc, area)
    local cands = {}
    for h = 1, area do
        if area % h == 0 then
            local w = area / h
            for dr = 0, h - 1 do
                local r1 = cr - dr
                local r2 = r1 + h - 1
                if r1 >= 1 and r2 <= n then
                    for dc = 0, w - 1 do
                        local c1 = cc - dc
                        local c2 = c1 + w - 1
                        if c1 >= 1 and c2 <= n then
                            local ok = true
                            for r = r1, r2 do
                                for c = c1, c2 do
                                    if not (r == cr and c == cc) and clues[r][c] and clues[r][c] > 0 then
                                        ok = false; break
                                    end
                                end
                                if not ok then break end
                            end
                            if ok then
                                cands[#cands + 1] = { r1 = r1, c1 = c1, r2 = r2, c2 = c2 }
                            end
                        end
                    end
                end
            end
        end
    end
    return cands
end

local function countSolutions(clues, n, limit, node_budget)
    local clue_list = {}
    for r = 1, n do
        for c = 1, n do
            if clues[r][c] and clues[r][c] > 0 then
                clue_list[#clue_list + 1] = { r = r, c = c, area = clues[r][c] }
            end
        end
    end

    local occupied = {}
    for r = 1, n do occupied[r] = {}; for c = 1, n do occupied[r][c] = false end end
    local placed = {}
    for i = 1, #clue_list do placed[i] = false end
    local total_cells = n * n
    local cells_filled = 0

    local solutions, nodes, exhausted = 0, 0, false

    local function rectFits(rect)
        for r = rect.r1, rect.r2 do
            for c = rect.c1, rect.c2 do
                if occupied[r][c] then return false end
            end
        end
        return true
    end

    local function applyRect(rect, val)
        for r = rect.r1, rect.r2 do
            for c = rect.c1, rect.c2 do occupied[r][c] = val end
        end
    end

    local function search()
        if solutions >= limit or exhausted then return end
        nodes = nodes + 1
        if nodes > node_budget then exhausted = true; return end

        local best_i, best_fits, best_len = nil, nil, math.huge
        for i = 1, #clue_list do
            if not placed[i] then
                local cl = clue_list[i]
                local cands = candidateRectsFor(clues, n, cl.r, cl.c, cl.area)
                local fits = {}
                for _, rect in ipairs(cands) do
                    if rectFits(rect) then fits[#fits + 1] = rect end
                end
                if #fits < best_len then
                    best_len, best_fits, best_i = #fits, fits, i
                    if best_len == 0 then break end
                end
            end
        end

        if not best_i then
            if cells_filled == total_cells then solutions = solutions + 1 end
            return
        end
        if best_len == 0 then return end

        placed[best_i] = true
        local area = clue_list[best_i].area
        for _, rect in ipairs(best_fits) do
            applyRect(rect, true)
            cells_filled = cells_filled + area
            search()
            cells_filled = cells_filled - area
            applyRect(rect, false)
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
        b:generate(difficulty)
        local solutions, exhausted = countSolutions(b.clues, n, 2, node_budget)
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

analyze(6, "easy", 20, 300000, 0.90)
analyze(6, "medium", 20, 300000, 0.90)
analyze(6, "hard", 20, 300000, 0.90)
analyze(8, "easy", 20, 300000, 0.90)
analyze(8, "medium", 20, 300000, 0.90)
analyze(8, "hard", 20, 300000, 0.90)
analyze(10, "easy", 20, 300000, 0.90)
analyze(10, "medium", 20, 300000, 0.90)
analyze(10, "hard", 20, 300000, 0.90)

os.exit(ok and 0 or 1)
