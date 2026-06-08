local Blitbuffer     = require("ffi/blitbuffer")
local Font           = require("ui/font")
local Geom           = require("ui/geometry")
local GestureRange   = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local RenderText     = require("ui/rendertext")
local UIManager      = require("ui/uimanager")

-- Color palette
local C_BG       = Blitbuffer.COLOR_WHITE
local C_FG       = Blitbuffer.COLOR_BLACK
local C_CLUE_BG  = Blitbuffer.COLOR_GRAY_4    -- dark background for clue cells
local C_SEL_BG   = Blitbuffer.COLOR_GRAY_D    -- highlight for selected cell
local C_GRID     = Blitbuffer.COLOR_GRAY_9    -- grid lines
local C_CLUE_FG  = Blitbuffer.COLOR_WHITE     -- clue text color

-- ---------------------------------------------------------------------------
-- Arrow drawing helpers
--
-- We draw arrows as small filled triangles at the edge of a clue cell.
-- Arrow "r" (right): triangle pointing right at the right edge.
-- Arrow "d" (down):  triangle pointing down at the bottom edge.
-- ---------------------------------------------------------------------------

local function drawArrowRight(bb, cx, cy, cw, ch)
    -- Small right-pointing triangle at the right side of the cell
    local aw = math.max(3, math.floor(cw * 0.18))   -- arrow width (depth)
    local ah = math.max(3, math.floor(ch * 0.28))   -- arrow height
    local tip_x = cx + cw - 1                         -- rightmost x
    local mid_y = cy + math.floor(ch / 2)             -- vertical center
    -- Draw filled triangle: base on the left, tip on the right
    for i = 0, aw do
        local half = math.floor(ah * i / aw / 2)
        local ystart = mid_y - half
        local yend   = mid_y + half
        if yend >= ystart then
            bb:paintRect(tip_x - aw + i, ystart, 1, yend - ystart + 1, C_FG)
        end
    end
end

local function drawArrowDown(bb, cx, cy, cw, ch)
    -- Small down-pointing triangle at the bottom of the cell
    local ah = math.max(3, math.floor(ch * 0.18))   -- arrow height (depth)
    local aw = math.max(3, math.floor(cw * 0.28))   -- arrow width
    local tip_y = cy + ch - 1                         -- bottom y
    local mid_x = cx + math.floor(cw / 2)             -- horizontal center
    for i = 0, ah do
        local half = math.floor(aw * i / ah / 2)
        local xstart = mid_x - half
        local xend   = mid_x + half
        if xend >= xstart then
            bb:paintRect(xstart, tip_y - ah + i, xend - xstart + 1, 1, C_FG)
        end
    end
end

-- ---------------------------------------------------------------------------
-- ArrowwordsBoardWidget
-- ---------------------------------------------------------------------------

local ArrowwordsBoardWidget = InputContainer:extend{
    board      = nil,
    max_width  = 200,
    max_height = 200,
    onCellTap  = nil,
}

function ArrowwordsBoardWidget:init()
    local board = self.board
    local n     = board.n
    local cell  = math.floor(math.min(self.max_width, self.max_height) / n)
    cell        = math.max(cell, 14)
    self.cell   = cell
    self.w      = cell * n
    self.h      = cell * n
    self.dimen  = Geom:new{ w = self.w, h = self.h }
    self.paint_rect = nil

    -- Letter font: large, centered in letter cell
    local lfs = math.max(8, math.floor(cell * 0.55))
    self.letter_face = Font:getFace("cfont", lfs)

    -- Clue font: tiny, to fit clue text inside a cell
    local cfs = math.max(5, math.floor(cell * 0.16))
    self.clue_face = Font:getFace("smallinfofont", cfs)

    self.ges_events = {
        CellTap = { GestureRange:new{ ges = "tap", range = self.dimen } },
    }
end

function ArrowwordsBoardWidget:onCellTap(ges)
    if not self.paint_rect then return true end
    local rect = self.paint_rect
    local lx   = ges.pos.x - rect.x
    local ly   = ges.pos.y - rect.y
    if lx < 0 or ly < 0 or lx >= self.w or ly >= self.h then return true end
    local c = math.floor(lx / self.cell) + 1
    local r = math.floor(ly / self.cell) + 1
    local n = self.board.n
    if r >= 1 and r <= n and c >= 1 and c <= n then
        if self.onCellTap then self.onCellTap(r, c) end
    end
    return true
end

function ArrowwordsBoardWidget:refresh()
    UIManager:setDirty(self, function()
        return "ui", self.paint_rect or self.dimen
    end)
end

-- Render multi-line clue text inside a cell.
-- Splits on "\n" and renders each line, fitting within the cell.
function ArrowwordsBoardWidget:_drawClueText(bb, text, cx, cy, cw, ch)
    if not text or text == "" then return end
    local face   = self.clue_face
    local line_h = math.max(6, math.floor(ch * 0.19))
    local pad    = math.max(1, math.floor(cw * 0.06))
    local avail_w = cw - 2 * pad

    -- Split into lines
    local lines = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        if line ~= "" then
            lines[#lines + 1] = line
        end
    end

    -- Limit to what fits vertically (reserve bottom for arrow)
    -- Also limit total lines to avoid overflow
    local max_lines = math.floor((ch * 0.65) / line_h)
    if max_lines < 1 then max_lines = 1 end

    local total_h = math.min(#lines, max_lines) * line_h
    local start_y = cy + math.floor((ch * 0.5 - total_h) / 2)
    if start_y < cy + pad then start_y = cy + pad end

    for i = 1, math.min(#lines, max_lines) do
        local line = lines[i]
        -- Truncate to fit width
        local m = RenderText:sizeUtf8Text(0, avail_w, face, line, true, false)
        while #line > 1 and m.x > avail_w do
            line = line:sub(1, -2)
            m = RenderText:sizeUtf8Text(0, avail_w, face, line, true, false)
        end
        if #line > 0 then
            local tx = cx + pad
            local ty = start_y + (i - 1) * line_h + line_h
            RenderText:renderUtf8Text(bb, tx, ty, face, line, true, false, C_CLUE_FG)
        end
    end
end

function ArrowwordsBoardWidget:paintTo(bb, x, y)
    self.paint_rect = Geom:new{ x = x, y = y, w = self.w, h = self.h }
    local board = self.board
    local n     = board.n
    local cell  = self.cell

    -- Background
    bb:paintRect(x, y, self.w, self.h, C_BG)

    for r = 1, n do
        for c = 1, n do
            local cx = x + (c - 1) * cell
            local cy = y + (r - 1) * cell
            local cdef = board:getCell(r, c)
            local is_sel = (r == board.sel_r and c == board.sel_c)

            if cdef.t == "c" then
                -- Clue cell: dark background
                bb:paintRect(cx, cy, cell, cell, C_CLUE_BG)

                -- Draw clue text
                self:_drawClueText(bb, cdef.tx, cx, cy, cell, cell)

                -- Draw arrow(s)
                local a = cdef.a
                if a == "r" or a == "b" then
                    drawArrowRight(bb, cx, cy, cell, cell)
                end
                if a == "d" or a == "b" then
                    drawArrowDown(bb, cx, cy, cell, cell)
                end
            else
                -- Letter cell
                local bg = is_sel and C_SEL_BG or C_BG
                bb:paintRect(cx, cy, cell, cell, bg)

                -- Draw user letter if any
                local letter = board.user[r][c]
                if letter and letter ~= "" then
                    local face = self.letter_face
                    local pad  = math.max(2, math.floor(cell * 0.1))
                    local avail = cell - 2 * pad
                    local m = RenderText:sizeUtf8Text(0, avail, face, letter, true, false)
                    local tx = cx + pad + math.floor((avail - m.x) / 2)
                    local ty = cy + pad + math.floor((avail + m.y_top - m.y_bottom) / 2) - m.y_top
                    if ty < cy + 1 then ty = cy + 1 end
                    RenderText:renderUtf8Text(bb, tx, ty, face, letter, true, false, C_FG)
                end

                -- Thin grid lines for letter cells only
                bb:paintRect(cx, cy, 1, cell, C_GRID)
                bb:paintRect(cx, cy, cell, 1, C_GRID)
            end
        end
    end

    -- Outer border (thick)
    local thick = math.max(2, math.floor(cell * 0.05))
    bb:paintRect(x,              y,              self.w, thick, C_FG)
    bb:paintRect(x,              y + self.h - thick, self.w, thick, C_FG)
    bb:paintRect(x,              y,              thick, self.h, C_FG)
    bb:paintRect(x + self.w - thick, y,          thick, self.h, C_FG)
end

return ArrowwordsBoardWidget
