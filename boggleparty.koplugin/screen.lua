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
local TextBoxWidget   = require("ui/widget/textboxwidget")
local TextWidget      = require("ui/widget/textwidget")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local _               = require("gettext")

local MenuHelper   = require("menu_helper")
local ScreenBase   = require("screen_base")
local BoggleBoard  = lrequire("board")  -- board.lua is a symlink → boggle.koplugin/board.lua
local BoardDisplay = lrequire("board_widget")

local DeviceScreen = Device.screen

local DEFAULT_DURATION = 180  -- 3 minutes

local RULES_EN = _([[
Boggle Party — Rules

Everyone gets a sheet of paper. When the timer starts, all players simultaneously search for words in the grid.

Rules:
• Letters must be adjacent (horizontally, vertically, or diagonally).
• Each letter may be used only once per word.
• Minimum 3 letters.
• Longer words score more: 3=1pt, 4=1pt, 5=2pts, 6=3pts, 7=5pts, 8+=11pts.

When time runs out:
• Read your lists aloud — any word found by more than one player is cancelled.
• Score only your unique words.
]])

local RULES_FR = [[
Boggle Party — Règles

Chaque joueur prend une feuille. Au signal, tous cherchent simultanément des mots dans la grille.

Règles :
• Les lettres doivent être adjacentes (horizontalement, verticalement ou en diagonale).
• Chaque lettre ne peut être utilisée qu'une seule fois par mot.
• Minimum 3 lettres.
• Score : 3=1pt, 4=1pt, 5=2pts, 6=3pts, 7=5pts, 8+=11pts.

À la fin du temps :
• Chacun lit sa liste à voix haute — les mots trouvés par plusieurs joueurs sont annulés.
• Seuls les mots uniques comptent.
]]

-- ---------------------------------------------------------------------------
-- PartyScreen
-- ---------------------------------------------------------------------------

local PartyScreen = ScreenBase:extend{}

function PartyScreen:init()
    local lang = self.plugin:getSetting("lang", "en")
    self.duration       = self.plugin:getSetting("duration", DEFAULT_DURATION)
    self.time_remaining = self.duration
    self.phase          = "playing"  -- "playing" | "solved"
    self.timer_running  = false
    self.board          = BoggleBoard:new{ lang = lang }
    ScreenBase.init(self)
    self:_startCountdown()
end

function PartyScreen:serializeState()
    return { lang = self.board.lang, duration = self.duration }
end

-- ---------------------------------------------------------------------------
-- Countdown
-- ---------------------------------------------------------------------------

function PartyScreen:_startCountdown()
    if self.phase ~= "playing" then return end
    -- Generation counter: any tick from a previous countdown sees a stale gen and exits.
    self._tick_gen = (self._tick_gen or 0) + 1
    local gen = self._tick_gen
    UIManager:scheduleIn(1, function() self:_onTick(gen) end)
end

function PartyScreen:_stopCountdown()
    -- Bump generation so any pending tick becomes a no-op.
    self._tick_gen = (self._tick_gen or 0) + 1
end

function PartyScreen:_onTick(gen)
    if gen ~= self._tick_gen then return end
    self.time_remaining = math.max(0, self.time_remaining - 1)
    self:_refreshTimerWidget()
    if self.time_remaining <= 0 then
        self:_onTimerEnd()
    else
        UIManager:scheduleIn(1, function() self:_onTick(gen) end)
    end
end

function PartyScreen:_refreshTimerWidget()
    if not self.timer_widget then return end
    self.timer_widget:setText(self:_timerText())
    -- "fast" (A2) refresh for the full screen: minimal flicker, good enough for a digit change.
    UIManager:setDirty(self, function() return "fast", self.dimen end)
end

function PartyScreen:_onTimerEnd()
    self:_stopCountdown()
    self.phase = "solved"
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function PartyScreen:_timerText()
    local m = math.floor(self.time_remaining / 60)
    local s = self.time_remaining % 60
    return string.format("%d:%02d", m, s)
end

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

function PartyScreen:onNewGame()
    self:_stopCountdown()
    self.board:newGame()
    self.time_remaining = self.duration
    self.phase          = "playing"
    self.plugin:saveState(self:serializeState())
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
    self:_startCountdown()
end

function PartyScreen:onSolveNow()
    self:_stopCountdown()
    self.time_remaining = 0
    self:_onTimerEnd()
end

function PartyScreen:openLangMenu()
    local items = {
        { id = "en", text = _("English") },
        { id = "fr", text = _("Français") },
    }
    MenuHelper.openPickerMenu{
        title      = _("Language"),
        items      = items,
        current_id = self.board.lang,
        parent     = self,
        on_select  = function(lang)
            self.board.lang = lang
            self.plugin:saveSetting("lang", lang)
            self.board:_loadDict()
            self:onNewGame()
        end,
    }
end

function PartyScreen:openDurationMenu()
    local durations = {
        { id = 120, text = "2:00" },
        { id = 180, text = "3:00" },
        { id = 240, text = "4:00" },
        { id = 300, text = "5:00" },
    }
    MenuHelper.openPickerMenu{
        title      = _("Duration"),
        items      = durations,
        current_id = self.duration,
        parent     = self,
        on_select  = function(dur)
            self.duration = dur
            self.plugin:saveSetting("duration", dur)
            self:onNewGame()
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Solutions text
-- ---------------------------------------------------------------------------

function PartyScreen:_buildSolutionText()
    local all = self.board._all_words or {}
    local by_len = {}
    local max_len = 3
    for w in pairs(all) do
        local l = #w
        if l > max_len then max_len = l end
        by_len[l] = by_len[l] or {}
        by_len[l][#by_len[l] + 1] = w
    end
    for _, words in pairs(by_len) do
        table.sort(words)
    end

    local total = 0
    for _ in pairs(all) do total = total + 1 end

    local lines = {}
    local is_fr = self.board.lang == "fr"
    for l = 3, max_len do
        local words = by_len[l]
        if words and #words > 0 then
            local label = is_fr
                and string.format("%d lettres (%d) : ", l, #words)
                or  string.format("%d letters (%d): ",  l, #words)
            lines[#lines + 1] = label .. table.concat(words, ", ")
        end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = is_fr
        and string.format("Total : %d mot%s", total, total > 1 and "s" or "")
        or  string.format("Total: %d word%s",  total, total > 1 and "s" or "")

    return table.concat(lines, "\n")
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

function PartyScreen:_langLabel()
    return self.board.lang == "fr" and "FR" or "EN"
end

function PartyScreen:buildLayout()
    local sw           = DeviceScreen:getWidth()
    local sh           = DeviceScreen:getHeight()
    local is_landscape = self:isLandscape()
    local playing      = self.phase == "playing"

    -- Buttons
    local btn_width = is_landscape
        and math.max(math.floor(sw * 0.40), 120)
        or  math.floor(sw * 0.92)

    local btn_row
    if playing then
        btn_row = {{
            { text = _("New"),       callback = function() self:onNewGame()    end },
            { text = _("Solutions"), callback = function() self:onSolveNow()   end },
            { id = "lang_btn", text = self:_langLabel(),
              callback = function() self:openLangMenu() end },
            { text = _("Time"),      callback = function() self:openDurationMenu() end },
            self:makeRulesButtonConfig(RULES_EN, RULES_FR),
            self:makeCloseButtonConfig(),
        }}
    else
        btn_row = {{
            { text = _("New"),       callback = function() self:onNewGame()    end },
            { id = "lang_btn", text = self:_langLabel(),
              callback = function() self:openLangMenu() end },
            { text = _("Time"),      callback = function() self:openDurationMenu() end },
            self:makeRulesButtonConfig(RULES_EN, RULES_FR),
            self:makeCloseButtonConfig(),
        }}
    end

    local button_table = ButtonTable:new{
        shrink_unneeded_width = true,
        width   = btn_width,
        buttons = btn_row,
    }
    self.lang_btn = button_table:getButtonById("lang_btn")

    -- Board size: large while playing, smaller in solution view
    local board_size
    if playing then
        board_size = is_landscape
            and math.floor(math.min(sh * 0.88, sw * 0.52))
            or  math.floor(math.min(sw * 0.90, sh * 0.58))
    else
        board_size = is_landscape
            and math.floor(math.min(sh * 0.72, sw * 0.42))
            or  math.floor(math.min(sw * 0.48, sh * 0.36))
    end
    board_size = math.max(board_size, 80)

    self.board_widget = BoardDisplay:new{
        board      = self.board,
        max_width  = board_size,
        max_height = board_size,
    }
    local board_frame = FrameContainer:new{
        padding = Size.padding.default,
        margin  = 0,
        self.board_widget,
    }

    -- Right / bottom panel
    local right_panel
    if playing then
        -- Big countdown timer
        local timer_fs = is_landscape
            and math.max(24, math.min(math.floor(sh * 0.18), 130))
            or  math.max(24, math.min(math.floor(sw * 0.18), 130))
        self.timer_widget = TextWidget:new{
            text = self:_timerText(),
            face = Font:getFace("cfont", timer_fs),
        }

        if is_landscape then
            right_panel = VerticalGroup:new{
                align = "center",
                button_table,
                VerticalSpan:new{ width = Size.span.vertical_large * 3 },
                self.timer_widget,
            }
        else
            -- Portrait: timer goes below the grid, so we expose it separately
            self.timer_widget_below = self.timer_widget
        end
    else
        self.timer_widget = nil
        -- Solutions list
        local sol_w = is_landscape
            and math.max(math.floor(sw * 0.46) - Size.margin.default * 2, 160)
            or  math.floor(sw * 0.92)
        local sol_h = is_landscape
            and math.floor(sh * 0.72)
            or  math.floor(sh * 0.44)

        local sol_widget = TextBoxWidget:new{
            text   = self:_buildSolutionText(),
            face   = Font:getFace("smallinfofont"),
            width  = sol_w,
            height = sol_h,
        }

        if is_landscape then
            right_panel = VerticalGroup:new{
                align = "center",
                button_table,
                VerticalSpan:new{ width = Size.span.vertical_large },
                sol_widget,
            }
        else
            right_panel = sol_widget
        end
    end

    -- Assemble
    local vspan = VerticalSpan:new{ width = Size.span.vertical_large }
    if is_landscape then
        self.layout = HorizontalGroup:new{
            align = "center",
            board_frame,
            HorizontalSpan:new{ width = Size.span.horizontal_default },
            right_panel,
        }
    else
        if playing then
            self.layout = VerticalGroup:new{
                align = "center",
                vspan,
                button_table,
                vspan,
                board_frame,
                vspan,
                self.timer_widget,
            }
        else
            self.layout = VerticalGroup:new{
                align = "center",
                vspan,
                button_table,
                vspan,
                board_frame,
                vspan,
                right_panel,
            }
        end
    end

    self[1] = self.layout
    self:updateStatus()
end

function PartyScreen:updateStatus(msg)
    local status
    if msg then
        status = msg
    elseif self.phase == "playing" then
        local dur_m = math.floor(self.duration / 60)
        local dur_s = self.duration % 60
        status = self.board.lang == "fr"
            and string.format("Mots possibles : %d  •  Durée : %d:%02d",
                    self.board.total_possible, dur_m, dur_s)
            or  string.format("Possible words: %d  •  Duration: %d:%02d",
                    self.board.total_possible, dur_m, dur_s)
    else
        status = self.board.lang == "fr"
            and string.format("Solutions : %d mots possibles", self.board.total_possible)
            or  string.format("Solutions: %d possible words",  self.board.total_possible)
    end
    ScreenBase.updateStatus(self, status)
end

function PartyScreen:onClose()
    self:_stopCountdown()
    ScreenBase.onClose(self)
end

return PartyScreen
