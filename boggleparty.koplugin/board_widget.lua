local Blitbuffer     = require("ffi/blitbuffer")
local Font           = require("ui/font")
local Geom           = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local RenderText     = require("ui/rendertext")

local gwb      = require("grid_widget_base")
local drawLine = gwb.drawLine

local C_BG     = Blitbuffer.COLOR_WHITE
local C_TILE   = Blitbuffer.COLOR_GRAY_E
local C_GRID   = Blitbuffer.COLOR_GRAY_9
local C_BORDER = Blitbuffer.COLOR_BLACK
local C_TEXT   = Blitbuffer.COLOR_BLACK

-- ---------------------------------------------------------------------------
-- BoardDisplay — read-only grid widget for Boggle Party
-- No gesture handling; maximises letter size for table visibility.
-- ---------------------------------------------------------------------------

local BoardDisplay = InputContainer:extend{
    board      = nil,
    max_width  = 300,
    max_height = 300,
}

local function centeredText(bb, text, face, cx, cy)
    local m  = RenderText:sizeUtf8Text(0, cx * 2, face, text, true, false)
    local tx = cx - math.floor(m.x / 2)
    local ty = cy - math.floor((m.y_bottom - m.y_top) / 2) + m.y_top
    RenderText:renderUtf8Text(bb, tx, ty, face, text, true, false, C_TEXT)
end

function BoardDisplay:init()
    local n    = self.board.n
    local cell = math.floor(math.min(self.max_width / n, self.max_height / n))
    self.cell  = math.max(cell, 20)
    self.w     = self.cell * n
    self.h     = self.cell * n
    self.dimen = Geom:new{ w = self.w, h = self.h }
    local fs   = math.max(12, math.floor(self.cell * 0.62))
    self.letter_face = Font:getFace("cfont", fs)
end

function BoardDisplay:paintTo(bb, x, y)
    local n    = self.board.n
    local cell = self.cell
    local pad  = math.max(3, math.floor(cell * 0.06))

    bb:paintRect(x, y, self.w, self.h, C_BG)

    for r = 1, n do
        for c = 1, n do
            local cx = x + (c - 1) * cell
            local cy = y + (r - 1) * cell
            bb:paintRect(cx + pad, cy + pad, cell - 2 * pad, cell - 2 * pad, C_TILE)
            centeredText(bb, self.board.grid[r][c], self.letter_face,
                cx + cell // 2, cy + cell // 2)
        end
    end

    local thin = 1
    for i = 0, n do
        drawLine(bb, x + i * cell, y,           thin,   self.h, C_GRID)
        drawLine(bb, x,            y + i * cell, self.w, thin,   C_GRID)
    end
    local bw = math.max(2, thin)
    drawLine(bb, x,               y,                self.w, bw,     C_BORDER)
    drawLine(bb, x,               y + self.h - bw,  self.w, bw,     C_BORDER)
    drawLine(bb, x,               y,                bw,     self.h, C_BORDER)
    drawLine(bb, x + self.w - bw, y,                bw,     self.h, C_BORDER)
end

return BoardDisplay
