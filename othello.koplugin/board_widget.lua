-- ---------------------------------------------------------------------------
-- OthelloBoardWidget — renders an 8x8 Othello board
-- ---------------------------------------------------------------------------

local Blitbuffer = require("ffi/blitbuffer")
local Geom       = require("ui/geometry")

local gwb            = require("grid_widget_base")
local GridWidgetBase = gwb.GridWidgetBase
local drawLine       = gwb.drawLine

-- Color palette (e-ink friendly)
local C_BOARD   = Blitbuffer.COLOR_GRAY_9   -- board background (dark green substitute)
local C_CELL    = Blitbuffer.COLOR_GRAY_E   -- individual cell background
local C_LINE    = Blitbuffer.COLOR_GRAY_D   -- internal grid lines
local C_BORDER  = Blitbuffer.COLOR_BLACK    -- outer border
local C_BLACK   = Blitbuffer.COLOR_BLACK    -- black disc fill
local C_BLACK_B = Blitbuffer.COLOR_GRAY_4   -- black disc border highlight
local C_WHITE   = Blitbuffer.COLOR_WHITE    -- white disc fill
local C_WHITE_B = Blitbuffer.COLOR_BLACK    -- white disc border
local C_DOT     = Blitbuffer.COLOR_GRAY_9   -- valid-move indicator dot
local C_LAST    = Blitbuffer.COLOR_BLACK    -- last-move marker outline

-- ---------------------------------------------------------------------------
-- OthelloBoardWidget
-- ---------------------------------------------------------------------------

local OthelloBoardWidget = GridWidgetBase:extend{
    board        = nil,
    size_ratio   = 0.82,
    onCellAction = nil,
}

function OthelloBoardWidget:init()
    self.cols = 8
    self.rows = 8
    GridWidgetBase.init(self)
end

function OthelloBoardWidget:onCellTap(row, col)
    if self.onCellAction then self.onCellAction(row, col) end
end

function OthelloBoardWidget:paintTo(bb, x, y)
    -- Save paint_rect for gesture hit-testing
    self.paint_rect = Geom:new{ x = x, y = y, w = self.dimen.w, h = self.dimen.h }

    local board = self.board
    local grid  = board.grid
    local n     = 8
    local cw    = self.cell_w
    local ch    = self.cell_h

    -- Full board background
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, C_BOARD)

    -- Precompute valid moves for current player (only when playing)
    local valid_set = {}
    if board.status == "playing" then
        local valid = board:getValidMoves(board.turn)
        for _, pos in ipairs(valid) do
            valid_set[pos.r * 10 + pos.c] = true
        end
    end

    -- Draw each cell
    for r = 1, n do
        for c = 1, n do
            local cx  = x + math.floor((c - 1) * cw)
            local cy  = y + math.floor((r - 1) * ch)
            local cew = math.ceil(cw)
            local ceh = math.ceil(ch)

            -- Cell background
            bb:paintRect(cx + 1, cy + 1, cew - 2, ceh - 2, C_CELL)

            local v = grid[r][c]

            if v ~= 0 then
                -- Draw disc (black or white)
                local pad = math.max(3, math.floor(math.min(cew, ceh) * 0.12))
                local pw  = cew - 2 * pad
                local ph  = ceh - 2 * pad
                local fill, border

                if v == 1 then  -- BLACK
                    fill   = C_BLACK
                    border = C_BLACK_B
                else            -- WHITE
                    fill   = C_WHITE
                    border = C_WHITE_B
                end

                -- Fill disc body
                bb:paintRect(cx + pad, cy + pad, pw, ph, fill)

                -- Border (4 sides, 1px)
                local bw = math.max(1, math.floor(math.min(cew, ceh) * 0.04))
                bb:paintRect(cx + pad,           cy + pad,           pw, bw, border)
                bb:paintRect(cx + pad,           cy + pad + ph - bw, pw, bw, border)
                bb:paintRect(cx + pad,           cy + pad,           bw, ph, border)
                bb:paintRect(cx + pad + pw - bw, cy + pad,           bw, ph, border)

            elseif valid_set[r * 10 + c] then
                -- Valid-move indicator: small centered dot
                local dot = math.max(3, math.floor(math.min(cw, ch) * 0.18))
                local mx  = cx + math.floor(cew / 2) - math.floor(dot / 2)
                local my  = cy + math.floor(ceh / 2) - math.floor(dot / 2)
                bb:paintRect(mx, my, dot, dot, C_DOT)
            end

            -- Last-move indicator: small outline square inside the cell
            if board.last_r == r and board.last_c == c then
                local mp  = math.max(2, math.floor(math.min(cew, ceh) * 0.25))
                local mw  = cew - 2 * mp
                local mh  = ceh - 2 * mp
                local lw  = math.max(1, math.floor(math.min(cew, ceh) * 0.04))
                -- Draw outline (4 sides)
                bb:paintRect(cx + mp,           cy + mp,           mw, lw, C_LAST)
                bb:paintRect(cx + mp,           cy + mp + mh - lw, mw, lw, C_LAST)
                bb:paintRect(cx + mp,           cy + mp,           lw, mh, C_LAST)
                bb:paintRect(cx + mp + mw - lw, cy + mp,           lw, mh, C_LAST)
            end
        end
    end

    -- Grid lines (thin inner, thick outer border)
    local thin  = 1
    local thick = math.max(2, math.floor(math.min(cw, ch) * 0.06))

    for i = 0, n do
        local lw = (i == 0 or i == n) and thick or thin
        local color = (i == 0 or i == n) and C_BORDER or C_LINE
        drawLine(bb, x + math.floor(i * cw), y, lw, self.dimen.h, color)
        drawLine(bb, x, y + math.floor(i * ch), self.dimen.w, lw, color)
    end
end

return OthelloBoardWidget
