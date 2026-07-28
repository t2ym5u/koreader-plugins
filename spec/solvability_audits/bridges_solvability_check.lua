-- Uniqueness regression check for bridges.koplugin (Hashiwokakero).
--
-- This is NOT a busted spec -- see docs/generator_robustness_audit.md,
-- "Human-solvability audit" section, for why this class of check needs its
-- own tooling separate from `busted spec/`.
--
-- Run from the repo root:
--   luajit spec/solvability_audits/bridges_solvability_check.lua
--
-- Background: unlike classic Hashiwokakero, this implementation's
-- `tapBridge` only lets the player adjust the bridge count on connection
-- slots that already exist in `solution_bridges` (clamped to that slot's
-- own solution count) -- there's no mechanic to invent a bridge between an
-- island pair that isn't already one of the generator's chosen edges. So
-- the actual puzzle is simpler than full Hashi: the graph topology (which
-- island pairs connect) is fixed and already crossing-free by construction
-- (checked at generation time) -- solving means finding how many bridges
-- (0, 1, or 2) go on each FIXED edge such that every island's total
-- incident count matches its target and the resulting graph connects
-- every island.
--
-- Good news measured here: this construction (Prim's spanning tree + a
-- degree-bounded extra-bridges pass) is ALREADY close to uniquely solvable
-- on its own -- once the uniqueness counter itself was correct (see below),
-- it found ~93-100% unique across every size/difficulty even before adding
-- any retry logic. Much lower severity than every other Tier 3 plugin
-- audited so far.
--
-- A real bug was found and fixed in the counter while building it, though,
-- and it's worth remembering for any future CSP solver in this repo: the
-- first version only checked that a candidate edge value didn't EXCEED
-- what a vertex had left (an "overshoot" check), with no check that the
-- leftover was actually REACHABLE by the vertex's other still-undecided
-- edges (an "undershoot"/forward-checking gap). Without that, the search
-- wastes nearly all its effort on combinations that only fail the final
-- exact-degree check once every edge is already decided, instead of
-- pruning the instant a vertex can no longer possibly reach its target --
-- measured: even a 20-million-node budget couldn't find the ONE known
-- valid solution for a modest ~22-edge puzzle before this was fixed
-- (caught via the standard sanity check: solver returned solutions=0 for
-- the generator's own known-good layout). Fixed by also bounding each
-- endpoint's leftover against `2 * (number of its other undecided edges)`.
--
-- Fixed the residual few-percent ambiguity generate+verify style: retry
-- generating the island layout (up to 40 attempts, the existing cap) and
-- verify each candidate's uniqueness with the counter, falling back to the
-- first structurally-valid layout if nothing proves unique (never worse
-- than before). 20/20 unique at every size/difficulty after, generation
-- still near-instant (~0.001s avg).
--
-- Exit code is non-zero if any size/difficulty drops below its threshold.

package.preload["gettext"] = function() return function(s) return s end end
package.path = "game-common/?.lua;bridges.koplugin/?.lua;" .. package.path
local Board = require("board")

-- Independent cross-check counter (deliberately separate from board.lua's
-- own copy) -- cross-checks the production gate rather than testing a fix
-- against itself.
local function islandsBFSConnected(num_islands, edges_with_count)
    if num_islands == 0 then return true end
    local adj = {}
    for i = 1, num_islands do adj[i] = {} end
    for _, e in ipairs(edges_with_count) do
        if e.count > 0 then
            adj[e.i1][#adj[e.i1] + 1] = e.i2
            adj[e.i2][#adj[e.i2] + 1] = e.i1
        end
    end
    local visited, queue = {}, { 1 }
    visited[1] = true
    local count, head = 1, 1
    while head <= #queue do
        local cur = queue[head]; head = head + 1
        for _, nb in ipairs(adj[cur]) do
            if not visited[nb] then
                visited[nb] = true
                count = count + 1
                queue[#queue + 1] = nb
            end
        end
    end
    return count == num_islands
end

local function countSolutions(islands, edges, limit, node_budget)
    local n_islands = #islands
    local remaining = {}
    for i = 1, n_islands do remaining[i] = islands[i].value end

    local incident = {}
    for i = 1, n_islands do incident[i] = {} end
    for idx, e in ipairs(edges) do
        incident[e.i1][#incident[e.i1] + 1] = idx
        incident[e.i2][#incident[e.i2] + 1] = idx
    end

    local decided = {}
    for idx = 1, #edges do decided[idx] = nil end

    local solutions, nodes, exhausted = 0, 0, false

    local function otherUndecidedCount(v, exclude_idx)
        local count = 0
        for _, idx2 in ipairs(incident[v]) do
            if idx2 ~= exclude_idx and not decided[idx2] then count = count + 1 end
        end
        return count
    end

    local function legalValuesFor(idx)
        local e = edges[idx]
        local cands = {}
        for v = 0, 2 do
            local ok = true
            for _, endp in ipairs({ e.i1, e.i2 }) do
                local left = remaining[endp] - v
                if left < 0 then ok = false; break end
                local max_from_others = 2 * otherUndecidedCount(endp, idx)
                if left > max_from_others then ok = false; break end
            end
            if ok then cands[#cands + 1] = v end
        end
        return cands
    end

    local function applyValue(idx, v)
        local e = edges[idx]
        decided[idx] = v
        remaining[e.i1] = remaining[e.i1] - v
        remaining[e.i2] = remaining[e.i2] - v
    end

    local function undoValue(idx)
        local e = edges[idx]
        local v = decided[idx]
        remaining[e.i1] = remaining[e.i1] + v
        remaining[e.i2] = remaining[e.i2] + v
        decided[idx] = nil
    end

    local function search()
        if solutions >= limit or exhausted then return end
        nodes = nodes + 1
        if nodes > node_budget then exhausted = true; return end

        local best_idx, best_cands, best_len = nil, nil, math.huge
        for idx = 1, #edges do
            if not decided[idx] then
                local cands = legalValuesFor(idx)
                if #cands < best_len then
                    best_len, best_cands, best_idx = #cands, cands, idx
                    if best_len == 0 then break end
                end
            end
        end

        if not best_idx then
            for i = 1, n_islands do if remaining[i] ~= 0 then return end end
            local ec = {}
            for idx, e in ipairs(edges) do ec[idx] = { i1 = e.i1, i2 = e.i2, count = decided[idx] } end
            if islandsBFSConnected(n_islands, ec) then
                solutions = solutions + 1
            end
            return
        end
        if best_len == 0 then return end

        for _, v in ipairs(best_cands) do
            applyValue(best_idx, v)
            search()
            undoValue(best_idx)
            if solutions >= limit or exhausted then break end
        end
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
        local edges = {}
        for _, sb in ipairs(b.solution_bridges) do
            edges[#edges + 1] = { i1 = sb.i1, i2 = sb.i2 }
        end
        local solutions, exhausted = countSolutions(b.islands, edges, 2, node_budget)
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

for _, n in ipairs({7, 9, 11}) do
    for _, diff in ipairs({"easy", "medium", "hard"}) do
        analyze(n, diff, 20, 300000, 0.90)
    end
end

os.exit(ok and 0 or 1)
