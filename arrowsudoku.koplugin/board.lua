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
-- Arrow placement helpers
-- ---------------------------------------------------------------------------

-- Place 5-8 arrows on the solution grid.
-- Each arrow: { src={r,c}, cells={{r,c},...}, value=N }
-- src is the tail cell (shows the sum), cells are the path cells (not including src).
-- value = sum of solution values along cells.
local function placeArrows(solution)
    local n = 9
    local directions = {
        { dr = 0,  dc = 1  },  -- right
        { dr = 1,  dc = 0  },  -- down
        { dr = 1,  dc = 1  },  -- diag down-right
        { dr = 1,  dc = -1 },  -- diag down-left
    }

    local arrows   = {}
    local cell_used = {}

    local function cellKey(r, c) return r * 100 + c end

    local target_count = math.random(5, 8)
    local attempts     = 0
    local max_attempts = 300

    while #arrows < target_count and attempts < max_attempts do
        attempts = attempts + 1

        -- Pick a random source (tail) cell
        local sr = math.random(1, n)
        local sc = math.random(1, n)
        if cell_used[cellKey(sr, sc)] then goto continue end

        -- Pick a random direction and length for the path (2-3 cells, not including src)
        local dir    = directions[math.random(#directions)]
        local length = math.random(2, 3)

        local path = {}
        local valid = true
        for i = 1, length do
            local nr = sr + dir.dr * i
            local nc = sc + dir.dc * i
            if nr < 1 or nr > n or nc < 1 or nc > n then
                valid = false
                break
            end
            if cell_used[cellKey(nr, nc)] then
                valid = false
                break
            end
            path[#path + 1] = { r = nr, c = nc }
        end
        if not valid or #path < 2 then goto continue end

        -- Compute sum of solution values along path
        local total = 0
        for _, cell in ipairs(path) do
            total = total + solution[cell.r][cell.c]
        end

        -- Mark cells as used
        cell_used[cellKey(sr, sc)] = true
        for _, cell in ipairs(path) do
            cell_used[cellKey(cell.r, cell.c)] = true
        end

        arrows[#arrows + 1] = {
            src   = { r = sr, c = sc },
            cells = path,
            value = total,
        }

        ::continue::
    end

    return arrows
end

-- ---------------------------------------------------------------------------
-- ArrowSudokuBoard
-- ---------------------------------------------------------------------------

local ArrowSudokuBoard = setmetatable({}, { __index = BaseBoard })
ArrowSudokuBoard.__index = ArrowSudokuBoard

function ArrowSudokuBoard:new(config)
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
        arrows          = {},
    }
    setmetatable(board, self)
    board:recalcConflicts()
    return board
end

function ArrowSudokuBoard:serialize()
    local n = self.n
    -- Serialize arrows
    local arrows_data = {}
    for i, arrow in ipairs(self.arrows) do
        local cells_data = {}
        for j, cell in ipairs(arrow.cells) do
            cells_data[j] = { r = cell.r, c = cell.c }
        end
        arrows_data[i] = {
            src   = { r = arrow.src.r, c = arrow.src.c },
            cells = cells_data,
            value = arrow.value,
        }
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
        arrows          = arrows_data,
    }
end

function ArrowSudokuBoard:load(state)
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
    -- Load arrows
    self.arrows = {}
    if state.arrows then
        for i, ad in ipairs(state.arrows) do
            local cells = {}
            for j, cell in ipairs(ad.cells) do
                cells[j] = { r = cell.r, c = cell.c }
            end
            self.arrows[i] = {
                src   = { r = ad.src.r, c = ad.src.c },
                cells = cells,
                value = ad.value,
            }
        end
    end
    self:recalcConflicts()
    return true
end

function ArrowSudokuBoard:generate(difficulty)
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
    self.arrows          = placeArrows(solution)
    self:recalcConflicts()
end

function ArrowSudokuBoard:isGiven(row, col)
    return self.puzzle[row][col] ~= 0
end

function ArrowSudokuBoard:getWorkingValue(row, col)
    local given = self.puzzle[row][col]
    if given ~= 0 then return given end
    return self.user[row][col]
end

function ArrowSudokuBoard:getDisplayValue(row, col)
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

function ArrowSudokuBoard:recalcConflicts()
    -- Call parent for row/col/box conflicts
    BaseBoard.recalcConflicts(self)
    -- Check arrow sum violations: if all cells in an arrow path are filled,
    -- verify sum equals arrow.value; if not, mark those cells as conflicts.
    for _, arrow in ipairs(self.arrows or {}) do
        local path_cells = arrow.cells
        -- Check if all path cells are filled
        local all_filled = true
        local actual_sum = 0
        for _, cell in ipairs(path_cells) do
            local v = self:getWorkingValue(cell.r, cell.c)
            if v == 0 then
                all_filled = false
                break
            end
            actual_sum = actual_sum + v
        end
        if all_filled and actual_sum ~= arrow.value then
            -- Mark all path cells as conflicts
            for _, cell in ipairs(path_cells) do
                self.conflicts[cell.r][cell.c] = true
            end
            -- Also mark the source cell
            local src = arrow.src
            self.conflicts[src.r][src.c] = true
        end
    end
end

function ArrowSudokuBoard:isConflict(row, col)
    return self.conflicts[row][col]
end

function ArrowSudokuBoard:clearUndoHistory()
    self.undo_stack = {}
end

return {
    ArrowSudokuBoard   = ArrowSudokuBoard,
    DEFAULT_DIFFICULTY = DEFAULT_DIFFICULTY,
    GRID_CONFIGS       = GRID_CONFIGS,
    getGridConfig      = getGridConfig,
}
