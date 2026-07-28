-- Regression check for the Tier 4 sudoku-variant siblings (see
-- docs/generator_robustness_audit.md, "Human-solvability audit" ->
-- "Tier 4"). This is NOT a busted spec -- see that doc's "Human-solvability
-- audit" section for why this class of check needs its own tooling.
--
-- Run from the repo root:
--   luajit spec/solvability_audits/tier4_sudoku_variants_check.lua
--
-- Background: unlike Tier 2 (numbrix, binairo, etc.), Tier 4's core digging
-- mechanism (shared `puzzle_generator.lua`, duplicated per-plugin) already
-- verifies uniqueness at every removal step -- so it was never suspected of
-- the same "zero uniqueness check" bug. The real open question, investigated
-- here (2026-07-27), was different per variant:
--
-- 1. windoku / hypersudoku / sudokux add their extra rule (windows, hyper
--    boxes, diagonals) as an `extra_regions` "no duplicate digit in this
--    cell set" list, threaded through `generateSolvedBoard` AND
--    `createPuzzle` by the shared module -- so the generated SOLUTION itself
--    is guaranteed to respect the extra rule, not just the puzzle's clue
--    count. All three derive their extra_regions programmatically from a
--    single region-definition table also used elsewhere in board.lua for
--    conflict-checking (no risk of the two drifting apart). Verified 0
--    duplicate-in-region violations across 60 generated solutions each.
--
-- 2. arrowsudoku / thermosudoku / betweenlines can't use extra_regions at
--    all -- their constraint (arrow sum, strictly-increasing thermometer,
--    strictly-between line) isn't a "no duplicate" rule, so instead each
--    picks a random path on the ALREADY-SOLVED grid and only keeps it if the
--    existing values already happen to satisfy the constraint (mirrors
--    sudokukiller/fillomino's "derive a clue from the fixed solution"
--    pattern) -- this is correctness-safe by construction, nothing to prove
--    wrong there. But it's a bounded-retry-loop-with-implicit-shortfall,
--    the exact shape of the very first bug this whole audit ever found
--    (bridges, 2026-07-20): `betweenlines.placeBetweenLines` targeted 4-6
--    lines with `max_attempts = 300` and measured 3/100 trials landing at
--    only 3 lines; `thermosudoku.placeThermos` targeted a fixed 5 with
--    `max_attempts = 200` and measured 1/100 trials landing at only 3 (its
--    own comment claimed "minimum 2 for visual interest" but nothing in the
--    code actually enforced that floor -- removed the stale, dead no-op
--    `if #thermos < 5 then` block along with the fix). Both low-severity
--    (3% and 1%) but real and easily fixed the same way as bridges/
--    starbattle/tapa: raise the attempt budget (300->3000, 200->2000).
--    Re-measured 0/300 shortfall for both after the fix, generation still
--    trivially fast (~0.003s avg). `arrowsudoku.placeArrows` has no
--    value-relationship rejection filter (any two unused cells form a valid
--    arrow, the sum is just computed from whatever's there), so it was
--    never at real risk -- confirmed 0/300 shortfall even before any
--    change, left as-is. `sandwichsudoku` computes its clues unconditionally
--    from any solution (every row/column already contains 1..9, so the sum
--    between those two cells is always well-defined) -- no placement step
--    exists, so no risk of this bug class at all.
--
-- 3. `betweenlines.koplugin` itself turned out to be misclassified in the
--    audit doc's original sweep -- listed as both "no procedural generator,
--    out of scope" AND as a Tier 4 variant to audit. It has a real
--    generator (shares this same `puzzle_generator.lua` module) -- the
--    "out of scope" listing was simply wrong and has been corrected.
--
-- Exit code is non-zero if any check regresses.

package.preload["gettext"] = function() return function(s) return s end end

local ok = true

local function checkClueCount(name, boardKey, field, trials, floor)
    package.path = name .. ".koplugin/common/?.lua;" .. package.path
    package.loaded["grid_utils"] = nil
    package.loaded["sudoku_grid_utils"] = nil
    local mod   = loadfile(name .. ".koplugin/board.lua")()
    local Board = mod[boardKey]
    local min_count, shortfalls = math.huge, 0
    for i = 1, trials do
        math.randomseed(i * 104729)
        local b = Board:new({})
        b:generate("medium")
        local n = #b[field]
        if n < min_count then min_count = n end
        if n < floor then shortfalls = shortfalls + 1 end
    end
    local status = shortfalls == 0 and "OK" or "FAIL"
    if status == "FAIL" then ok = false end
    print(string.format("[%s] %s: min=%d over %d trials, %d below floor of %d",
        status, name, min_count, trials, shortfalls, floor))
end

local function checkNoDupInRegions(name, boardKey, regions, trials)
    package.path = name .. ".koplugin/common/?.lua;" .. package.path
    package.loaded["grid_utils"] = nil
    package.loaded["sudoku_grid_utils"] = nil
    local mod   = loadfile(name .. ".koplugin/board.lua")()
    local Board = mod[boardKey]
    local violations = 0
    for i = 1, trials do
        math.randomseed(i * 12345)
        local b = Board:new({})
        b:generate("medium")
        for _, region in ipairs(regions) do
            local seen = {}
            for _, cell in ipairs(region) do
                local v = b.solution[cell.r][cell.c]
                if seen[v] then violations = violations + 1 end
                seen[v] = true
            end
        end
    end
    local status = violations == 0 and "OK" or "FAIL"
    if status == "FAIL" then ok = false end
    print(string.format("[%s] %s: %d duplicate-in-region violations over %d trials",
        status, name, violations, trials))
end

local function rectRegions(defs)
    local out = {}
    for _, region in ipairs(defs) do
        local cells = {}
        for r = region.row_start, region.row_end do
            for c = region.col_start, region.col_end do
                cells[#cells + 1] = { r = r, c = c }
            end
        end
        out[#out + 1] = cells
    end
    return out
end

local function diagonalRegions(n)
    local d1, d2 = {}, {}
    for r = 1, n do
        d1[#d1 + 1] = { r = r, c = r }
        d2[#d2 + 1] = { r = r, c = n + 1 - r }
    end
    return { d1, d2 }
end

local WINDOWS = rectRegions({
    { row_start = 2, row_end = 4, col_start = 2, col_end = 4 },
    { row_start = 2, row_end = 4, col_start = 6, col_end = 8 },
    { row_start = 6, row_end = 8, col_start = 2, col_end = 4 },
    { row_start = 6, row_end = 8, col_start = 6, col_end = 8 },
})

checkClueCount("betweenlines", "BetweenLinesBoard", "lines", 300, 4)
checkClueCount("thermosudoku", "ThermoSudokuBoard", "thermos", 300, 5)
checkClueCount("arrowsudoku", "ArrowSudokuBoard", "arrows", 300, 5)

checkNoDupInRegions("windoku", "WindokuBoard", WINDOWS, 60)
checkNoDupInRegions("hypersudoku", "HyperSudokuBoard", WINDOWS, 60)
checkNoDupInRegions("sudokux", "SudokuXBoard", diagonalRegions(9), 60)

-- Sanity check independent of clue generation entirely: fill the working
-- grid with the board's own stored solution and confirm the plugin's own
-- win-check (isSolved(), via each variant's recalcConflicts()) actually
-- accepts it. This is the exact bug class hidato/numbrix/tatami had this
-- same audit (a broken win condition that rejects, or a rule check that
-- accepts, the wrong thing) -- cheap to check and worth guarding against
-- regressing, independent of anything else in this file.
local function checkWinConditionAcceptsSolution(name, boardKey, trials)
    package.path = name .. ".koplugin/common/?.lua;" .. package.path
    package.loaded["grid_utils"] = nil
    package.loaded["sudoku_grid_utils"] = nil
    local mod   = loadfile(name .. ".koplugin/board.lua")()
    local Board = mod[boardKey]
    local fails = 0
    for i = 1, trials do
        math.randomseed(i * 999983)
        local b = Board:new()
        b:generate("medium")
        for r = 1, b.n do
            for c = 1, b.n do
                b.user[r][c] = b.solution[r][c]
            end
        end
        b:recalcConflicts()
        if not b:isSolved() then fails = fails + 1 end
    end
    local status = fails == 0 and "OK" or "FAIL"
    if status == "FAIL" then ok = false end
    print(string.format("[%s] %s: %d/%d trials rejected the true solution as unsolved",
        status, name, fails, trials))
end

checkWinConditionAcceptsSolution("sudoku", "SudokuBoard", 20)
checkWinConditionAcceptsSolution("windoku", "WindokuBoard", 20)
checkWinConditionAcceptsSolution("hypersudoku", "HyperSudokuBoard", 20)
checkWinConditionAcceptsSolution("sudokux", "SudokuXBoard", 20)
checkWinConditionAcceptsSolution("arrowsudoku", "ArrowSudokuBoard", 20)
checkWinConditionAcceptsSolution("thermosudoku", "ThermoSudokuBoard", 20)
checkWinConditionAcceptsSolution("sandwichsudoku", "SandwichSudokuBoard", 20)
checkWinConditionAcceptsSolution("betweenlines", "BetweenLinesBoard", 20)

os.exit(ok and 0 or 1)
