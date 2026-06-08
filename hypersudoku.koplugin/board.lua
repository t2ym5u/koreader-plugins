local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire_common(name)
    local key = _dir .. "common/" .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. "common/" .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local grid_utils       = lrequire_common("grid_utils")
local puzzle_generator = lrequire_common("puzzle_generator")
local BaseBoard        = lrequire_common("base_board")

local emptyGrid        = grid_utils.emptyGrid
local emptyNotes       = grid_utils.emptyNotes
local emptyMarkerGrid  = grid_utils.emptyMarkerGrid
local copyGrid         = grid_utils.copyGrid
local copyNotes        = grid_utils.copyNotes

local generateSolvedBoard = puzzle_generator.generateSolvedBoard
local createPuzzle        = puzzle_generator.createPuzzle

local DEFAULT_DIFFICULTY = "medium"

local HYPER_REGIONS = {
    { row_start = 2, row_end = 4, col_start = 2, col_end = 4 },
    { row_start = 2, row_end = 4, col_start = 6, col_end = 8 },
    { row_start = 6, row_end = 8, col_start = 2, col_end = 4 },
    { row_start = 6, row_end = 8, col_start = 6, col_end = 8 },
}

local HyperSudokuBoard = setmetatable({}, { __index = BaseBoard })
HyperSudokuBoard.__index = HyperSudokuBoard

function HyperSudokuBoard:new()
    local n = 9
    local board = {
        n               = n,
        box_rows        = 3,
        box_cols        = 3,
        grid_id         = "9x9",
        puzzle          = emptyGrid(n),
        solution        = emptyGrid(n),
        user            = emptyGrid(n),
        conflicts       = emptyGrid(n),
        notes           = emptyNotes(n),
        wrong_marks     = emptyMarkerGrid(n),
        selected        = { row = 1, col = 1 },
        difficulty      = DEFAULT_DIFFICULTY,
        reveal_solution = false,
        undo_stack      = {},
    }
    setmetatable(board, self)
    board:recalcConflicts()
    return board
end

function HyperSudokuBoard:recalcConflicts()
    BaseBoard.recalcConflicts(self)
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
    for _, region in ipairs(HYPER_REGIONS) do
        local cells = {}
        for r = region.row_start, region.row_end do
            for c = region.col_start, region.col_end do
                cells[#cells + 1] = { row = r, col = c, value = self:getWorkingValue(r, c) }
            end
        end
        markConflicts(cells)
    end
end

function HyperSudokuBoard:serialize()
    local n = self.n
    return {
        n               = n,
        box_rows        = self.box_rows,
        box_cols        = self.box_cols,
        grid_id         = self.grid_id,
        puzzle          = copyGrid(self.puzzle, n),
        solution        = copyGrid(self.solution, n),
        user            = copyGrid(self.user, n),
        notes           = copyNotes(self.notes, n),
        wrong_marks     = copyGrid(self.wrong_marks, n),
        selected        = { row = self.selected.row, col = self.selected.col },
        difficulty      = self.difficulty,
        reveal_solution = self.reveal_solution,
    }
end

function HyperSudokuBoard:load(state)
    if not state or not state.puzzle or not state.solution or not state.user then
        return false
    end
    self.n        = 9
    self.box_rows = 3
    self.box_cols = 3
    self.grid_id  = "9x9"
    local n = self.n
    self.puzzle      = copyGrid(state.puzzle, n)
    self.solution    = copyGrid(state.solution, n)
    self.user        = copyGrid(state.user, n)
    self.notes       = copyNotes(state.notes, n)
    self.wrong_marks = state.wrong_marks and copyGrid(state.wrong_marks, n) or emptyMarkerGrid(n)
    self.conflicts   = emptyGrid(n)
    self.difficulty  = state.difficulty or DEFAULT_DIFFICULTY
    self.undo_stack  = {}
    if state.selected then
        self.selected = {
            row = math.max(1, math.min(n, state.selected.row or 1)),
            col = math.max(1, math.min(n, state.selected.col or 1)),
        }
    else
        self.selected = { row = 1, col = 1 }
    end
    self.reveal_solution = state.reveal_solution or false
    self:recalcConflicts()
    return true
end

function HyperSudokuBoard:generate(difficulty)
    self.difficulty = difficulty or self.difficulty or DEFAULT_DIFFICULTY
    local n, box_rows, box_cols = self.n, self.box_rows, self.box_cols
    local solution = generateSolvedBoard(n, box_rows, box_cols)
    local puzzle   = createPuzzle(solution, self.difficulty, n, box_rows, box_cols)
    self.puzzle          = puzzle
    self.solution        = solution
    self.user            = emptyGrid(n)
    self.notes           = emptyNotes(n)
    self.wrong_marks     = emptyMarkerGrid(n)
    self.selected        = { row = 1, col = 1 }
    self.reveal_solution = false
    self.undo_stack      = {}
    self:recalcConflicts()
end

function HyperSudokuBoard:isGiven(row, col)
    return self.puzzle[row][col] ~= 0
end

function HyperSudokuBoard:getWorkingValue(row, col)
    local given = self.puzzle[row][col]
    if given ~= 0 then return given end
    return self.user[row][col]
end

function HyperSudokuBoard:getDisplayValue(row, col)
    if self.reveal_solution then
        return self.solution[row][col], self:isGiven(row, col)
    end
    if self:isGiven(row, col) then
        return self.puzzle[row][col], true
    end
    local value = self.user[row][col]
    if value == 0 then return nil end
    return value, false
end

function HyperSudokuBoard:clearUndoHistory()
    self.undo_stack = {}
end

function HyperSudokuBoard:isConflict(row, col)
    return self.conflicts[row][col]
end

return {
    HyperSudokuBoard = HyperSudokuBoard,
    DEFAULT_DIFFICULTY = DEFAULT_DIFFICULTY,
    HYPER_REGIONS    = HYPER_REGIONS,
}
