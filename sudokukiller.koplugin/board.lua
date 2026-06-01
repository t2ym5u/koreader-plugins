local _ = require("gettext")

-- ---------------------------------------------------------------------------
-- Difficulty configurations
-- ---------------------------------------------------------------------------

local DEFAULT_DIFFICULTY = "medium"

-- Target cage count ranges per difficulty (9×9 = 81 cells)
local CAGE_COUNT_RANGES = {
    easy   = { min = 28, max = 32 },   -- avg ~2.5-2.9 cells/cage
    medium = { min = 22, max = 27 },   -- avg ~3.0-3.7 cells/cage
    hard   = { min = 16, max = 21 },   -- avg ~3.9-5.1 cells/cage
}

-- Maximum cage size per difficulty
local CAGE_MAX_SIZE = {
    easy   = 3,
    medium = 5,
    hard   = 6,
}

-- ---------------------------------------------------------------------------
-- Grid / note utility functions (unchanged from sudoku)
-- ---------------------------------------------------------------------------

local function emptyGrid(n)
    local grid = {}
    for r = 1, n do
        grid[r] = {}
        for c = 1, n do
            grid[r][c] = 0
        end
    end
    return grid
end

local function copyGrid(src, n)
    local grid = {}
    for r = 1, n do
        grid[r] = {}
        for c = 1, n do
            grid[r][c] = src[r][c]
        end
    end
    return grid
end

local function emptyNotes(n)
    local notes = {}
    for r = 1, n do
        notes[r] = {}
        for c = 1, n do
            notes[r][c] = {}
        end
    end
    return notes
end

local function emptyMarkerGrid(n)
    local grid = {}
    for r = 1, n do
        grid[r] = {}
        for c = 1, n do
            grid[r][c] = false
        end
    end
    return grid
end

local function cloneNoteCell(cell)
    if not cell then
        return nil
    end
    local copy = nil
    for digit = 1, 16 do
        if cell[digit] then
            copy = copy or {}
            copy[digit] = true
        end
    end
    return copy
end

local function copyNotes(src, n)
    local notes = {}
    for r = 1, n do
        notes[r] = {}
        for c = 1, n do
            local dest_cell = {}
            local source_cell = src and src[r] and src[r][c]
            if type(source_cell) == "table" then
                local had_array_values = false
                for _, digit in ipairs(source_cell) do
                    local d = tonumber(digit)
                    if d and d >= 1 and d <= n then
                        dest_cell[d] = true
                        had_array_values = true
                    end
                end
                if not had_array_values then
                    for digit, flag in pairs(source_cell) do
                        local d = tonumber(digit)
                        if d and d >= 1 and d <= n and flag then
                            dest_cell[d] = true
                        end
                    end
                end
            end
            notes[r][c] = dest_cell
        end
    end
    return notes
end

-- ---------------------------------------------------------------------------
-- Puzzle generator (unchanged from sudoku)
-- ---------------------------------------------------------------------------

local function shuffledDigits(n)
    local digits = {}
    for i = 1, n do digits[i] = i end
    for i = n, 2, -1 do
        local j = math.random(i)
        digits[i], digits[j] = digits[j], digits[i]
    end
    return digits
end

local function isValidPlacement(grid, row, col, value, n, box_rows, box_cols)
    for i = 1, n do
        if grid[row][i] == value or grid[i][col] == value then
            return false
        end
    end
    local br = math.floor((row - 1) / box_rows) * box_rows + 1
    local bc = math.floor((col - 1) / box_cols) * box_cols + 1
    for r = br, br + box_rows - 1 do
        for c = bc, bc + box_cols - 1 do
            if grid[r][c] == value then
                return false
            end
        end
    end
    return true
end

local function fillBoard(grid, cell, n, box_rows, box_cols)
    if cell > n * n then
        return true
    end
    local row = math.floor((cell - 1) / n) + 1
    local col = (cell - 1) % n + 1
    local numbers = shuffledDigits(n)
    for _, value in ipairs(numbers) do
        if isValidPlacement(grid, row, col, value, n, box_rows, box_cols) then
            grid[row][col] = value
            if fillBoard(grid, cell + 1, n, box_rows, box_cols) then
                return true
            end
            grid[row][col] = 0
        end
    end
    return false
end

local function generateSolvedBoard(n, box_rows, box_cols)
    local grid = emptyGrid(n)
    fillBoard(grid, 1, n, box_rows, box_cols)
    return grid
end

-- ---------------------------------------------------------------------------
-- Cage generator
-- ---------------------------------------------------------------------------

-- Returns (cages, cell_cage) where:
--   cages = list of { id, cells = {{r,c},...}, sum }
--   cell_cage[r][c] = cage_id
local function generateCages(solution, difficulty, n)
    local range = CAGE_COUNT_RANGES[difficulty] or CAGE_COUNT_RANGES.medium
    local target_count = math.random(range.min, range.max)
    local max_size = CAGE_MAX_SIZE[difficulty] or CAGE_MAX_SIZE.medium

    -- Assignment tracking
    local assigned = {}
    for r = 1, n do
        assigned[r] = {}
        for c = 1, n do assigned[r][c] = false end
    end

    -- Track number of unassigned cells
    local unassigned_count = n * n

    -- Orthogonal directions
    local dirs = { {-1, 0}, {1, 0}, {0, -1}, {0, 1} }

    -- Returns list of unassigned orthogonal neighbors
    local function unassignedNeighbors(r, c)
        local nb = {}
        for _, d in ipairs(dirs) do
            local nr, nc = r + d[1], c + d[2]
            if nr >= 1 and nr <= n and nc >= 1 and nc <= n and not assigned[nr][nc] then
                nb[#nb + 1] = { r = nr, c = nc }
            end
        end
        return nb
    end

    -- Randomized list of all cells (seeds for cage generation)
    local cell_list = {}
    for r = 1, n do
        for c = 1, n do cell_list[#cell_list + 1] = { r = r, c = c } end
    end
    for i = #cell_list, 2, -1 do
        local j = math.random(i)
        cell_list[i], cell_list[j] = cell_list[j], cell_list[i]
    end

    local cages = {}

    for _, seed in ipairs(cell_list) do
        -- Stop growing new cages once target is reached (rest become singletons)
        if #cages >= target_count then break end
        if assigned[seed.r][seed.c] then
            -- Skip already-assigned cells
        else
            local cage_id = #cages + 1
            local cage = {
                id = cage_id,
                cells = { { r = seed.r, c = seed.c } },
                sum = solution[seed.r][seed.c],
            }
            assigned[seed.r][seed.c] = true
            unassigned_count = unassigned_count - 1

            -- Compute a safe maximum size to avoid starving later cages
            -- remaining_cages: how many more cages we still need to create after this one
            local remaining_cages = target_count - cage_id
            local safe_max
            if remaining_cages > 0 then
                safe_max = math.max(1, unassigned_count - remaining_cages)
            else
                safe_max = unassigned_count
            end

            local target_size
            if safe_max < 2 then
                target_size = 1
            else
                target_size = math.random(2, math.min(max_size, safe_max))
            end

            -- Grow cage via random flood-fill
            local frontier = unassignedNeighbors(seed.r, seed.c)

            while #cage.cells < target_size and #frontier > 0 do
                -- Pick a random cell from the frontier
                local idx = math.random(#frontier)
                local candidate = frontier[idx]
                table.remove(frontier, idx)

                if not assigned[candidate.r][candidate.c] then
                    -- Add candidate to cage
                    cage.cells[#cage.cells + 1] = candidate
                    cage.sum = cage.sum + solution[candidate.r][candidate.c]
                    assigned[candidate.r][candidate.c] = true
                    unassigned_count = unassigned_count - 1

                    -- Enqueue new unassigned neighbors (no duplicates)
                    for _, nb in ipairs(unassignedNeighbors(candidate.r, candidate.c)) do
                        local dup = false
                        for _, f in ipairs(frontier) do
                            if f.r == nb.r and f.c == nb.c then
                                dup = true
                                break
                            end
                        end
                        if not dup then
                            frontier[#frontier + 1] = nb
                        end
                    end
                end
            end

            cages[#cages + 1] = cage
        end
    end

    -- Any remaining unassigned cells become singleton cages
    for r = 1, n do
        for c = 1, n do
            if not assigned[r][c] then
                local cage_id = #cages + 1
                cages[cage_id] = {
                    id = cage_id,
                    cells = { { r = r, c = c } },
                    sum = solution[r][c],
                }
                assigned[r][c] = true
            end
        end
    end

    -- Build cell_cage lookup table
    local cell_cage = {}
    for r = 1, n do
        cell_cage[r] = {}
        for c = 1, n do cell_cage[r][c] = 0 end
    end
    for _, cage in ipairs(cages) do
        for _, cell in ipairs(cage.cells) do
            cell_cage[cell.r][cell.c] = cage.id
        end
    end

    return cages, cell_cage
end

-- ---------------------------------------------------------------------------
-- KillerSudokuBoard — game state
-- ---------------------------------------------------------------------------

local KillerSudokuBoard = {}
KillerSudokuBoard.__index = KillerSudokuBoard

function KillerSudokuBoard:new()
    local n = 9
    local board = {
        n         = n,
        box_rows  = 3,
        box_cols  = 3,
        grid_id   = "9x9",
        -- No puzzle grid — killer sudoku has no pre-filled cells
        solution  = emptyGrid(n),
        user      = emptyGrid(n),
        conflicts = emptyGrid(n),
        notes     = emptyNotes(n),
        wrong_marks = emptyMarkerGrid(n),
        selected  = { row = 1, col = 1 },
        difficulty = DEFAULT_DIFFICULTY,
        reveal_solution = false,
        undo_stack = {},
        -- Killer-specific
        cages     = {},
        cell_cage = emptyGrid(n),
    }
    setmetatable(board, self)
    board:recalcConflicts()
    return board
end

function KillerSudokuBoard:serialize()
    local n = self.n
    return {
        n           = n,
        box_rows    = self.box_rows,
        box_cols    = self.box_cols,
        grid_id     = self.grid_id,
        solution    = copyGrid(self.solution, n),
        user        = copyGrid(self.user, n),
        notes       = copyNotes(self.notes, n),
        wrong_marks = copyGrid(self.wrong_marks, n),
        selected    = { row = self.selected.row, col = self.selected.col },
        difficulty  = self.difficulty,
        reveal_solution = self.reveal_solution,
        cages       = self.cages,
        cell_cage   = copyGrid(self.cell_cage, n),
    }
end

function KillerSudokuBoard:load(state)
    if not state or not state.solution or not state.user or not state.cages then
        return false
    end
    local n = state.n or 9
    self.n          = n
    self.box_rows   = state.box_rows or 3
    self.box_cols   = state.box_cols or 3
    self.grid_id    = state.grid_id or "9x9"
    self.solution   = copyGrid(state.solution, n)
    self.user       = copyGrid(state.user, n)
    self.notes      = copyNotes(state.notes, n)
    self.wrong_marks = state.wrong_marks and copyGrid(state.wrong_marks, n) or emptyMarkerGrid(n)
    self.conflicts  = emptyGrid(n)
    self.difficulty = state.difficulty or DEFAULT_DIFFICULTY
    self.undo_stack = {}
    self.reveal_solution = state.reveal_solution or false
    self.cages      = state.cages or {}
    self.cell_cage  = state.cell_cage and copyGrid(state.cell_cage, n) or emptyGrid(n)
    if state.selected then
        self.selected = {
            row = math.max(1, math.min(n, state.selected.row or 1)),
            col = math.max(1, math.min(n, state.selected.col or 1)),
        }
    else
        self.selected = { row = 1, col = 1 }
    end
    self:recalcConflicts()
    return true
end

function KillerSudokuBoard:generate(difficulty)
    self.difficulty = difficulty or self.difficulty or DEFAULT_DIFFICULTY
    local n, box_rows, box_cols = self.n, self.box_rows, self.box_cols
    local solution = generateSolvedBoard(n, box_rows, box_cols)
    local cages, cell_cage = generateCages(solution, self.difficulty, n)
    self.solution   = solution
    self.cages      = cages
    self.cell_cage  = cell_cage
    self.user       = emptyGrid(n)
    self.notes      = emptyNotes(n)
    self.wrong_marks = emptyMarkerGrid(n)
    self.selected   = { row = 1, col = 1 }
    self.reveal_solution = false
    self.undo_stack = {}
    self:recalcConflicts()
end

-- ---------------------------------------------------------------------------
-- Cage helpers
-- ---------------------------------------------------------------------------

-- Returns the cage table for a given cell, or nil
function KillerSudokuBoard:getCage(row, col)
    local cage_id = self.cell_cage[row] and self.cell_cage[row][col] or 0
    if cage_id == 0 then return nil end
    return self.cages[cage_id]
end

-- Returns the "label cell" of a cage: topmost-leftmost cell (min reading-order index)
function KillerSudokuBoard:getCageLabelCell(cage)
    local best = nil
    local best_idx = math.huge
    for _, cell in ipairs(cage.cells) do
        local idx = (cell.r - 1) * self.n + (cell.c - 1)
        if idx < best_idx then
            best_idx = idx
            best = cell
        end
    end
    return best
end

-- Returns true if the edge between (r1,c1) and (r2,c2) is a cage boundary
-- and is NOT a box boundary (box boundaries are already shown as thick lines)
function KillerSudokuBoard:isCageBoundary(r1, c1, r2, c2)
    local id1 = self.cell_cage[r1] and self.cell_cage[r1][c1] or 0
    local id2 = self.cell_cage[r2] and self.cell_cage[r2][c2] or 0
    if id1 == id2 then return false end
    -- Skip edges that are box boundaries (they already show as thick solid lines)
    if r1 ~= r2 then
        -- Horizontal edge between row r1 and r2=r1+1: box boundary if r1 % box_rows == 0
        return (r1 % self.box_rows) ~= 0
    else
        -- Vertical edge between col c1 and c2=c1+1: box boundary if c1 % box_cols == 0
        return (c1 % self.box_cols) ~= 0
    end
end

-- ---------------------------------------------------------------------------
-- Game state accessors
-- ---------------------------------------------------------------------------

-- Killer sudoku has no pre-filled cells
function KillerSudokuBoard:isGiven()
    return false
end

function KillerSudokuBoard:getWorkingValue(row, col)
    return self.user[row][col]
end

function KillerSudokuBoard:getDisplayValue(row, col)
    if self.reveal_solution then
        return self.solution[row][col], false
    end
    local value = self.user[row][col]
    if value == 0 then return nil end
    return value, false
end

function KillerSudokuBoard:isConflict(row, col)
    return self.conflicts[row][col]
end

function KillerSudokuBoard:isShowingSolution()
    return self.reveal_solution
end

function KillerSudokuBoard:toggleSolution()
    self.reveal_solution = not self.reveal_solution
end

function KillerSudokuBoard:setSelection(row, col)
    local n = self.n
    self.selected = { row = math.max(1, math.min(n, row)), col = math.max(1, math.min(n, col)) }
end

function KillerSudokuBoard:getSelection()
    return self.selected.row, self.selected.col
end

function KillerSudokuBoard:getRemainingCells()
    local remaining = 0
    for r = 1, self.n do
        for c = 1, self.n do
            if self.user[r][c] == 0 then
                remaining = remaining + 1
            end
        end
    end
    return remaining
end

function KillerSudokuBoard:countDigit(digit)
    local count = 0
    for r = 1, self.n do
        for c = 1, self.n do
            if self.user[r][c] == digit then
                count = count + 1
            end
        end
    end
    return count
end

function KillerSudokuBoard:canUndo()
    return self.undo_stack[1] ~= nil
end

-- ---------------------------------------------------------------------------
-- Conflict detection
-- ---------------------------------------------------------------------------

local function ensureGridValues(grid, n)
    for r = 1, n do
        grid[r] = grid[r] or {}
        for c = 1, n do
            grid[r][c] = grid[r][c] or 0
        end
    end
end

function KillerSudokuBoard:recalcConflicts()
    local n, box_rows, box_cols = self.n, self.box_rows, self.box_cols
    ensureGridValues(self.conflicts, n)
    for r = 1, n do
        for c = 1, n do
            self.conflicts[r][c] = false
        end
    end

    local function markConflicts(cells)
        local map = {}
        for _, cell in ipairs(cells) do
            if cell.value ~= 0 then
                map[cell.value] = map[cell.value] or {}
                table.insert(map[cell.value], cell)
            end
        end
        for _, positions in pairs(map) do
            if #positions > 1 then
                for _, pos in ipairs(positions) do
                    self.conflicts[pos.row][pos.col] = true
                end
            end
        end
    end

    -- Standard row conflicts
    for r = 1, n do
        local cells = {}
        for c = 1, n do
            cells[#cells + 1] = { row = r, col = c, value = self:getWorkingValue(r, c) }
        end
        markConflicts(cells)
    end

    -- Standard column conflicts
    for c = 1, n do
        local cells = {}
        for r = 1, n do
            cells[#cells + 1] = { row = r, col = c, value = self:getWorkingValue(r, c) }
        end
        markConflicts(cells)
    end

    -- Standard box conflicts
    local num_box_rows = math.floor(n / box_rows)
    local num_box_cols = math.floor(n / box_cols)
    for box_r = 0, num_box_rows - 1 do
        for box_c = 0, num_box_cols - 1 do
            local cells = {}
            for r = 1, box_rows do
                for c = 1, box_cols do
                    local row = box_r * box_rows + r
                    local col = box_c * box_cols + c
                    cells[#cells + 1] = { row = row, col = col, value = self:getWorkingValue(row, col) }
                end
            end
            markConflicts(cells)
        end
    end

    -- Cage duplicate conflicts
    for _, cage in ipairs(self.cages) do
        local seen = {}
        for _, cell in ipairs(cage.cells) do
            local v = self:getWorkingValue(cell.r, cell.c)
            if v ~= 0 then
                if seen[v] then
                    -- Mark both occurrences as conflicts
                    self.conflicts[cell.r][cell.c] = true
                    if type(seen[v]) == "table" then
                        self.conflicts[seen[v].r][seen[v].c] = true
                        seen[v] = true  -- sentinel: first cell already marked
                    end
                else
                    seen[v] = cell
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Notes management
-- ---------------------------------------------------------------------------

function KillerSudokuBoard:clearNotes(row, col)
    if self.notes[row] and self.notes[row][col] then
        self.notes[row][col] = {}
    end
end

function KillerSudokuBoard:getCellNotes(row, col)
    local cell = self.notes[row] and self.notes[row][col]
    if not cell then return nil end
    for digit = 1, self.n do
        if cell[digit] then return cell end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Wrong marks
-- ---------------------------------------------------------------------------

function KillerSudokuBoard:clearWrongMarks()
    for r = 1, self.n do
        for c = 1, self.n do
            self.wrong_marks[r][c] = false
        end
    end
end

function KillerSudokuBoard:clearWrongMark(row, col)
    if self.wrong_marks[row] then
        self.wrong_marks[row][col] = false
    end
end

function KillerSudokuBoard:hasWrongMark(row, col)
    return self.wrong_marks[row] and self.wrong_marks[row][col] or false
end

function KillerSudokuBoard:updateWrongMarks()
    self:clearWrongMarks()
    local has_wrong = false
    for r = 1, self.n do
        for c = 1, self.n do
            local value = self.user[r][c]
            if value ~= 0 and value ~= self.solution[r][c] then
                self.wrong_marks[r][c] = true
                has_wrong = true
            end
        end
    end
    return has_wrong
end

-- ---------------------------------------------------------------------------
-- Undo
-- ---------------------------------------------------------------------------

function KillerSudokuBoard:pushUndo(entry)
    if entry then
        self.undo_stack[#self.undo_stack + 1] = entry
    end
end

function KillerSudokuBoard:undo()
    local entry = table.remove(self.undo_stack)
    if not entry then
        return false, _("Nothing to undo.")
    end
    local row, col = entry.row, entry.col
    if entry.type == "value" then
        self.user[row][col] = entry.prev_value or 0
        self.notes[row][col] = cloneNoteCell(entry.prev_notes) or {}
        self:setSelection(row, col)
        self:recalcConflicts()
        self:clearWrongMark(row, col)
    elseif entry.type == "notes" then
        self.notes[row][col] = cloneNoteCell(entry.prev_notes) or {}
        self:setSelection(row, col)
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Cell value / note editing
-- ---------------------------------------------------------------------------

function KillerSudokuBoard:setValue(value)
    if self.reveal_solution then
        return false, _("Hide result to keep playing.")
    end
    local row, col = self:getSelection()
    local prev_value = self.user[row][col]
    local prev_notes = cloneNoteCell(self.notes[row][col])
    local new_value = value or 0

    if prev_value == new_value and not prev_notes then
        if not value then
            return false, _("Cell already empty.")
        end
        return true
    end

    self.user[row][col] = new_value
    self:clearNotes(row, col)
    self:clearWrongMark(row, col)
    self:recalcConflicts()
    if prev_value ~= new_value or prev_notes then
        self:pushUndo{
            type = "value",
            row = row,
            col = col,
            prev_value = prev_value,
            prev_notes = prev_notes,
        }
    end
    return true
end

function KillerSudokuBoard:clearSelection()
    return self:setValue(nil)
end

function KillerSudokuBoard:toggleNoteDigit(value)
    if self.reveal_solution then
        return false, _("Hide result to keep playing.")
    end
    local row, col = self:getSelection()
    if self.user[row][col] ~= 0 then
        return false, _("Clear the cell before adding notes.")
    end
    self.notes[row][col] = self.notes[row][col] or {}
    local prev_cell = cloneNoteCell(self.notes[row][col])
    local was_set = self.notes[row][col][value] and true or false
    if was_set then
        self.notes[row][col][value] = nil
    else
        self.notes[row][col][value] = true
    end
    local now_set = self.notes[row][col][value] and true or false
    if was_set == now_set then
        return true
    end
    self:pushUndo{
        type = "notes",
        row = row,
        col = col,
        prev_notes = prev_cell,
    }
    return true
end

-- ---------------------------------------------------------------------------
-- Win condition
-- ---------------------------------------------------------------------------

function KillerSudokuBoard:isSolved()
    if self.reveal_solution then
        return false
    end
    -- All cells must match the solution and have no conflicts
    -- (The solution was built first; matching it guarantees all cage sum constraints)
    for r = 1, self.n do
        for c = 1, self.n do
            if self.user[r][c] ~= self.solution[r][c] or self.conflicts[r][c] then
                return false
            end
        end
    end
    return true
end

return {
    KillerSudokuBoard = KillerSudokuBoard,
    DEFAULT_DIFFICULTY = DEFAULT_DIFFICULTY,
    CAGE_COUNT_RANGES = CAGE_COUNT_RANGES,
}
