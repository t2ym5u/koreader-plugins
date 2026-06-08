local Blitbuffer     = require("ffi/blitbuffer")
local Font           = require("ui/font")
local Geom           = require("ui/geometry")
local GestureRange   = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local RenderText     = require("ui/rendertext")
local UIManager      = require("ui/uimanager")

local C_BG       = Blitbuffer.COLOR_WHITE
local C_CELL     = Blitbuffer.COLOR_GRAY_E
local C_SELECTED = Blitbuffer.COLOR_GRAY_9
local C_DECODED  = Blitbuffer.COLOR_GRAY_D
local C_BORDER   = Blitbuffer.COLOR_BLACK
local C_TEXT     = Blitbuffer.COLOR_BLACK
local C_DIM      = Blitbuffer.COLOR_GRAY_7

-- ---------------------------------------------------------------------------
-- CryptogramBoardWidget
-- ---------------------------------------------------------------------------

local CryptogramBoardWidget = InputContainer:extend{
    board       = nil,
    max_width   = 300,
    max_height  = 200,
    onCipherTap = nil,
}

function CryptogramBoardWidget:init()
    local cell_w = math.max(12, math.floor(self.max_width / 20))
    local cell_h = math.max(20, math.floor(self.max_height / 4))
    -- Each position is 2 rows tall: cipher + decoded
    -- We'll figure actual height from layout
    self.cell_w = cell_w
    self.cell_h = math.floor(cell_h / 2)

    local face_sz = math.max(6, math.floor(self.cell_h * 0.6))
    self.letter_face  = Font:getFace("smallinfofont", face_sz)
    local small_sz = math.max(5, math.floor(self.cell_h * 0.5))
    self.small_face   = Font:getFace("smallinfofont", small_sz)

    self:_layout()

    self.ges_events = {
        CipherTap = { GestureRange:new{ ges = "tap", range = self.dimen } },
    }
end

function CryptogramBoardWidget:_layout()
    local board     = self.board
    local ciphered  = board.ciphered
    local cell_w    = self.cell_w
    local cell_h    = self.cell_h
    local row_h     = cell_h * 2 + 4
    local max_w     = self.max_width

    -- word-wrap into rows
    local rows    = {}
    local cur_row = {}
    local cur_x   = 0

    local i = 1
    while i <= #ciphered do
        -- find next word (sequence of letters or space)
        local ch = ciphered:sub(i, i)
        if ch == " " then
            -- space token: wrap if needed, otherwise add gap
            if cur_x + cell_w > max_w and #cur_row > 0 then
                rows[#rows + 1] = cur_row
                cur_row = {}
                cur_x   = 0
            end
            cur_row[#cur_row + 1] = { ch = " ", idx = i }
            cur_x = cur_x + cell_w
            i = i + 1
        else
            -- single cipher letter
            if cur_x + cell_w > max_w and #cur_row > 0 then
                rows[#rows + 1] = cur_row
                cur_row = {}
                cur_x   = 0
            end
            cur_row[#cur_row + 1] = { ch = ch, idx = i }
            cur_x = cur_x + cell_w
            i = i + 1
        end
    end
    if #cur_row > 0 then rows[#rows + 1] = cur_row end

    self.rows  = rows
    local w    = 0
    for _, row in ipairs(rows) do
        local rw = #row * cell_w
        if rw > w then w = rw end
    end
    self.w     = math.min(w, max_w)
    self.h     = #rows * row_h + 4
    self.row_h = row_h
    self.dimen = Geom:new{ w = self.w, h = self.h }
    self.paint_rect = nil
end

function CryptogramBoardWidget:onCipherTap(ges)
    if not self.paint_rect then return true end
    local rect = self.paint_rect
    local lx = ges.pos.x - rect.x
    local ly = ges.pos.y - rect.y
    if lx < 0 or ly < 0 or lx >= self.w or ly >= self.h then return true end

    local row_h  = self.row_h
    local cell_w = self.cell_w
    local cell_h = self.cell_h

    local row_idx = math.floor(ly / row_h) + 1
    -- only the top half (cipher row) is tappable
    local within_row_y = ly - (row_idx - 1) * row_h
    if within_row_y >= cell_h then return true end

    local col_idx = math.floor(lx / cell_w) + 1

    if row_idx >= 1 and row_idx <= #self.rows then
        local row = self.rows[row_idx]
        if col_idx >= 1 and col_idx <= #row then
            local token = row[col_idx]
            if token and token.ch ~= " " and token.ch >= "A" and token.ch <= "Z" then
                if self.onCipherTap then self.onCipherTap(token.ch) end
            end
        end
    end
    return true
end

function CryptogramBoardWidget:paintTo(bb, x, y)
    self.paint_rect = Geom:new{ x = x, y = y, w = self.w, h = self.h }
    local board    = self.board
    local cell_w   = self.cell_w
    local cell_h   = self.cell_h
    local row_h    = self.row_h
    local pad      = math.max(1, math.floor(cell_h * 0.08))

    bb:paintRect(x, y, self.w, self.h, C_BG)

    for ri, row in ipairs(self.rows) do
        local ry = y + (ri - 1) * row_h
        for ci, token in ipairs(row) do
            local cx = x + (ci - 1) * cell_w
            local is_letter = token.ch >= "A" and token.ch <= "Z"
            if is_letter then
                local is_sel = token.ch == board.selected_cipher
                local decoded = board.user_map[token.ch]

                -- cipher cell
                local bg1 = is_sel and C_SELECTED or C_CELL
                bb:paintRect(cx + 1, ry + 1, cell_w - 2, cell_h - 2, bg1)
                bb:paintRect(cx, ry, cell_w, 1, C_BORDER)
                bb:paintRect(cx, ry + cell_h - 1, cell_w, 1, C_BORDER)
                bb:paintRect(cx, ry, 1, cell_h, C_BORDER)
                bb:paintRect(cx + cell_w - 1, ry, 1, cell_h, C_BORDER)

                -- cipher letter
                local cw_inner = cell_w - 2 * pad
                local m1 = RenderText:sizeUtf8Text(0, cw_inner, self.letter_face, token.ch, true, false)
                local tx1 = cx + pad + math.floor((cw_inner - m1.x) / 2)
                local ty1 = ry + pad + math.floor((cell_h - 2*pad + m1.y_top - m1.y_bottom) / 2)
                RenderText:renderUtf8Text(bb, tx1, ty1, self.letter_face, token.ch, true, false, C_DIM)

                -- decoded cell
                local dy = ry + cell_h + 4
                bb:paintRect(cx + 1, dy + 1, cell_w - 2, cell_h - 2, C_DECODED)
                bb:paintRect(cx, dy, cell_w, 1, C_BORDER)
                bb:paintRect(cx, dy + cell_h - 1, cell_w, 1, C_BORDER)
                bb:paintRect(cx, dy, 1, cell_h, C_BORDER)
                bb:paintRect(cx + cell_w - 1, dy, 1, cell_h, C_BORDER)

                if decoded then
                    local m2 = RenderText:sizeUtf8Text(0, cw_inner, self.letter_face, decoded, true, false)
                    local tx2 = cx + pad + math.floor((cw_inner - m2.x) / 2)
                    local ty2 = dy + pad + math.floor((cell_h - 2*pad + m2.y_top - m2.y_bottom) / 2)
                    RenderText:renderUtf8Text(bb, tx2, ty2, self.letter_face, decoded, true, false, C_TEXT)
                end
            end
        end
    end
end

function CryptogramBoardWidget:refresh()
    UIManager:setDirty(self, function()
        return "ui", self.paint_rect or self.dimen
    end)
end

return CryptogramBoardWidget
