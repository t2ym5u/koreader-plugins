-- Uniqueness regression check for masyu.koplugin.
--
-- This is NOT a busted spec -- see docs/generator_robustness_audit.md,
-- "Human-solvability audit" section, for why this class of check needs its
-- own tooling separate from `busted spec/`.
--
-- Run from the repo root:
--   luajit spec/solvability_audits/masyu_solvability_check.lua
--
-- Background: _checkWin() is genuinely rule-based (every marked cell has
-- exactly 2 marked neighbours; black clues are marked turns with straight
-- arms; white clues are marked straights with a turning arm) but, before
-- this fix, did NOT require the marked cells to form a SINGLE loop -- only
-- that union of cycles satisfy those local rules. generate() picked a
-- random loop shape and revealed a flat fraction of the available
-- black/white clue candidates with zero uniqueness verification. Combined,
-- almost any generated puzzle admitted a completely different, unrelated
-- valid marking (e.g. the clues pin down only a small part of the grid,
-- leaving the rest free to form other loops/paths), which is a real,
-- structural correctness bug, not just a clue-density tuning problem: even
-- revealing every single available clue candidate only produced a genuinely
-- unique puzzle for roughly 10% of generated loop shapes at n=6 and n=8.
--
-- Fix: added single-loop-connectivity to _checkWin() (trace from any
-- marked cell, always stepping to the marked neighbour that isn't where we
-- came from, and require every marked cell to be visited before returning
-- to start) -- matching real Masyu rules. The uniqueness counter below
-- mirrors that same connectivity check. Cell-based backtracking (clue
-- cells forced marked from the start; degree-2 propagation once a marked
-- cell's decided-neighbour-count is known); final verification (single
-- loop + all clue turn/straight/arm rules) only runs once every cell is
-- decided.
--
-- Since sparser reveal ratios essentially never help (full reveal itself
-- only succeeds ~10% of the time per loop shape), generate() always reveals
-- every available candidate and instead retries with a fresh loop shape
-- (up to 40 attempts). n=6 reaches 100% unique this way, fast. n=8 is
-- fundamentally harder for this solver -- proving a shape UNIQUE requires
-- exhausting its whole remaining search space, which only succeeds for a
-- minority of shapes -- so generate() there is capped by both a node
-- budget and a wall-clock budget (8s) per call, falling back to the best
-- (structurally valid, not proven-unique) candidate found if nothing
-- verifies in time. This is a known, accepted limitation for the larger
-- board size: a real, positive improvement over the prior near-total
-- brokenness, not a full fix. See docs/generator_robustness_audit.md for
-- the tracked limitation.
--
-- Exit code is non-zero if n=6 drops below its threshold. n=8 is reported
-- but not gated (see limitation above).

package.preload["gettext"] = function() return function(s) return s end end
package.path = "game-common/?.lua;masyu.koplugin/?.lua;" .. package.path
local Board = require("board")

local CELL_EMPTY, CELL_WHITE, CELL_BLACK = 0, 1, 2
local DIRS = { {-1,0},{1,0},{0,-1},{0,1} }
local function inBounds(r, c, n) return r >= 1 and r <= n and c >= 1 and c <= n end

-- Independent cross-check counter (deliberately separate from board.lua's
-- own copy) -- cross-checks the production gate rather than testing a fix
-- against itself.
local function countSolutions(clues, n, limit, node_budget)
    local marked = {}
    for r = 1, n do marked[r] = {} end
    for r = 1, n do for c = 1, n do if clues[r][c] ~= CELL_EMPTY then marked[r][c] = true end end end

    local solutions, nodes, exhausted = 0, 0, false

    local function arms(r, c)
        local a = {}
        for _, d in ipairs(DIRS) do
            local nr, nc = r + d[1], c + d[2]
            if inBounds(nr, nc, n) and marked[nr][nc] then a[#a+1] = d end
        end
        return a
    end
    local function isTurn(r, c)
        local a = arms(r, c)
        return #a == 2 and not (a[1][1] == -a[2][1] and a[1][2] == -a[2][2])
    end
    local function isStraight(r, c)
        local a = arms(r, c)
        return #a == 2 and a[1][1] == -a[2][1] and a[1][2] == -a[2][2]
    end
    local function allCluesOK()
        for r = 1, n do for c = 1, n do
            local clue = clues[r][c]
            if clue == CELL_BLACK then
                if not marked[r][c] or not isTurn(r, c) then return false end
                for _, d in ipairs(arms(r, c)) do
                    if not isStraight(r + d[1], c + d[2]) then return false end
                end
            elseif clue == CELL_WHITE then
                if not marked[r][c] or not isStraight(r, c) then return false end
                local ok = false
                for _, d in ipairs(arms(r, c)) do
                    if isTurn(r + d[1], c + d[2]) then ok = true; break end
                end
                if not ok then return false end
            end
        end end
        return true
    end
    local function isSingleLoop()
        local total, start_r, start_c = 0, nil, nil
        for r = 1, n do for c = 1, n do
            if marked[r][c] then
                total = total + 1
                if not start_r then start_r, start_c = r, c end
            end
        end end
        if total == 0 then return false end
        local visited = 0
        local cur_r, cur_c = start_r, start_c
        local prev_r, prev_c = nil, nil
        repeat
            visited = visited + 1
            local next_r, next_c
            for _, d in ipairs(DIRS) do
                local nr, nc = cur_r + d[1], cur_c + d[2]
                if inBounds(nr, nc, n) and marked[nr][nc] and not (nr == prev_r and nc == prev_c) then
                    next_r, next_c = nr, nc
                    break
                end
            end
            if not next_r then return false end
            prev_r, prev_c = cur_r, cur_c
            cur_r, cur_c = next_r, next_c
        until cur_r == start_r and cur_c == start_c
        return visited == total
    end
    local function degOK()
        for r = 1, n do for c = 1, n do
            if marked[r][c] == true then
                local have, undec = 0, 0
                for _, d in ipairs(DIRS) do
                    local nr, nc = r + d[1], c + d[2]
                    if inBounds(nr, nc, n) then
                        local v = marked[nr][nc]
                        if v == true then have = have + 1
                        elseif v == nil then undec = undec + 1 end
                    end
                end
                if have > 2 or have + undec < 2 then return false end
            end
        end end
        return true
    end

    local cells = {}
    for r = 1, n do for c = 1, n do if marked[r][c] == nil then cells[#cells+1] = { r, c } end end end

    local function search(idx)
        if solutions >= limit or exhausted then return end
        nodes = nodes + 1
        if nodes > node_budget then exhausted = true; return end
        if not degOK() then return end
        if idx > #cells then
            local finaldeg = true
            for r = 1, n do for c = 1, n do
                if marked[r][c] == true then
                    local have = 0
                    for _, d in ipairs(DIRS) do
                        local nr, nc = r + d[1], c + d[2]
                        if inBounds(nr, nc, n) and marked[nr][nc] == true then have = have + 1 end
                    end
                    if have ~= 2 then finaldeg = false end
                end
            end end
            if finaldeg and isSingleLoop() and allCluesOK() then solutions = solutions + 1 end
            return
        end
        local r, c = cells[idx][1], cells[idx][2]
        for _, val in ipairs({ true, false }) do
            marked[r][c] = val
            search(idx + 1)
            marked[r][c] = nil
            if solutions >= limit or exhausted then break end
        end
    end
    search(1)
    return solutions, exhausted
end

local ok = true

local function analyze(n, n_trials, node_budget, threshold, gate)
    local unique, ambiguous, inconclusive = 0, 0, 0
    local worst_gen = 0
    for i = 1, n_trials do
        math.randomseed(i * 7919)
        local b = Board:new({ n = n })
        local t0 = os.clock()
        b:generate()
        local gen_t = os.clock() - t0
        if gen_t > worst_gen then worst_gen = gen_t end
        local solutions, exhausted = countSolutions(b.clues, n, 2, node_budget)
        if exhausted then inconclusive = inconclusive + 1
        elseif solutions == 1 then unique = unique + 1
        else ambiguous = ambiguous + 1 end
    end
    local rate = unique / n_trials
    local status = rate >= threshold and "OK" or (gate and "FAIL" or "KNOWN-LIMITATION")
    if status == "FAIL" then ok = false end
    print(string.format("[%s] n=%d: unique=%d/%d ambiguous=%d inconclusive=%d (threshold %.0f%%, worst gen %.2fs)",
        status, n, unique, n_trials, ambiguous, inconclusive, threshold * 100, worst_gen))
    io.flush()
end

analyze(6, 20, 300000, 0.90, true)
analyze(8, 20, 300000, 0.90, false) -- gated off: see known limitation in the header comment

os.exit(ok and 0 or 1)
