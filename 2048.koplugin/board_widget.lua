local Blitbuffer    = require("ffi/blitbuffer")
local Font          = require("ui/font")
local Geom          = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local RenderText    = require("ui/rendertext")
local Size          = require("ui/size")

local gwb      = require("grid_widget_base")
local drawLine = gwb.drawLine

-- ---------------------------------------------------------------------------
-- Tile colour scheme (e-ink friendly: lighter = smaller value)
-- ---------------------------------------------------------------------------

local TILE_COLORS = {}

local function tileColorForValue(v)
    if v == 0    then return Blitbuffer.COLOR_GRAY_E end
    local level = 0
    local tmp = v
    while tmp > 1 do tmp = math.floor(tmp / 2); level = level + 1 end
    -- level: 1→2, 2→4, 3→8, 4→16, 5→32, 6→64, 7→128, 8→256, 9→512, 10→1024, 11→2048+
    if     level <= 1  then return Blitbuffer.COLOR_GRAY_E
    elseif level == 2  then return Blitbuffer.COLOR_GRAY_D
    elseif level == 3  then return Blitbuffer.COLOR_GRAY_C
    elseif level == 4  then return Blitbuffer.COLOR_GRAY_B
    elseif level == 5  then return Blitbuffer.COLOR_GRAY_9
    elseif level == 6  then return Blitbuffer.COLOR_GRAY_7
    elseif level == 7  then return Blitbuffer.COLOR_GRAY_5
    elseif level == 8  then return Blitbuffer.COLOR_GRAY_4
    elseif level == 9  then return Blitbuffer.COLOR_GRAY_3
    elseif level == 10 then return Blitbuffer.COLOR_GRAY_2
    else                    return Blitbuffer.COLOR_BLACK
    end
end

local function textColorForValue(v)
    if v == 0 then return Blitbuffer.COLOR_GRAY_9 end
    local level = 0
    local tmp = v
    while tmp > 1 do tmp = math.floor(tmp / 2); level = level + 1 end
    return level >= 7 and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK
end

-- ---------------------------------------------------------------------------
-- Game2048BoardWidget
-- ---------------------------------------------------------------------------

local Game2048BoardWidget = InputContainer:extend{
    board     = nil,
    onSwipe   = nil,   -- function(direction)
    cell_size = 0,
}

function Game2048BoardWidget:init()
    local board = self.board
    local n     = board.n
    local sw    = require("device").screen:getWidth()
    local sh    = require("device").screen:getHeight()
    local avail = math.min(sw, sh)

    -- Use 85% of the shorter screen dimension for the board
    local total = math.floor(avail * 0.85)
    local gap   = math.max(2, math.floor(total * 0.02))
    local cell  = math.floor((total - (n + 1) * gap) / n)
    cell = math.max(cell, 20)

    self.gap    = gap
    self.cell   = cell
    local board_px = cell * n + gap * (n + 1)
    self.board_px  = board_px

    self.dimen = Geom:new{ w = board_px, h = board_px }

    -- Font sizes relative to cell
    self.face_large  = Font:getFace("infont",      math.max(8, math.floor(cell * 0.45)))
    self.face_medium = Font:getFace("infont",      math.max(7, math.floor(cell * 0.35)))
    self.face_small  = Font:getFace("smallinfofont", math.max(6, math.floor(cell * 0.28)))

    self.paint_rect = nil

    self.ges_events = {
        BoardSwipe = { GestureRange:new{ ges = "swipe", range = self.dimen } },
    }
end

function Game2048BoardWidget:onBoardSwipe(ges)
    if self.onSwipe then
        local dir = ges.direction  -- "east","west","north","south"
        local map = { east="right", west="left", north="up", south="down" }
        local d   = map[dir]
        if d then self.onSwipe(d) end
    end
    return true
end

function Game2048BoardWidget:refresh()
    local UIManager = require("ui/uimanager")
    UIManager:setDirty(self, function()
        return "ui", self.paint_rect or self.dimen
    end)
end

function Game2048BoardWidget:paintTo(bb, x, y)
    local board = self.board
    local n     = board.n
    local cell  = self.cell
    local gap   = self.gap
    local bp    = self.board_px

    self.paint_rect = Geom:new{ x = x, y = y, w = bp, h = bp }

    -- Board background
    bb:paintRect(x, y, bp, bp, Blitbuffer.COLOR_GRAY_A)

    for r = 1, n do
        for c = 1, n do
            local v   = board.grid[r][c]
            local tx  = x + gap + (c - 1) * (cell + gap)
            local ty  = y + gap + (r - 1) * (cell + gap)
            local bg  = tileColorForValue(v)
            local fg  = textColorForValue(v)

            -- Tile background
            bb:paintRect(tx, ty, cell, cell, bg)

            -- Tile value text
            if v ~= 0 then
                local text = tostring(v)
                local len  = #text
                local face = len <= 2 and self.face_large
                          or len == 3 and self.face_medium
                          or self.face_small
                local m    = RenderText:sizeUtf8Text(0, cell, face, text, true, false)
                local base = ty + math.floor((cell + m.y_top - m.y_bottom) / 2)
                local lx   = tx + math.floor((cell - m.x) / 2)
                RenderText:renderUtf8Text(bb, lx, base, face, text, true, false, fg)
            end
        end
    end
end

return Game2048BoardWidget
