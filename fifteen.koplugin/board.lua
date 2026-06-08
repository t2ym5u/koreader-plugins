local Timer  = require("timer")

local SIZES      = { 3, 4, 5 }
local DEFAULT_N  = 4
local SCRAMBLE_MOVES = 200

-- ---------------------------------------------------------------------------
-- FifteenBoard
-- ---------------------------------------------------------------------------

local FifteenBoard = {}
FifteenBoard.__index = FifteenBoard

function FifteenBoard:new(opts)
    opts = opts or {}
    local n   = opts.n or DEFAULT_N
    local obj = setmetatable({
        n           = n,
        grid        = {},   -- grid[r][c] = tile value (0 = empty)
        blank_r     = n,
        blank_c     = n,
        moves       = 0,
        won         = false,
        timer       = Timer:new(),
    }, self)
    obj:_buildSolved()
    obj:_scramble()
    return obj
end

function FifteenBoard:_buildSolved()
    local n = self.n
    local v = 1
    for r = 1, n do
        self.grid[r] = {}
        for c = 1, n do
            self.grid[r][c] = (r == n and c == n) and 0 or v
            v = v + 1
        end
    end
    self.blank_r = n
    self.blank_c = n
end

function FifteenBoard:_scramble()
    local dirs = { {0,1}, {0,-1}, {1,0}, {-1,0} }
    local prev_dr, prev_dc = 0, 0
    for _ = 1, SCRAMBLE_MOVES do
        local valid = {}
        for _, d in ipairs(dirs) do
            local nr = self.blank_r + d[1]
            local nc = self.blank_c + d[2]
            -- skip reverse of last move to avoid trivial back-and-forth
            if nr >= 1 and nr <= self.n and nc >= 1 and nc <= self.n
                    and not (d[1] == -prev_dr and d[2] == -prev_dc) then
                valid[#valid + 1] = d
            end
        end
        if #valid == 0 then
            for _, d in ipairs(dirs) do
                local nr = self.blank_r + d[1]
                local nc = self.blank_c + d[2]
                if nr >= 1 and nr <= self.n and nc >= 1 and nc <= self.n then
                    valid[#valid + 1] = d
                end
            end
        end
        local d = valid[math.random(#valid)]
        local tr = self.blank_r + d[1]
        local tc = self.blank_c + d[2]
        self.grid[self.blank_r][self.blank_c] = self.grid[tr][tc]
        self.grid[tr][tc] = 0
        prev_dr, prev_dc = d[1], d[2]
        self.blank_r, self.blank_c = tr, tc
    end
    self.moves = 0
    self.won   = false
    self.timer:reset()
end

-- Try to slide the tile at (r, c) into the blank.
-- Returns true if a move was made.
function FifteenBoard:slide(r, c)
    if self.won then return false end
    local br, bc = self.blank_r, self.blank_c
    local dr, dc = math.abs(r - br), math.abs(c - bc)
    if not ((dr == 1 and dc == 0) or (dr == 0 and dc == 1)) then
        return false
    end
    if not self.timer:isRunning() then self.timer:start() end
    self.grid[br][bc] = self.grid[r][c]
    self.grid[r][c]   = 0
    self.blank_r, self.blank_c = r, c
    self.moves = self.moves + 1
    if self:_checkWin() then
        self.won = true
        self.timer:stop()
    end
    return true
end

function FifteenBoard:_checkWin()
    local n = self.n
    local expected = 1
    for r = 1, n do
        for c = 1, n do
            local v = self.grid[r][c]
            if r == n and c == n then
                if v ~= 0 then return false end
            else
                if v ~= expected then return false end
                expected = expected + 1
            end
        end
    end
    return true
end

function FifteenBoard:newGame(n)
    self.n = n or self.n
    self:_buildSolved()
    self:_scramble()
end

-- ---------------------------------------------------------------------------
-- Persistence
-- ---------------------------------------------------------------------------

function FifteenBoard:serialize()
    local flat = {}
    local n = self.n
    for r = 1, n do
        for c = 1, n do
            flat[#flat + 1] = self.grid[r][c]
        end
    end
    return {
        n       = n,
        grid    = flat,
        blank_r = self.blank_r,
        blank_c = self.blank_c,
        moves   = self.moves,
        won     = self.won,
        timer   = self.timer:serialize(),
    }
end

function FifteenBoard:load(data)
    if type(data) ~= "table" or not data.grid then return false end
    local n = data.n or DEFAULT_N
    self.n  = n
    self.grid = {}
    local idx = 1
    for r = 1, n do
        self.grid[r] = {}
        for c = 1, n do
            self.grid[r][c] = data.grid[idx] or 0
            idx = idx + 1
        end
    end
    self.blank_r = data.blank_r or n
    self.blank_c = data.blank_c or n
    self.moves   = data.moves   or 0
    self.won     = data.won     or false
    self.timer   = Timer:new()
    if data.timer then self.timer:load(data.timer) end
    return true
end

FifteenBoard.SIZES       = SIZES
FifteenBoard.DEFAULT_N   = DEFAULT_N

return FifteenBoard
