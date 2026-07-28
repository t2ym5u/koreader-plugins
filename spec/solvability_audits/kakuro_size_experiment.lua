-- Experiment (2026-07-22): does going to a much larger grid (12x12, 15x15+)
-- reduce the generalized-rectangle-swap ambiguity that made every
-- construction ~100% ambiguous at 9x10 in the prior audit? Reuses the
-- existing, already-tested tooling in kakuro_construction_attempts.lua
-- (buildRandomGrid, stabilizeGrid, countSolutions) instead of writing new
-- unverified machinery.
--
-- RESULT: inconclusive, not a negative result. At n=12/density=0.75 (63
-- white cells), countSolutions' node budget (50000-400000 tried) is
-- exhausted before even confirming the ONE already-known valid solution --
-- its min/max sum-range pruning (no real subset-sum feasibility check) gets
-- lost long before this scale. This is a solver-performance ceiling, not a
-- uniqueness measurement -- see docs/generator_robustness_audit.md's
-- "Kakuro follow-up" section. Needs a rewrite with proper per-run combo
-- pruning (see kakuro_solvability_check.lua's combosFor-based humanSolve for
-- the right shape) before size can be tested at all.
package.path = "spec/solvability_audits/?.lua;" .. package.path
local K = dofile("spec/solvability_audits/kakuro_construction_attempts.lua")

local function fillGrid(across_runs, down_runs, n_rows, n_cols)
    local cell_across, cell_down = {}, {}
    for r = 1, n_rows do cell_across[r] = {}; cell_down[r] = {} end
    for i, run in ipairs(across_runs) do for _, cell in ipairs(run.cells) do cell_across[cell.r][cell.c] = i end end
    for i, run in ipairs(down_runs) do for _, cell in ipairs(run.cells) do cell_down[cell.r][cell.c] = i end end
    local sol = {}
    for r = 1, n_rows do
        sol[r] = {}
        for c = 1, n_cols do sol[r][c] = (cell_across[r][c] or cell_down[r][c]) and -1 or 0 end
    end
    local white_cells = {}
    for r = 1, n_rows do for c = 1, n_cols do if sol[r][c] == -1 then white_cells[#white_cells + 1] = { r = r, c = c } end end end
    local function used(run)
        local u = {}
        for _, cell in ipairs(run.cells) do local v = sol[cell.r][cell.c]; if v > 0 then u[v] = true end end
        return u
    end
    local function bt(idx)
        if idx > #white_cells then return true end
        local r, c = white_cells[idx].r, white_cells[idx].c
        local ai, di = cell_across[r][c], cell_down[r][c]
        local arun = ai and across_runs[ai]
        local drun = di and down_runs[di]
        local ua = arun and used(arun) or {}
        local ud = drun and used(drun) or {}
        local digits = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
        for i = #digits, 2, -1 do local j = math.random(i); digits[i], digits[j] = digits[j], digits[i] end
        for _, d in ipairs(digits) do
            if not ua[d] and not ud[d] then
                sol[r][c] = d
                if bt(idx + 1) then return true end
                sol[r][c] = -1
            end
        end
        return false
    end
    if not bt(1) then return nil end
    return sol
end

local function trial(n, density, trials, node_budget)
    local unique, exhausted_count, no_fill, total_time = 0, 0, 0, 0
    for t = 1, trials do
        math.randomseed(t * 104729 + n * 31 + math.floor(density * 1000))
        local grid = K.buildRandomGrid(n, n, density)
        local across_runs, down_runs = K.stabilizeGrid(grid, n, n)
        if #across_runs < 4 or #down_runs < 4 then
            no_fill = no_fill + 1
        else
            local sol = fillGrid(across_runs, down_runs, n, n)
            if not sol then
                no_fill = no_fill + 1
            else
                local t0 = os.clock()
                local solutions, exhausted = K.countSolutions(across_runs, down_runs, sol, n, n, 2, node_budget)
                local dt = os.clock() - t0
                total_time = total_time + dt
                if exhausted then exhausted_count = exhausted_count + 1
                elseif solutions == 1 then unique = unique + 1 end
            end
        end
    end
    print(string.format(
        "n=%d density=%.2f: unique=%d/%d  exhausted=%d  no_fill=%d  avg_time=%.2fs",
        n, density, unique, trials, exhausted_count, no_fill, total_time / trials))
    io.flush()
end

trial(12, 0.75, 10, 200000)
trial(15, 0.75, 10, 200000)
trial(18, 0.75, 6, 300000)
trial(20, 0.75, 4, 400000)
