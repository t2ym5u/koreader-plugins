-- Kakuro grid-construction experiments, kept for whoever picks this back up
-- (see kakuro_solvability_check.lua's header for the full writeup of what
-- was tried and why each attempt failed). None of these are wired into
-- board.lua -- they're standalone builders + an independent uniqueness
-- counter, meant to be loaded and experimented with directly:
--
--   luajit -e '
--     package.preload["gettext"] = function() return function(s) return s end end
--     package.path = "game-common/?.lua;kakuro.koplugin/?.lua;" .. package.path
--     local Board = require("board")
--     local K = loadfile("spec/solvability_audits/kakuro_construction_attempts.lua")()
--     -- e.g. try the staircase builder against board.lua's own solver:
--     local tmpl = K.buildStaircaseLayout(6)
--     ...
--   '
--
-- All of these were tested against board.lua's REAL solveGrid/getRuns (not
-- reimplemented), so any given result here should reproduce if re-run.

local M = {}

-- ---------------------------------------------------------------------------
-- Attempt 1: staircase of overlapping 2-cell across-runs (dominoes).
-- Provably free of the "generalized rectangle swap" (no 2 rows ever share
-- both columns of their across-run) -- but its 2 endpoints end up as
-- length-1 down-runs, which board.lua's own sanitiser (generateFromTemplate,
-- "Pass 2: remove runs of length 1") strips, cascading into stripping the
-- ENTIRE chain (each removal shortens its row's run to length 1, which gets
-- removed too, shortening the next column, etc). Confirmed: 0 surviving
-- cells for k>=2 when run through the real sanitiser. DO NOT feed this
-- straight into generateFromTemplate expecting it to work -- it won't; it's
-- here to show what doesn't survive and why, if someone wants to try fixing
-- the termination instead of abandoning the domino-chain idea.
function M.buildStaircaseLayout(k)
    local n_rows, n_cols = k + 2, k + 3
    local layout = {}
    for r = 1, n_rows do
        layout[r] = {}
        for c = 1, n_cols do layout[r][c] = 0 end
    end
    for i = 1, k do
        local r = i + 1
        layout[r][1] = 2
        layout[r][i + 1] = 1
        layout[r][i + 2] = 1
    end
    for c = 1, n_cols do
        local topmost = nil
        for r = 1, n_rows do
            if layout[r][c] == 1 then topmost = r; break end
        end
        if topmost then layout[topmost - 1][c] = 2 end
    end
    return { n_rows = n_rows, n_cols = n_cols, layout = layout }
end

-- ---------------------------------------------------------------------------
-- Attempt 2: periodic "brick" black-cell pattern (diagonal offset per row).
-- Produces genuinely irregular, varied-length runs (unlike a rectangle or a
-- uniform chain) and survives a clue-independent stabilization pass (see
-- stabilizeGrid below) with a healthy cell count. Empirically STILL ~100%
-- ambiguous though (tested at 9x10, period 4-6, several row_seed values,
-- with up to 500 retried digit-fills per pattern) -- the swap turned out to
-- be pervasive at this grid scale regardless of construction method.
function M.buildBrickGrid(n_rows, n_cols, period, row_seed)
    local grid = {}
    for r = 1, n_rows do
        grid[r] = {}
        for c = 1, n_cols do grid[r][c] = 0 end
    end
    for r = 2, n_rows do
        local offset = (r * row_seed) % period
        for c = 2, n_cols do
            grid[r][c] = ((c + offset) % period == 0) and 0 or 1
        end
    end
    return grid
end

-- ---------------------------------------------------------------------------
-- Attempt 3: fully random black/white grid at a given white-cell density.
-- Same conclusion as the brick pattern: survives stabilization fine at
-- density ~0.6-0.85, still ~100% ambiguous (60/60 random patterns tested
-- ambiguous at 9x10). Larger sizes (15x16+) were not conclusively tested --
-- countRunSolutions got too slow to iterate on before a size where this
-- might plausibly change (see "untried directions" in
-- kakuro_solvability_check.lua).
function M.buildRandomGrid(n_rows, n_cols, density)
    local grid = {}
    for r = 1, n_rows do
        grid[r] = {}
        for c = 1, n_cols do grid[r][c] = 0 end
    end
    for r = 2, n_rows do
        for c = 2, n_cols do
            grid[r][c] = (math.random() < density) and 1 or 0
        end
    end
    return grid
end

local function extractRuns(grid, n_rows, n_cols, direction)
    local runs = {}
    if direction == "across" then
        for r = 1, n_rows do
            local c = 1
            while c <= n_cols do
                if grid[r][c] == 1 then
                    local cells = {}
                    while c <= n_cols and grid[r][c] == 1 do
                        cells[#cells + 1] = { r = r, c = c }; c = c + 1
                    end
                    if #cells >= 2 then runs[#runs + 1] = { cells = cells, clue_r = r, clue_c = cells[1].c - 1 } end
                else c = c + 1 end
            end
        end
    else
        for c = 1, n_cols do
            local r = 1
            while r <= n_rows do
                if grid[r][c] == 1 then
                    local cells = {}
                    while r <= n_rows and grid[r][c] == 1 do
                        cells[#cells + 1] = { r = r, c = c }; r = r + 1
                    end
                    if #cells >= 2 then runs[#runs + 1] = { cells = cells, clue_r = cells[1].r - 1, clue_c = c } end
                else r = r + 1 end
            end
        end
    end
    return runs
end

-- Iteratively blackens any white cell that isn't part of BOTH a valid
-- across-run and a valid down-run, re-extracting runs each pass until
-- stable. Unlike board.lua's own sanitiser, this needs no pre-placed clue
-- markers (it derives clue positions fresh from the final stable run
-- boundaries), so trimming can never orphan a clue -- this is what let the
-- brick/random patterns above survive at all, where a naive port of the old
-- clue-first sanitiser collapsed them the same way it collapses dominoes.
function M.stabilizeGrid(grid, n_rows, n_cols)
    local changed = true
    while changed do
        changed = false
        local across_runs = extractRuns(grid, n_rows, n_cols, "across")
        local down_runs = extractRuns(grid, n_rows, n_cols, "down")
        local in_across, in_down = {}, {}
        for r = 1, n_rows do in_across[r] = {}; in_down[r] = {} end
        for _, run in ipairs(across_runs) do
            for _, cell in ipairs(run.cells) do in_across[cell.r][cell.c] = true end
        end
        for _, run in ipairs(down_runs) do
            for _, cell in ipairs(run.cells) do in_down[cell.r][cell.c] = true end
        end
        for r = 1, n_rows do
            for c = 1, n_cols do
                if grid[r][c] == 1 and (not in_across[r][c] or not in_down[r][c]) then
                    grid[r][c] = 0
                    changed = true
                end
            end
        end
    end
    return extractRuns(grid, n_rows, n_cols, "across"), extractRuns(grid, n_rows, n_cols, "down")
end

-- ---------------------------------------------------------------------------
-- Independent uniqueness counter (MRV + sum-feasibility pruning, capped at
-- `limit` solutions / `node_budget` search nodes). Deliberately a separate
-- implementation from board.lua's own solver, for cross-checking. Used
-- throughout the investigation to confirm ambiguity wasn't a counting bug
-- (verified by diffing the 2 found solutions directly: they differ by
-- exactly 2 independent 2-cell "pair swaps", each preserving its own
-- pair-sum -- a real, correct alternate solution, not an artifact).
function M.countSolutions(across_runs, down_runs, sol, n_rows, n_cols, limit, node_budget)
    local cell_across, cell_down = {}, {}
    for r = 1, n_rows do cell_across[r] = {}; cell_down[r] = {} end
    for i, run in ipairs(across_runs) do for _, cell in ipairs(run.cells) do cell_across[cell.r][cell.c] = i end end
    for i, run in ipairs(down_runs) do for _, cell in ipairs(run.cells) do cell_down[cell.r][cell.c] = i end end
    for _, run in ipairs(across_runs) do
        local s = 0
        for _, cell in ipairs(run.cells) do s = s + sol[cell.r][cell.c] end
        run.sum = s
    end
    for _, run in ipairs(down_runs) do
        local s = 0
        for _, cell in ipairs(run.cells) do s = s + sol[cell.r][cell.c] end
        run.sum = s
    end
    local white_cells = {}
    for r = 1, n_rows do for c = 1, n_cols do
        if cell_across[r][c] or cell_down[r][c] then white_cells[#white_cells + 1] = { r = r, c = c } end
    end end
    local grid = {}
    for r = 1, n_rows do grid[r] = {}; for c = 1, n_cols do grid[r][c] = 0 end end
    local solutions, nodes, exhausted = 0, 0, false
    local function usedAndRemaining(run)
        local fs, fc = 0, 0
        for _, cell in ipairs(run.cells) do
            local v = grid[cell.r][cell.c]
            if v ~= 0 then fs = fs + v; fc = fc + 1 end
        end
        return fs, fc
    end
    local function candidatesFor(r, c)
        local arun, drun = cell_across[r][c] and across_runs[cell_across[r][c]], cell_down[r][c] and down_runs[cell_down[r][c]]
        local used = {}
        local function markUsed(run)
            if run then for _, cell in ipairs(run.cells) do
                local v = grid[cell.r][cell.c]
                if v ~= 0 then used[v] = true end
            end end
        end
        markUsed(arun); markUsed(drun)
        local cands = {}
        for v = 1, 9 do
            if not used[v] then
                local ok = true
                if arun then
                    local fs, fc = usedAndRemaining(arun)
                    local ra = #arun.cells - fc - 1
                    local rs = arun.sum - fs - v
                    if rs < 0 or (ra == 0 and rs ~= 0) then ok = false end
                    if ok and ra > 0 and (rs < ra or rs > ra * 9) then ok = false end
                end
                if ok and drun then
                    local fs, fc = usedAndRemaining(drun)
                    local ra = #drun.cells - fc - 1
                    local rs = drun.sum - fs - v
                    if rs < 0 or (ra == 0 and rs ~= 0) then ok = false end
                    if ok and ra > 0 and (rs < ra or rs > ra * 9) then ok = false end
                end
                if ok then cands[#cands + 1] = v end
            end
        end
        return cands
    end
    local function search(depth)
        if solutions >= limit or exhausted then return end
        nodes = nodes + 1
        if nodes > node_budget then exhausted = true; return end
        if depth > #white_cells then solutions = solutions + 1; return end
        local best_idx, best_cands, best_len = nil, nil, 1000
        for i, cell in ipairs(white_cells) do
            if grid[cell.r][cell.c] == 0 then
                local cands = candidatesFor(cell.r, cell.c)
                if #cands < best_len then
                    best_len, best_cands, best_idx = #cands, cands, i
                    if best_len <= 1 then break end
                end
            end
        end
        if best_idx == nil then solutions = solutions + 1; return end
        if best_len == 0 then return end
        local cell = white_cells[best_idx]
        for _, v in ipairs(best_cands) do
            grid[cell.r][cell.c] = v
            search(depth + 1)
            grid[cell.r][cell.c] = 0
            if solutions >= limit or exhausted then return end
        end
    end
    search(1)
    return solutions, exhausted, nodes
end

return M
