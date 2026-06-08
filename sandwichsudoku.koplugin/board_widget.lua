local Blitbuffer    = require("ffi/blitbuffer")
local Font          = require("ui/font")
local Geom          = require("ui/geometry")
local RenderText    = require("ui/rendertext")

local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire_common(name)
    local key = _dir .. "common/" .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. "common/" .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local common           = lrequire_common("base_board_widget")
local BaseBoardWidget  = common.BaseBoardWidget
local drawLine         = common.drawLine
local drawDiagonalLine = common.drawDiagonalLine

local Size = require("ui/size")

local DISPLAY_PINS_ON_GIVEN = true

local function digitToChar(d)
    return d <= 9 and tostring(d) or string.char(55 + d)
end

-- ---------------------------------------------------------------------------
-- SandwichSudokuBoardWidget
--
-- Layout: The widget reserves a margin on all 4 sides for clue numbers.
-- The 9x9 grid is drawn inset. Row clues appear on the left margin,
-- column clues appear on the top margin.
-- ---------------------------------------------------------------------------

local SandwichSudokuBoardWidget = BaseBoardWidget:extend{
    board = nil,
}

function SandwichSudokuBoardWidget:init()
    BaseBoardWidget.init(self)
    local n = self.n or 9
    -- Reserve a margin around the grid for clue numbers
    -- The total widget size stays the same; grid is drawn smaller inside it
    local total = self.size
    local clue_margin = math.max(20, math.floor(total * 0.08))
    self.clue_margin   = clue_margin
    self.grid_size     = total - 2 * clue_margin
    -- Clue font: sized to fit in the margin
    local clue_size = math.max(8, math.floor(clue_margin * 0.6))
    self.clue_face  = Font:getFace("smallinfofont", clue_size)
end

function SandwichSudokuBoardWidget:paintTo(bb, x, y)
    if not self.board then return end
    local n        = self.n
    local box_rows = self.box_rows
    local box_cols = self.box_cols
    self.paint_rect = Geom:new{ x = x, y = y, w = self.dimen.w, h = self.dimen.h }

    local margin    = self.clue_margin
    local grid_size = self.grid_size
    -- Grid origin (top-left corner of the 9x9 grid)
    local gx = x + margin
    local gy = y + margin
    local cell = grid_size / n

    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)

    -- Draw selection highlight (within grid area)
    local sel_row, sel_col = self.board:getSelection()
    local band_highlight = Blitbuffer.COLOR_GRAY_D
    local cell_highlight = Blitbuffer.COLOR_GRAY
    bb:paintRect(gx + (sel_col - 1) * cell, gy, cell, grid_size, band_highlight)
    bb:paintRect(gx, gy + (sel_row - 1) * cell, grid_size, cell, band_highlight)
    bb:paintRect(gx + (sel_col - 1) * cell, gy + (sel_row - 1) * cell, cell, cell, cell_highlight)

    -- Draw grid lines
    for i = 0, n do
        local v_thick = (i % box_cols == 0) and Size.line.thick or Size.line.thin
        local h_thick = (i % box_rows == 0) and Size.line.thick or Size.line.thin
        drawLine(bb, gx + math.floor(i * cell), gy, v_thick, grid_size, Blitbuffer.COLOR_BLACK)
        drawLine(bb, gx, gy + math.floor(i * cell), grid_size, h_thick, Blitbuffer.COLOR_BLACK)
    end

    -- Draw row clues in left margin and right margin (we use left)
    local clue_color = Blitbuffer.COLOR_BLACK
    local clue_face  = self.clue_face
    for r = 1, n do
        local clue_val = self.board.row_clues and self.board.row_clues[r]
        if clue_val then
            local text = tostring(clue_val)
            local cell_cy = gy + (r - 0.5) * cell
            local m = RenderText:sizeUtf8Text(0, margin - 2, clue_face, text, true, false)
            local tx = x + math.floor((margin - m.x) / 2)
            local ty = math.floor(cell_cy) - math.floor((m.y_bottom - m.y_top) / 2) + math.abs(m.y_top)
            RenderText:renderUtf8Text(bb, tx, ty, clue_face, text, true, false, clue_color)
        end
    end

    -- Draw column clues in top margin
    for c = 1, n do
        local clue_val = self.board.col_clues and self.board.col_clues[c]
        if clue_val then
            local text = tostring(clue_val)
            local cell_cx = gx + (c - 0.5) * cell
            local m = RenderText:sizeUtf8Text(0, cell, clue_face, text, true, false)
            local tx = math.floor(cell_cx) - math.floor(m.x / 2)
            local ty = y + math.floor((margin - (m.y_bottom - m.y_top)) / 2) + math.abs(m.y_top)
            RenderText:renderUtf8Text(bb, tx, ty, clue_face, text, true, false, clue_color)
        end
    end

    -- Draw cell values
    for row = 1, n do
        for col = 1, n do
            local value, is_given = self.board:getDisplayValue(row, col)
            if value then
                local cell_x = gx + (col - 1) * cell
                local cell_y = gy + (row - 1) * cell
                local color
                if self.board:isShowingSolution() and not is_given then
                    color = Blitbuffer.COLOR_GRAY_4
                elseif is_given then
                    color = Blitbuffer.COLOR_BLACK
                else
                    color = Blitbuffer.COLOR_GRAY_2
                end
                if self.board:isConflict(row, col) then
                    color = Blitbuffer.COLOR_RED
                end
                local text         = digitToChar(value)
                local cell_padding = self.number_cell_padding or 0
                local cell_inner   = math.max(1, math.floor(cell - 2 * cell_padding))
                local metrics      = RenderText:sizeUtf8Text(0, cell_inner, self.number_face, text, true, false)
                local text_w       = metrics.x
                local baseline     = cell_y + cell_padding + math.floor((cell_inner + metrics.y_top - metrics.y_bottom) / 2)
                local text_x       = cell_x + cell_padding + math.floor((cell_inner - text_w) / 2)
                RenderText:renderUtf8Text(bb, text_x, baseline, self.number_face, text, true, false, color)
                if is_given and DISPLAY_PINS_ON_GIVEN then
                    local dot     = math.max(1, math.floor(cell / 18))
                    local padding = math.max(1, math.floor(cell / 20))
                    local dot_color = Blitbuffer.COLOR_GRAY_4
                    bb:paintRect(cell_x + padding,              cell_y + padding,              dot, dot, dot_color)
                    bb:paintRect(cell_x + cell - padding - dot, cell_y + padding,              dot, dot, dot_color)
                    bb:paintRect(cell_x + padding,              cell_y + cell - padding - dot, dot, dot, dot_color)
                    bb:paintRect(cell_x + cell - padding - dot, cell_y + cell - padding - dot, dot, dot, dot_color)
                elseif self.board:hasWrongMark(row, col) then
                    local padding   = math.max(1, math.floor(cell / 12))
                    local diag_len  = math.max(0, math.floor(cell - padding * 2))
                    local thickness = math.max(2, math.floor(cell / 18))
                    drawDiagonalLine(bb, cell_x + padding, cell_y + padding,        diag_len, 1,  1, Blitbuffer.COLOR_BLACK, thickness)
                    drawDiagonalLine(bb, cell_x + padding, cell_y + cell - padding, diag_len, 1, -1, Blitbuffer.COLOR_BLACK, thickness)
                end
            else
                local notes = self.board:getCellNotes(row, col)
                if notes then
                    local mini_w       = cell / box_cols
                    local mini_h       = cell / box_rows
                    local mini_padding = self.note_mini_padding or 0
                    local mini_inner_w = math.max(1, math.floor(mini_w - 2 * mini_padding))
                    local mini_inner_h = math.max(1, math.floor(mini_h - 2 * mini_padding))
                    for digit = 1, n do
                        if notes[digit] then
                            local mini_col    = (digit - 1) % box_cols
                            local mini_row    = math.floor((digit - 1) / box_cols)
                            local mini_x      = gx + (col - 1) * cell + mini_col * mini_w
                            local mini_y      = gy + (row - 1) * cell + mini_row * mini_h
                            local note_text   = digitToChar(digit)
                            local note_m      = RenderText:sizeUtf8Text(0, mini_inner_w, self.note_face, note_text, true, false)
                            local note_baseline = mini_y + mini_padding + math.floor((mini_inner_h + note_m.y_top - note_m.y_bottom) / 2)
                            local note_x      = mini_x + mini_padding + math.floor((mini_inner_w - note_m.x) / 2)
                            RenderText:renderUtf8Text(bb, note_x, note_baseline, self.note_face, note_text, true, false, Blitbuffer.COLOR_GRAY_4)
                        end
                    end
                end
            end
        end
    end
end

-- Override getCellFromPoint to account for the margin offset
function SandwichSudokuBoardWidget:getCellFromPoint(x, y)
    local rect    = self.paint_rect
    local margin  = self.clue_margin
    local gs      = self.grid_size
    local n       = self.n
    local local_x = x - rect.x - margin
    local local_y = y - rect.y - margin
    if local_x < 0 or local_y < 0 or local_x > gs or local_y > gs then
        return nil
    end
    local cell_size = gs / n
    local col = math.floor(local_x / cell_size) + 1
    local row = math.floor(local_y / cell_size) + 1
    if row < 1 or row > n or col < 1 or col > n then
        return nil
    end
    return row, col
end

return SandwichSudokuBoardWidget
