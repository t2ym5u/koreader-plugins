local Blitbuffer    = require("ffi/blitbuffer")
local Font          = require("ui/font")
local Geom          = require("ui/geometry")
local GestureRange  = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local RenderText    = require("ui/rendertext")
local UIManager     = require("ui/uimanager")

local C_BG       = Blitbuffer.COLOR_WHITE
local C_GRID     = Blitbuffer.COLOR_GRAY_9
local C_BORDER   = Blitbuffer.COLOR_BLACK
local C_FOUND    = Blitbuffer.COLOR_GRAY_C
local C_SELECTED = Blitbuffer.COLOR_GRAY_A
local C_TEXT     = Blitbuffer.COLOR_BLACK

-- ---------------------------------------------------------------------------
-- WordSearchBoardWidget
-- ---------------------------------------------------------------------------

local WordSearchBoardWidget = InputContainer:extend{
    board      = nil,
    max_width  = 200,
    max_height = 200,
    onFirstTap = nil,
    onSelectWord = nil,
}

function WordSearchBoardWidget:init()
    local size = self.board.size
    local cell = math.floor(math.min(self.max_width, self.max_height) / size)
    cell = math.max(cell, 12)
    self.cell  = cell
    self.w     = cell * size
    self.h     = cell * size
    self.dimen = Geom:new{ w = self.w, h = self.h }
    self.paint_rect = nil
    self.first_tap  = nil

    local face_sz = math.max(6, math.floor(cell * 0.55))
    self.letter_face = Font:getFace("smallinfofont", face_sz)

    self.ges_events = {
        CellTap = { GestureRange:new{ ges = "tap", range = self.dimen } },
    }
end

function WordSearchBoardWidget:onCellTap(ges)
    if not self.paint_rect then return true end
    local rect = self.paint_rect
    local lx = ges.pos.x - rect.x
    local ly = ges.pos.y - rect.y
    local cell = self.cell
    if lx < 0 or ly < 0 or lx >= self.w or ly >= self.h then return true end
    local c = math.floor(lx / cell) + 1
    local r = math.floor(ly / cell) + 1
    local size = self.board.size
    if r < 1 or r > size or c < 1 or c > size then return true end

    if not self.first_tap then
        self.first_tap = { r = r, c = c }
        self:refresh()
    else
        local r1, c1 = self.first_tap.r, self.first_tap.c
        self.first_tap = nil
        if self.onSelectWord then
            self.onSelectWord(r1, c1, r, c)
        end
        self:refresh()
    end
    return true
end

function WordSearchBoardWidget:_isCellFound(r, c)
    local board = self.board
    for i, entry in ipairs(board.word_list) do
        if board.found[i] then
            local dr = entry.r2 - entry.r1
            local dc = entry.c2 - entry.c1
            local wlen = math.max(math.abs(dr), math.abs(dc)) + 1
            local step_r = dr == 0 and 0 or (dr > 0 and 1 or -1)
            local step_c = dc == 0 and 0 or (dc > 0 and 1 or -1)
            for s = 0, wlen - 1 do
                if entry.r1 + step_r * s == r and entry.c1 + step_c * s == c then
                    return true
                end
            end
        end
    end
    return false
end

function WordSearchBoardWidget:paintTo(bb, x, y)
    self.paint_rect = Geom:new{ x = x, y = y, w = self.w, h = self.h }
    local board = self.board
    local size  = board.size
    local cell  = self.cell

    bb:paintRect(x, y, self.w, self.h, C_BG)

    -- Cell backgrounds
    for r = 1, size do
        for c = 1, size do
            local cx = x + (c - 1) * cell
            local cy = y + (r - 1) * cell
            local bg = C_BG
            if self:_isCellFound(r, c) then
                bg = C_FOUND
            elseif self.first_tap and self.first_tap.r == r and self.first_tap.c == c then
                bg = C_SELECTED
            end
            if bg ~= C_BG then
                bb:paintRect(cx, cy, cell, cell, bg)
            end
        end
    end

    -- Grid lines
    for i = 0, size do
        bb:paintRect(x + i * cell, y, 1, self.h, C_GRID)
        bb:paintRect(x, y + i * cell, self.w, 1, C_GRID)
    end

    -- Border
    local thick = 2
    bb:paintRect(x, y, self.w, thick, C_BORDER)
    bb:paintRect(x, y + self.h - thick, self.w, thick, C_BORDER)
    bb:paintRect(x, y, thick, self.h, C_BORDER)
    bb:paintRect(x + self.w - thick, y, thick, self.h, C_BORDER)

    -- Letters
    local pad  = math.max(1, math.floor(cell * 0.1))
    local cinn = cell - 2 * pad
    for r = 1, size do
        for c = 1, size do
            local ch = board.grid[r][c]
            if ch and ch ~= "" then
                local cx = x + (c - 1) * cell
                local cy = y + (r - 1) * cell
                local m  = RenderText:sizeUtf8Text(0, cinn, self.letter_face, ch, true, false)
                local tx = cx + pad + math.floor((cinn - m.x) / 2)
                local ty = cy + pad + math.floor((cinn + m.y_top - m.y_bottom) / 2)
                RenderText:renderUtf8Text(bb, tx, ty, self.letter_face, ch, true, false, C_TEXT)
            end
        end
    end
end

function WordSearchBoardWidget:refresh()
    UIManager:setDirty(self, function()
        return "ui", self.paint_rect or self.dimen
    end)
end

return WordSearchBoardWidget
