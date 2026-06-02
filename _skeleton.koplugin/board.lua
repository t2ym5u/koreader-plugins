local UndoStack  = require("undo_stack")
local grid_utils = require("grid_utils")
local Timer      = require("timer")
local _          = require("gettext")

-- ---------------------------------------------------------------------------
-- MyGameBoard — game state and logic
--
-- Adapt this to your game's rules.
-- ---------------------------------------------------------------------------

local MyGameBoard = {}
MyGameBoard.__index = MyGameBoard

local DEFAULT_COLS = 9
local DEFAULT_ROWS = 9

function MyGameBoard:new(opts)
    opts = opts or {}
    local b = setmetatable({
        cols       = opts.cols or DEFAULT_COLS,
        rows       = opts.rows or DEFAULT_ROWS,
        difficulty = opts.difficulty or "easy",
        undo       = UndoStack:new(),
        timer      = Timer:new(),
        -- game-specific state below:
        grid       = nil,
        solved     = false,
    }, self)
    return b
end

-- Generate a new puzzle.
function MyGameBoard:generate(difficulty)
    self.difficulty = difficulty or self.difficulty
    self.undo:clear()
    self.solved = false
    self.timer:reset()
    self.timer:start()
    -- TODO: fill self.grid with a new puzzle
    self.grid = grid_utils.emptyGrid(self.cols, self.rows)
end

-- Return true when the puzzle is solved.
function MyGameBoard:isSolved()
    return self.solved
end

-- ---------------------------------------------------------------------------
-- Persistence
-- ---------------------------------------------------------------------------

function MyGameBoard:serialize()
    local timer_data = self.timer:serialize()
    return {
        cols       = self.cols,
        rows       = self.rows,
        difficulty = self.difficulty,
        grid       = self.grid,
        solved     = self.solved,
        timer      = timer_data,
        undo       = self.undo:serialize(),
    }
end

function MyGameBoard:load(data)
    if type(data) ~= "table" then return false end
    self.cols       = data.cols       or self.cols
    self.rows       = data.rows       or self.rows
    self.difficulty = data.difficulty or self.difficulty
    self.grid       = data.grid       or grid_utils.emptyGrid(self.cols, self.rows)
    self.solved     = data.solved     or false
    self.timer:load(data.timer)
    self.undo:load(data.undo)
    return true
end

return MyGameBoard
