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

local ScreenBase            = require("screen_base")
local MenuHelper            = require("menu_helper")
local WordSearchBoard       = lrequire("board")
local WordSearchBoardWidget = lrequire("board_widget")

local DeviceScreen = Device.screen

-- ---------------------------------------------------------------------------
-- WordSearchScreen
-- ---------------------------------------------------------------------------

local GAME_RULES_EN = _([[
Word Search — Rules

Find all the hidden words in the letter grid.

Words may be hidden in any direction:
• Horizontally (left→right or right→left)
• Vertically (top→bottom or bottom→top)
• Diagonally (all four diagonal directions)

Tap the first letter of a word, then tap the last letter to mark it found.
Found words are crossed off the word list.
Solve the puzzle by finding every word in the list.
]])

local GAME_RULES_FR = [[
Mots Cachés — Règles

Trouvez tous les mots cachés dans la grille de lettres.

Les mots peuvent être cachés dans n'importe quelle direction :
• Horizontalement (gauche→droite ou droite→gauche)
• Verticalement (haut→bas ou bas→haut)
• En diagonale (les quatre directions diagonales)

Appuyez sur la première lettre d'un mot, puis sur la dernière pour le marquer comme trouvé.
Les mots trouvés sont barrés dans la liste.
Résolvez le puzzle en trouvant tous les mots de la liste.
]]

local WordSearchScreen = ScreenBase:extend{}

function WordSearchScreen:init()
    local state = self.plugin:loadState()
    local lang  = self.plugin:getSetting("lang", "en")
    self.board  = WordSearchBoard:new{ lang = lang }
    if not self.board:load(state) then
        -- fresh game
    end
    ScreenBase.init(self)
end

function WordSearchScreen:serializeState()
    return self.board:serialize()
end

function WordSearchScreen:buildLayout()
    local sw           = DeviceScreen:getWidth()
    local sh           = DeviceScreen:getHeight()
    local is_landscape = self:isLandscape()

    local btn_width = is_landscape
        and math.max(math.floor(sw * 0.38), 120)
        or  math.floor(sw * 0.9)

    local top_buttons = ButtonTable:new{
        shrink_unneeded_width = true,
        width   = btn_width,
        buttons = {{
            { text = _("New"),  callback = function() self:onNewGame() end },
            { id = "lang_btn", text = self:_langLabel(),
              callback = function() self:openLangMenu() end },
            self:makeRulesButtonConfig(GAME_RULES_EN, GAME_RULES_FR),
            self:makeCloseButtonConfig(),
        }},
    }
    self.lang_btn = top_buttons:getButtonById("lang_btn")

    local margin      = Size.margin.default
    local padding     = Size.padding.large
    local frame_extra = (padding + margin) * 2

    local board_max_w, board_max_h
    if is_landscape then
        board_max_w = math.floor(sw * 0.55)
        board_max_h = sh - frame_extra - 20
    else
        board_max_w = sw - frame_extra
        board_max_h = math.floor(sh * 0.55)
    end
    board_max_w = math.max(board_max_w, 100)
    board_max_h = math.max(board_max_h, 100)

    self.board_widget = WordSearchBoardWidget:new{
        board        = self.board,
        max_width    = board_max_w,
        max_height   = board_max_h,
        onSelectWord = function(r1, c1, r2, c2)
            self:onSelectWord(r1, c1, r2, c2)
        end,
    }

    local board_frame = FrameContainer:new{
        padding = padding,
        margin  = margin,
        self.board_widget,
    }

    -- Word list display
    self.word_list_widget = self:_buildWordList()

    if is_landscape then
        local right = VerticalGroup:new{
            align = "center",
            top_buttons,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.status_text,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.word_list_widget,
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
            self.status_text,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.word_list_widget,
            VerticalSpan:new{ width = Size.span.vertical_large },
        }
    end
    self[1] = self.layout
    self:updateStatus()
end

function WordSearchScreen:_buildWordList()
    local board = self.board
    local parts = {}
    for i, entry in ipairs(board.word_list) do
        if board.found[i] then
            parts[#parts + 1] = "\xE2\x9C\x93 " .. entry.word
        else
            parts[#parts + 1] = entry.word
        end
    end
    local text = table.concat(parts, "  ")
    return TextWidget:new{
        text = text,
        face = Font:getFace("smallinfofont"),
    }
end

function WordSearchScreen:onSelectWord(r1, c1, r2, c2)
    local result, word = self.board:tapCell(r1, c1, r2, c2)
    if result == "found" then
        self.board_widget:refresh()
        self:updateStatus(T(_("Found: %1!"), word))
        self.plugin:saveState(self.board:serialize())
        if self.board:allFound() then
            self:updateStatus(_("Congratulations! All words found!"))
        else
            self:_refreshWordList()
        end
    else
        self:updateStatus(_("No match. Try again."))
    end
end

function WordSearchScreen:_refreshWordList()
    if self.word_list_widget then
        local board = self.board
        local parts = {}
        for i, entry in ipairs(board.word_list) do
            if board.found[i] then
                parts[#parts + 1] = "\xE2\x9C\x93 " .. entry.word
            else
                parts[#parts + 1] = entry.word
            end
        end
        self.word_list_widget:setText(table.concat(parts, "  "))
    end
end

function WordSearchScreen:onNewGame()
    local lang = self.plugin:getSetting("lang", "en")
    self.board = WordSearchBoard:new{ lang = lang }
    self.plugin:saveState(self.board:serialize())
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function WordSearchScreen:openLangMenu()
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
            self.plugin:saveSetting("lang", lang)
            if self.lang_btn then
                self.lang_btn:setText(self:_langLabel(), self.lang_btn.width)
            end
            self:onNewGame()
        end,
    }
end

function WordSearchScreen:updateStatus(msg)
    local status
    if msg then
        status = msg
    elseif self.board:allFound() then
        status = _("All words found!")
    else
        local found = self.board:foundCount()
        local total = #self.board.word_list
        status = T(_("Found: %1/%2 words"), found, total)
    end
    ScreenBase.updateStatus(self, status)
end

function WordSearchScreen:_langLabel()
    local lang = self.plugin:getSetting("lang", "en")
    return lang == "fr" and "FR" or "EN"
end

return WordSearchScreen
