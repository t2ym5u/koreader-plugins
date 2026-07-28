-- Human-solvability regression check for sudokukiller.koplugin.
--
-- This is NOT a busted spec (it's a statistical driver over many random
-- generations, not a fast deterministic unit test) -- see
-- docs/generator_robustness_audit.md, "Human-solvability audit" section, for
-- why this class of check needs its own tooling separate from `busted spec/`.
--
-- Run from the repo root:
--   luajit spec/solvability_audits/sudokukiller_solvability_check.lua
--
-- What it checks: killer sudoku puzzles (Easy/Medium) are supposed to be
-- fully solvable by a human using naked/hidden singles, cage-sum combo
-- elimination, and the "45 rule" -- with NO backtracking/guessing. This
-- script implements that solver INDEPENDENTLY of board.lua's own
-- isHumanSolvable (deliberately separate code, so this cross-checks the
-- production gate rather than testing a fix against itself) and measures
-- the fraction of freshly generated puzzles it can fully complete.
--
-- Background: before 2026-07-22, Easy/Medium killer sudoku averaged ~2
-- given digits out of 81 with cage layouts built by unconstrained random
-- region growth -- this solver completed 0/15 Easy puzzles. Fixed by adding
-- deliberate given-digit anchors and gating generation on this same class of
-- solver reaching 100%. Re-run this after ANY future change to board.lua's
-- cage generator (GIVEN_COUNT_RANGES, CAGE_MAX_SIZE, CAGE_COUNT_RANGES,
-- mergeStraySingletons, generateVerifiedCages) to catch a regression.
--
-- Exit code is non-zero if either gated difficulty drops below its
-- threshold, so this can be wired into CI later if desired.

package.preload["gettext"] = function() return function(s) return s end end
package.preload["grid_utils"] = function()
    local chunk = assert(loadfile("sudoku-common/grid_utils.lua"))
    return chunk()
end
package.path = "sudoku-common/?.lua;sudokukiller.koplugin/?.lua;" .. package.path

local Mod = require("board")
local KillerSudokuBoard = Mod.KillerSudokuBoard

local function combosForSum(size, target, forbidden_digits)
    local combos = {}
    local function rec(start, chosen, remaining_sum, remaining_slots)
        if remaining_slots == 0 then
            if remaining_sum == 0 then
                local copy = {}
                for i = 1, #chosen do copy[i] = chosen[i] end
                combos[#combos + 1] = copy
            end
            return
        end
        for v = start, 9 do
            if remaining_sum - v >= 0 then
                chosen[#chosen + 1] = v
                rec(v + 1, chosen, remaining_sum - v, remaining_slots - 1)
                chosen[#chosen] = nil
            end
        end
    end
    rec(1, {}, target, size)
    return combos
end

local function humanSolve(b)
    local n = 9
    local grid = {}
    for r = 1, n do grid[r] = {}; for c = 1, n do grid[r][c] = b.user[r][c] end end
    local function rowOf(r) local s = {} for c = 1, n do if grid[r][c] ~= 0 then s[grid[r][c]] = true end end return s end
    local function colOf(c) local s = {} for r = 1, n do if grid[r][c] ~= 0 then s[grid[r][c]] = true end end return s end
    local function boxOf(r, c)
        local br, bc = math.floor((r - 1) / 3) * 3, math.floor((c - 1) / 3) * 3
        local s = {}
        for rr = br + 1, br + 3 do for cc = bc + 1, bc + 3 do if grid[rr][cc] ~= 0 then s[grid[rr][cc]] = true end end end
        return s
    end
    local progress, iterations = true, 0
    while progress do
        progress = false
        iterations = iterations + 1
        if iterations > 200 then break end
        local cand = {}
        for r = 1, n do
            cand[r] = {}
            for c = 1, n do
                if grid[r][c] == 0 then
                    local rs, cs, bs = rowOf(r), colOf(c), boxOf(r, c)
                    local s = {}
                    for v = 1, 9 do if not rs[v] and not cs[v] and not bs[v] then s[v] = true end end
                    cand[r][c] = s
                end
            end
        end
        for _, cage in ipairs(b.cages) do
            local empties, filled_sum, filled_digits = {}, 0, {}
            for _, cell in ipairs(cage.cells) do
                local v = grid[cell.r][cell.c]
                if v ~= 0 then filled_sum = filled_sum + v; filled_digits[v] = true
                else empties[#empties + 1] = cell end
            end
            if #empties > 0 then
                local target = cage.sum - filled_sum
                local combos = combosForSum(#empties, target, filled_digits)
                local possible_per_cell = {}
                for i = 1, #empties do possible_per_cell[i] = {} end
                for _, combo in ipairs(combos) do
                    local ok = true
                    for _, d in ipairs(combo) do if filled_digits[d] then ok = false break end end
                    if ok then
                        for i, cell in ipairs(empties) do
                            for _, d in ipairs(combo) do
                                if cand[cell.r][cell.c][d] then
                                    local used = { [d] = true }
                                    local function permCheck2(order_idx)
                                        if order_idx > #empties then return true end
                                        if order_idx == i then return permCheck2(order_idx + 1) end
                                        local c2 = empties[order_idx]
                                        for _, d2 in ipairs(combo) do
                                            if not used[d2] and cand[c2.r][c2.c][d2] then
                                                used[d2] = true
                                                if permCheck2(order_idx + 1) then return true end
                                                used[d2] = nil
                                            end
                                        end
                                        return false
                                    end
                                    if permCheck2(1) then possible_per_cell[i][d] = true end
                                end
                            end
                        end
                    end
                end
                for i, cell in ipairs(empties) do
                    local newset = {}
                    for v = 1, 9 do
                        if cand[cell.r][cell.c][v] and possible_per_cell[i][v] then newset[v] = true end
                    end
                    cand[cell.r][cell.c] = newset
                end
            end
        end
        local function liveCandOk(r, c, v)
            for cc = 1, n do if cc ~= c and grid[r][cc] == v then return false end end
            for rr = 1, n do if rr ~= r and grid[rr][c] == v then return false end end
            local br, bc = math.floor((r - 1) / 3) * 3, math.floor((c - 1) / 3) * 3
            for rr = br + 1, br + 3 do for cc = bc + 1, bc + 3 do
                if (rr ~= r or cc ~= c) and grid[rr][cc] == v then return false end
            end end
            return true
        end
        -- 45-rule: a row/col/box always sums to 45, so if it's covered by
        -- cages fully inside it plus exactly one cage with a single-cell
        -- overhang, that overhang cell is directly readable.
        local function apply45Rule(cells)
            local cage_inside_count, cage_total_size = {}, {}
            for _, cell in ipairs(cells) do
                local cid = b.cell_cage[cell.r][cell.c]
                cage_inside_count[cid] = (cage_inside_count[cid] or 0) + 1
            end
            for cid in pairs(cage_inside_count) do cage_total_size[cid] = #b.cages[cid].cells end
            local full_sum, crossing = 0, {}
            for cid, inside_count in pairs(cage_inside_count) do
                if inside_count == cage_total_size[cid] then full_sum = full_sum + b.cages[cid].sum
                else crossing[#crossing + 1] = { cid = cid, inside = inside_count, total = cage_total_size[cid] } end
            end
            if #crossing == 1 then
                local x = crossing[1]
                local cage = b.cages[x.cid]
                if x.inside == 1 then
                    for _, cell in ipairs(cells) do
                        if b.cell_cage[cell.r][cell.c] == x.cid and grid[cell.r][cell.c] == 0 then
                            local v = 45 - full_sum
                            if v >= 1 and v <= 9 and cand[cell.r][cell.c][v] and liveCandOk(cell.r, cell.c, v) then
                                grid[cell.r][cell.c] = v; progress = true
                            end
                        end
                    end
                elseif x.total - x.inside == 1 then
                    local outside_val = cage.sum - (45 - full_sum)
                    if outside_val >= 1 and outside_val <= 9 then
                        for _, cell in ipairs(cage.cells) do
                            local in_unit = false
                            for _, c2 in ipairs(cells) do if c2.r == cell.r and c2.c == cell.c then in_unit = true; break end end
                            if not in_unit and grid[cell.r][cell.c] == 0 and cand[cell.r][cell.c][outside_val]
                                and liveCandOk(cell.r, cell.c, outside_val) then
                                grid[cell.r][cell.c] = outside_val; progress = true
                            end
                        end
                    end
                end
            end
        end
        for r = 1, n do local cells = {} for c = 1, n do cells[#cells + 1] = { r = r, c = c } end apply45Rule(cells) end
        for c = 1, n do local cells = {} for r = 1, n do cells[#cells + 1] = { r = r, c = c } end apply45Rule(cells) end
        for br = 0, 2 do for bc = 0, 2 do
            local cells = {}
            for r = br * 3 + 1, br * 3 + 3 do for c = bc * 3 + 1, bc * 3 + 3 do cells[#cells + 1] = { r = r, c = c } end end
            apply45Rule(cells)
        end end
        for r = 1, n do
            for c = 1, n do
                if grid[r][c] == 0 then
                    local s = cand[r][c]
                    local only, count = nil, 0
                    for v = 1, 9 do if s[v] then count = count + 1; only = v end end
                    if count == 1 then grid[r][c] = only; progress = true
                    elseif count == 0 then return 0 end
                end
            end
        end
        if not progress then
            local function tryHiddenSingle(cells)
                for v = 1, 9 do
                    local spot, cnt = nil, 0
                    for _, cell in ipairs(cells) do
                        if grid[cell.r][cell.c] == 0 and cand[cell.r][cell.c][v] then cnt = cnt + 1; spot = cell end
                    end
                    if cnt == 1 then grid[spot.r][spot.c] = v; return true end
                end
                return false
            end
            for r = 1, n do local cells = {} for c = 1, n do cells[#cells + 1] = { r = r, c = c } end if tryHiddenSingle(cells) then progress = true end end
            for c = 1, n do local cells = {} for r = 1, n do cells[#cells + 1] = { r = r, c = c } end if tryHiddenSingle(cells) then progress = true end end
            for br = 0, 2 do for bc = 0, 2 do
                local cells = {}
                for r = br * 3 + 1, br * 3 + 3 do for c = bc * 3 + 1, bc * 3 + 3 do cells[#cells + 1] = { r = r, c = c } end end
                if tryHiddenSingle(cells) then progress = true end
            end end
        end
    end
    local solved_count = 0
    for r = 1, n do for c = 1, n do if grid[r][c] ~= 0 then solved_count = solved_count + 1 end end end
    return solved_count
end

local THRESHOLDS = { easy = 0.8, medium = 0.7 }
local ok = true

local function trial(difficulty, n_trials)
    local fully_solved, total_frac = 0, 0
    for i = 1, n_trials do
        local b = KillerSudokuBoard:new()
        b:generate(difficulty)
        local solved_count = humanSolve(b)
        total_frac = total_frac + solved_count / 81
        if solved_count == 81 then fully_solved = fully_solved + 1 end
    end
    local rate = fully_solved / n_trials
    local threshold = THRESHOLDS[difficulty]
    local status = (not threshold or rate >= threshold) and "OK" or "FAIL"
    if status == "FAIL" then ok = false end
    print(string.format("[%s] %s: %d/%d fully solved, avg completion %.1f%% (threshold %.0f%%)",
        status, difficulty, fully_solved, n_trials, 100 * total_frac / n_trials,
        threshold and threshold * 100 or 0))
    io.flush()
end

trial("easy", 15)
trial("medium", 12)

os.exit(ok and 0 or 1)
