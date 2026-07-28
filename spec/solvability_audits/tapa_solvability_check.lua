-- Uniqueness regression check for tapa.koplugin.
--
-- This is NOT a busted spec -- see docs/generator_robustness_audit.md,
-- "Human-solvability audit" section, for why this class of check needs its
-- own tooling separate from `busted spec/`.
--
-- Run from the repo root:
--   luajit spec/solvability_audits/tapa_solvability_check.lua
--
-- Background: no "given" mask -- clue cells (numbers at a subset of
-- unshaded cells, showing the circular run-length grouping of shaded
-- 8-neighbors) ARE the entire puzzle; the whole shading is unknown, and
-- the win-check is a literal comparison to the stored solution (not
-- rule-based). `generate()` picked a random shaded region and a random
-- subset of clue cells with zero uniqueness verification. Measured
-- pre-fix: severe, real ambiguity (0% unique at every size/difficulty).
--
-- The uniqueness counter was the hardest of this whole batch to get both
-- correct and fast, with two real bugs found along the way:
--
-- 1. A first version pruned only via per-cell 2x2/clue checks, deferring
--    ALL connectivity checking to once every cell was decided. With only
--    ~6-15 clue cells governing 50-90+ free cells, that's nowhere near
--    enough pruning -- even a 20-million-node budget couldn't find the
--    ONE known valid solution for a modest puzzle (caught via the
--    standard sanity check: solver returned solutions=0 for the
--    generator's own known-good clues). Fixed by adding INCREMENTAL
--    connectivity pruning: after any cell is decided unshaded, check
--    whether the "maybe-shaded" (shaded-or-still-undecided) cells split
--    into 2+ connected components.
--
-- 2. That first incremental-connectivity attempt was itself unsound: it
--    required the ENTIRE maybe-shaded superset to stay one component, but
--    a component made entirely of cells that are simply going to resolve
--    to all-unshaded later doesn't need to connect to anything -- it
--    wrongly rejected the known-good solution at n=10 (re-triggering the
--    same sanity check). Fixed by only rejecting when 2+ components EACH
--    already anchor a confirmed-shaded cell -- those genuinely can never
--    be reconciled, but a component of only-undecided cells might still
--    resolve to nothing.
--
-- Once the counter was correct and fast (sub-10ms per call), a real
-- *generation* problem surfaced: adding a uniqueness gate to the existing
-- "regenerate the whole shading+clue-selection, check, repeat" retry loop
-- did NOT work at all -- essentially 0% unique even after 3000 attempts,
-- because every fresh attempt draws from the SAME distribution at the
-- SAME nominal clue density, and that density (like hitori's nominal
-- black-cell density) is almost never unique on its own; retrying doesn't
-- change the odds. Fixed the same way as hitori/lightup: escalate the
-- CLUE density in bounded steps for a given shading (repicking which
-- candidate cells become clues is much cheaper than regenerating the
-- shading, and more clues can only add constraints), with the final tier
-- guaranteed to reveal every candidate cell as a clue. "hard" difficulty's
-- low base ratio (0.12) needed a wide escalation range (up to 10x) to
-- reliably reach a provably-unique reveal level.
--
-- 20/20 unique at every size/difficulty after both fixes, worst case
-- ~0.8s avg at n=10/hard.
--
-- Exit code is non-zero if any size/difficulty drops below its threshold.

package.preload["gettext"] = function() return function(s) return s end end
package.path = "game-common/?.lua;tapa.koplugin/?.lua;" .. package.path
local Board = require("board")

local DIRS4 = { {-1,0},{1,0},{0,-1},{0,1} }
local DIRS8 = { {-1,0},{-1,1},{0,1},{1,1},{1,0},{1,-1},{0,-1},{-1,-1} }
local function inBounds(r, c, n) return r >= 1 and r <= n and c >= 1 and c <= n end

-- Independent cross-check counter (deliberately separate from board.lua's
-- own copy) -- cross-checks the production gate rather than testing a fix
-- against itself.
local function computeGroups(vals)
    local n_ring = #vals
    local start = 1
    for i = 1, n_ring do if vals[i] == 0 then start = i; break end end
    local groups, in_run, run_len = {}, false, 0
    for i = 0, n_ring - 1 do
        local idx = (start + i - 1) % n_ring + 1
        if vals[idx] == 1 then
            in_run = true; run_len = run_len + 1
        else
            if in_run then groups[#groups + 1] = run_len; run_len = 0 end
            in_run = false
        end
    end
    if in_run then groups[#groups + 1] = run_len end
    if #groups == 0 then
        local total = 0
        for _, v in ipairs(vals) do total = total + v end
        if total > 0 then groups[#groups + 1] = total end
    end
    table.sort(groups, function(a, b) return a > b end)
    return groups
end

local function groupsEqual(g1, g2)
    if #g1 ~= #g2 then return false end
    for i = 1, #g1 do if g1[i] ~= g2[i] then return false end end
    return true
end

local function countSolutions(clues, n, limit, node_budget)
    local shaded = {}
    for r = 1, n do shaded[r] = {} end
    local clue_cells = {}
    for r = 1, n do
        for c = 1, n do
            if clues[r][c] then
                clue_cells[#clue_cells + 1] = { r = r, c = c, groups = clues[r][c] }
                shaded[r][c] = false
            end
        end
    end

    local order, seen = {}, {}
    for _, cl in ipairs(clue_cells) do
        for _, d in ipairs(DIRS8) do
            local nr, nc = cl.r + d[1], cl.c + d[2]
            local key = nr * 1000 + nc
            if inBounds(nr, nc, n) and not clues[nr][nc] and not seen[key] then
                seen[key] = true
                order[#order + 1] = { r = nr, c = nc }
            end
        end
    end
    for r = 1, n do
        for c = 1, n do
            local key = r * 1000 + c
            if not clues[r][c] and not seen[key] then
                seen[key] = true
                order[#order + 1] = { r = r, c = c }
            end
        end
    end

    local solutions, nodes, exhausted = 0, 0, false

    local function violates2x2(r, c)
        for dr = -1, 0 do
            for dc = -1, 0 do
                local r1, r2 = r + dr, r + dr + 1
                local c1, c2 = c + dc, c + dc + 1
                if r1 >= 1 and r2 <= n and c1 >= 1 and c2 <= n then
                    if shaded[r1][c1] and shaded[r1][c2] and shaded[r2][c1] and shaded[r2][c2] then
                        return true
                    end
                end
            end
        end
        return false
    end

    local function neighborsAllDecided(cl)
        for _, d in ipairs(DIRS8) do
            local nr, nc = cl.r + d[1], cl.c + d[2]
            if inBounds(nr, nc, n) and shaded[nr][nc] == nil then return false end
        end
        return true
    end

    local function checkClue(cl)
        local vals = {}
        for _, d in ipairs(DIRS8) do
            local nr, nc = cl.r + d[1], cl.c + d[2]
            vals[#vals + 1] = (inBounds(nr, nc, n) and shaded[nr][nc]) and 1 or 0
        end
        return groupsEqual(computeGroups(vals), cl.groups)
    end

    local affecting = {}
    for r = 1, n do affecting[r] = {} end
    for _, cl in ipairs(clue_cells) do
        for _, d in ipairs(DIRS8) do
            local nr, nc = cl.r + d[1], cl.c + d[2]
            if inBounds(nr, nc, n) then
                affecting[nr][nc] = affecting[nr][nc] or {}
                table.insert(affecting[nr][nc], cl)
            end
        end
    end

    local function isConnectedFull()
        local sr, sc
        for r = 1, n do
            for c = 1, n do
                if shaded[r][c] then sr, sc = r, c end
            end
            if sr then break end
        end
        if not sr then return true end
        local visited = {}
        for r = 1, n do visited[r] = {} end
        local stack = { { sr, sc } }
        visited[sr][sc] = true
        local count = 1
        while #stack > 0 do
            local cell = table.remove(stack)
            for _, d in ipairs(DIRS4) do
                local nr, nc = cell[1] + d[1], cell[2] + d[2]
                if inBounds(nr, nc, n) and shaded[nr][nc] and not visited[nr][nc] then
                    visited[nr][nc] = true
                    count = count + 1
                    stack[#stack + 1] = { nr, nc }
                end
            end
        end
        local total = 0
        for r = 1, n do for c = 1, n do if shaded[r][c] then total = total + 1 end end end
        return count == total
    end

    -- Only a "maybe-shaded" component that already anchors a confirmed-
    -- shaded cell is a genuine problem; 2+ such anchored components can
    -- never be reconciled. A component of only-undecided cells might still
    -- resolve to all-unshaded, so it isn't rejected on its own.
    local function potentialRegionSingleComponent()
        local visited = {}
        for r = 1, n do visited[r] = {} end
        local components_with_true = 0
        for r = 1, n do
            for c = 1, n do
                if shaded[r][c] ~= false and not visited[r][c] then
                    local stack = { { r, c } }
                    visited[r][c] = true
                    local has_true = shaded[r][c] == true
                    while #stack > 0 do
                        local cell = table.remove(stack)
                        for _, d in ipairs(DIRS4) do
                            local nr, nc = cell[1] + d[1], cell[2] + d[2]
                            if inBounds(nr, nc, n) and shaded[nr][nc] ~= false and not visited[nr][nc] then
                                visited[nr][nc] = true
                                if shaded[nr][nc] == true then has_true = true end
                                stack[#stack + 1] = { nr, nc }
                            end
                        end
                    end
                    if has_true then
                        components_with_true = components_with_true + 1
                        if components_with_true > 1 then return false end
                    end
                end
            end
        end
        return true
    end

    local function search(idx)
        if solutions >= limit or exhausted then return end
        nodes = nodes + 1
        if nodes > node_budget then exhausted = true; return end

        if idx > #order then
            if isConnectedFull() then solutions = solutions + 1 end
            return
        end

        local cell = order[idx]
        local r, c = cell.r, cell.c
        for _, val in ipairs({ false, true }) do
            shaded[r][c] = val
            local ok = true
            if val and violates2x2(r, c) then ok = false end
            if ok and affecting[r][c] then
                for _, cl in ipairs(affecting[r][c]) do
                    if neighborsAllDecided(cl) and not checkClue(cl) then ok = false; break end
                end
            end
            if ok and not val then ok = potentialRegionSingleComponent() end
            if ok then search(idx + 1) end
            shaded[r][c] = nil
            if solutions >= limit or exhausted then return end
        end
    end

    search(1)
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

for _, n in ipairs({6, 8, 10}) do
    for _, diff in ipairs({"easy", "medium", "hard"}) do
        analyze(n, diff, 15, 300000, 0.90)
    end
end

os.exit(ok and 0 or 1)
