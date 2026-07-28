-- Uniqueness regression check for numberlink.koplugin.
--
-- This is NOT a busted spec -- see docs/generator_robustness_audit.md,
-- "Human-solvability audit" section, for why this class of check needs its
-- own tooling separate from `busted spec/`.
--
-- Run from the repo root:
--   luajit spec/solvability_audits/numberlink_solvability_check.lua
--
-- Background: isSolved() is a LITERAL full-grid comparison to self.solution
-- (every cell must match exactly, not just "some valid path exists"), so
-- uniqueness means: given only the clue endpoint pairs (2 per color), is
-- there only one way to partition the WHOLE grid into n_colors simple
-- (Hamiltonian) paths, each connecting its own two given endpoints and
-- jointly covering every cell? The old generator built ONE serpentine
-- Hamiltonian path over the whole grid and sliced it into n_colors
-- contiguous segments (endpoints = each segment's two ends), with zero
-- uniqueness verification -- and at the original color density (8/12/16
-- colors per 100 cells), this is severely ambiguous: even 400 fresh
-- attempts at n=5 (24000+ underlying layouts via a since-added 60-attempt
-- retry loop) never produced a single genuinely unique layout at any of
-- the 3 real difficulties. Root cause isn't the construction method, it's
-- that 2-4 colors on a 25-cell grid leaves far too much room to shift a
-- segment boundary by a cell or two and still connect the same two
-- endpoints via a different route. Confirmed by sweeping color count
-- directly: per-attempt success only becomes reliable (>90%) around a 30%+
-- colors-per-cell ratio, roughly double the original density.
--
-- The uniqueness counter grows each color's path as an actual ordered path
-- via DFS (from endpoint1 to endpoint2, one adjacent unclaimed cell at a
-- time), recursing into the next color on every completed path; succeeds
-- only once every color is done AND every cell ends up claimed. Deliberately
-- does NOT require each color's induced grid-adjacency subgraph to have
-- degree <=2 -- that would be a stricter, WRONG condition: "chords" (extra
-- same-color adjacencies beyond the intended path) don't prevent a
-- Hamiltonian path from existing, and the tap-to-extend interaction only
-- ever needs SOME valid path to exist, not a chordless one. Two prunes
-- make the search tractable: colors are processed in ascending
-- endpoint-distance order (MRV -- the tightest-constrained path first),
-- and a cheap BFS reachability check confirms every remaining color's
-- endpoint pair (and the current path's own target) is still connectable
-- through unclaimed cells, abandoning the branch immediately otherwise
-- (mirrors bridges' forward-checking fix elsewhere in this audit).
--
-- A first version of both this counter and generate()'s own copy had a
-- real, separate SOUNDNESS bug: the "unclaimed" check for extending a path
-- was just `owner[cell] == 0`, which let one color's path walk straight
-- through ANOTHER color's reserved clue endpoint cell (silently stealing
-- it), corrupting the ownership bookkeeping and undercounting solutions --
-- caught by cross-checking against a plain unpruned reference on a fixed
-- seed (found 3 solutions where the pruned counter claimed exactly 1).
-- Fixed by requiring a cell be BOTH unclaimed AND not a clue belonging to a
-- different color before a path may claim it. This is what made the
-- earlier (now known-wrong) "n=5 already mostly fixable" measurement from
-- this same investigation illusory -- worth remembering: an aggressive
-- prune that looks like it's just cutting dead branches can instead be
-- silently corrupting shared mutable state (here, the `owner` grid) in a
-- way that produces false "unique" verdicts, not just wrong ambiguous ones.
--
-- Fixed generate+verify style (nothing to dig, same shape as
-- hitori/nurikabe/masyu): raised N_COLORS_PER_100 to a density that's
-- actually achievable (25/32/40 instead of 8/12/16), then retries the
-- serpentine-slice construction with randomized segment lengths (the
-- straightforward floor-division split is fully deterministic given n and
-- n_colors -- only 8 corner/orientation combos exist at all, so retrying
-- without varying the split itself could never explore anything new) up to
-- 60 times per generate() call, verifying each candidate. At the corrected
-- density, more (shorter) colors also makes verification itself much
-- cheaper than the old few-long-paths shape, so every size gets verified,
-- not just the smallest.
--
-- 20/20 unique at every size/difficulty after the fix, worst case ~0.02s
-- (n=10/easy) -- one of the fastest and most complete fixes in this whole
-- audit, once the real density problem (not a retry-budget problem) was
-- identified.
--
-- Exit code is non-zero if any size/difficulty drops below its threshold.

package.preload["gettext"] = function() return function(s) return s end end
package.path = "game-common/?.lua;numberlink.koplugin/?.lua;" .. package.path
local Board = require("board")

local DIRS = { {-1,0}, {1,0}, {0,-1}, {0,1} }
local function inBounds(r, c, n) return r >= 1 and r <= n and c >= 1 and c <= n end

-- Independent cross-check counter (deliberately separate from board.lua's
-- own copy) -- cross-checks the production gate rather than testing a fix
-- against itself.
local function countSolutions(clues, n, k, limit, node_budget)
    local owner = {}
    for r = 1, n do owner[r] = {}; for c = 1, n do owner[r][c] = 0 end end

    local endpoints = {}
    for col = 1, k do
        local ep = {}
        for r = 1, n do for c = 1, n do if clues[r][c] == col then ep[#ep + 1] = { r, c } end end end
        endpoints[col] = ep
    end

    local order = {}
    for col = 1, k do order[col] = col end
    table.sort(order, function(a, b)
        local ea, eb = endpoints[a], endpoints[b]
        local da = math.abs(ea[1][1] - ea[2][1]) + math.abs(ea[1][2] - ea[2][2])
        local db = math.abs(eb[1][1] - eb[2][1]) + math.abs(eb[1][2] - eb[2][2])
        return da < db
    end)

    local solutions, nodes, exhausted = 0, 0, false
    local total_cells = n * n

    local bfs_seen = {}
    for r = 1, n do bfs_seen[r] = {} end
    local bfs_stamp = 0
    local bfs_queue = {}

    -- A cell is usable for `col`'s path if unclaimed AND not another
    -- color's reserved clue endpoint (see header: letting a different
    -- color's path walk through it was a real soundness bug).
    local function usableFor(r, c, col)
        return owner[r][c] == 0 and (clues[r][c] == 0 or clues[r][c] == col)
    end

    local function reachable(cr, cc, tr, tc, col)
        bfs_stamp = bfs_stamp + 1
        local qhead, qtail = 1, 0
        qtail = qtail + 1; bfs_queue[qtail] = { cr, cc }
        bfs_seen[cr][cc] = bfs_stamp
        while qhead <= qtail do
            local cell = bfs_queue[qhead]; qhead = qhead + 1
            local r, c = cell[1], cell[2]
            if r == tr and c == tc then return true end
            for _, d in ipairs(DIRS) do
                local nr, nc = r + d[1], c + d[2]
                if inBounds(nr, nc, n) and bfs_seen[nr][nc] ~= bfs_stamp then
                    if (nr == tr and nc == tc) or usableFor(nr, nc, col) then
                        bfs_seen[nr][nc] = bfs_stamp
                        qtail = qtail + 1; bfs_queue[qtail] = { nr, nc }
                    end
                end
            end
        end
        return false
    end

    local function claimedCount()
        local cnt = 0
        for r = 1, n do for c = 1, n do if owner[r][c] ~= 0 then cnt = cnt + 1 end end end
        return cnt
    end

    local function otherColorsStillFeasible(from_idx)
        for oi = from_idx + 1, k do
            local col = order[oi]
            local ep = endpoints[col]
            if ep[1] and ep[2] then
                if not reachable(ep[1][1], ep[1][2], ep[2][1], ep[2][2], col) then return false end
            end
        end
        return true
    end

    local function growPath(col, cr, cc, tr, tc, idx, onComplete)
        if solutions >= limit or exhausted then return false end
        nodes = nodes + 1
        if nodes > node_budget then exhausted = true; return false end
        if cr == tr and cc == tc then
            if not otherColorsStillFeasible(idx) then return true end
            return onComplete()
        end
        if not reachable(cr, cc, tr, tc, col) then return true end
        for _, d in ipairs(DIRS) do
            local nr, nc = cr + d[1], cc + d[2]
            if inBounds(nr, nc, n) and usableFor(nr, nc, col) then
                owner[nr][nc] = col
                local keep_going = growPath(col, nr, nc, tr, tc, idx, onComplete)
                owner[nr][nc] = 0
                if not keep_going then return false end
            end
        end
        return true
    end

    local function solveColor(idx)
        if solutions >= limit or exhausted then return false end
        if idx > k then
            if claimedCount() == total_cells then solutions = solutions + 1 end
            return true
        end
        local col = order[idx]
        local ep = endpoints[col]
        if #ep ~= 2 then return true end
        local r1, c1 = ep[1][1], ep[1][2]
        local r2, c2 = ep[2][1], ep[2][2]
        owner[r1][c1] = col
        local keep_going = growPath(col, r1, c1, r2, c2, idx, function() return solveColor(idx + 1) end)
        owner[r1][c1] = 0
        return keep_going
    end

    solveColor(1)
    return solutions, exhausted
end

local ok = true

local function analyze(n, difficulty, n_trials, node_budget, threshold)
    local unique, ambiguous, inconclusive = 0, 0, 0
    local worst_gen = 0
    for i = 1, n_trials do
        math.randomseed(i * 7919)
        local b = Board:new({ n = n, difficulty = difficulty })
        local t0 = os.clock()
        b:generate(difficulty)
        local gen_t = os.clock() - t0
        if gen_t > worst_gen then worst_gen = gen_t end
        local solutions, exhausted = countSolutions(b.clues, n, b.n_colors, 2, node_budget)
        if exhausted then inconclusive = inconclusive + 1
        elseif solutions == 1 then unique = unique + 1
        else ambiguous = ambiguous + 1 end
    end
    local rate = unique / n_trials
    local status = rate >= threshold and "OK" or "FAIL"
    if status == "FAIL" then ok = false end
    print(string.format("[%s] n=%d %s: unique=%d/%d ambiguous=%d inconclusive=%d (threshold %.0f%%, worst gen %.3fs)",
        status, n, difficulty, unique, n_trials, ambiguous, inconclusive, threshold * 100, worst_gen))
    io.flush()
end

for _, n in ipairs({5, 7, 9, 10}) do
    for _, diff in ipairs({"easy", "medium", "hard"}) do
        analyze(n, diff, 20, 1000000, 0.90)
    end
end

os.exit(ok and 0 or 1)
