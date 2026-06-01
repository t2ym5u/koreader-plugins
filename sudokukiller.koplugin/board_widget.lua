local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local GestureRange = require("ui/gesturerange")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local RenderText = require("ui/rendertext")
local Size = require("ui/size")
local UIManager = require("ui/uimanager")

local Screen = Device.screen

-- Dashed line parameters (pixels on / pixels off)
local DASH_ON  = 3
local DASH_OFF = 3

-- ---------------------------------------------------------------------------
-- Drawing helpers
-- ---------------------------------------------------------------------------

local function drawLine(bb, x, y, w, h, color)
    bb:paintRect(x, y, w, h, color)
end

local function drawDiagonalLine(bb, x, y, length, dx, dy, color, thickness)
    color = color or Blitbuffer.COLOR_BLACK
    thickness = thickness or 1
    length = math.max(0, length)
    for step = 0, length do
        local px = math.floor(x + dx * step)
        local py = math.floor(y + dy * step)
        bb:paintRect(px, py, thickness, thickness, color)
    end
end

-- Draw a dashed horizontal or vertical line
local function drawDashedLine(bb, x, y, length, horizontal, color)
    color = color or Blitbuffer.COLOR_BLACK
    local pos = 0
    while pos < length do
        local seg = math.min(DASH_ON, length - pos)
        if seg > 0 then
            if horizontal then
                bb:paintRect(x + pos, y, seg, 1, color)
            else
                bb:paintRect(x, y + pos, 1, seg, color)
            end
        end
        pos = pos + DASH_ON + DASH_OFF
    end
end

-- ---------------------------------------------------------------------------
-- KillerSudokuBoardWidget — renders the 9×9 killer sudoku grid
-- ---------------------------------------------------------------------------

local KillerSudokuBoardWidget = InputContainer:extend{
    board = nil,
}

function KillerSudokuBoardWidget:init()
    local n        = self.board and self.board.n        or 9
    local box_rows = self.board and self.board.box_rows or 3
    local box_cols = self.board and self.board.box_cols or 3
    self.n        = n
    self.box_rows = box_rows
    self.box_cols = box_cols

    self.size = math.floor(math.min(Screen:getWidth(), Screen:getHeight()) * 0.82)
    self.dimen = Geom:new{ w = self.size, h = self.size }
    self.paint_rect = Geom:new{ x = 0, y = 0, w = self.size, h = self.size }
    self.number_face = Font:getFace("cfont", math.max(28, math.floor(self.size / 14)))
    self.note_face = Font:getFace("smallinfofont", math.max(16, math.floor(self.size / 28)))
    self.number_face_size = self.number_face.size
    self.number_cell_padding = 0
    self.note_face_size = self.note_face.size
    self.note_mini_padding = 0

    -- Cage sum label font: small text in the top-left corner of cage label cells
    local cell_size = self.size / n
    local sum_font_size = math.max(8, math.floor(cell_size * 0.28))
    self.cage_sum_face = Font:getFace("smallinfofont", sum_font_size)
    self.cage_sum_padding = math.max(1, math.floor(cell_size / 12))

    -- Note font: sized to fit in a mini cell (cell / box_cols × cell / box_rows)
    do
        local cell = self.size / n
        local mini_w = cell / box_cols
        local mini_h = cell / box_rows
        local padding = math.max(1, math.floor(math.min(mini_w, mini_h) / 8))
        local safety  = math.max(1, math.floor(math.min(mini_w, mini_h) / 18))
        local max_w = math.max(1, math.floor(mini_w - 2 * padding - safety))
        local max_h = math.max(1, math.floor(mini_h - 2 * padding - safety))
        local size = self.note_face_size
        while size > 8 do
            local face = Font:getFace("smallinfofont", size)
            local m = RenderText:sizeUtf8Text(0, max_w, face, "8", true, false)
            local h = m.y_bottom - m.y_top
            if m.x <= max_w and h <= max_h then
                local final_size = math.max(8, size - 2)
                self.note_face = Font:getFace("smallinfofont", final_size)
                self.note_face_size = final_size
                self.note_mini_padding = padding
                break
            end
            size = size - 1
        end
    end

    -- Number font: sized to fit in a full cell
    do
        local cell = self.size / n
        local padding = math.max(2, math.floor(cell / 9))
        local safety  = math.max(1, math.floor(cell / 20))
        local max_w = math.max(1, math.floor(cell - 2 * padding - safety))
        local max_h = math.max(1, math.floor(cell - 2 * padding - safety))
        local size = self.number_face_size
        while size > 10 do
            local face = Font:getFace("cfont", size)
            local m = RenderText:sizeUtf8Text(0, max_w, face, "8", true, false)
            local h = m.y_bottom - m.y_top
            if m.x <= max_w and h <= max_h then
                local final_size = math.max(10, size - 4)
                self.number_face = Font:getFace("cfont", final_size)
                self.number_face_size = final_size
                self.number_cell_padding = padding
                break
            end
            size = size - 1
        end
    end

    self.ges_events = {
        Tap = {
            GestureRange:new{
                ges = "tap",
                range = function() return self.paint_rect end,
            }
        }
    }
end

function KillerSudokuBoardWidget:getCellFromPoint(x, y)
    local rect = self.paint_rect
    local local_x = x - rect.x
    local local_y = y - rect.y
    if local_x < 0 or local_y < 0 or local_x > rect.w or local_y > rect.h then
        return nil
    end
    local cell_size = rect.w / self.n
    local col = math.floor(local_x / cell_size) + 1
    local row = math.floor(local_y / cell_size) + 1
    if row < 1 or row > self.n or col < 1 or col > self.n then
        return nil
    end
    return row, col
end

function KillerSudokuBoardWidget:onTap(_, ges)
    if not (self.board and ges and ges.pos) then
        return false
    end
    local row, col = self:getCellFromPoint(ges.pos.x, ges.pos.y)
    if not row then
        return false
    end
    self.board:setSelection(row, col)
    if self.onSelectionChanged then
        self.onSelectionChanged(row, col)
    end
    self:refresh()
    return true
end

function KillerSudokuBoardWidget:refresh()
    local rect = self.paint_rect
    UIManager:setDirty(self, function()
        return "ui", Geom:new{ x = rect.x, y = rect.y, w = rect.w, h = rect.h }
    end)
end

function KillerSudokuBoardWidget:paintTo(bb, x, y)
    if not self.board then return end
    local n        = self.n
    local box_rows = self.box_rows
    local box_cols = self.box_cols
    self.paint_rect = Geom:new{ x = x, y = y, w = self.dimen.w, h = self.dimen.h }
    local cell = self.dimen.w / n

    -- 1. White background
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)

    -- 2. Selection highlight (row band, column band, selected cell)
    local sel_row, sel_col = self.board:getSelection()
    local band_highlight = Blitbuffer.COLOR_GRAY_D
    local cell_highlight = Blitbuffer.COLOR_GRAY
    bb:paintRect(x + (sel_col - 1) * cell, y, cell, self.dimen.h, band_highlight)
    bb:paintRect(x, y + (sel_row - 1) * cell, self.dimen.w, cell, band_highlight)
    bb:paintRect(x + (sel_col - 1) * cell, y + (sel_row - 1) * cell, cell, cell, cell_highlight)

    -- 3. Standard grid lines (thin everywhere, thick at box boundaries)
    for i = 0, n do
        local v_thick = (i % box_cols == 0) and Size.line.thick or Size.line.thin
        local h_thick = (i % box_rows == 0) and Size.line.thick or Size.line.thin
        drawLine(bb, x + math.floor(i * cell), y, v_thick, self.dimen.h, Blitbuffer.COLOR_BLACK)
        drawLine(bb, x, y + math.floor(i * cell), self.dimen.w, h_thick, Blitbuffer.COLOR_BLACK)
    end

    -- 4. Cage boundary dashed lines
    -- Draw only on edges that are cage boundaries AND are not box boundaries
    -- (box boundaries are already solid thick lines)
    if self.board.cages and #self.board.cages > 0 then
        local border_color = Blitbuffer.COLOR_BLACK
        -- Horizontal cage boundaries: between row r and row r+1
        for row = 1, n - 1 do
            for col = 1, n do
                if self.board:isCageBoundary(row, col, row + 1, col) then
                    local bx = math.floor(x + (col - 1) * cell)
                    local by = math.floor(y + row * cell)  -- bottom edge of row r
                    drawDashedLine(bb, bx, by, math.floor(cell), true, border_color)
                end
            end
        end
        -- Vertical cage boundaries: between col c and col c+1
        for row = 1, n do
            for col = 1, n - 1 do
                if self.board:isCageBoundary(row, col, row, col + 1) then
                    local bx = math.floor(x + col * cell)  -- right edge of col c
                    local by = math.floor(y + (row - 1) * cell)
                    drawDashedLine(bb, bx, by, math.floor(cell), false, border_color)
                end
            end
        end
    end

    -- 5. Cell content (numbers, wrong marks, notes)
    for row = 1, n do
        for col = 1, n do
            local value = self.board:getDisplayValue(row, col)
            if value then
                local cell_x = x + (col - 1) * cell
                local cell_y = y + (row - 1) * cell
                local color
                if self.board:isShowingSolution() then
                    color = Blitbuffer.COLOR_GRAY_4
                else
                    color = Blitbuffer.COLOR_GRAY_2
                end
                if self.board:isConflict(row, col) then
                    color = Blitbuffer.COLOR_RED
                end
                local text = tostring(value)
                local cell_padding = self.number_cell_padding or 0
                -- Reserve space for cage sum label in top-left corner
                local sum_reserve = self.cage_sum_padding + self.cage_sum_face.size
                local cell_inner_w = math.max(1, math.floor(cell - 2 * cell_padding))
                local metrics = RenderText:sizeUtf8Text(0, cell_inner_w, self.number_face, text, true, false)
                local text_w = metrics.x
                -- Center number in the lower portion of the cell (below sum label)
                local avail_h = math.max(1, cell - sum_reserve - cell_padding)
                local baseline = cell_y + sum_reserve + math.floor((avail_h + metrics.y_top - metrics.y_bottom) / 2)
                local text_x = cell_x + cell_padding + math.floor((cell_inner_w - text_w) / 2)
                RenderText:renderUtf8Text(bb, text_x, baseline, self.number_face, text, true, false, color)

                -- Wrong mark: diagonal cross
                if self.board:hasWrongMark(row, col) then
                    local padding = math.max(1, math.floor(cell / 12))
                    local diag_len = math.max(0, math.floor(cell - padding * 2))
                    local cross_thickness = math.max(2, math.floor(cell / 18))
                    drawDiagonalLine(bb, cell_x + padding, cell_y + padding, diag_len, 1, 1, Blitbuffer.COLOR_BLACK, cross_thickness)
                    drawDiagonalLine(bb, cell_x + padding, cell_y + cell - padding, diag_len, 1, -1, Blitbuffer.COLOR_BLACK, cross_thickness)
                end
            else
                -- Empty cell: draw notes if any
                local notes = self.board:getCellNotes(row, col)
                if notes then
                    local mini_w = cell / box_cols
                    local mini_h = cell / box_rows
                    local mini_padding = self.note_mini_padding or 0
                    local mini_inner_w = math.max(1, math.floor(mini_w - 2 * mini_padding))
                    local mini_inner_h = math.max(1, math.floor(mini_h - 2 * mini_padding))
                    for digit = 1, n do
                        if notes[digit] then
                            local mini_col = (digit - 1) % box_cols
                            local mini_row = math.floor((digit - 1) / box_cols)
                            local mini_x = x + (col - 1) * cell + mini_col * mini_w
                            local mini_y = y + (row - 1) * cell + mini_row * mini_h
                            local note_text = tostring(digit)
                            local note_metrics = RenderText:sizeUtf8Text(0, mini_inner_w, self.note_face, note_text, true, false)
                            local note_baseline = mini_y + mini_padding + math.floor((mini_inner_h + note_metrics.y_top - note_metrics.y_bottom) / 2)
                            local note_x = mini_x + mini_padding + math.floor((mini_inner_w - note_metrics.x) / 2)
                            RenderText:renderUtf8Text(bb, note_x, note_baseline, self.note_face, note_text, true, false, Blitbuffer.COLOR_GRAY_4)
                        end
                    end
                end
            end
        end
    end

    -- 6. Cage sum labels: small number in top-left corner of each cage's label cell
    if self.board.cages and #self.board.cages > 0 then
        local pad = self.cage_sum_padding or 1
        for _, cage in ipairs(self.board.cages) do
            local label_cell = self.board:getCageLabelCell(cage)
            if label_cell then
                local label_text = tostring(cage.sum)
                local cell_x = math.floor(x + (label_cell.c - 1) * cell)
                local cell_y = math.floor(y + (label_cell.r - 1) * cell)
                local baseline = cell_y + pad + self.cage_sum_face.size
                RenderText:renderUtf8Text(bb, cell_x + pad, baseline, self.cage_sum_face, label_text, true, false, Blitbuffer.COLOR_BLACK)
            end
        end
    end
end

return KillerSudokuBoardWidget
