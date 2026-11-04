-- Uniqueness regression check for cave.koplugin.
--
-- This is NOT a busted spec -- see docs/generator_robustness_audit.md,
-- "Human-solvability audit" section, for why this class of check needs its
-- own tooling separate from `busted spec/`.
--
-- Run from the repo root:
--   luajit spec/solvability_audits/cave_solvability_check.lua
--
-- Background: checkWin() is a literal full-grid comparison to
-- self.solution (every cell must match exactly), so uniqueness means:
-- given only the revealed visibility clues (all on cells known to be
-- unshaded), is there only one shaded/unshaded assignment satisfying every
-- rule (shaded cells connected and touching the border, unshaded cells
-- connected, no 2x2 block fully shaded, every clue's visibility count
-- matches)? generate() picked a random cave shape then revealed a flat
-- fraction of visibility clues with zero uniqueness verification --
-- measured pre-fix: severe, graduated ambiguity (e.g. n=6/hard 0/10
-- unique, n=8/easy only 1/15).
--
-- The independent counter below prunes with three sound rules after every
-- tentative cell: no shaded 2x2 (tested AFTER setting the cell, so the
-- block it completes counts), per-clue visibility bounds, and
-- connectivity as the Rules screen states it (clear cells connected,
-- every shaded cell reaching the grid edge). It branches on the cell just
-- past a clue's clear run.
--
-- 2026-11-04 (cave 1.6.0): the earlier version of this script tested the
-- 2x2 rule before setting the cell (so it counted rule-breaking grids as
-- extra solutions and reported false ambiguity) and, like the plugin
-- until 1.6.0, demanded one single shaded group. Both fixed; on 400
-- random clue sets it returns exactly the plugin's solution counts.
--
-- Since 1.6.0 the generator digs clues out of a fully numbered grid and
-- keeps a removal only while board.lua's deduce() (clue rays, 2x2,
-- walled-off cells, plus bottlenecks at Hard -- no trial and error) still
-- fills the whole grid, so every puzzle should be unique AND solvable
-- without guessing; both are gated here at 100%.
--
-- Exit code is non-zero if any size/difficulty drops below its threshold.

package.preload["gettext"] = function() return function(s) return s end end
package.path = "game-common/?.lua;cave.koplugin/?.lua;" .. package.path
local M = require("board")
local Board = M.CaveBoard

local DIRS = { {0,1}, {0,-1}, {1,0}, {-1,0} }
local function inBounds(r, c, n) return r >= 1 and r <= n and c >= 1 and c <= n end

-- Independent cross-check counter (deliberately separate from board.lua's
-- own copy) -- cross-checks the production gate rather than testing a fix
-- against itself.
local function countSolutions(clues, n, limit, node_budget)
    local state = {}
    for r = 1, n do state[r] = {} end
    for r = 1, n do for c = 1, n do if clues[r][c] then state[r][c] = false end end end

    local solutions, nodes, exhausted = 0, 0, false

    local function has2x2ShadedAt(r, c)
        for _, o in ipairs({ {0,0}, {0,-1}, {-1,0}, {-1,-1} }) do
            local r0, c0 = r + o[1], c + o[2]
            if r0 >= 1 and r0 <= n-1 and c0 >= 1 and c0 <= n-1 then
                if state[r0][c0] == true and state[r0+1][c0] == true
                    and state[r0][c0+1] == true and state[r0+1][c0+1] == true then
                    return true
                end
            end
        end
        return false
    end

    -- Connectivity as the Rules screen states it: decided clear cells must
    -- still reach each other through clear-or-undecided cells, and every
    -- decided shaded cell must still reach the grid edge through shaded-or-
    -- undecided cells (shaded cells may form several groups, each touching
    -- the edge -- cave 1.6.0 counts the same way; earlier versions of both
    -- this script and the plugin demanded one single shaded group).
    local visited_stamp = {}
    for r = 1, n do visited_stamp[r] = {} end
    local stamp = 0
    local queue = {}
    local function regionOK(want_shaded)
        stamp = stamp + 1
        local qh, qt = 1, 0
        local decided_count = 0
        for r = 1, n do for c = 1, n do
            if state[r][c] == want_shaded then decided_count = decided_count + 1 end
        end end
        if decided_count == 0 then return true end
        local function push(r, c)
            visited_stamp[r][c] = stamp
            qt = qt + 1
            queue[qt] = { r, c }
        end
        if want_shaded then
            -- seed from the edge: every border cell that may be shaded
            for r = 1, n do for c = 1, n do
                if (r == 1 or r == n or c == 1 or c == n)
                    and (state[r][c] == true or state[r][c] == nil) then push(r, c) end
            end end
        else
            for r = 1, n do for c = 1, n do
                if qt == 0 and state[r][c] == false then push(r, c) end
            end end
        end
        local found_decided = 0
        while qh <= qt do
            local cell = queue[qh]; qh = qh + 1
            local r, c = cell[1], cell[2]
            if state[r][c] == want_shaded then found_decided = found_decided + 1 end
            for _, d in ipairs(DIRS) do
                local nr, nc = r + d[1], c + d[2]
                if inBounds(nr, nc, n) and visited_stamp[nr][nc] ~= stamp then
                    local v = state[nr][nc]
                    if v == want_shaded or v == nil then push(nr, nc) end
                end
            end
        end
        return found_decided == decided_count
    end

    local function visibilityFinal(r, c)
        local count = 1
        for _, d in ipairs(DIRS) do
            local nr, nc = r + d[1], c + d[2]
            while inBounds(nr, nc, n) and not state[nr][nc] do
                count = count + 1
                nr, nc = nr + d[1], nc + d[2]
            end
        end
        return count
    end
    local function allCluesOKFinal()
        for r = 1, n do for c = 1, n do
            if clues[r][c] and visibilityFinal(r, c) ~= clues[r][c] then return false end
        end end
        return true
    end
    local clue_cells = {}
    for r = 1, n do for c = 1, n do
        if clues[r][c] then clue_cells[#clue_cells + 1] = { r, c, clues[r][c] } end
    end end

    -- Per-clue visibility bounds (sound): each ray sees at least its run
    -- of decided-clear cells and at most its run of not-shaded cells.
    local function cluesInRange()
        for _, cl in ipairs(clue_cells) do
            local lo, hi = 1, 1
            for _, d in ipairs(DIRS) do
                local nr, nc = cl[1] + d[1], cl[2] + d[2]
                local sure = true
                while inBounds(nr, nc, n) and state[nr][nc] ~= true do
                    hi = hi + 1
                    if state[nr][nc] == nil then sure = false end
                    if sure then lo = lo + 1 end
                    nr, nc = nr + d[1], nc + d[2]
                end
            end
            if cl[3] < lo or cl[3] > hi then return false end
        end
        return true
    end

    -- Next cell: the first undecided cell just past a clue's clear run
    -- (most constrained), else the first undecided cell in reading order.
    local function pick()
        for _, cl in ipairs(clue_cells) do
            for _, d in ipairs(DIRS) do
                local nr, nc = cl[1] + d[1], cl[2] + d[2]
                while inBounds(nr, nc, n) and state[nr][nc] == false do
                    nr, nc = nr + d[1], nc + d[2]
                end
                if inBounds(nr, nc, n) and state[nr][nc] == nil then return nr, nc end
            end
        end
        for r = 1, n do for c = 1, n do
            if state[r][c] == nil then return r, c end
        end end
        return nil
    end

    local function search()
        if solutions >= limit or exhausted then return end
        nodes = nodes + 1
        if nodes > node_budget then exhausted = true; return end
        local r, c = pick()
        if not r then
            if allCluesOKFinal() then
                solutions = solutions + 1
            end
            return
        end
        for _, val in ipairs({ false, true }) do
            -- Set the cell first: the 2x2 test must see the block this
            -- very cell completes (the pre-1.6.0 script tested before
            -- setting it, so it let such grids through as extra solutions).
            state[r][c] = val
            local ok = not (val == true and has2x2ShadedAt(r, c))
                and cluesInRange() and regionOK(true) and regionOK(false)
            if ok then search() end
            state[r][c] = nil
            if solutions >= limit or exhausted then break end
        end
    end
    search()
    return solutions, exhausted
end

local ok = true

local function analyze(n, difficulty, n_trials, node_budget, threshold, gate)
    local unique, ambiguous, inconclusive = 0, 0, 0
    local worst_gen, clue_total, clear_total = 0, 0, 0
    local level = M.LEVELS[difficulty]
    local deducible = 0
    for i = 1, n_trials do
        math.randomseed(i * 7919)
        local b = Board:new({ n = n, difficulty = difficulty })
        local t0 = os.clock()
        b:generate(difficulty)
        local gen_t = os.clock() - t0
        if gen_t > worst_gen then worst_gen = gen_t end
        -- Shape sanity (see the audit doc): a silent fallback to a trivial
        -- grid would pass the uniqueness test, so check size and that some
        -- clear cells are left unnumbered.
        assert(b.n == n and #b.clues == n, "wrong board size")
        local clues, clear = 0, 0
        for r = 1, n do for c = 1, n do
            if b.clues[r][c] then clues = clues + 1 end
            if not b.solution[r][c] then clear = clear + 1 end
        end end
        clue_total, clear_total = clue_total + clues, clear_total + clear
        if M.deduce(b.clues, n, level.tier) then deducible = deducible + 1 end
        local solutions, exhausted = countSolutions(b.clues, n, 2, node_budget)
        if exhausted then inconclusive = inconclusive + 1
        elseif solutions == 1 then unique = unique + 1
        else ambiguous = ambiguous + 1 end
    end
    local rate = unique / n_trials
    local status = (rate >= threshold and deducible == n_trials) and "OK"
        or (gate and "FAIL" or "KNOWN-LIMITATION")
    if status == "FAIL" then ok = false end
    print(string.format("[%s] n=%d %s: unique=%d/%d ambiguous=%d inconclusive=%d, solvable without guessing %d/%d, clues %.0f%% of clear cells (threshold %.0f%%, worst gen %.3fs)",
        status, n, difficulty, unique, n_trials, ambiguous, inconclusive, deducible, n_trials,
        100 * clue_total / clear_total, threshold * 100, worst_gen))
    io.flush()
end

for _, n in ipairs({ 6, 7, 8 }) do
    for _, diff in ipairs({ "easy", "medium", "hard" }) do
        analyze(n, diff, 20, 1500000, 1.0, true)
    end
end

os.exit(ok and 0 or 1)
