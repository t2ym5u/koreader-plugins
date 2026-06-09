local Blitbuffer = require("ffi/blitbuffer")
local Font       = require("ui/font")
local Geom       = require("ui/geometry")
local RenderText = require("ui/rendertext")
local UIManager  = require("ui/uimanager")

local gwb            = require("grid_widget_base")
local GridWidgetBase = gwb.GridWidgetBase
local drawLine       = gwb.drawLine

-- Square colors (e-ink friendly)
local C_LIGHT_SQ = Blitbuffer.COLOR_GRAY_E   -- light squares (r+c even)
local C_DARK_SQ  = Blitbuffer.COLOR_GRAY_9   -- dark squares (r+c odd)
local C_SEL      = Blitbuffer.COLOR_GRAY_D   -- selected square highlight
local C_DOT      = Blitbuffer.COLOR_GRAY_4   -- valid-move dot
local C_LINE     = Blitbuffer.COLOR_BLACK    -- grid lines

-- French piece letter abbreviations
-- P=pion, T=tour, C=cavalier, F=fou, D=dame, R=roi
local PIECE_LETTER = {
    [1]  = "P",  -- W_PAWN
    [2]  = "T",  -- W_ROOK
    [3]  = "C",  -- W_KNIGHT
    [4]  = "F",  -- W_BISHOP
    [5]  = "D",  -- W_QUEEN
    [6]  = "R",  -- W_KING
    [7]  = "P",  -- B_PAWN
    [8]  = "T",  -- B_ROOK
    [9]  = "C",  -- B_KNIGHT
    [10] = "F",  -- B_BISHOP
    [11] = "D",  -- B_QUEEN
    [12] = "R",  -- B_KING
}

-- ---------------------------------------------------------------------------
-- CoursBoardWidget
-- ---------------------------------------------------------------------------

local CoursBoardWidget = GridWidgetBase:extend{
    board        = nil,
    size_ratio   = 0.80,
    onCellAction = nil,
}

function CoursBoardWidget:init()
    self.cols = 8
    self.rows = 8
    GridWidgetBase.init(self)
end

function CoursBoardWidget:onCellTap(row, col)
    if self.onCellAction then self.onCellAction(row, col) end
end

function CoursBoardWidget:paintTo(bb, x, y)
    -- Update paint_rect for gesture hit-testing
    self.paint_rect = Geom:new{ x = x, y = y, w = self.dimen.w, h = self.dimen.h }

    local board = self.board
    local n     = 8
    local cw    = self.cell_w
    local ch    = self.cell_h

    -- Draw background squares
    for r = 1, n do
        for c = 1, n do
            local cx  = x + math.floor((c - 1) * cw)
            local cy  = y + math.floor((r - 1) * ch)
            local cew = math.ceil(cw)
            local ceh = math.ceil(ch)
            -- Light square when (r+c) is even; dark when odd
            local dark = (r + c) % 2 == 1
            bb:paintRect(cx, cy, cew, ceh, dark and C_DARK_SQ or C_LIGHT_SQ)
        end
    end

    -- Draw selected square highlight
    if board.selected then
        local sr = board.selected[1]
        local sc = board.selected[2]
        local sx = x + math.floor((sc - 1) * cw)
        local sy = y + math.floor((sr - 1) * ch)
        bb:paintRect(sx, sy, math.ceil(cw), math.ceil(ch), C_SEL)
    end

    -- Build valid-move target set for the selected piece
    local move_targets = {}
    if board.selected then
        local sr, sc = board.selected[1], board.selected[2]
        local moves = board:getMovesForSquare(sr, sc)
        for _, m in ipairs(moves) do
            move_targets[m.tr * 10 + m.tc] = true
        end
    end

    local face = self.number_face

    -- Draw pieces and valid-move dots
    for r = 1, n do
        for c = 1, n do
            local v = board.sq[r][c]

            -- Draw piece
            if v ~= 0 then
                local cx  = x + math.floor((c - 1) * cw)
                local cy  = y + math.floor((r - 1) * ch)
                local cew = math.ceil(cw)
                local ceh = math.ceil(ch)
                local pad = math.max(3, math.floor(math.min(cew, ceh) * 0.12))
                local pw  = cew - 2 * pad
                local ph  = ceh - 2 * pad

                local fill, border, letter_color
                if v <= 6 then
                    -- White piece
                    fill         = Blitbuffer.COLOR_WHITE
                    border       = Blitbuffer.COLOR_BLACK
                    letter_color = Blitbuffer.COLOR_BLACK
                else
                    -- Black piece
                    fill         = Blitbuffer.COLOR_BLACK
                    border       = Blitbuffer.COLOR_GRAY_4
                    letter_color = Blitbuffer.COLOR_WHITE
                end

                -- Piece body
                bb:paintRect(cx + pad, cy + pad, pw, ph, fill)

                -- Border (4 sides, 1-pixel thick minimum)
                local bw = math.max(1, math.floor(math.min(cew, ceh) * 0.05))
                bb:paintRect(cx + pad,           cy + pad,           pw, bw, border)
                bb:paintRect(cx + pad,           cy + pad + ph - bw, pw, bw, border)
                bb:paintRect(cx + pad,           cy + pad,           bw, ph, border)
                bb:paintRect(cx + pad + pw - bw, cy + pad,           bw, ph, border)

                -- Piece letter
                local letter = PIECE_LETTER[v]
                if letter and face then
                    local m  = RenderText:sizeUtf8Text(0, pw - 2, face, letter, true, false)
                    local tx = cx + math.floor((cew - m.x) / 2)
                    local ty = cy + math.floor((ceh - (m.y_bottom - m.y_top)) / 2) - m.y_top
                    RenderText:renderUtf8Text(bb, tx, ty, face, letter, true, false, letter_color)
                end
            end

            -- Draw valid-move dot (small square at cell center)
            if move_targets[r * 10 + c] then
                local cx  = x + math.floor((c - 1) * cw)
                local cy  = y + math.floor((r - 1) * ch)
                local dot = math.max(3, math.floor(math.min(cw, ch) * 0.15))
                local mx  = cx + math.floor(cw / 2) - math.floor(dot / 2)
                local my  = cy + math.floor(ch / 2) - math.floor(dot / 2)
                bb:paintRect(mx, my, dot, dot, C_DOT)
            end
        end
    end

    -- Draw grid lines (thin interior, thick border)
    local thin  = 1
    local thick = math.max(2, math.floor(math.min(cw, ch) * 0.06))
    for i = 0, n do
        local lw = (i == 0 or i == n) and thick or thin
        drawLine(bb, x + math.floor(i * cw), y, lw, self.dimen.h, C_LINE)
        drawLine(bb, x, y + math.floor(i * ch), self.dimen.w, lw, C_LINE)
    end
end

return CoursBoardWidget
