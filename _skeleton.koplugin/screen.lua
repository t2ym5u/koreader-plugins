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

local ScreenBase      = require("screen_base")
local MenuHelper      = require("menu_helper")
local SettingsDialog  = require("settings_dialog")

local MyGameBoard       = lrequire("board")
local MyGameBoardWidget = lrequire("board_widget")

local DeviceScreen = Device.screen

-- ---------------------------------------------------------------------------
-- MyGameScreen
-- ---------------------------------------------------------------------------

local MyGameScreen = ScreenBase:extend{}

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

function MyGameScreen:init()
    -- Load or create a board before calling ScreenBase:init (which calls buildLayout).
    local state = self.plugin:loadState()
    self.board = MyGameBoard:new()
    if not self.board:load(state) then
        self.board:generate(self.plugin:getSetting("difficulty", "easy"))
    end
    ScreenBase.init(self)
end

function MyGameScreen:serializeState()
    return self.board:serialize()
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

function MyGameScreen:buildLayout()
    self.board_widget = MyGameBoardWidget:new{
        board            = self.board,
        onCellSelected   = function(row, col, is_hold)
            self:onCellSelected(row, col, is_hold)
        end,
    }

    local is_landscape  = self:isLandscape()
    local sw            = DeviceScreen:getWidth()
    local board_frame   = FrameContainer:new{
        padding = Size.padding.large,
        margin  = Size.margin.default,
        self.board_widget,
    }

    local board_frame_size  = self.board_widget.size + (Size.padding.large + Size.margin.default) * 2
    local right_panel_width = sw - board_frame_size - Size.span.horizontal_default
    local button_width = is_landscape
        and math.max(right_panel_width - Size.span.horizontal_default, 100)
        or  math.floor(sw * 0.9)

    -- Top action bar
    local top_buttons = ButtonTable:new{
        shrink_unneeded_width = true,
        width   = button_width,
        buttons = {
            {
                { text = _("New game"),  callback = function() self:onNewGame() end },
                { id = "diff_button",    text = self:getDifficultyButtonText(),
                  callback = function() self:openDifficultyMenu() end },
                { text = _("Settings"),  callback = function() self:openSettings() end },
                self:makeCloseButtonConfig(),
            },
        },
    }
    self.diff_button = top_buttons:getButtonById("diff_button")

    -- Bottom action bar
    local bottom_buttons = ButtonTable:new{
        shrink_unneeded_width = true,
        width   = button_width,
        buttons = {
            {
                { id = "undo_button", text = _("Undo"),  callback = function() self:onUndo() end },
                { text = _("Check"),  callback = function() self:onCheck() end },
                { text = _("Reveal"), callback = function() self:onReveal() end },
            },
        },
    }
    self.undo_button = bottom_buttons:getButtonById("undo_button")
    self:updateUndoButton()

    if is_landscape then
        local right_panel = VerticalGroup:new{
            align = "center",
            top_buttons,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.status_text,
            VerticalSpan:new{ width = Size.span.vertical_large },
            bottom_buttons,
        }
        self.layout = HorizontalGroup:new{
            align = "center",
            board_frame,
            HorizontalSpan:new{ width = Size.span.horizontal_default },
            right_panel,
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
            bottom_buttons,
            VerticalSpan:new{ width = Size.span.vertical_large },
        }
    end
    self[1] = self.layout
    self:updateStatus()
end

-- ---------------------------------------------------------------------------
-- Cell interaction
-- ---------------------------------------------------------------------------

function MyGameScreen:onCellSelected(row, col, is_hold)
    -- TODO: handle cell tap / long-press
    self:updateStatus(T(_("Cell %1,%2 selected."), row, col))
    self.board_widget:refresh()
    self.plugin:saveState(self.board:serialize())
end

-- ---------------------------------------------------------------------------
-- Game actions
-- ---------------------------------------------------------------------------

function MyGameScreen:onNewGame()
    local diff = self.plugin:getSetting("difficulty", "easy")
    self.board:generate(diff)
    self.plugin:saveState(self.board:serialize())
    self.board_widget:refresh()
    self:updateUndoButton()
    self:updateStatus(_("New game started."))
end

function MyGameScreen:onUndo()
    -- TODO: implement undo using self.board.undo
    self:updateUndoButton()
    self.board_widget:refresh()
    self.plugin:saveState(self.board:serialize())
    self:updateStatus(_("Last move undone."))
end

function MyGameScreen:onCheck()
    -- TODO: validate current board state
    self:updateStatus(_("Checking…"))
end

function MyGameScreen:onReveal()
    -- TODO: show solution
    self:updateStatus(_("Solution revealed."))
    self.board_widget:refresh()
end

-- ---------------------------------------------------------------------------
-- Difficulty
-- ---------------------------------------------------------------------------

function MyGameScreen:getDifficultyButtonText()
    local diff  = self.plugin:getSetting("difficulty", "easy")
    local label = MenuHelper.DIFFICULTY_LABELS[diff] or diff
    return T(_("Diff: %1"), label)
end

function MyGameScreen:openDifficultyMenu()
    MenuHelper.openDifficultyMenu{
        current   = self.plugin:getSetting("difficulty", "easy"),
        parent    = self,
        on_select = function(id)
            self.plugin:saveSetting("difficulty", id)
            if self.diff_button then
                self.diff_button:setText(self:getDifficultyButtonText(), self.diff_button.width)
            end
            self:onNewGame()
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

function MyGameScreen:openSettings()
    SettingsDialog.open{
        title  = _("My Game — Settings"),
        plugin = self.plugin,
        parent = self,
        sections = {
            {
                title = _("Gameplay"),
                items = {
                    {
                        label       = _("Difficulty"),
                        setting_key = "difficulty",
                        type        = "picker",
                        values      = {
                            { id = "easy",   text = _("Easy")   },
                            { id = "medium", text = _("Medium") },
                            { id = "hard",   text = _("Hard")   },
                        },
                        on_change = function(id)
                            self.plugin:saveSetting("difficulty", id)
                            if self.diff_button then
                                self.diff_button:setText(self:getDifficultyButtonText(), self.diff_button.width)
                            end
                        end,
                    },
                    -- Add more settings here, e.g.:
                    -- { label = _("Auto-save"), setting_key = "auto_save", type = "toggle" },
                },
            },
            {
                title = _("About"),
                items = {
                    { label = _("My Game v1.0"), type = "info" },
                },
            },
        },
    }
end

-- ---------------------------------------------------------------------------
-- Status bar
-- ---------------------------------------------------------------------------

function MyGameScreen:updateStatus(message)
    local status
    if message then
        status = message
    else
        local diff  = self.plugin:getSetting("difficulty", "easy")
        local label = MenuHelper.DIFFICULTY_LABELS[diff] or diff
        status = T(_("Difficulty: %1"), label)
        if self.board:isSolved() then
            status = _("Congratulations! Puzzle solved.")
        end
    end
    ScreenBase.updateStatus(self, status)
end

-- ---------------------------------------------------------------------------
-- Button state helpers
-- ---------------------------------------------------------------------------

function MyGameScreen:updateUndoButton()
    if not self.undo_button then return end
    self.undo_button:enableDisable(self.board.undo:canUndo())
end

return MyGameScreen
