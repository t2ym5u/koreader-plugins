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
-- Drawing helpers
-- ---------------------------------------------------------------------------

-- Draw a line between two points (Bresenham-style via steps)
local function drawThinLine(bb, x1, y1, x2, y2, color, thickness)
    thickness = thickness or 1
    local dx = x2 - x1
    local dy = y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then return end
    local steps = math.ceil(len)
    local half = math.floor(thickness / 2)
    for i = 0, steps do
        local t  = i / steps
        local px = math.floor(x1 + t * dx)
        local py = math.floor(y1 + t * dy)
        bb:paintRect(px - half, py - half, thickness, thickness, color)
    end
end

-- Draw an arrowhead pointing from (fx,fy) toward (tx,ty) at position (tx,ty)
local function drawArrowhead(bb, fx, fy, tx, ty, size, color)
    local dx = tx - fx
    local dy = ty - fy
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then return end
    local ux = dx / len
    local uy = dy / len
    -- perpendicular
    local px = -uy
    local py =  ux
    -- arrowhead triangle: tip at (tx,ty), two base points behind
    local base_x = tx - ux * size
    local base_y = ty - uy * size
    local lx = math.floor(base_x + px * size * 0.5)
    local ly = math.floor(base_y + py * size * 0.5)
    local rx = math.floor(base_x - px * size * 0.5)
    local ry = math.floor(base_y - py * size * 0.5)
    local tipx = math.floor(tx)
    local tipy = math.floor(ty)
    -- Draw filled triangle by drawing lines from tip to base edge
    local bsteps = size
    for s = 0, bsteps do
        local t = s / bsteps
        local bx = math.floor(lx + t * (rx - lx))
        local by = math.floor(ly + t * (ry - ly))
        drawThinLine(bb, tipx, tipy, bx, by, color, 1)
    end
end

-- ---------------------------------------------------------------------------
-- ArrowSudokuBoardWidget
-- ---------------------------------------------------------------------------

local ArrowSudokuBoardWidget = BaseBoardWidget:extend{
    board = nil,
}

function ArrowSudokuBoardWidget:init()
    BaseBoardWidget.init(self)
    -- Small font for arrow sum labels in the corner of source cells
    local cell = self.size / (self.n or 9)
    local label_size = math.max(8, math.floor(cell / 4))
    self.arrow_label_face = Font:getFace("smallinfofont", label_size)
end

function ArrowSudokuBoardWidget:paintTo(bb, x, y)
    if not self.board then return end
    local n        = self.n
    local box_rows = self.box_rows
    local box_cols = self.box_cols
    self.paint_rect = Geom:new{ x = x, y = y, w = self.dimen.w, h = self.dimen.h }
    local cell = self.dimen.w / n

    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)

    -- Draw selection highlight
    local sel_row, sel_col = self.board:getSelection()
    local band_highlight = Blitbuffer.COLOR_GRAY_D
    local cell_highlight = Blitbuffer.COLOR_GRAY
    bb:paintRect(x + (sel_col - 1) * cell, y, cell, self.dimen.h, band_highlight)
    bb:paintRect(x, y + (sel_row - 1) * cell, self.dimen.w, cell, band_highlight)
    bb:paintRect(x + (sel_col - 1) * cell, y + (sel_row - 1) * cell, cell, cell, cell_highlight)

    -- Draw arrows BEFORE grid lines
    local arrow_color = Blitbuffer.COLOR_GRAY_B
    local line_thick  = math.max(1, math.floor(cell * 0.06))
    local head_size   = math.max(3, math.floor(cell * 0.15))

    for _, arrow in ipairs(self.board.arrows or {}) do
        local src   = arrow.src
        local cells = arrow.cells
        if #cells >= 1 then
            -- Draw line from src center through each path cell center
            local prev_r, prev_c = src.r, src.c
            for _, cell_pos in ipairs(cells) do
                local x1 = math.floor(x + (prev_c - 0.5) * cell)
                local y1 = math.floor(y + (prev_r - 0.5) * cell)
                local x2 = math.floor(x + (cell_pos.c - 0.5) * cell)
                local y2 = math.floor(y + (cell_pos.r - 0.5) * cell)
                drawThinLine(bb, x1, y1, x2, y2, arrow_color, line_thick)
                prev_r, prev_c = cell_pos.r, cell_pos.c
            end
            -- Draw arrowhead at last path cell
            local last = cells[#cells]
            local second_last = #cells >= 2 and cells[#cells - 1] or src
            local fx = math.floor(x + (second_last.c - 0.5) * cell)
            local fy = math.floor(y + (second_last.r - 0.5) * cell)
            local tx = math.floor(x + (last.c - 0.5) * cell)
            local ty = math.floor(y + (last.r - 0.5) * cell)
            drawArrowhead(bb, fx, fy, tx, ty, head_size, arrow_color)

            -- Draw sum label in top-left corner of source cell
            local label = tostring(arrow.value)
            local src_x = x + (src.c - 1) * cell
            local src_y = y + (src.r - 1) * cell
            local pad   = math.max(1, math.floor(cell / 10))
            local face  = self.arrow_label_face
            local m = RenderText:sizeUtf8Text(0, cell - pad, face, label, true, false)
            RenderText:renderUtf8Text(bb, src_x + pad, src_y + pad + math.abs(m.y_top), face, label, true, false, arrow_color)
        end
    end

    -- Draw grid lines
    for i = 0, n do
        local v_thick = (i % box_cols == 0) and Size.line.thick or Size.line.thin
        local h_thick = (i % box_rows == 0) and Size.line.thick or Size.line.thin
        drawLine(bb, x + math.floor(i * cell), y, v_thick, self.dimen.h, Blitbuffer.COLOR_BLACK)
        drawLine(bb, x, y + math.floor(i * cell), self.dimen.w, h_thick, Blitbuffer.COLOR_BLACK)
    end

    -- Draw cell values
    for row = 1, n do
        for col = 1, n do
            local value, is_given = self.board:getDisplayValue(row, col)
            if value then
                local cell_x = x + (col - 1) * cell
                local cell_y = y + (row - 1) * cell
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
                local text        = digitToChar(value)
                local cell_padding = self.number_cell_padding or 0
                local cell_inner  = math.max(1, math.floor(cell - 2 * cell_padding))
                local metrics     = RenderText:sizeUtf8Text(0, cell_inner, self.number_face, text, true, false)
                local text_w      = metrics.x
                local baseline    = cell_y + cell_padding + math.floor((cell_inner + metrics.y_top - metrics.y_bottom) / 2)
                local text_x      = cell_x + cell_padding + math.floor((cell_inner - text_w) / 2)
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
                            local mini_x      = x + (col - 1) * cell + mini_col * mini_w
                            local mini_y      = y + (row - 1) * cell + mini_row * mini_h
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

return ArrowSudokuBoardWidget
