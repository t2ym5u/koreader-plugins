local Blitbuffer     = require("ffi/blitbuffer")
local Device         = require("device")
local Font           = require("ui/font")
local Geom           = require("ui/geometry")
local GestureRange   = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local RenderText     = require("ui/rendertext")
local Size           = require("ui/size")
local UIManager      = require("ui/uimanager")

local gwb      = require("grid_widget_base")
local drawLine = gwb.drawLine

local C_BG      = Blitbuffer.COLOR_WHITE
local C_TILE    = Blitbuffer.COLOR_GRAY_E
local C_EMPTY   = Blitbuffer.COLOR_WHITE
local C_BORDER  = Blitbuffer.COLOR_BLACK
local C_GRID    = Blitbuffer.COLOR_GRAY_9
local C_TEXT    = Blitbuffer.COLOR_BLACK

-- ---------------------------------------------------------------------------
-- FifteenBoardWidget
-- ---------------------------------------------------------------------------

local FifteenBoardWidget = InputContainer:extend{
    board       = nil,
    onCellTap   = nil,
    max_width   = 0,
    max_height  = 0,
}

function FifteenBoardWidget:init()
    local board = self.board
    local n     = board.n

    local cell = math.floor(math.min(self.max_width / n, self.max_height / n))
    cell = math.max(cell, 16)
    self.cell = cell
    self.w    = cell * n
    self.h    = cell * n
    self.dimen = Geom:new{ w = self.w, h = self.h }

    local fs = math.max(8, math.floor(cell * 0.55))
    self.face = Font:getFace("cfont", fs)

    self.paint_rect = nil

    self.ges_events = {
        CellTap = { GestureRange:new{ ges = "tap", range = self.dimen } },
    }
end

function FifteenBoardWidget:onCellTap(ges)
    if not self.paint_rect then return end
    local lx = ges.pos.x - self.paint_rect.x
    local ly = ges.pos.y - self.paint_rect.y
    if lx < 0 or ly < 0 or lx >= self.w or ly >= self.h then return end
    local c = math.floor(lx / self.cell) + 1
    local r = math.floor(ly / self.cell) + 1
    local n = self.board.n
    if r >= 1 and r <= n and c >= 1 and c <= n then
        if self.onCellTap then self.onCellTap(r, c) end
    end
    return true
end

function FifteenBoardWidget:refresh()
    UIManager:setDirty(self, function()
        return "ui", self.paint_rect or self.dimen
    end)
end

function FifteenBoardWidget:paintTo(bb, x, y)
    self.paint_rect = Geom:new{ x = x, y = y, w = self.w, h = self.h }
    local board = self.board
    local n     = board.n
    local cell  = self.cell

    bb:paintRect(x, y, self.w, self.h, C_BG)

    -- Tiles
    local pad  = math.max(2, math.floor(cell * 0.06))
    for r = 1, n do
        for c = 1, n do
            local v  = board.grid[r][c]
            local cx = x + (c - 1) * cell
            local cy = y + (r - 1) * cell
            if v == 0 then
                bb:paintRect(cx, cy, cell, cell, C_EMPTY)
            else
                bb:paintRect(cx + pad, cy + pad, cell - 2*pad, cell - 2*pad, C_TILE)
                local text = tostring(v)
                local m = RenderText:sizeUtf8Text(0, cell, self.face, text, true, false)
                local tx = cx + math.floor((cell - m.x) / 2)
                local ty = cy + math.floor((cell - (m.y_bottom - m.y_top)) / 2) + m.y_top
                RenderText:renderUtf8Text(bb, tx, ty, self.face, text, true, false, C_TEXT)
            end
        end
    end

    -- Grid lines
    local thin = Size.line.thin or 1
    for i = 0, n do
        drawLine(bb, x + i * cell, y,          thin, self.h, C_GRID)
        drawLine(bb, x,            y + i*cell, self.w, thin, C_GRID)
    end

    -- Border
    local thick = math.max(2, math.floor(cell * 0.06))
    drawLine(bb, x,              y,              self.w, thick, C_BORDER)
    drawLine(bb, x,              y + self.h - thick, self.w, thick, C_BORDER)
    drawLine(bb, x,              y,              thick, self.h, C_BORDER)
    drawLine(bb, x + self.w - thick, y,          thick, self.h, C_BORDER)
end

return FifteenBoardWidget
