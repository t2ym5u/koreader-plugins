local Blitbuffer     = require("ffi/blitbuffer")
local Font           = require("ui/font")
local Geom           = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local RenderText     = require("ui/rendertext")

local gwb      = require("grid_widget_base")
local drawLine = gwb.drawLine

local C_BG    = Blitbuffer.COLOR_WHITE
local C_FG    = Blitbuffer.COLOR_BLACK
local C_GRAY  = Blitbuffer.COLOR_GRAY_9

-- ---------------------------------------------------------------------------
-- HangmanBoardWidget — draws the gallows, figure, word, and wrong letters
-- ---------------------------------------------------------------------------

local HangmanBoardWidget = InputContainer:extend{
    board      = nil,
    width      = 200,
    height     = 200,
}

function HangmanBoardWidget:init()
    self.dimen = Geom:new{ w = self.width, h = self.height }

    local word_size = math.max(10, math.floor(self.width * 0.07))
    self.word_face   = Font:getFace("cfont",       word_size)
    local info_size  = math.max(8,  math.floor(self.width * 0.05))
    self.info_face   = Font:getFace("smallinfofont", info_size)
    self.paint_rect  = nil
end

function HangmanBoardWidget:refresh()
    local UIManager = require("ui/uimanager")
    UIManager:setDirty(self, function()
        return "ui", self.paint_rect or self.dimen
    end)
end

function HangmanBoardWidget:paintTo(bb, x, y)
    self.paint_rect = Geom:new{ x = x, y = y, w = self.width, h = self.height }
    bb:paintRect(x, y, self.width, self.height, C_BG)

    local w, h = self.width, self.height
    local board = self.board
    local wrong = board.wrong
    local max_w = board:maxWrong()

    -- Gallows area: top 55% of height
    local gall_h = math.floor(h * 0.55)
    self:_drawGallows(bb, x, y, w, gall_h, wrong, max_w)

    -- Word display: below gallows
    local word_y = y + gall_h + math.floor(h * 0.03)
    local display = board:getDisplay()
    local m = RenderText:sizeUtf8Text(0, w, self.word_face, display, true, false)
    local tx = x + math.floor((w - m.x) / 2)
    RenderText:renderUtf8Text(bb, tx, word_y + m.y_top, self.word_face, display, true, false, C_FG)

    -- Wrong letters label
    local wrong_letters = board:getWrongLetters()
    if #wrong_letters > 0 then
        local wrong_str = table.concat(wrong_letters, " ")
        local wy = word_y + math.floor(h * 0.13)
        local wm = RenderText:sizeUtf8Text(0, w, self.info_face, wrong_str, true, false)
        local wx = x + math.floor((w - wm.x) / 2)
        RenderText:renderUtf8Text(bb, wx, wy + wm.y_top, self.info_face, wrong_str, true, false, C_GRAY)
    end
end

function HangmanBoardWidget:_drawGallows(bb, x, y, w, h, wrong, max_w)
    local lw = math.max(2, math.floor(w * 0.025))   -- line width
    local px = x + math.floor(w * 0.15)             -- gallows left edge
    local py = y + math.floor(h * 0.05)             -- gallows top

    -- Base
    drawLine(bb, px, y + h - lw, math.floor(w * 0.5), lw, C_FG)
    -- Vertical pole
    local pole_h = math.floor(h * 0.85)
    drawLine(bb, px, y + h - lw - pole_h, lw, pole_h, C_FG)
    -- Horizontal beam
    local beam_w = math.floor(w * 0.35)
    drawLine(bb, px, py, beam_w, lw, C_FG)
    -- Rope
    local rope_x = px + beam_w - lw
    local rope_h = math.floor(h * 0.12)
    drawLine(bb, rope_x, py + lw, lw, rope_h, C_FG)

    -- Figure parts drawn based on wrong count
    -- Scale figure relative to how many wrong steps we have (max 6 or 8)
    local steps_per_part = max_w <= 6 and 1 or math.floor(max_w / 6)
    local parts = math.floor(wrong / steps_per_part + 0.5)
    parts = math.min(parts, 6)

    local head_cy = py + lw + rope_h
    local head_r  = math.max(4, math.floor(h * 0.09))
    local body_top = head_cy + head_r
    local body_len = math.floor(h * 0.2)
    local body_cx  = rope_x + math.floor(lw / 2)
    local arm_len  = math.floor(h * 0.12)
    local leg_len  = math.floor(h * 0.15)

    if parts >= 1 then -- head
        bb:paintCircle(body_cx, head_cy, head_r, C_FG, true)
        bb:paintCircle(body_cx, head_cy, head_r - lw, C_BG, true)
    end
    if parts >= 2 then -- body
        drawLine(bb, body_cx - math.floor(lw/2), body_top, lw, body_len, C_FG)
    end
    if parts >= 3 then -- left arm
        local ax = body_cx - math.floor(lw/2)
        local ay = body_top + math.floor(body_len * 0.25)
        local len = arm_len
        for step = 0, len do
            local px2 = ax - step
            local py2 = ay + step
            bb:paintRect(px2, py2, lw, lw, C_FG)
        end
    end
    if parts >= 4 then -- right arm
        local ax = body_cx + math.floor(lw/2)
        local ay = body_top + math.floor(body_len * 0.25)
        local len = arm_len
        for step = 0, len do
            local px2 = ax + step
            local py2 = ay + step
            bb:paintRect(px2, py2, lw, lw, C_FG)
        end
    end
    if parts >= 5 then -- left leg
        local lx = body_cx - math.floor(lw/2)
        local ly = body_top + body_len
        local len = leg_len
        for step = 0, len do
            local px2 = lx - step
            local py2 = ly + step
            bb:paintRect(px2, py2, lw, lw, C_FG)
        end
    end
    if parts >= 6 then -- right leg
        local lx = body_cx + math.floor(lw/2)
        local ly = body_top + body_len
        local len = leg_len
        for step = 0, len do
            local px2 = lx + step
            local py2 = ly + step
            bb:paintRect(px2, py2, lw, lw, C_FG)
        end
    end
end

return HangmanBoardWidget
