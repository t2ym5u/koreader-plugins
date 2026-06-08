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
local HangmanBoard       = lrequire("board")
local HangmanBoardWidget = lrequire("board_widget")

local DeviceScreen = Device.screen

-- ---------------------------------------------------------------------------
-- HangmanScreen
-- ---------------------------------------------------------------------------

local HangmanScreen = ScreenBase:extend{}

local ALPHABET = {
    {"A","B","C","D","E","F","G"},
    {"H","I","J","K","L","M","N"},
    {"O","P","Q","R","S","T","U"},
    {"V","W","X","Y","Z"},
}

function HangmanScreen:init()
    local state = self.plugin:loadState()
    local lang  = self.plugin:getSetting("lang",       "en")
    local diff  = self.plugin:getSetting("difficulty", "medium")
    self.board  = HangmanBoard:new{ lang = lang, difficulty = diff }
    if not self.board:load(state) then
        -- fresh game already created
    end
    ScreenBase.init(self)
end

function HangmanScreen:serializeState()
    return self.board:serialize()
end

function HangmanScreen:buildLayout()
    local sw           = DeviceScreen:getWidth()
    local sh           = DeviceScreen:getHeight()
    local is_landscape = self:isLandscape()

    local btn_width = is_landscape
        and math.max(math.floor(sw * 0.38), 120)
        or  math.floor(sw * 0.9)

    -- Top bar
    local top_buttons = ButtonTable:new{
        shrink_unneeded_width = true,
        width   = btn_width,
        buttons = {{
            { text = _("New"),  callback = function() self:onNewGame() end },
            { id = "lang_btn",  text = self:_langLabel(),
              callback = function() self:openLangMenu() end },
            { id = "diff_btn",  text = self:_diffLabel(),
              callback = function() self:openDiffMenu() end },
            self:makeCloseButtonConfig(),
        }},
    }
    self.lang_btn = top_buttons:getButtonById("lang_btn")
    self.diff_btn = top_buttons:getButtonById("diff_btn")

    -- Board widget
    local bw_size
    if is_landscape then
        bw_size = math.min(math.floor(sw * 0.45), math.floor(sh * 0.75))
    else
        bw_size = math.floor(sw * 0.85)
    end
    bw_size = math.max(bw_size, 100)

    self.board_widget = HangmanBoardWidget:new{
        board  = self.board,
        width  = bw_size,
        height = math.floor(bw_size * 0.7),
    }

    local board_frame = FrameContainer:new{
        padding = Size.padding.default,
        margin  = Size.margin.default,
        self.board_widget,
    }

    -- Alphabet keyboard
    local key_w    = math.floor(btn_width / 7)
    local alpha_rows = {}
    for _, row in ipairs(ALPHABET) do
        local btns = {}
        for _, letter in ipairs(row) do
            local l = letter
            btns[#btns + 1] = {
                id       = "btn_" .. l,
                text     = l,
                callback = function() self:onLetterTap(l) end,
            }
        end
        alpha_rows[#alpha_rows + 1] = btns
    end
    self.alpha_widget = ButtonTable:new{
        shrink_unneeded_width = true,
        width   = btn_width,
        buttons = alpha_rows,
    }

    self:_updateAlphaButtons()

    if is_landscape then
        local right = VerticalGroup:new{
            align = "center",
            top_buttons,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.status_text,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.alpha_widget,
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
            self.alpha_widget,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.status_text,
            VerticalSpan:new{ width = Size.span.vertical_large },
        }
    end
    self[1] = self.layout
    self:updateStatus()
end

function HangmanScreen:_updateAlphaButtons()
    if not self.alpha_widget then return end
    for _, row in ipairs(ALPHABET) do
        for _, letter in ipairs(row) do
            local btn = self.alpha_widget:getButtonById("btn_" .. letter)
            if btn then
                local used = self.board.guessed[letter]
                -- dim used letters by marking them with a different visual cue
                if used then
                    btn:setText("·", btn.width)
                else
                    btn:setText(letter, btn.width)
                end
            end
        end
    end
end

function HangmanScreen:onLetterTap(letter)
    local result = self.board:guess(letter)
    if result == "already" or result == "done" then return end
    self.board_widget:refresh()
    self:_updateAlphaButtons()
    self:updateStatus()
    self.plugin:saveState(self.board:serialize())
end

function HangmanScreen:onNewGame()
    self.board:newGame()
    self.plugin:saveState(self.board:serialize())
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function HangmanScreen:openLangMenu()
    local items = {
        { id = "en", text = _("English") },
        { id = "fr", text = _("Français") },
    }
    MenuHelper.openPickerMenu{
        title      = _("Language"),
        items      = items,
        current_id = self.plugin:getSetting("lang", "en"),
        parent     = self,
        on_select  = function(lang)
            self.board.lang = lang
            self.plugin:saveSetting("lang", lang)
            if self.lang_btn then
                self.lang_btn:setText(self:_langLabel(), self.lang_btn.width)
            end
            self:onNewGame()
        end,
    }
end

function HangmanScreen:openDiffMenu()
    MenuHelper.openDifficultyMenu{
        current   = self.plugin:getSetting("difficulty", "medium"),
        parent    = self,
        on_select = function(diff)
            self.board.difficulty = diff
            self.plugin:saveSetting("difficulty", diff)
            if self.diff_btn then
                self.diff_btn:setText(self:_diffLabel(), self.diff_btn.width)
            end
            self:onNewGame()
        end,
    }
end

function HangmanScreen:updateStatus(msg)
    local status
    if msg then
        status = msg
    elseif self.board.won then
        status = T(_("You won! W:%1 L:%2"), self.board.wins, self.board.losses)
    elseif self.board.lost then
        status = T(_("Lost! Word: %1  W:%2 L:%3"),
            self.board.secret, self.board.wins, self.board.losses)
    else
        status = T(_("Wrong: %1/%2  W:%3 L:%4"),
            self.board.wrong, self.board:maxWrong(),
            self.board.wins, self.board.losses)
    end
    ScreenBase.updateStatus(self, status)
end

function HangmanScreen:_langLabel()
    local lang = self.plugin:getSetting("lang", "en")
    return lang == "fr" and "FR" or "EN"
end

function HangmanScreen:_diffLabel()
    local diff = self.plugin:getSetting("difficulty", "medium")
    local labels = { easy = _("Easy"), medium = _("Medium"), hard = _("Hard") }
    return labels[diff] or diff
end

return HangmanScreen
