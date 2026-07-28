-- Uniqueness regression check for hitori.koplugin.
--
-- This is NOT a busted spec -- see docs/generator_robustness_audit.md,
-- "Human-solvability audit" section, for why this class of check needs its
-- own tooling separate from `busted spec/`.
--
-- Run from the repo root:
--   luajit spec/solvability_audits/hitori_solvability_check.lua
--
-- Background: before 2026-07, hitori generated a random black-cell pattern
-- at a flat per-difficulty density with zero uniqueness verification
-- (measured, original `hitori_uniqueness_diagnostic.lua`: severe on
-- Easy/Medium, better on Hard). Hitori has no "reveal a subset of cells"
-- mechanic to dig -- every number is visible from the start, and the
-- puzzle to find is a *shading* -- so the fix isn't the usual dig-with-
-- verification retrofit. Instead: generate whole candidate puzzles
-- (black-pattern + number assignment) and verify with `countSolutions` (an
-- independent shading-CSP counter, separate code from board.lua's own
-- copy); if not unique, retry, escalating density in bounded steps when
-- the nominal difficulty density keeps coming back ambiguous (empirically,
-- nominal density is essentially never unique, but success climbs sharply
-- past ~0.30). Re-run this after any future change to board.lua's
-- `generate`/`countSolutions`/density constants to catch a regression.
--
-- Exit code is non-zero if any difficulty drops below its threshold.

package.preload["gettext"] = function() return function(s) return s end end
package.path = "game-common/?.lua;hitori.koplugin/?.lua;" .. package.path
local Board = require("board")

-- Deliberately separate from board.lua's own countSolutions -- cross-checks
-- the production gate rather than testing a fix against itself.
local function countSolutions(b, limit, node_budget)
    local n = b.n
    local shaded = {}
    for r = 1, n do shaded[r] = {}; for c = 1, n do shaded[r][c] = nil end end
    local solutions, nodes, exhausted = 0, 0, false

    local function rowComplete(r) for c = 1, n do if shaded[r][c] == nil then return false end end return true end
    local function colComplete(c) for r = 1, n do if shaded[r][c] == nil then return false end end return true end

    local function checkRow(r)
        local seen = {}
        for c = 1, n do
            if not shaded[r][c] then
                local v = b.puzzle[r][c]
                if seen[v] then return false end
                seen[v] = true
            end
        end
        return true
    end
    local function checkCol(c)
        local seen = {}
        for r = 1, n do
            if not shaded[r][c] then
                local v = b.puzzle[r][c]
                if seen[v] then return false end
                seen[v] = true
            end
        end
        return true
    end

    local function isConnected()
        local start_r, start_c = nil, nil
        local total_unshaded = 0
        for r = 1, n do for c = 1, n do
            if not shaded[r][c] then
                total_unshaded = total_unshaded + 1
                if not start_r then start_r, start_c = r, c end
            end
        end end
        if total_unshaded == 0 then return true end
        local visited = {}
        for r = 1, n do visited[r] = {} end
        local stack = {{start_r, start_c}}
        visited[start_r][start_c] = true
        local count = 1
        local dirs = {{-1,0},{1,0},{0,-1},{0,1}}
        while #stack > 0 do
            local cur = table.remove(stack)
            for _, d in ipairs(dirs) do
                local nr, nc = cur[1]+d[1], cur[2]+d[2]
                if nr>=1 and nr<=n and nc>=1 and nc<=n and not shaded[nr][nc] and not visited[nr][nc] then
                    visited[nr][nc] = true
                    count = count + 1
                    stack[#stack+1] = {nr,nc}
                end
            end
        end
        return count == total_unshaded
    end

    local cells = {}
    for r = 1, n do for c = 1, n do cells[#cells+1] = {r=r,c=c} end end

    local function search(idx)
        if solutions >= limit or exhausted then return end
        nodes = nodes + 1
        if nodes > node_budget then exhausted = true; return end
        if idx > #cells then
            if isConnected() then solutions = solutions + 1 end
            return
        end
        local cell = cells[idx]
        local r, c = cell.r, cell.c
        for _, choice in ipairs({false, true}) do
            local ok = true
            if choice then
                if (r > 1 and shaded[r-1][c]) or (c > 1 and shaded[r][c-1]) then ok = false end
            end
            if ok then
                shaded[r][c] = choice
                if rowComplete(r) and not checkRow(r) then ok = false end
                if ok and colComplete(c) and not checkCol(c) then ok = false end
                if ok then search(idx + 1) end
                shaded[r][c] = nil
            end
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
        b:generate(difficulty)
        local solutions, exhausted = countSolutions(b, 2, 400000)
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

for _, n in ipairs({5, 7}) do
    for _, diff in ipairs({"easy", "medium", "hard"}) do
        analyze(n, diff, 20)
    end
end

os.exit(ok and 0 or 1)
