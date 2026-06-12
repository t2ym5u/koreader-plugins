-- ---------------------------------------------------------------------------
-- CoursBoardWidget — renders the 8×8 board for the chess lessons plugin.
-- Uses chess_pieces.lua for pixel-art piece rendering.
-- Supports flipping via the `flipped` field.
-- ---------------------------------------------------------------------------

local Blitbuffer = require("ffi/blitbuffer")
local Font       = require("ui/font")
local Geom       = require("ui/geometry")
local RenderText = require("ui/rendertext")

local gwb            = require("grid_widget_base")
local GridWidgetBase = gwb.GridWidgetBase
local ChessPieces    = require("chess_pieces")

local C_LIGHT_SQ = Blitbuffer.COLOR_GRAY_E
local C_DARK_SQ  = Blitbuffer.COLOR_GRAY_9
local C_SEL      = Blitbuffer.COLOR_GRAY_C
local C_LASTMOV  = Blitbuffer.COLOR_GRAY_B
local C_DOT      = Blitbuffer.COLOR_GRAY_3
local C_LINE     = Blitbuffer.COLOR_BLACK

-- ---------------------------------------------------------------------------
-- CoursBoardWidget
-- ---------------------------------------------------------------------------

local CoursBoardWidget = GridWidgetBase:extend{
    board        = nil,
    size_ratio   = 0.80,
    onCellAction = nil,
    cols         = 8,
    rows         = 8,
    -- last_move: {fr,fc,tr,tc} or nil
    last_move    = nil,
    -- flipped: true → black's perspective
    flipped      = false,
}

function CoursBoardWidget:init()
    GridWidgetBase.init(self)
    local cell_min   = math.min(self.cell_w, self.cell_h)
    local label_size = math.max(6, math.floor(cell_min * 0.22))
    self.label_face  = Font:getFace("smallinfofont", label_size)
end

function CoursBoardWidget:onCellTap(v_row, v_col)
    local br = self.flipped and (9 - v_row) or v_row
    local bc = self.flipped and (9 - v_col) or v_col
    if self.onCellAction then self.onCellAction(br, bc) end
end

-- ---------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------

function CoursBoardWidget:paintTo(bb, x, y)
    self.paint_rect = Geom:new{ x = x, y = y, w = self.dimen.w, h = self.dimen.h }

    local board = self.board
    local n     = 8
    local cw    = self.cell_w
    local ch    = self.cell_h
    local flip  = self.flipped
    local S     = self.size

    -- Selected square and valid targets
    local sel_r, sel_c
    if board.selected then
        sel_r = board.selected[1]
        sel_c = board.selected[2]
    end
    local move_targets = {}
    if sel_r then
        local moves = board:getMovesForSquare(sel_r, sel_c)
        for _, m in ipairs(moves) do
            move_targets[m.tr * 10 + m.tc] = true
        end
    end

    -- Last move
    local lm         = self.last_move
    local lm_key_fr  = lm and (lm.fr * 10 + lm.fc) or nil
    local lm_key_to  = lm and (lm.tr * 10 + lm.tc) or nil

    for v_row = 1, n do
        for v_col = 1, n do
            local br  = flip and (9 - v_row) or v_row
            local bc  = flip and (9 - v_col) or v_col
            local px  = x + math.floor((v_col - 1) * cw)
            local py  = y + math.floor((v_row - 1) * ch)
            local pcw = math.ceil(cw)
            local pch = math.ceil(ch)
            local key = br * 10 + bc

            -- Background
            local dark = (br + bc) % 2 == 1
            local bg
            if sel_r and br == sel_r and bc == sel_c then
                bg = C_SEL
            elseif lm and (key == lm_key_fr or key == lm_key_to) then
                bg = C_LASTMOV
            else
                bg = dark and C_DARK_SQ or C_LIGHT_SQ
            end
            bb:paintRect(px, py, pcw, pch, bg)

            -- Piece
            local v = board.sq[br][bc]
            if v ~= 0 then
                ChessPieces.drawPiece(bb, px, py, pcw, pch, v)
            end

            -- Valid-move dot
            if move_targets[key] then
                local dot = math.max(3, math.floor(math.min(cw, ch) * 0.18))
                bb:paintRect(px + math.floor(cw / 2) - math.floor(dot / 2),
                             py + math.floor(ch / 2) - math.floor(dot / 2),
                             dot, dot, C_DOT)
            end
        end
    end

    -- Grid lines
    local thick = math.max(2, math.floor(math.min(cw, ch) * 0.06))
    for i = 0, n do
        local lw    = (i == 0 or i == n) and thick or 1
        local color = (i == 0 or i == n) and C_LINE or Blitbuffer.COLOR_GRAY_9
        bb:paintRect(x + math.floor(i * cw), y,  lw, S, color)
        bb:paintRect(x, y + math.floor(i * ch),  S, lw, color)
    end

    -- Rank / file labels
    local file_letters = {"a","b","c","d","e","f","g","h"}
    local label_face   = self.label_face
    for i = 1, n do
        local board_row  = flip and i or (9 - i)
        local rank_label = tostring(board_row)
        local lx  = x + math.floor((i - 1) * cw) + 2
        local ly  = y + math.floor((i - 1) * ch) + 2
        local m1  = RenderText:sizeUtf8Text(0, 20, label_face, rank_label, true, false)
        RenderText:renderUtf8Text(bb, lx, ly + (m1.y_bottom or 0), label_face, rank_label,
            true, false, Blitbuffer.COLOR_GRAY_5)

        local board_col  = flip and (9 - i) or i
        local file_label = file_letters[board_col] or ""
        local lx2 = x + math.floor((i - 1) * cw) + math.floor(cw / 2)
        local m2  = RenderText:sizeUtf8Text(0, 20, label_face, file_label, true, false)
        RenderText:renderUtf8Text(bb, lx2 - math.floor(m2.x / 2),
            y + S - 3, label_face, file_label, true, false, Blitbuffer.COLOR_GRAY_5)
    end
end

return CoursBoardWidget
