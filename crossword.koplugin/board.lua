local UndoStack = require("undo_stack")

local PUZZLES = require("puzzles")

-- ---------------------------------------------------------------------------
-- Helper: assign numbers to grid cells
-- ---------------------------------------------------------------------------

local function buildNumberedGrid(raw_grid)
    local rows = #raw_grid
    local cols = 0
    for _, row in ipairs(raw_grid) do
        if #row > cols then cols = #row end
    end

    -- Normalize to 2D array
    local grid = {}
    for r = 1, rows do
        grid[r] = {}
        for c = 1, cols do
            local ch = raw_grid[r]:sub(c, c)
            if ch == "" then ch = "#" end
            grid[r][c] = ch
        end
    end

    -- Assign cell numbers
    local numbers = {}   -- numbers[r][c] = number or nil
    for r = 1, rows do
        numbers[r] = {}
    end
    local num = 1
    local across_starts = {}  -- num → {r, c, len}
    local down_starts   = {}  -- num → {r, c, len}

    for r = 1, rows do
        for c = 1, cols do
            if grid[r][c] ~= "#" then
                local starts_across = (c == 1 or grid[r][c-1] == "#")
                    and (c + 1 <= cols and grid[r][c+1] ~= "#")
                local starts_down   = (r == 1 or grid[r-1][c] == "#")
                    and (r + 1 <= rows and grid[r+1][c] ~= "#")
                if starts_across or starts_down then
                    numbers[r][c] = num
                    if starts_across then
                        -- Measure length
                        local len = 0
                        local nc  = c
                        while nc <= cols and grid[r][nc] ~= "#" do
                            len = len + 1
                            nc  = nc + 1
                        end
                        across_starts[num] = { r = r, c = c, len = len }
                    end
                    if starts_down then
                        local len = 0
                        local nr  = r
                        while nr <= rows and grid[nr][c] ~= "#" do
                            len = len + 1
                            nr  = nr + 1
                        end
                        down_starts[num] = { r = r, c = c, len = len }
                    end
                    num = num + 1
                end
            end
        end
    end

    return grid, numbers, rows, cols, across_starts, down_starts
end

-- ---------------------------------------------------------------------------
-- CrosswordBoard
-- ---------------------------------------------------------------------------

local CrosswordBoard = {}
CrosswordBoard.__index = CrosswordBoard

function CrosswordBoard:new(opts)
    opts = opts or {}
    local obj = setmetatable({
        puzzle_idx   = opts.puzzle_idx or 1,
        grid         = nil,   -- solution letters (uppercase), '#' = black
        user         = nil,   -- user letters
        numbers      = nil,   -- cell numbers
        rows         = 0,
        cols         = 0,
        across_starts = nil,
        down_starts   = nil,
        clues_across  = nil,
        clues_down    = nil,
        title         = "",
        sel_r         = 1,
        sel_c         = 1,
        direction     = "across",  -- or "down"
        won           = false,
        undo          = UndoStack:new{ max_size = 500 },
    }, self)
    obj:loadPuzzle(obj.puzzle_idx)
    return obj
end

function CrosswordBoard:loadPuzzle(idx)
    idx = ((idx - 1) % #PUZZLES) + 1
    self.puzzle_idx = idx
    local puzzle = PUZZLES[idx]

    local grid, numbers, rows, cols, across_starts, down_starts =
        buildNumberedGrid(puzzle.grid)

    self.grid          = grid
    self.numbers       = numbers
    self.rows          = rows
    self.cols          = cols
    self.across_starts = across_starts
    self.down_starts   = down_starts
    self.clues_across  = puzzle.clues_across or {}
    self.clues_down    = puzzle.clues_down   or {}
    self.title         = puzzle.title        or ""

    -- User grid (empty)
    self.user = {}
    for r = 1, rows do
        self.user[r] = {}
        for c = 1, cols do
            self.user[r][c] = grid[r][c] == "#" and "#" or ""
        end
    end

    self.sel_r    = 1
    self.sel_c    = 1
    self.direction = "across"
    self.won       = false
    self.undo:clear()

    -- Move selection to first white cell
    for r = 1, rows do
        for c = 1, cols do
            if grid[r][c] ~= "#" then
                self.sel_r = r
                self.sel_c = c
                return
            end
        end
    end
end

function CrosswordBoard:selectCell(r, c)
    if r < 1 or r > self.rows or c < 1 or c > self.cols then return end
    if self.grid[r][c] == "#" then return end
    if r == self.sel_r and c == self.sel_c then
        -- Toggle direction
        self.direction = self.direction == "across" and "down" or "across"
    end
    self.sel_r = r
    self.sel_c = c
end

function CrosswordBoard:typeLetter(letter)
    if self.won then return end
    local r, c = self.sel_r, self.sel_c
    if self.grid[r][c] == "#" then return end
    local old = self.user[r][c]
    self.undo:push{ r = r, c = c, old = old }
    self.user[r][c] = letter:upper()
    self:_advance()
    self:_checkWin()
end

function CrosswordBoard:deleteLetter()
    local r, c = self.sel_r, self.sel_c
    if self.grid[r][c] == "#" then return end
    if self.user[r][c] ~= "" then
        local old = self.user[r][c]
        self.undo:push{ r = r, c = c, old = old }
        self.user[r][c] = ""
    else
        -- Move back and delete
        self:_retreat()
        r, c = self.sel_r, self.sel_c
        local old = self.user[r][c]
        self.undo:push{ r = r, c = c, old = old }
        self.user[r][c] = ""
    end
    self.won = false
end

function CrosswordBoard:undoMove()
    local entry = self.undo:pop()
    if not entry then return false end
    self.user[entry.r][entry.c] = entry.old
    self.sel_r = entry.r
    self.sel_c = entry.c
    self.won   = false
    return true
end

function CrosswordBoard:_advance()
    local r, c = self.sel_r, self.sel_c
    if self.direction == "across" then
        local nc = c + 1
        while nc <= self.cols do
            if self.grid[r][nc] ~= "#" then
                self.sel_c = nc; return
            end
            nc = nc + 1
        end
    else
        local nr = r + 1
        while nr <= self.rows do
            if self.grid[nr][c] ~= "#" then
                self.sel_r = nr; return
            end
            nr = nr + 1
        end
    end
end

function CrosswordBoard:_retreat()
    local r, c = self.sel_r, self.sel_c
    if self.direction == "across" then
        local nc = c - 1
        while nc >= 1 do
            if self.grid[r][nc] ~= "#" then
                self.sel_c = nc; return
            end
            nc = nc - 1
        end
    else
        local nr = r - 1
        while nr >= 1 do
            if self.grid[nr][c] ~= "#" then
                self.sel_r = nr; return
            end
            nr = nr - 1
        end
    end
end

function CrosswordBoard:checkLetters()
    -- Returns grid of booleans: true = wrong fill (not matching solution)
    local wrong = {}
    for r = 1, self.rows do
        wrong[r] = {}
        for c = 1, self.cols do
            local sol = self.grid[r][c]
            local usr = self.user[r][c]
            wrong[r][c] = (sol ~= "#" and usr ~= "" and usr ~= sol)
        end
    end
    return wrong
end

function CrosswordBoard:reveal()
    for r = 1, self.rows do
        for c = 1, self.cols do
            if self.grid[r][c] ~= "#" then
                self.user[r][c] = self.grid[r][c]
            end
        end
    end
    self.won = true
end

function CrosswordBoard:_checkWin()
    for r = 1, self.rows do
        for c = 1, self.cols do
            local sol = self.grid[r][c]
            if sol ~= "#" and self.user[r][c] ~= sol then
                self.won = false; return
            end
        end
    end
    self.won = true
end

-- Get current clue info: number, direction, clue text
function CrosswordBoard:getCurrentClue()
    local r, c = self.sel_r, self.sel_c
    -- Find the start of the current word in the current direction
    if self.direction == "across" then
        -- Walk left to find start
        local sc = c
        while sc > 1 and self.grid[r][sc-1] ~= "#" do sc = sc - 1 end
        local num = self.numbers[r] and self.numbers[r][sc]
        if num and self.clues_across[num] then
            return num, "across", self.clues_across[num]
        end
    else
        local sr = r
        while sr > 1 and self.grid[sr-1][c] ~= "#" do sr = sr - 1 end
        local num = self.numbers[sr] and self.numbers[sr][c]
        if num and self.clues_down[num] then
            return num, "down", self.clues_down[num]
        end
    end
    return nil, self.direction, ""
end

-- Get cells of current word
function CrosswordBoard:getCurrentWordCells()
    local r, c = self.sel_r, self.sel_c
    local cells = {}
    if self.direction == "across" then
        local sc = c
        while sc > 1 and self.grid[r][sc-1] ~= "#" do sc = sc - 1 end
        while sc <= self.cols and self.grid[r][sc] ~= "#" do
            cells[#cells + 1] = { r, sc }; sc = sc + 1
        end
    else
        local sr = r
        while sr > 1 and self.grid[sr-1][c] ~= "#" do sr = sr - 1 end
        while sr <= self.rows and self.grid[sr][c] ~= "#" do
            cells[#cells + 1] = { sr, c }; sr = sr + 1
        end
    end
    return cells
end

-- ---------------------------------------------------------------------------
-- Persistence
-- ---------------------------------------------------------------------------

function CrosswordBoard:serialize()
    local flat_user = {}
    for r = 1, self.rows do
        for c = 1, self.cols do
            flat_user[#flat_user + 1] = self.user[r][c]
        end
    end
    return {
        puzzle_idx = self.puzzle_idx,
        user       = flat_user,
        rows       = self.rows,
        cols       = self.cols,
        sel_r      = self.sel_r,
        sel_c      = self.sel_c,
        direction  = self.direction,
        won        = self.won,
    }
end

function CrosswordBoard:load(data)
    if type(data) ~= "table" or not data.user then return false end
    local idx = data.puzzle_idx or 1
    self:loadPuzzle(idx)
    local rows, cols = data.rows or self.rows, data.cols or self.cols
    local idx2 = 1
    for r = 1, rows do
        if not self.user[r] then break end
        for c = 1, cols do
            if self.user[r][c] ~= nil then
                self.user[r][c] = data.user[idx2] or ""
            end
            idx2 = idx2 + 1
        end
    end
    self.sel_r    = data.sel_r    or self.sel_r
    self.sel_c    = data.sel_c    or self.sel_c
    self.direction = data.direction or "across"
    self.won       = data.won       or false
    return true
end

CrosswordBoard.NUM_PUZZLES = #PUZZLES

return CrosswordBoard
