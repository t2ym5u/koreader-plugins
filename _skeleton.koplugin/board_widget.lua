local Blitbuffer = require("ffi/blitbuffer")
local common     = require("grid_widget_base")

local GridWidgetBase = common.GridWidgetBase
local drawLine       = common.drawLine
local drawCenteredText = common.drawCenteredText

-- ---------------------------------------------------------------------------
-- MyGameBoardWidget — renders the game grid
-- ---------------------------------------------------------------------------

local MyGameBoardWidget = GridWidgetBase:extend{
    -- board: MyGameBoard instance (set by caller)
}

function MyGameBoardWidget:init()
    self.cols = self.board and self.board.cols or 9
    self.rows = self.board and self.board.rows or 9
    GridWidgetBase.init(self)  -- computes size, fonts, gestures
end

-- ---------------------------------------------------------------------------
-- Cell tap / hold — delegate to the screen
-- ---------------------------------------------------------------------------

function MyGameBoardWidget:onCellTap(row, col)
    if self.onCellSelected then
        self.onCellSelected(row, col, false)
    end
end

function MyGameBoardWidget:onCellHold(row, col)
    if self.onCellSelected then
        self.onCellSelected(row, col, true)
    end
end

-- ---------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------

function MyGameBoardWidget:paintTo(bb, x, y)
    local rect = self.paint_rect
    rect.x = x
    rect.y = y

    local board    = self.board
    local cols     = self.cols
    local rows     = self.rows
    local cell_w   = self.cell_w
    local cell_h   = self.cell_h

    -- White background
    bb:paintRect(x, y, rect.w, rect.h, Blitbuffer.COLOR_WHITE)

    -- Draw cells
    for r = 1, rows do
        for c = 1, cols do
            local cx = x + math.floor((c - 1) * cell_w)
            local cy = y + math.floor((r - 1) * cell_h)
            -- TODO: draw cell content from board.grid[r][c]
        end
    end

    -- Draw grid lines
    for c = 0, cols do
        local lx = x + math.floor(c * cell_w)
        drawLine(bb, lx, y, 1, rect.h, Blitbuffer.COLOR_BLACK)
    end
    for r = 0, rows do
        local ly = y + math.floor(r * cell_h)
        drawLine(bb, x, ly, rect.w, 1, Blitbuffer.COLOR_BLACK)
    end
end

return MyGameBoardWidget
