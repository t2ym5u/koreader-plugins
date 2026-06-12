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
local Font            = require("ui/font")
local FrameContainer  = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local Size            = require("ui/size")
local TextWidget      = require("ui/widget/textwidget")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local _               = require("gettext")
local T               = require("ffi/util").template

local ScreenBase             = require("screen_base")
local ArrowwordsBoard        = lrequire("board")
local ArrowwordsBoardWidget  = lrequire("board_widget")

local DeviceScreen = Device.screen

-- ---------------------------------------------------------------------------
-- Keyboard layout (AZERTY — standard French layout)
-- ---------------------------------------------------------------------------

local KEY_ROWS = {
    { "A", "Z", "E", "R", "T", "Y", "U", "I", "O", "P" },
    { "Q", "S", "D", "F", "G", "H", "J", "K", "L", "M" },
    { "W", "X", "C", "V", "B", "N", "⌫" },
}

-- ---------------------------------------------------------------------------
-- ArrowwordsScreen
-- ---------------------------------------------------------------------------

local GAME_RULES_EN = _([[
Arrowwords — Rules

Fill in the crossword grid where clues are placed inside the cells themselves.

Each clue cell contains a short clue and an arrow pointing in the direction of the answer.
The answer is entered in the cells the arrow points to.
Letters at crossing cells must satisfy both the across and down words.
]])

local GAME_RULES_FR = [[
Mots Fléchés — Règles

Remplissez la grille avec des mots dont les définitions se trouvent directement dans les cases, accompagnées d'une flèche indiquant la direction de la réponse. Les lettres aux intersections doivent satisfaire tous les mots qui les traversent. Résolvez toutes les définitions pour compléter la grille.
]]

local ArrowwordsScreen = ScreenBase:extend{}

function ArrowwordsScreen:init()
    local state = self.plugin:loadState()
    local idx   = self.plugin:getSetting("puzzle_index", 1)
    self.board  = ArrowwordsBoard:new{ puzzle_index = idx }
    if not self.board:load(state) then
        -- fresh puzzle
    end
    ScreenBase.init(self)
end

function ArrowwordsScreen:serializeState()
    return self.board:serialize()
end

function ArrowwordsScreen:buildLayout()
    local sw           = DeviceScreen:getWidth()
    local sh           = DeviceScreen:getHeight()
    local is_landscape = self:isLandscape()

    local btn_width = is_landscape
        and math.max(math.floor(sw * 0.38), 120)
        or  math.floor(sw * 0.9)

    -- Top bar: prev / puzzle label / next / clear / close
    local top_buttons = ButtonTable:new{
        shrink_unneeded_width = true,
        width   = btn_width,
        buttons = {{
            { text = "\xe2\x97\x80", callback = function() self:onPrevPuzzle() end },
            { id = "puzzle_lbl", text = self:_puzzleLabel(),
              callback = function() end },
            { text = "\xe2\x96\xb6", callback = function() self:onNextPuzzle() end },
            { text = _("Clear"), callback = function() self:onClear() end },
            self:makeRulesButtonConfig(GAME_RULES_EN, GAME_RULES_FR),
            self:makeCloseButtonConfig(),
        }},
    }
    self.puzzle_lbl_btn = top_buttons:getButtonById("puzzle_lbl")

    -- Board widget
    local board_max
    if is_landscape then
        board_max = math.min(math.floor(sw * 0.52), sh - 40)
    else
        -- In portrait, leave room for keyboard rows + buttons
        board_max = math.min(sw - Size.margin.default * 4, sh - 260)
    end
    board_max = math.max(board_max, 80)

    self.board_widget = ArrowwordsBoardWidget:new{
        board      = self.board,
        max_width  = board_max,
        max_height = board_max,
        cellTapHandler = function(r, c) self:onCellTap(r, c) end,
    }

    local board_frame = FrameContainer:new{
        padding = Size.padding.default,
        margin  = Size.margin.default,
        self.board_widget,
    }

    -- Keyboard
    local key_rows_cfg = {}
    for _, row in ipairs(KEY_ROWS) do
        local btns = {}
        for _, key in ipairs(row) do
            local k = key
            btns[#btns + 1] = {
                text     = k,
                callback = function() self:onKeyPress(k) end,
            }
        end
        key_rows_cfg[#key_rows_cfg + 1] = btns
    end

    self.keyboard_widget = ButtonTable:new{
        shrink_unneeded_width = true,
        width   = btn_width,
        buttons = key_rows_cfg,
    }

    -- Action buttons: Reveal / (future: check)
    local action_buttons = ButtonTable:new{
        shrink_unneeded_width = true,
        width   = btn_width,
        buttons = {{
            { text = _("Reveal"), callback = function() self:onReveal() end },
        }},
    }

    if is_landscape then
        local right = VerticalGroup:new{
            align = "center",
            top_buttons,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.keyboard_widget,
            VerticalSpan:new{ width = Size.span.vertical_large },
            action_buttons,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.status_text,
        }
        self.layout = HorizontalGroup:new{
            align  = "center",
            board_frame,
            HorizontalSpan:new{ width = Size.span.horizontal_default },
            right,
        }
    else
        self.layout = VerticalGroup:new{
            align = "center",
            VerticalSpan:new{ width = Size.span.vertical_large },
            top_buttons,
            VerticalSpan:new{ width = Size.span.vertical_large },
            board_frame,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.keyboard_widget,
            VerticalSpan:new{ width = Size.span.vertical_large },
            action_buttons,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.status_text,
            VerticalSpan:new{ width = Size.span.vertical_large },
        }
    end

    self[1] = self.layout
    self:updateStatus()
end

-- ---------------------------------------------------------------------------
-- Event handlers
-- ---------------------------------------------------------------------------

function ArrowwordsScreen:onCellTap(r, c)
    self.board:selectCell(r, c)
    if self.board_widget then
        self.board_widget:refresh()
    end
    self:updateStatus()
end

function ArrowwordsScreen:onKeyPress(key)
    if key == "⌫" then
        self.board:deleteLetter()
    else
        self.board:typeLetter(key)
    end
    if self.board_widget then
        self.board_widget:refresh()
    end
    self:updateStatus()
    self.plugin:saveState(self.board:serialize())
end

function ArrowwordsScreen:onNextPuzzle()
    local next_idx = (self.board.puzzle_index % ArrowwordsBoard.NUM_PUZZLES) + 1
    self.board = ArrowwordsBoard:new{ puzzle_index = next_idx }
    self.plugin:saveSetting("puzzle_index", next_idx)
    self.plugin:saveState(self.board:serialize())
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function ArrowwordsScreen:onPrevPuzzle()
    local prev_idx = self.board.puzzle_index - 1
    if prev_idx < 1 then prev_idx = ArrowwordsBoard.NUM_PUZZLES end
    self.board = ArrowwordsBoard:new{ puzzle_index = prev_idx }
    self.plugin:saveSetting("puzzle_index", prev_idx)
    self.plugin:saveState(self.board:serialize())
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function ArrowwordsScreen:onClear()
    self.board:clearAll()
    if self.board_widget then
        self.board_widget:refresh()
    end
    self:updateStatus()
    self.plugin:saveState(self.board:serialize())
end

function ArrowwordsScreen:onReveal()
    self.board:reveal()
    if self.board_widget then
        self.board_widget:refresh()
    end
    self:updateStatus(_("Solution revealed."))
    self.plugin:saveState(self.board:serialize())
end

-- ---------------------------------------------------------------------------
-- Status bar
-- ---------------------------------------------------------------------------

function ArrowwordsScreen:updateStatus(msg)
    local status
    if msg then
        status = msg
    elseif self.board.won then
        status = T(_("Puzzle %1 solved!"), self.board.puzzle_index)
    else
        local filled, total = self.board:countFilled()
        status = T(_("%1/%2 — %3"), filled, total, self.board.title)
    end
    ScreenBase.updateStatus(self, status)
end

function ArrowwordsScreen:_puzzleLabel()
    return T(_("%1/%2"), self.board.puzzle_index, ArrowwordsBoard.NUM_PUZZLES)
end

return ArrowwordsScreen
