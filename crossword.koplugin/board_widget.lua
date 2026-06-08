local Blitbuffer     = require("ffi/blitbuffer")
local Font           = require("ui/font")
local Geom           = require("ui/geometry")
local GestureRange   = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local RenderText     = require("ui/rendertext")
local UIManager      = require("ui/uimanager")

local gwb      = require("grid_widget_base")
local drawLine = gwb.drawLine

local C_BG      = Blitbuffer.COLOR_WHITE
local C_FG      = Blitbuffer.COLOR_BLACK
local C_GRID    = Blitbuffer.COLOR_GRAY_9
local C_BLACK   = Blitbuffer.COLOR_BLACK
local C_SEL     = Blitbuffer.COLOR_GRAY_9
local C_WORD    = Blitbuffer.COLOR_GRAY_D
local C_WRONG   = Blitbuffer.COLOR_GRAY_4
local C_NUMBER  = Blitbuffer.COLOR_GRAY_2

-- ---------------------------------------------------------------------------
-- CrosswordBoardWidget
-- ---------------------------------------------------------------------------

local CrosswordBoardWidget = InputContainer:extend{
    board      = nil,
    max_width  = 0,
    max_height = 0,
    onCellTap  = nil,
    wrong_cells = nil,   -- optional: {r}{c} = bool
}

function CrosswordBoardWidget:init()
    local board = self.board
    local cell  = math.floor(math.min(self.max_width / board.cols, self.max_height / board.rows))
    cell = math.max(cell, 12)
    self.cell = cell
    self.w    = cell * board.cols
    self.h    = cell * board.rows
    self.dimen = Geom:new{ w = self.w, h = self.h }

    local fs = math.max(7, math.floor(cell * 0.6))
    self.letter_face = Font:getFace("cfont", fs)
    local ns = math.max(5, math.floor(cell * 0.28))
    self.num_face = Font:getFace("smallinfofont", ns)

    self.paint_rect = nil

    self.ges_events = {
        CellTap = { GestureRange:new{ ges = "tap", range = self.dimen } },
    }
end

function CrosswordBoardWidget:onCellTap(ges)
    if not self.paint_rect then return end
    local lx = ges.pos.x - self.paint_rect.x
    local ly = ges.pos.y - self.paint_rect.y
    if lx < 0 or ly < 0 or lx >= self.w or ly >= self.h then return end
    local c = math.floor(lx / self.cell) + 1
    local r = math.floor(ly / self.cell) + 1
    local board = self.board
    if r >= 1 and r <= board.rows and c >= 1 and c <= board.cols then
        if self.onCellTap then self.onCellTap(r, c) end
    end
    return true
end

function CrosswordBoardWidget:refresh()
    UIManager:setDirty(self, function()
        return "ui", self.paint_rect or self.dimen
    end)
end

function CrosswordBoardWidget:paintTo(bb, x, y)
    self.paint_rect = Geom:new{ x = x, y = y, w = self.w, h = self.h }
    local board  = self.board
    local cell   = self.cell
    local thin   = 1

    bb:paintRect(x, y, self.w, self.h, C_BG)

    -- Determine which cells are in the current word
    local in_word = {}
    local word_cells = board:getCurrentWordCells()
    for _, wc in ipairs(word_cells) do
        in_word[wc[1] * 1000 + wc[2]] = true
    end

    for r = 1, board.rows do
        for c = 1, board.cols do
            local cx = x + (c - 1) * cell
            local cy = y + (r - 1) * cell
            local sol = board.grid[r][c]
            local usr = board.user[r][c]
            local num = board.numbers[r] and board.numbers[r][c]
            local is_sel  = (r == board.sel_r and c == board.sel_c)
            local is_word = in_word[r * 1000 + c]
            local is_wrong = self.wrong_cells and self.wrong_cells[r]
                and self.wrong_cells[r][c]

            if sol == "#" then
                -- Black cell
                bb:paintRect(cx, cy, cell, cell, C_BLACK)
            else
                -- White cell
                local bg = is_sel  and C_SEL
                        or is_word and C_WORD
                        or is_wrong and C_WRONG
                        or C_BG
                bb:paintRect(cx, cy, cell, cell, bg)

                -- Cell number (top-left)
                if num then
                    RenderText:renderUtf8Text(bb, cx + 1, cy + (self.num_face.size or 7),
                        self.num_face, tostring(num), true, false, C_NUMBER)
                end

                -- User letter (centered)
                if usr and usr ~= "" and usr ~= "#" then
                    local m = RenderText:sizeUtf8Text(0, cell, self.letter_face, usr, true, false)
                    local tx = cx + math.floor((cell - m.x) / 2)
                    local ty = cy + math.floor((cell - (m.y_bottom - m.y_top)) / 2) + m.y_top
                    RenderText:renderUtf8Text(bb, tx, ty, self.letter_face, usr, true, false, C_FG)
                end

                -- Draw thin lines only between white cells
                drawLine(bb, cx, cy, thin, cell, C_GRID)
                drawLine(bb, cx, cy, cell, thin, C_GRID)
            end
        end
    end

    -- Outer border
    local bw = math.max(2, thin)
    drawLine(bb, x,              y,              self.w, bw, C_FG)
    drawLine(bb, x,              y + self.h - bw, self.w, bw, C_FG)
    drawLine(bb, x,              y,              bw, self.h, C_FG)
    drawLine(bb, x + self.w - bw, y,             bw, self.h, C_FG)
end

return CrosswordBoardWidget
