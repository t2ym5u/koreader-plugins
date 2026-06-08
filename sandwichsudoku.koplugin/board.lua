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

-- ---------------------------------------------------------------------------
-- Grid config (9x9 only)
-- ---------------------------------------------------------------------------

local GRID_CONFIGS = {
    { id = "9x9", n = 9, box_rows = 3, box_cols = 3, label = "9\xC3\x979" },
}

local function getGridConfig(id)
    return GRID_CONFIGS[1]
end

local DEFAULT_DIFFICULTY = "medium"

-- ---------------------------------------------------------------------------
-- Sandwich clue computation
-- ---------------------------------------------------------------------------

-- For a given row/col array of values (1..9), compute the sandwich sum:
-- the sum of digits strictly between the positions of 1 and 9.
local function computeSandwichSum(values, n)
    local pos1, pos9
    for i = 1, n do
        if values[i] == 1 then pos1 = i end
        if values[i] == 9 then pos9 = i end
    end
    if not pos1 or not pos9 then return 0 end
    local lo = math.min(pos1, pos9)
    local hi = math.max(pos1, pos9)
    local sum = 0
    for i = lo + 1, hi - 1 do
        sum = sum + values[i]
    end
    return sum
end

local function computeAllClues(solution, n)
    local row_clues = {}
    local col_clues = {}
    for r = 1, n do
        local vals = {}
        for c = 1, n do vals[c] = solution[r][c] end
        row_clues[r] = computeSandwichSum(vals, n)
    end
    for c = 1, n do
        local vals = {}
        for r = 1, n do vals[r] = solution[r][c] end
        col_clues[c] = computeSandwichSum(vals, n)
    end
    return row_clues, col_clues
end

-- ---------------------------------------------------------------------------
-- SandwichSudokuBoard
-- ---------------------------------------------------------------------------

local SandwichSudokuBoard = setmetatable({}, { __index = BaseBoard })
SandwichSudokuBoard.__index = SandwichSudokuBoard

function SandwichSudokuBoard:new(config)
    local n        = 9
    local box_rows = 3
    local box_cols = 3
    local board = {
        n               = n,
        box_rows        = box_rows,
        box_cols        = box_cols,
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
        row_clues       = {},
        col_clues       = {},
    }
    setmetatable(board, self)
    board:recalcConflicts()
    return board
end

function SandwichSudokuBoard:serialize()
    local n = self.n
    -- Copy clues
    local row_clues = {}
    local col_clues = {}
    for i = 1, n do
        row_clues[i] = self.row_clues[i] or 0
        col_clues[i] = self.col_clues[i] or 0
    end
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
        row_clues       = row_clues,
        col_clues       = col_clues,
    }
end

function SandwichSudokuBoard:load(state)
    if not state or not state.puzzle or not state.solution or not state.user then
        return false
    end
    self.n        = state.n        or 9
    self.box_rows = state.box_rows or 3
    self.box_cols = state.box_cols or 3
    self.grid_id  = state.grid_id  or "9x9"
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
    -- Load clues
    self.row_clues = {}
    self.col_clues = {}
    for i = 1, n do
        self.row_clues[i] = state.row_clues and state.row_clues[i] or 0
        self.col_clues[i] = state.col_clues and state.col_clues[i] or 0
    end
    self:recalcConflicts()
    return true
end

function SandwichSudokuBoard:generate(difficulty)
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
    self.row_clues, self.col_clues = computeAllClues(solution, n)
    self:recalcConflicts()
end

function SandwichSudokuBoard:isGiven(row, col)
    return self.puzzle[row][col] ~= 0
end

function SandwichSudokuBoard:getWorkingValue(row, col)
    local given = self.puzzle[row][col]
    if given ~= 0 then return given end
    return self.user[row][col]
end

function SandwichSudokuBoard:getDisplayValue(row, col)
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

function SandwichSudokuBoard:recalcConflicts()
    -- Call parent for row/col/box conflicts
    BaseBoard.recalcConflicts(self)
    local n = self.n
    -- Check sandwich sum violations for rows
    for r = 1, n do
        -- Check if all cells in this row are filled
        local all_filled = true
        local vals = {}
        for c = 1, n do
            local v = self:getWorkingValue(r, c)
            if v == 0 then
                all_filled = false
                break
            end
            vals[c] = v
        end
        if all_filled then
            local actual = computeSandwichSum(vals, n)
            local expected = self.row_clues[r] or 0
            if actual ~= expected then
                -- Mark the sandwich cells (between 1 and 9) as conflicts
                local pos1, pos9
                for c = 1, n do
                    if vals[c] == 1 then pos1 = c end
                    if vals[c] == 9 then pos9 = c end
                end
                if pos1 and pos9 then
                    local lo = math.min(pos1, pos9)
                    local hi = math.max(pos1, pos9)
                    for c = lo, hi do
                        self.conflicts[r][c] = true
                    end
                end
            end
        end
    end
    -- Check sandwich sum violations for columns
    for c = 1, n do
        local all_filled = true
        local vals = {}
        for r = 1, n do
            local v = self:getWorkingValue(r, c)
            if v == 0 then
                all_filled = false
                break
            end
            vals[r] = v
        end
        if all_filled then
            local actual = computeSandwichSum(vals, n)
            local expected = self.col_clues[c] or 0
            if actual ~= expected then
                local pos1, pos9
                for r = 1, n do
                    if vals[r] == 1 then pos1 = r end
                    if vals[r] == 9 then pos9 = r end
                end
                if pos1 and pos9 then
                    local lo = math.min(pos1, pos9)
                    local hi = math.max(pos1, pos9)
                    for r = lo, hi do
                        self.conflicts[r][c] = true
                    end
                end
            end
        end
    end
end

function SandwichSudokuBoard:isConflict(row, col)
    return self.conflicts[row][col]
end

function SandwichSudokuBoard:clearUndoHistory()
    self.undo_stack = {}
end

return {
    SandwichSudokuBoard = SandwichSudokuBoard,
    DEFAULT_DIFFICULTY  = DEFAULT_DIFFICULTY,
    GRID_CONFIGS        = GRID_CONFIGS,
    getGridConfig       = getGridConfig,
}
