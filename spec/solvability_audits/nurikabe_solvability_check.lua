-- Uniqueness regression check for nurikabe.koplugin.
--
-- This is NOT a busted spec -- see docs/generator_robustness_audit.md,
-- "Human-solvability audit" section, for why this class of check needs its
-- own tooling separate from `busted spec/`.
--
-- Run from the repo root:
--   luajit spec/solvability_audits/nurikabe_solvability_check.lua
--
-- Background: nurikabe's clues are structurally 1-per-island, so before
-- 1.5.0 the generator produced candidate layouts with zero uniqueness
-- verification, then (1.5.0) verified candidates with a counter and fell
-- back to an unproven layout at n=10/15 -- or to a single all-white
-- island when no layout could be built (15x15 Hard, every seed).
--
-- Since 1.6.0 (2026-11-04) the generator builds puzzles that its own logic
-- solver (no guessing) solves to the last cell, which proves uniqueness by
-- construction at every size. This script cross-checks that with exact
-- counters: board.lua's countSolutions (independent of the logic solver
-- the generator uses) at every size, plus the plain counter below
-- (deliberately separate from board.lua's) up to 10x10 -- it is too slow
-- at 15x15 -- and
-- also checks each puzzle is a real one (several islands, each with one
-- number equal to its size, river connected, no 2x2 river block) and that
-- the logic solver solves it within the difficulty's tier.
--
-- Counter history: an early version processed cells in row-major order
-- and could only join an island via an already-decided neighbour (missed
-- valid shapes); the MRV-over-islands rewrite fixed that, but branched over
-- every frontier cell in turn, counting each island shape once per growth
-- order (unique puzzles reported ambiguous -- FAILed at 5x5 once the
-- generator was fixed). Now binary per frontier cell: join or black.
--
-- Exit code is non-zero if any size/difficulty drops below its threshold.

package.preload["gettext"] = function() return function(s) return s end end
package.path = "game-common/?.lua;nurikabe.koplugin/?.lua;" .. package.path
local Board = require("board")

local DIRS = {{-1,0},{1,0},{0,-1},{0,1}}

-- MRV-over-islands counter (up to `limit` solutions). Deliberately separate
-- from board.lua's own countSolutions -- cross-checks the production gate
-- rather than testing a fix against itself.
local function countSolutions(b, limit, node_budget)
    local n = b.n
    local islands = {}
    for r = 1, n do for c = 1, n do
        if b.clues[r][c] > 0 then
            islands[#islands+1] = {r=r, c=c, target=b.clues[r][c], cells={{r,c}}}
        end
    end end
    local num_islands = #islands

    local color = {}
    for r=1,n do color[r]={}; for c=1,n do color[r][c]=0 end end
    local island_count = {}
    for i=1,num_islands do
        island_count[i] = 1
        color[islands[i].r][islands[i].c] = i
    end

    local solutions, nodes, exhausted = 0, 0, false

    -- color: 0 undecided, -1 black, k > 0 island k
    local function frontierFor(idx)
        local isl = islands[idx]
        local cands, seen = {}, {}
        for _, cell in ipairs(isl.cells) do
            for _, d in ipairs(DIRS) do
                local nr, nc = cell[1]+d[1], cell[2]+d[2]
                local key = nr*1000+nc
                if nr>=1 and nr<=n and nc>=1 and nc<=n and color[nr][nc]==0 and not seen[key] then
                    local conflict = false
                    for _, d2 in ipairs(DIRS) do
                        local mr, mc = nr+d2[1], nc+d2[2]
                        if mr>=1 and mr<=n and mc>=1 and mc<=n then
                            local v = color[mr][mc]
                            if v > 0 and v ~= idx then conflict = true; break end
                        end
                    end
                    if not conflict then seen[key] = true; cands[#cands+1] = {nr,nc} end
                end
            end
        end
        return cands
    end

    -- every island complete: undecided cells are black
    local function finalBlackValid()
        for r=1,n-1 do for c=1,n-1 do
            if color[r][c]<=0 and color[r+1][c]<=0 and color[r][c+1]<=0 and color[r+1][c+1]<=0 then return false end
        end end
        local start_r,start_c,total = nil,nil,0
        for r=1,n do for c=1,n do
            if color[r][c]<=0 then total=total+1; if not start_r then start_r,start_c=r,c end end
        end end
        if total==0 then return true end
        local visited={}
        for r=1,n do visited[r]={} end
        local stack={{start_r,start_c}}
        visited[start_r][start_c]=true
        local seen=1
        while #stack>0 do
            local cur=table.remove(stack)
            for _,d in ipairs(DIRS) do
                local nr,nc=cur[1]+d[1],cur[2]+d[2]
                if nr>=1 and nr<=n and nc>=1 and nc<=n and color[nr][nc]<=0 and not visited[nr][nc] then
                    visited[nr][nc]=true; seen=seen+1; stack[#stack+1]={nr,nc}
                end
            end
        end
        return seen==total
    end

    -- a 2x2 block already all black is a dead end (prunes the search)
    local function blackBlockAt(r, c)
        for dr = -1, 0 do for dc = -1, 0 do
            local r0, c0 = r+dr, c+dc
            if r0>=1 and c0>=1 and r0<n and c0<n
                and color[r0][c0]==-1 and color[r0+1][c0]==-1
                and color[r0][c0+1]==-1 and color[r0+1][c0+1]==-1 then return true end
        end end
        return false
    end

    -- MRV over islands, but each branch is binary on ONE frontier cell of
    -- the chosen island: it joins the island, or it is black. (Until
    -- 2026-11-04 this branched over every frontier cell in turn, so the
    -- same island shape was reached once per order its cells could be
    -- added in and counted that many times -- unique puzzles were reported
    -- ambiguous; the same bug board.lua's counter had before 1.5.0.) A
    -- frontier cell can't belong to another island (it would touch this
    -- one), so the two branches cover every solution exactly once.
    local function search()
        if solutions >= limit or exhausted then return end
        nodes = nodes + 1
        if nodes > node_budget then exhausted = true; return end
        local best_idx, best_frontier, best_len = nil, nil, math.huge
        for i=1,num_islands do
            if island_count[i] < islands[i].target then
                local frontier = frontierFor(i)
                if #frontier < best_len then
                    best_len, best_frontier, best_idx = #frontier, frontier, i
                    if best_len == 0 then break end
                end
            end
        end
        if not best_idx then
            if finalBlackValid() then solutions = solutions + 1 end
            return
        end
        if best_len == 0 then return end
        local isl = islands[best_idx]
        local cell = best_frontier[1]
        local cr, cc = cell[1], cell[2]
        color[cr][cc] = best_idx
        isl.cells[#isl.cells+1] = cell
        island_count[best_idx] = island_count[best_idx] + 1
        search()
        island_count[best_idx] = island_count[best_idx] - 1
        isl.cells[#isl.cells] = nil
        if solutions >= limit or exhausted then color[cr][cc] = 0; return end
        color[cr][cc] = -1
        if not blackBlockAt(cr, cc) then search() end
        color[cr][cc] = 0
    end
    search()
    return solutions, exhausted
end

local ok = true
local TIER = { easy = 1, medium = 2, hard = 3 }

-- the stored solution is a real Nurikabe solution of the clues
local function sane(b)
    local n, sb, clues = b.n, b.solution_black, b.clues
    local black, start = 0, nil
    for r = 1, n do for c = 1, n do
        if sb[r][c] then black = black + 1; start = start or { r, c } end
        if r < n and c < n and sb[r][c] and sb[r+1][c] and sb[r][c+1] and sb[r+1][c+1] then
            return false, "2x2 river block"
        end
    end end
    local seen = {}
    for r = 1, n do seen[r] = {} end
    local function flood(r0, c0, want_black)
        local stack, cells, number, nums = { { r0, c0 } }, 0, 0, 0
        seen[r0][c0] = true
        while #stack > 0 do
            local p = table.remove(stack)
            cells = cells + 1
            if clues[p[1]][p[2]] > 0 then number = clues[p[1]][p[2]]; nums = nums + 1 end
            for _, d in ipairs(DIRS) do
                local r, c = p[1] + d[1], p[2] + d[2]
                if r >= 1 and r <= n and c >= 1 and c <= n and not seen[r][c] and sb[r][c] == want_black then
                    seen[r][c] = true; stack[#stack + 1] = { r, c }
                end
            end
        end
        return cells, number, nums
    end
    if start and flood(start[1], start[2], true) ~= black then return false, "river split" end
    local islands = 0
    for r = 1, n do for c = 1, n do
        if not seen[r][c] then
            islands = islands + 1
            local cells, number, nums = flood(r, c, false)
            if nums ~= 1 or number ~= cells then return false, "island/number mismatch" end
        end
    end end
    if islands < math.floor(n * n / 12) then return false, "only " .. islands .. " islands" end
    return true
end

local function analyze(n, difficulty, n_trials, node_budget, threshold)
    local unique, ambiguous, inconclusive, broken, guessing = 0, 0, 0, 0, 0
    for i = 1, n_trials do
        math.randomseed(i * 7919)
        local b = Board:new({ n = n, difficulty = difficulty })
        b:generate(difficulty)
        local good, why = sane(b)
        if not good then
            broken = broken + 1
            print(("  n=%d %s seed %d: %s"):format(n, difficulty, i, why))
        end
        if not Board.logicSolve(b.clues, n, TIER[difficulty]) then guessing = guessing + 1 end
        -- board.lua's own exact counter (propagating, fast enough at 15x15),
        -- cross-checked by this file's plain one where that one is fast
        local solutions, exhausted = Board.countSolutions(b.clues, n, 2, node_budget)
        if n <= 10 then
            local s2, ex2 = countSolutions(b, 2, node_budget)
            if not ex2 and not exhausted and s2 ~= solutions then
                print(("  n=%d %s seed %d: counters disagree (%d vs %d)"):format(n, difficulty, i, solutions, s2))
                exhausted = true
            end
        end
        if exhausted then inconclusive = inconclusive + 1
        elseif solutions == 1 and good then unique = unique + 1
        else ambiguous = ambiguous + 1 end
    end
    local rate = unique / n_trials
    local status = (rate >= threshold and guessing == 0 and broken == 0) and "OK" or "FAIL"
    if status == "FAIL" then ok = false end
    print(string.format("[%s] n=%d %s: unique=%d/%d ambiguous=%d inconclusive=%d broken=%d needs-guessing=%d (threshold %.0f%%)",
        status, n, difficulty, unique, n_trials, ambiguous, inconclusive, broken, guessing, threshold * 100))
    io.flush()
end

-- Every size is held to the full bar since 1.6.0.
for _, n in ipairs({ 5, 10, 15 }) do
    for _, d in ipairs({ "easy", "medium", "hard" }) do
        analyze(n, d, n == 15 and 8 or (n == 10 and 10 or 15), 5000000, 1.0)
    end
end

os.exit(ok and 0 or 1)
