local Blitbuffer     = require("ffi/blitbuffer")
local Font           = require("ui/font")
local GestureRange   = require("ui/gesturerange")
local Geom           = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local RenderText     = require("ui/rendertext")
local UIManager      = require("ui/uimanager")

local C_BG       = Blitbuffer.COLOR_WHITE
local C_PLATFORM = Blitbuffer.COLOR_BLACK
local C_PEG      = Blitbuffer.COLOR_GRAY_5
local C_DISK_BG  = Blitbuffer.COLOR_GRAY_B
local C_DISK_SEL = Blitbuffer.COLOR_GRAY_9
local C_DISK_BDR = Blitbuffer.COLOR_BLACK
local C_SEL_COL  = Blitbuffer.COLOR_GRAY_E
local C_LABEL    = Blitbuffer.COLOR_BLACK

-- ---------------------------------------------------------------------------
-- HanoiBoardWidget
-- ---------------------------------------------------------------------------

local HanoiBoardWidget = InputContainer:extend{
    board      = nil,
    max_width  = 200,
    max_height = 200,
    onPegTap   = nil,
}

function HanoiBoardWidget:init()
    local w = self.max_width
    local h = self.max_height
    self.w = w
    self.h = h
    self.dimen = Geom:new{ x = 0, y = 0, w = w, h = h }
    self.paint_rect = Geom:new{ x = 0, y = 0, w = w, h = h }

    local label_sz = math.max(8, math.floor(h * 0.06))
    self.label_face = Font:getFace("smallinfofont", label_sz)

    self.ges_events = {
        PegTap = {
            GestureRange:new{
                ges   = "tap",
                range = function() return self.paint_rect end,
            }
        },
    }
end

function HanoiBoardWidget:onPegTap(_, ges)
    if not (ges and ges.pos) then return false end
    local rect = self.paint_rect
    local lx   = ges.pos.x - rect.x
    local ly   = ges.pos.y - rect.y
    if lx < 0 or ly < 0 or lx >= rect.w or ly >= rect.h then return false end
    local zone_w = rect.w / 3
    local peg    = math.floor(lx / zone_w) + 1
    if peg < 1 then peg = 1 end
    if peg > 3 then peg = 3 end
    if self.onPegTap then self.onPegTap(peg) end
    return true
end

function HanoiBoardWidget:refresh()
    local rect = self.paint_rect
    UIManager:setDirty(self, function()
        return "ui", Geom:new{ x = rect.x, y = rect.y, w = rect.w, h = rect.h }
    end)
end

function HanoiBoardWidget:paintTo(bb, x, y)
    self.paint_rect = Geom:new{ x = x, y = y, w = self.w, h = self.h }
    local board = self.board
    local nd    = board.num_disks
    local w, h  = self.w, self.h

    bb:paintRect(x, y, w, h, C_BG)

    local label_h    = math.floor(h * 0.08)
    local platform_h = math.max(4, math.floor(h * 0.04))
    local play_h     = h - label_h - platform_h
    local peg_w      = math.max(4, math.floor(w * 0.02))
    local zone_w     = math.floor(w / 3)
    local cell_w     = math.floor(zone_w * 0.7)  -- max disk width
    local peg_h      = math.floor(play_h * 0.85)

    -- Draw platform
    local plat_y = y + play_h
    bb:paintRect(x, plat_y, w, platform_h, C_PLATFORM)

    -- Draw label area and pegs
    local peg_labels = { "A", "B", "C" }
    for p = 1, 3 do
        local zone_x   = x + (p - 1) * zone_w
        local peg_cx   = zone_x + math.floor(zone_w / 2)
        local peg_x    = peg_cx - math.floor(peg_w / 2)
        local peg_top  = y + play_h - peg_h

        -- Selected peg highlight column
        if board.selected_peg == p then
            bb:paintRect(zone_x, y, zone_w, play_h, C_SEL_COL)
        end

        -- Peg rod
        bb:paintRect(peg_x, peg_top, peg_w, peg_h, C_PEG)

        -- Disks on this peg (bottom of stack = index 1 = bottom of play area)
        local peg_data = board.pegs[p]
        for di = 1, #peg_data do
            local disk_num = peg_data[di]
            -- Width proportional to disk_num / (nd+1)
            local disk_w   = math.floor(cell_w * disk_num / (nd + 1))
            local disk_h   = math.max(4, math.floor(peg_h / (nd + 2)))
            local disk_x   = peg_cx - math.floor(disk_w / 2)
            -- di=1 is bottom disk, drawn at lowest position
            local disk_y   = plat_y - di * disk_h

            local fill = C_DISK_BG
            if board.selected_peg == p and di == #peg_data then
                fill = C_DISK_SEL
            end
            bb:paintRect(disk_x, disk_y, disk_w, disk_h, fill)
            -- Border
            bb:paintRect(disk_x, disk_y, disk_w, 1, C_DISK_BDR)
            bb:paintRect(disk_x, disk_y + disk_h - 1, disk_w, 1, C_DISK_BDR)
            bb:paintRect(disk_x, disk_y, 1, disk_h, C_DISK_BDR)
            bb:paintRect(disk_x + disk_w - 1, disk_y, 1, disk_h, C_DISK_BDR)
        end

        -- Peg label below platform
        local label   = peg_labels[p]
        local lbl_y   = plat_y + platform_h
        local m       = RenderText:sizeUtf8Text(0, zone_w, self.label_face, label, true, false)
        local lbl_x   = peg_cx - math.floor(m.x / 2)
        local lbl_base = lbl_y + math.floor((label_h - (m.y_bottom - m.y_top)) / 2) + m.y_bottom
        RenderText:renderUtf8Text(bb, lbl_x, lbl_base, self.label_face, label, true, false, C_LABEL)
    end
end

return HanoiBoardWidget
