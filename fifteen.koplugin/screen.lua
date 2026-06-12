local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local ButtonTable     = require("ui/widget/buttontable")
local Device          = require("device")
local FrameContainer  = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local Size            = require("ui/size")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local _               = require("gettext")
local T               = require("ffi/util").template

local ScreenBase         = require("screen_base")
local MenuHelper         = require("menu_helper")
local FifteenBoard       = lrequire("board")
local FifteenBoardWidget = lrequire("board_widget")

local DeviceScreen = Device.screen

-- ---------------------------------------------------------------------------
-- FifteenScreen
-- ---------------------------------------------------------------------------

local GAME_RULES_EN = _([[
Fifteen Puzzle — Rules

Arrange the numbered tiles in order by sliding them into the empty space.

Tap a tile adjacent to the empty space to slide it in.
Only tiles directly next to the empty space can move.
Goal: arrange tiles 1, 2, 3 … in order from top-left to bottom-right, with the empty space in the bottom-right corner.

The puzzle is always solvable.
]])

local GAME_RULES_FR = [[
Taquin — Règles

Glissez les tuiles numérotées (1 à 15) dans l'espace vide pour les ranger dans l'ordre, de gauche à droite et de haut en bas, avec l'espace vide en bas à droite.

Appuyez sur une tuile adjacente à l'espace vide pour la faire glisser. Seules les tuiles directement à côté de l'espace vide peuvent bouger.

Le puzzle est toujours soluble.
]]

local FifteenScreen = ScreenBase:extend{}

function FifteenScreen:init()
    local state = self.plugin:loadState()
    local n     = self.plugin:getSetting("grid_n", FifteenBoard.DEFAULT_N)
    self.board  = FifteenBoard:new{ n = n }
    if not self.board:load(state) then
        -- fresh board from new()
    end
    ScreenBase.init(self)
end

function FifteenScreen:serializeState()
    return self.board:serialize()
end

function FifteenScreen:buildLayout()
    local sw          = DeviceScreen:getWidth()
    local sh          = DeviceScreen:getHeight()
    local is_landscape = self:isLandscape()

    local btn_width = is_landscape
        and math.max(math.floor(sw * 0.35), 100)
        or  math.floor(sw * 0.9)

    local top_buttons = ButtonTable:new{
        shrink_unneeded_width = true,
        width   = btn_width,
        buttons = {{
            { text = _("New"),  callback = function() self:onNewGame() end },
            { id = "grid_btn", text = self:_gridLabel(),
              callback = function() self:openGridMenu() end },
            self:makeRulesButtonConfig(GAME_RULES_EN, GAME_RULES_FR),
            self:makeCloseButtonConfig(),
        }},
    }
    self.grid_btn = top_buttons:getButtonById("grid_btn")

    local margin      = Size.margin.default
    local padding     = Size.padding.large
    local frame_extra = (padding + margin) * 2
    local board_max_w, board_max_h
    if is_landscape then
        board_max_w = math.floor(sw * 0.58)
        board_max_h = sh - frame_extra - 20
    else
        board_max_w = sw - frame_extra
        board_max_h = sh - 130 - frame_extra * 2
    end

    self.board_widget = FifteenBoardWidget:new{
        board      = self.board,
        max_width  = math.max(board_max_w, 60),
        max_height = math.max(board_max_h, 60),
        onCellTap  = function(r, c) self:onCellTap(r, c) end,
    }

    local board_frame = FrameContainer:new{
        padding = padding,
        margin  = margin,
        self.board_widget,
    }

    if is_landscape then
        local panel = VerticalGroup:new{
            align = "center",
            top_buttons,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.status_text,
        }
        self.layout = HorizontalGroup:new{
            align = "center",
            board_frame,
            HorizontalSpan:new{ width = Size.span.horizontal_default },
            panel,
        }
    else
        self.layout = VerticalGroup:new{
            align = "center",
            VerticalSpan:new{ width = Size.span.vertical_large },
            top_buttons,
            VerticalSpan:new{ width = Size.span.vertical_large },
            board_frame,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.status_text,
            VerticalSpan:new{ width = Size.span.vertical_large },
        }
    end
    self[1] = self.layout
    self:updateStatus()
end

function FifteenScreen:onCellTap(r, c)
    local moved = self.board:slide(r, c)
    if moved then
        self.board_widget:refresh()
        self:updateStatus()
        self.plugin:saveState(self.board:serialize())
        if self.board.won then
            local best_key = "best_moves_" .. self.board.n
            local best = self.plugin:getSetting(best_key)
            local moves = self.board.moves
            if not best or moves < best then
                self.plugin:saveSetting(best_key, moves)
            end
        end
    end
end

function FifteenScreen:onNewGame()
    local n = self.plugin:getSetting("grid_n", FifteenBoard.DEFAULT_N)
    self.board:newGame(n)
    self.plugin:saveState(self.board:serialize())
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function FifteenScreen:openGridMenu()
    local items = {}
    for _, n in ipairs(FifteenBoard.SIZES) do
        items[#items + 1] = { id = n, text = string.format("%d\xC3\x97%d", n, n) }
    end
    MenuHelper.openPickerMenu{
        title      = _("Grid size"),
        items      = items,
        current_id = self.plugin:getSetting("grid_n", FifteenBoard.DEFAULT_N),
        parent     = self,
        on_select  = function(n)
            self.plugin:saveSetting("grid_n", n)
            if self.grid_btn then
                self.grid_btn:setText(self:_gridLabel(), self.grid_btn.width)
            end
            self:onNewGame()
        end,
    }
end

function FifteenScreen:updateStatus(msg)
    local status
    if msg then
        status = msg
    elseif self.board.won then
        local best_key = "best_moves_" .. self.board.n
        local best = self.plugin:getSetting(best_key)
        status = T(_("Solved in %1 moves! Best: %2"), self.board.moves, best or self.board.moves)
    else
        local time_str = self.board.timer:format()
        local best_key = "best_moves_" .. self.board.n
        local best = self.plugin:getSetting(best_key)
        local best_str = best and tostring(best) or "-"
        status = T(_("Moves: %1  Time: %2  Best: %3"), self.board.moves, time_str, best_str)
    end
    ScreenBase.updateStatus(self, status)
end

function FifteenScreen:_gridLabel()
    local n = self.plugin:getSetting("grid_n", FifteenBoard.DEFAULT_N)
    return string.format("%d\xC3\x97%d", n, n)
end

return FifteenScreen
