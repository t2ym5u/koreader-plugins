-- ---------------------------------------------------------------------------
-- OthelloBoard — game logic for Othello/Reversi (8x8)
--
-- grid[r][c]:
--   0 = empty
--   1 = black disc
--   2 = white disc
--
-- r=1 is the top row, c=1 is the leftmost column.
-- Black goes first.
-- Initial position:
--   (4,4)=white  (4,5)=black
--   (5,4)=black  (5,5)=white
-- ---------------------------------------------------------------------------

local OthelloBoard = {}
OthelloBoard.__index = OthelloBoard

local BLACK = 1
local WHITE = 2
local INF   = 1e9

-- All 8 directions
local DIRS = {
    {-1, -1}, {-1, 0}, {-1, 1},
    { 0, -1},           { 0, 1},
    { 1, -1}, { 1, 0}, { 1, 1},
}

-- Corner positions (1-indexed)
local CORNERS = { {1,1}, {1,8}, {8,1}, {8,8} }
local CORNER_SET = {}
for _, pos in ipairs(CORNERS) do
    CORNER_SET[pos[1] * 10 + pos[2]] = true
end

-- ---------------------------------------------------------------------------
-- Constructor
-- ---------------------------------------------------------------------------

function OthelloBoard:new()
    local o = setmetatable({}, self)
    o.grid     = {}
    o.turn     = "black"
    o.status   = "playing"
    o.winner   = nil
    o.last_r   = nil
    o.last_c   = nil
    for r = 1, 8 do
        o.grid[r] = {}
        for c = 1, 8 do
            o.grid[r][c] = 0
        end
    end
    return o
end

-- ---------------------------------------------------------------------------
-- Reset / initial position
-- ---------------------------------------------------------------------------

function OthelloBoard:reset()
    for r = 1, 8 do
        for c = 1, 8 do
            self.grid[r][c] = 0
        end
    end
    -- Standard Othello starting position
    self.grid[4][4] = WHITE
    self.grid[4][5] = BLACK
    self.grid[5][4] = BLACK
    self.grid[5][5] = WHITE

    self.turn   = "black"
    self.status = "playing"
    self.winner = nil
    self.last_r = nil
    self.last_c = nil
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function inBounds(r, c)
    return r >= 1 and r <= 8 and c >= 1 and c <= 8
end

local function colorVal(color)
    return (color == "black") and BLACK or WHITE
end

local function oppColor(color)
    return (color == "black") and "white" or "black"
end

local function oppVal(v)
    return (v == BLACK) and WHITE or BLACK
end

-- ---------------------------------------------------------------------------
-- getFlips — list of {r,c} discs that would be flipped by placing at (r,c)
-- ---------------------------------------------------------------------------

function OthelloBoard:getFlips(r, c, color)
    local grid = self.grid
    if grid[r][c] ~= 0 then return {} end
    local my_val  = colorVal(color)
    local opp_val = oppVal(my_val)
    local flips   = {}

    for _, d in ipairs(DIRS) do
        local dr, dc   = d[1], d[2]
        local nr, nc   = r + dr, c + dc
        local line     = {}
        while inBounds(nr, nc) and grid[nr][nc] == opp_val do
            line[#line + 1] = { nr, nc }
            nr = nr + dr
            nc = nc + dc
        end
        if #line > 0 and inBounds(nr, nc) and grid[nr][nc] == my_val then
            for _, pos in ipairs(line) do
                flips[#flips + 1] = { r = pos[1], c = pos[2] }
            end
        end
    end
    return flips
end

-- ---------------------------------------------------------------------------
-- isValidMove
-- ---------------------------------------------------------------------------

function OthelloBoard:isValidMove(r, c, color)
    if self.grid[r][c] ~= 0 then return false end
    return #self:getFlips(r, c, color) > 0
end

-- ---------------------------------------------------------------------------
-- getValidMoves — list of {r,c}
-- ---------------------------------------------------------------------------

function OthelloBoard:getValidMoves(color)
    local moves = {}
    for r = 1, 8 do
        for c = 1, 8 do
            if self:isValidMove(r, c, color) then
                moves[#moves + 1] = { r = r, c = c }
            end
        end
    end
    return moves
end

-- ---------------------------------------------------------------------------
-- placeDisk — place a disc for self.turn at (r,c)
-- Returns: "ok", "invalid", "skip", "ended"
-- ---------------------------------------------------------------------------

function OthelloBoard:placeDisk(r, c)
    if self.status ~= "playing" then return "invalid" end
    local color = self.turn
    local flips = self:getFlips(r, c, color)
    if #flips == 0 then return "invalid" end

    -- Place disc and flip
    local my_val = colorVal(color)
    self.grid[r][c] = my_val
    for _, pos in ipairs(flips) do
        self.grid[pos.r][pos.c] = my_val
    end
    self.last_r = r
    self.last_c = c

    -- Switch turn
    return self:_advanceTurn()
end

-- Internal: determine whose turn comes next, handle skips and game end.
-- Returns "ok", "skip", or "ended".
function OthelloBoard:_advanceTurn()
    local next_color = oppColor(self.turn)
    local next_moves = self:getValidMoves(next_color)

    if #next_moves > 0 then
        self.turn = next_color
        return "ok"
    end

    -- Next player has no move — check if current player can continue
    local curr_moves = self:getValidMoves(self.turn)
    if #curr_moves > 0 then
        -- Skip: current player keeps their turn
        -- (turn stays the same)
        return "skip"
    end

    -- Neither player can move — game over
    self.status = "ended"
    local bc, wc = self:countDiscs()
    if bc > wc then
        self.winner = "black"
    elseif wc > bc then
        self.winner = "white"
    else
        self.winner = "draw"
    end
    return "ended"
end

-- ---------------------------------------------------------------------------
-- countDiscs
-- ---------------------------------------------------------------------------

function OthelloBoard:countDiscs()
    local black, white = 0, 0
    for r = 1, 8 do
        for c = 1, 8 do
            local v = self.grid[r][c]
            if v == BLACK then black = black + 1
            elseif v == WHITE then white = white + 1 end
        end
    end
    return black, white
end

-- ---------------------------------------------------------------------------
-- Serialize / Load
-- ---------------------------------------------------------------------------

function OthelloBoard:serialize()
    local grid_copy = {}
    for r = 1, 8 do
        grid_copy[r] = {}
        for c = 1, 8 do
            grid_copy[r][c] = self.grid[r][c]
        end
    end
    return {
        grid   = grid_copy,
        turn   = self.turn,
        status = self.status,
        winner = self.winner,
        last_r = self.last_r,
        last_c = self.last_c,
    }
end

function OthelloBoard:load(data)
    if type(data) ~= "table" or type(data.grid) ~= "table" then
        return false
    end
    for r = 1, 8 do
        if type(data.grid[r]) ~= "table" then return false end
        for c = 1, 8 do
            local v = data.grid[r][c]
            if type(v) ~= "number" or v < 0 or v > 2 then return false end
            self.grid[r][c] = v
        end
    end
    self.turn   = (data.turn == "white") and "white" or "black"
    self.status = (data.status == "ended") and "ended" or "playing"
    self.winner = data.winner
    self.last_r = data.last_r
    self.last_c = data.last_c
    return true
end

-- ---------------------------------------------------------------------------
-- AI — minimax with alpha-beta pruning
-- Evaluation is from black's perspective.
-- ---------------------------------------------------------------------------

-- Static evaluation of a grid state from black's perspective
local function evaluateGrid(grid)
    local score        = 0
    local black_count  = 0
    local white_count  = 0
    local black_moves  = 0  -- mobility (counted below)
    local white_moves  = 0

    -- Disc counts + positional bonuses
    for r = 1, 8 do
        for c = 1, 8 do
            local v = grid[r][c]
            if v == BLACK then
                black_count = black_count + 1
                local key = r * 10 + c
                if CORNER_SET[key] then
                    score = score + 30
                elseif r == 1 or r == 8 or c == 1 or c == 8 then
                    score = score + 5
                end
            elseif v == WHITE then
                white_count = white_count + 1
                local key = r * 10 + c
                if CORNER_SET[key] then
                    score = score - 30
                elseif r == 1 or r == 8 or c == 1 or c == 8 then
                    score = score - 5
                end
            end
        end
    end

    -- Disc count component
    score = score + (black_count - white_count)

    -- Mobility: count valid moves for each color
    -- (we compute flips on the grid directly for speed)
    local function countMovesForColor(my_val, opp_val_local)
        local count = 0
        for r = 1, 8 do
            for c = 1, 8 do
                if grid[r][c] == 0 then
                    local valid = false
                    for _, d in ipairs(DIRS) do
                        local dr, dc = d[1], d[2]
                        local nr, nc = r + dr, c + dc
                        local found_opp = false
                        while inBounds(nr, nc) and grid[nr][nc] == opp_val_local do
                            found_opp = true
                            nr = nr + dr
                            nc = nc + dc
                        end
                        if found_opp and inBounds(nr, nc) and grid[nr][nc] == my_val then
                            valid = true
                            break
                        end
                    end
                    if valid then count = count + 1 end
                end
            end
        end
        return count
    end

    black_moves = countMovesForColor(BLACK, WHITE)
    white_moves = countMovesForColor(WHITE, BLACK)
    score = score + (black_moves - white_moves) * 2

    return score
end

-- Get valid move positions for a color on a given grid
local function getMovesOnGrid(grid, my_val, opp_val_local)
    local moves = {}
    for r = 1, 8 do
        for c = 1, 8 do
            if grid[r][c] == 0 then
                for _, d in ipairs(DIRS) do
                    local dr, dc = d[1], d[2]
                    local nr, nc = r + dr, c + dc
                    local found_opp = false
                    while inBounds(nr, nc) and grid[nr][nc] == opp_val_local do
                        found_opp = true
                        nr = nr + dr
                        nc = nc + dc
                    end
                    if found_opp and inBounds(nr, nc) and grid[nr][nc] == my_val then
                        moves[#moves + 1] = { r, c }
                        break
                    end
                end
            end
        end
    end
    return moves
end

-- Apply a move to a grid copy; returns new grid
local function applyMoveToGrid(grid, r, c, my_val, opp_val_local)
    -- Deep copy grid
    local ng = {}
    for row = 1, 8 do
        ng[row] = {}
        for col = 1, 8 do
            ng[row][col] = grid[row][col]
        end
    end
    ng[r][c] = my_val
    -- Flip in all directions
    for _, d in ipairs(DIRS) do
        local dr, dc = d[1], d[2]
        local nr, nc = r + dr, c + dc
        local line   = {}
        while inBounds(nr, nc) and ng[nr][nc] == opp_val_local do
            line[#line + 1] = { nr, nc }
            nr = nr + dr
            nc = nc + dc
        end
        if #line > 0 and inBounds(nr, nc) and ng[nr][nc] == my_val then
            for _, pos in ipairs(line) do
                ng[pos[1]][pos[2]] = my_val
            end
        end
    end
    return ng
end

-- Minimax: maximiser = BLACK (1), minimiser = WHITE (2)
local function minimax(grid, turn_val, depth, alpha, beta)
    local opp_val_local = oppVal(turn_val)
    local moves  = getMovesOnGrid(grid, turn_val, opp_val_local)

    if #moves == 0 then
        -- Check if opponent can move
        local opp_moves = getMovesOnGrid(grid, opp_val_local, turn_val)
        if #opp_moves == 0 then
            -- Terminal: count discs
            return evaluateGrid(grid)
        end
        -- Current player skips; opponent plays
        if depth == 0 then return evaluateGrid(grid) end
        return minimax(grid, opp_val_local, depth - 1, alpha, beta)
    end

    if depth == 0 then
        return evaluateGrid(grid)
    end

    if turn_val == BLACK then
        local best = -INF
        for _, m in ipairs(moves) do
            local ng  = applyMoveToGrid(grid, m[1], m[2], turn_val, opp_val_local)
            local val = minimax(ng, opp_val_local, depth - 1, alpha, beta)
            if val > best then best = val end
            if best > alpha then alpha = best end
            if alpha >= beta then break end
        end
        return best
    else
        local best = INF
        for _, m in ipairs(moves) do
            local ng  = applyMoveToGrid(grid, m[1], m[2], turn_val, opp_val_local)
            local val = minimax(ng, opp_val_local, depth - 1, alpha, beta)
            if val < best then best = val end
            if best < beta then beta = best end
            if alpha >= beta then break end
        end
        return best
    end
end

-- ---------------------------------------------------------------------------
-- getAIMove — returns {r, c} or nil
-- ---------------------------------------------------------------------------

function OthelloBoard:getAIMove(depth)
    depth = depth or 4
    local color    = self.turn
    local my_val   = colorVal(color)
    local opp_val_local = oppVal(my_val)
    local moves    = getMovesOnGrid(self.grid, my_val, opp_val_local)
    if #moves == 0 then return nil end

    local best_move = nil
    local is_black  = (my_val == BLACK)
    local best_val  = is_black and -INF or INF

    for _, m in ipairs(moves) do
        local ng  = applyMoveToGrid(self.grid, m[1], m[2], my_val, opp_val_local)
        local val = minimax(ng, opp_val_local, depth - 1, -INF, INF)
        if is_black then
            if val > best_val then
                best_val  = val
                best_move = m
            end
        else
            if val < best_val then
                best_val  = val
                best_move = m
            end
        end
    end
    return best_move
end

-- ---------------------------------------------------------------------------
-- applyAIMove — apply best AI move
-- Returns "ok", "skip", "ended", or "none" (no moves available)
-- ---------------------------------------------------------------------------

function OthelloBoard:applyAIMove(depth)
    local move = self:getAIMove(depth)
    if not move then
        -- AI has no valid move — this shouldn't happen if called at the right time,
        -- but handle it gracefully by advancing the turn
        return self:_advanceTurn()
    end
    return self:placeDisk(move[1], move[2])
end

return OthelloBoard
