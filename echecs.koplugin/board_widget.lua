-- ---------------------------------------------------------------------------
-- EchecsBoardWidget — renders the 8×8 chess board
-- Extends GridWidgetBase (8 cols × 8 rows)
--
-- French piece letters:
--   P = Pion (pawn)
--   T = Tour (rook)
--   C = Cavalier (knight)
--   F = Fou (bishop)
--   D = Dame (queen)
--   R = Roi (king)
-- ---------------------------------------------------------------------------

local Blitbuffer      = require("ffi/blitbuffer")
local Font            = require("ui/font")
local RenderText      = require("ui/rendertext")

local gwb            = require("grid_widget_base")
local GridWidgetBase = gwb.GridWidgetBase

-- ---------------------------------------------------------------------------
-- Piece letters (French notation)
-- ---------------------------------------------------------------------------

local PIECE_LETTER = {
    [1]="P",  [2]="T",  [3]="C",  [4]="F",  [5]="D",  [6]="R",
    [7]="P",  [8]="T",  [9]="C",  [10]="F", [11]="D", [12]="R",
}

-- Square colors
local SQ_LIGHT    = Blitbuffer.COLOR_GRAY_E   -- light squares
local SQ_DARK     = Blitbuffer.COLOR_GRAY_9   -- dark squares
local SQ_SEL      = Blitbuffer.COLOR_GRAY_D   -- selected square highlight
local SQ_LAST_FR  = Blitbuffer.COLOR_GRAY_B   -- last move: from square
local SQ_LAST_TO  = Blitbuffer.COLOR_GRAY_B   -- last move: to square
local DOT_COLOR   = Blitbuffer.COLOR_GRAY_4   -- valid move dot

-- Piece box colors
local WHITE_FILL   = Blitbuffer.COLOR_WHITE
local BLACK_FILL   = Blitbuffer.COLOR_BLACK
local WHITE_BORDER = Blitbuffer.COLOR_BLACK
local BLACK_BORDER = Blitbuffer.COLOR_GRAY_E
local WHITE_TEXT   = Blitbuffer.COLOR_BLACK
local BLACK_TEXT   = Blitbuffer.COLOR_WHITE

-- ---------------------------------------------------------------------------
-- EchecsBoardWidget
-- ---------------------------------------------------------------------------

local EchecsBoardWidget = GridWidgetBase:extend{
    board        = nil,
    size_ratio   = 0.80,
    onCellAction = nil,
    cols         = 8,
    rows         = 8,
    -- last_move: {fr,fc,tr,tc} or nil (set by screen after each move)
    last_move    = nil,
}

function EchecsBoardWidget:init()
    GridWidgetBase.init(self)
    -- Use a slightly smaller font for pieces to fit with borders
    local cell_min = math.min(self.cell_w, self.cell_h)
    local piece_size = math.max(8, math.floor(cell_min * 0.50))
    self.piece_face = Font:getFace("cfont", piece_size)

    -- Small label font for rank/file annotations
    local label_size = math.max(6, math.floor(cell_min * 0.22))
    self.label_face = Font:getFace("smallinfofont", label_size)
end

function EchecsBoardWidget:onCellTap(r, c)
    if self.onCellAction then
        self.onCellAction(r, c)
    end
end

-- ---------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------

function EchecsBoardWidget:paintTo(bb, x, y)
    -- Update paint_rect so gesture detection is accurate
    self.paint_rect = require("ui/geometry"):new{
        x = x, y = y, w = self.size, h = self.size
    }

    local board = self.board
    local sq    = board and board.sq
    if not sq then return end

    local cell_w = self.cell_w
    local cell_h = self.cell_h

    -- Selected piece and its valid target squares
    local sel_r, sel_c
    if board.selected then
        sel_r = board.selected.r
        sel_c = board.selected.c
    end

    -- Build set of valid target squares for selected piece
    local valid_targets = {}
    if sel_r then
        local moves = board:getMovesForSquare(sel_r, sel_c)
        for _, m in ipairs(moves) do
            valid_targets[m.tr * 8 + m.tc] = true
        end
    end

    -- Last move squares
    local lm = self.last_move
    local lm_key_fr = lm and (lm.fr * 8 + lm.fc) or nil
    local lm_key_to = lm and (lm.tr * 8 + lm.tc) or nil

    for r = 1, 8 do
        for c = 1, 8 do
            local cx = x + math.floor((c - 1) * cell_w)
            local cy = y + math.floor((r - 1) * cell_h)
            local cw = math.ceil(cell_w)
            local ch = math.ceil(cell_h)

            -- Determine square background color
            -- Standard chess: light square when (r+c) is even
            -- (r=8,c=1 = a1 = light square: 8+1=9 odd → use (r+c)%2==0 for light)
            local is_light = ((r + c) % 2 == 0)
            local bg

            local key = r * 8 + c
            if sel_r and r == sel_r and c == sel_c then
                bg = SQ_SEL
            elseif lm and (key == lm_key_fr or key == lm_key_to) then
                bg = SQ_LAST_FR
            elseif is_light then
                bg = SQ_LIGHT
            else
                bg = SQ_DARK
            end

            bb:paintRect(cx, cy, cw, ch, bg)

            -- Valid move dot (small filled square at center)
            if valid_targets[key] then
                local dot_sz = math.max(3, math.floor(math.min(cw, ch) * 0.22))
                local dot_x  = cx + math.floor((cw - dot_sz) / 2)
                local dot_y  = cy + math.floor((ch - dot_sz) / 2)
                bb:paintRect(dot_x, dot_y, dot_sz, dot_sz, DOT_COLOR)
            end

            -- Draw piece
            local piece = sq[r][c]
            if piece ~= 0 then
                self:_drawPiece(bb, cx, cy, cw, ch, piece)
            end
        end
    end

    -- Draw board border
    bb:paintRect(x,              y,               self.size, 1,          Blitbuffer.COLOR_BLACK)
    bb:paintRect(x,              y + self.size-1, self.size, 1,          Blitbuffer.COLOR_BLACK)
    bb:paintRect(x,              y,               1,         self.size,  Blitbuffer.COLOR_BLACK)
    bb:paintRect(x + self.size-1, y,              1,         self.size,  Blitbuffer.COLOR_BLACK)

    -- Draw grid lines (thin, between cells)
    for i = 1, 7 do
        local lx = x + math.floor(i * cell_w)
        local ly = y + math.floor(i * cell_h)
        -- Vertical
        bb:paintRect(lx, y, 1, self.size, Blitbuffer.COLOR_GRAY_9)
        -- Horizontal
        bb:paintRect(x, ly, self.size, 1, Blitbuffer.COLOR_GRAY_9)
    end

    -- Rank labels (1-8) on left edge, File labels (a-h) on bottom edge
    local file_letters = {"a","b","c","d","e","f","g","h"}
    local label_face = self.label_face
    for i = 1, 8 do
        -- File label at bottom (r=8, each column)
        local rank_label = tostring(9 - i)   -- r=1 → rank 8, r=8 → rank 1
        local lx = x + math.floor((i - 1) * cell_w) + 1
        local ly_rank = y + math.floor((i - 1) * cell_h) + 1
        -- Rank number at left of each row
        local m = RenderText:sizeUtf8Text(0, 20, label_face, rank_label, true, false)
        local ty = ly_rank + (m.y_bottom or 0)
        RenderText:renderUtf8Text(bb, lx, ty, label_face, rank_label, true, false,
            Blitbuffer.COLOR_GRAY_5)

        -- File letter at bottom of each column
        local file_label = file_letters[i]
        local m2 = RenderText:sizeUtf8Text(0, 20, label_face, file_label, true, false)
        local bottom_y = y + self.size - 2
        local tx = lx + math.floor(cell_w / 2) - math.floor(m2.x / 2)
        RenderText:renderUtf8Text(bb, tx, bottom_y, label_face, file_label, true, false,
            Blitbuffer.COLOR_GRAY_5)
    end
end

function EchecsBoardWidget:_drawPiece(bb, cx, cy, cw, ch, piece)
    local is_white = (piece >= 1 and piece <= 6)
    local fill     = is_white and WHITE_FILL  or BLACK_FILL
    local border   = is_white and WHITE_BORDER or BLACK_BORDER
    local text_col = is_white and WHITE_TEXT  or BLACK_TEXT
    local letter   = PIECE_LETTER[piece] or "?"

    local pad    = math.max(2, math.floor(math.min(cw, ch) * 0.08))
    local bord   = math.max(1, math.floor(math.min(cw, ch) * 0.06))

    local bx = cx + pad
    local by = cy + pad
    local bw = cw - 2 * pad
    local bh = ch - 2 * pad

    -- Fill
    bb:paintRect(bx, by, bw, bh, fill)
    -- Border (4 lines)
    bb:paintRect(bx,          by,          bw, bord, border)
    bb:paintRect(bx,          by+bh-bord,  bw, bord, border)
    bb:paintRect(bx,          by,          bord, bh,  border)
    bb:paintRect(bx+bw-bord,  by,          bord, bh,  border)

    -- Piece letter centered
    local avail_w = bw - 2 * bord
    local avail_h = bh - 2 * bord
    local m = RenderText:sizeUtf8Text(0, avail_w, self.piece_face, letter, true, false)
    local text_w = m.x
    local text_h = m.y_bottom - m.y_top
    local tx = bx + bord + math.floor((avail_w - text_w) / 2)
    local ty = by + bord + math.floor((avail_h - text_h) / 2) + (m.y_bottom or 0)
    RenderText:renderUtf8Text(bb, tx, ty, self.piece_face, letter, true, false, text_col)
end

return EchecsBoardWidget
