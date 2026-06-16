local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

local ButtonTable     = require("ui/widget/buttontable")
local DataStorage     = require("datastorage")
local Device          = require("device")
local Font            = require("ui/font")
local FrameContainer  = require("ui/widget/container/framecontainer")
local InfoMessage     = require("ui/widget/infomessage")
local Size            = require("ui/size")
local TextBoxWidget   = require("ui/widget/textboxwidget")
local TextWidget      = require("ui/widget/textwidget")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local _               = require("gettext")

local MenuHelper  = require("menu_helper")
local ScreenBase  = require("screen_base")

local DeviceScreen = Device.screen

local DEFAULT_DURATION  = 60
local DEFAULT_NB_TEAMS  = 2
local DEFAULT_CARDS_PER_ROUND = 5

local RULES_EN = _([[
Tabou Party — Rules

Two (or more) teams take turns. Each round, one player from the active team describes as many words as possible in the time limit — without saying any of the forbidden words listed below the main word.

• ✓ +1 = teammates guessed correctly.
• ✗ Buzzed = opponent buzzed (forbidden word said) → −1.
• → Skip = pass, no penalty.

The round ends when the timer runs out or the agreed card count is reached. Teams swap roles each round.
]])

local RULES_FR = [[
Tabou Party — Règles

Deux équipes (ou plus) jouent à tour de rôle. Chaque manche, un joueur de l'équipe active fait deviner le maximum de mots dans le temps imparti — sans prononcer les mots interdits listés sous le mot principal.

• ✓ +1 = l'équipe a deviné correctement.
• ✗ Grillé = l'adversaire a buzzé (mot interdit prononcé) → −1.
• → Passer = on passe, sans pénalité.

La manche se termine quand le chrono sonne ou quand le nombre de cartes convenu est atteint. Les équipes échangent les rôles à chaque manche.
]]

-- ---------------------------------------------------------------------------
-- JSON loader (minimal, no external dependency)
-- ---------------------------------------------------------------------------

local function jsonDecode(s)
    -- Delegate to KOReader's bundled JSON library
    local ok, json = pcall(require, "json")
    if ok then
        local ok2, result = pcall(json.decode, s)
        if ok2 then return result end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- TabouScreen
-- ---------------------------------------------------------------------------

local TabouScreen = ScreenBase:extend{}

function TabouScreen:init()
    self.lang          = self.plugin:getSetting("lang", "fr")
    self.duration      = self.plugin:getSetting("duration", DEFAULT_DURATION)
    local nb           = self.plugin:getSetting("nb_teams", DEFAULT_NB_TEAMS)
    self.cards_path    = self.plugin:getSetting("cards_path", "")

    self.teams = {}
    for i = 1, nb do
        local default = self.lang == "fr" and ("Équipe " .. i) or ("Team " .. i)
        self.teams[i] = { name = self.plugin:getSetting("team_name_" .. i, default), score = 0 }
    end
    self.current_team   = 1
    self.phase          = "idle"   -- "idle" | "playing"
    self.cards          = {}
    self.card_index     = 1
    self.time_remaining = self.duration
    self.round_correct  = 0
    self.round_buzzed   = 0

    self:_loadCards()
    ScreenBase.init(self)
end

-- ---------------------------------------------------------------------------
-- Card loading
-- ---------------------------------------------------------------------------

function TabouScreen:_loadCards()
    -- Try configured path first, then default locations
    local paths = {}
    if self.cards_path ~= "" then paths[#paths + 1] = self.cards_path end
    local docs = DataStorage:getDataDir()
    paths[#paths + 1] = docs .. "/tabou_cards_" .. self.lang .. ".json"
    paths[#paths + 1] = docs .. "/tabou_cards.json"

    for _, path in ipairs(paths) do
        local f = io.open(path, "r")
        if f then
            local content = f:read("*all")
            f:close()
            local data = jsonDecode(content)
            if type(data) == "table" and #data > 0 then
                self.cards      = data
                self.cards_path = path
                self:_shuffleCards()
                return
            end
        end
    end
    -- No file found: show placeholder so the screen still renders
    self.cards = {}
end

function TabouScreen:_shuffleCards()
    local c = self.cards
    for i = #c, 2, -1 do
        local j = math.random(i)
        c[i], c[j] = c[j], c[i]
    end
    self.card_index = 1
end

function TabouScreen:_currentCard()
    if #self.cards == 0 then return nil end
    if self.card_index > #self.cards then
        self:_shuffleCards()  -- wrap around
    end
    return self.cards[self.card_index]
end

-- ---------------------------------------------------------------------------
-- Timer
-- ---------------------------------------------------------------------------

function TabouScreen:_startCountdown()
    self._tick_gen = (self._tick_gen or 0) + 1
    local gen = self._tick_gen
    UIManager:scheduleIn(1, function() self:_onTick(gen) end)
end

function TabouScreen:_stopCountdown()
    self._tick_gen = (self._tick_gen or 0) + 1
end

function TabouScreen:_onTick(gen)
    if gen ~= self._tick_gen then return end
    self.time_remaining = math.max(0, self.time_remaining - 1)
    if self.timer_widget then
        self.timer_widget:setText(self:_timerText())
        UIManager:setDirty(self, function() return "fast", self.dimen end)
    end
    if self.time_remaining <= 0 then
        self:_onTimerEnd()
    else
        UIManager:scheduleIn(1, function() self:_onTick(gen) end)
    end
end

function TabouScreen:_timerText()
    local m = math.floor(self.time_remaining / 60)
    local s = self.time_remaining % 60
    return string.format("%d:%02d", m, s)
end

function TabouScreen:_onTimerEnd()
    self:_stopCountdown()
    self.phase = "idle"
    -- Apply round score
    local delta = self.round_correct - self.round_buzzed
    self.teams[self.current_team].score = self.teams[self.current_team].score + delta
    -- Next team
    self.current_team = (self.current_team % #self.teams) + 1
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
    local is_fr = self.lang == "fr"
    local msg = is_fr
        and string.format("Temps écoulé ! +%d −%d = %+d points", self.round_correct, self.round_buzzed, delta)
        or  string.format("Time's up! +%d −%d = %+d points", self.round_correct, self.round_buzzed, delta)
    UIManager:show(InfoMessage:new{ text = msg, timeout = 3 })
end

-- ---------------------------------------------------------------------------
-- Game actions
-- ---------------------------------------------------------------------------

function TabouScreen:onStartRound()
    if #self.cards == 0 then
        local is_fr = self.lang == "fr"
        UIManager:show(InfoMessage:new{
            text = is_fr
                and "Aucune carte chargée.\n\nCopiez votre fichier tabou_cards_fr.json\n(ou tabou_cards.json) dans le dossier\ndocuments de KOReader."
                or  "No cards loaded.\n\nCopy your tabou_cards_en.json\n(or tabou_cards.json) to KOReader's\ndocuments folder.",
            timeout = 6,
        })
        return
    end
    self.time_remaining = self.duration
    self.round_correct  = 0
    self.round_buzzed   = 0
    self.phase          = "playing"
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
    self:_startCountdown()
end

function TabouScreen:onCorrect()
    self.round_correct = self.round_correct + 1
    self.card_index    = self.card_index + 1
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function TabouScreen:onBuzzed()
    self.round_buzzed = self.round_buzzed + 1
    self.card_index   = self.card_index + 1
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function TabouScreen:onSkip()
    self.card_index = self.card_index + 1
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function TabouScreen:onStopRound()
    self:_onTimerEnd()
end

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

function TabouScreen:openOptionsMenu()
    local is_fr = self.lang == "fr"
    local items = {
        { id = "lang",     text = is_fr and "Langue…"          or "Language…" },
        { id = "teams",    text = is_fr and "Nombre d'équipes…" or "Number of teams…" },
        { id = "duration", text = is_fr and "Durée du chrono…"  or "Timer duration…" },
        { id = "reset",    text = is_fr and "Remettre les scores à zéro" or "Reset scores" },
    }
    MenuHelper.openPickerMenu{
        title     = "Options",
        items     = items,
        parent    = self,
        on_select = function(id)
            if     id == "lang"     then self:openLangMenu()
            elseif id == "teams"    then self:openTeamsMenu()
            elseif id == "duration" then self:openDurationMenu()
            elseif id == "reset"    then self:onResetScores()
            end
        end,
    }
end

function TabouScreen:openLangMenu()
    MenuHelper.openPickerMenu{
        title      = "Language / Langue",
        items      = { { id = "fr", text = "Français" }, { id = "en", text = "English" } },
        current_id = self.lang,
        parent     = self,
        on_select  = function(lang)
            self.lang = lang
            self.plugin:saveSetting("lang", lang)
            self:_loadCards()
            self:buildLayout()
            UIManager:setDirty(self, function() return "ui", self.dimen end)
        end,
    }
end

function TabouScreen:openTeamsMenu()
    local is_fr = self.lang == "fr"
    local items = {}
    for n = 2, 6 do
        items[#items + 1] = { id = n, text = n .. " " .. (is_fr and "équipes" or "teams") }
    end
    MenuHelper.openPickerMenu{
        title      = is_fr and "Équipes" or "Teams",
        items      = items,
        current_id = #self.teams,
        parent     = self,
        on_select  = function(n)
            self.plugin:saveSetting("nb_teams", n)
            while #self.teams < n do
                local i = #self.teams + 1
                self.teams[i] = { name = (self.lang == "fr" and "Équipe " or "Team ") .. i, score = 0 }
            end
            while #self.teams > n do table.remove(self.teams) end
            if self.current_team > #self.teams then self.current_team = 1 end
            self:buildLayout()
            UIManager:setDirty(self, function() return "ui", self.dimen end)
        end,
    }
end

function TabouScreen:openDurationMenu()
    local items = {
        { id = 30,  text = "0:30" }, { id = 45,  text = "0:45" },
        { id = 60,  text = "1:00" }, { id = 90,  text = "1:30" },
        { id = 120, text = "2:00" },
    }
    MenuHelper.openPickerMenu{
        title      = self.lang == "fr" and "Durée" or "Duration",
        items      = items,
        current_id = self.duration,
        parent     = self,
        on_select  = function(dur)
            self.duration = dur
            self.plugin:saveSetting("duration", dur)
        end,
    }
end

function TabouScreen:onResetScores()
    for _, t in ipairs(self.teams) do t.score = 0 end
    self.current_team = 1
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

function TabouScreen:buildLayout()
    if self.phase == "idle" then
        self:_buildIdleLayout()
    else
        self:_buildPlayLayout()
    end
    self[1] = self.layout
    self:updateStatus()
end

function TabouScreen:_buildIdleLayout()
    local sw     = DeviceScreen:getWidth()
    local sh     = DeviceScreen:getHeight()
    local is_fr  = self.lang == "fr"
    local team   = self.teams[self.current_team]

    local btn_w = math.floor(sw * 0.92)
    local buttons = ButtonTable:new{
        shrink_unneeded_width = true,
        width   = btn_w,
        buttons = {{
            { text = is_fr and "Commencer la manche" or "Start round",
              callback = function() self:onStartRound() end },
            { text = "Options", callback = function() self:openOptionsMenu() end },
            self:makeRulesButtonConfig(RULES_EN, RULES_FR),
            self:makeCloseButtonConfig(),
        }},
    }

    -- Score display
    local score_parts = {}
    for _, t in ipairs(self.teams) do
        score_parts[#score_parts + 1] = t.name .. " : " .. t.score
    end
    local score_w = TextWidget:new{
        text = table.concat(score_parts, "   "),
        face = Font:getFace("smallinfofont"),
    }

    -- Whose turn
    local team_fs = math.max(24, math.floor(math.min(sw, sh) * 0.08))
    local team_w  = TextWidget:new{
        text = team.name:upper(),
        face = Font:getFace("cfont", team_fs),
    }

    local sub_text = is_fr and "C'est votre tour de faire deviner" or "It's your turn to describe"
    local sub_w = TextWidget:new{
        text = sub_text,
        face = Font:getFace("smallinfofont"),
    }

    -- Cards count
    local cards_info = #self.cards > 0
        and (is_fr and string.format("%d cartes chargées", #self.cards) or string.format("%d cards loaded", #self.cards))
        or  (is_fr and "⚠ Aucune carte — voir Options" or "⚠ No cards — see Options")
    local cards_w = TextWidget:new{
        text = cards_info,
        face = Font:getFace("smallinfofont"),
    }

    local vs  = VerticalSpan:new{ width = Size.span.vertical_large }
    local vs2 = VerticalSpan:new{ width = Size.span.vertical_large * 4 }

    self.timer_widget = nil
    self.layout = VerticalGroup:new{
        align = "center",
        vs,
        score_w,
        vs2,
        team_w,
        vs,
        sub_w,
        vs2,
        cards_w,
        vs2,
        buttons,
    }
end

function TabouScreen:_buildPlayLayout()
    local sw    = DeviceScreen:getWidth()
    local sh    = DeviceScreen:getHeight()
    local is_fr = self.lang == "fr"
    local card  = self:_currentCard()

    local btn_w = math.floor(sw * 0.92)

    -- Action buttons
    local correct_text = is_fr and "✓  +1 Trouvé" or "✓  +1 Got it"
    local buzzed_text  = is_fr and "✗  −1 Grillé"  or "✗  −1 Buzzed"
    local skip_text    = is_fr and "→  Passer"     or "→  Skip"
    local stop_text    = is_fr and "■  Fin de manche" or "■  End round"

    local action_btns = ButtonTable:new{
        shrink_unneeded_width = true,
        width   = btn_w,
        buttons = {{
            { text = correct_text, callback = function() self:onCorrect() end },
            { text = buzzed_text,  callback = function() self:onBuzzed() end },
            { text = skip_text,    callback = function() self:onSkip() end },
            { text = stop_text,    callback = function() self:onStopRound() end },
        }},
    }

    -- Timer
    local timer_fs = math.max(20, math.floor(math.min(sw, sh) * 0.09))
    self.timer_widget = TextWidget:new{
        text = self:_timerText(),
        face = Font:getFace("cfont", timer_fs),
    }

    -- Round stats
    local stats_text = is_fr
        and string.format("✓ %d   ✗ %d", self.round_correct, self.round_buzzed)
        or  string.format("✓ %d   ✗ %d", self.round_correct, self.round_buzzed)
    local stats_w = TextWidget:new{
        text = stats_text,
        face = Font:getFace("smallinfofont"),
    }

    -- Card content
    local card_group
    if not card then
        card_group = TextWidget:new{
            text = is_fr and "Aucune carte." or "No cards.",
            face = Font:getFace("cfont", 24),
        }
    else
        -- Main word
        local word     = card.word or card[1] or "?"
        local word_len = #word
        local word_fs  = word_len > 12 and math.floor(math.min(sw, sh) * 0.08)
                      or word_len > 8  and math.floor(math.min(sw, sh) * 0.10)
                      or                   math.floor(math.min(sw, sh) * 0.13)
        word_fs = math.max(22, math.min(word_fs, 110))

        local word_w = TextWidget:new{
            text = word,
            face = Font:getFace("cfont", word_fs),
        }

        -- Forbidden words
        local forbidden = card.forbidden or card[2] or {}
        local forb_lines = {}
        for _, fw in ipairs(forbidden) do
            forb_lines[#forb_lines + 1] = "× " .. fw
        end
        local forb_text = #forb_lines > 0 and table.concat(forb_lines, "\n") or ""

        local forb_w = TextBoxWidget:new{
            text  = forb_text,
            face  = Font:getFace("cfont", math.max(16, math.floor(math.min(sw, sh) * 0.045))),
            width = math.floor(sw * 0.7),
        }

        local sep_w = TextWidget:new{
            text = string.rep("─", 24),
            face = Font:getFace("smallinfofont"),
        }

        card_group = VerticalGroup:new{
            align = "center",
            word_w,
            VerticalSpan:new{ width = Size.span.vertical_large },
            sep_w,
            VerticalSpan:new{ width = Size.span.vertical_large },
            forb_w,
        }
    end

    -- Frame around card
    local card_frame = FrameContainer:new{
        padding = Size.padding.large,
        margin  = Size.margin.default,
        card_group,
    }

    local vs  = VerticalSpan:new{ width = Size.span.vertical_large }
    local vs2 = VerticalSpan:new{ width = Size.span.vertical_large * 2 }

    self.layout = VerticalGroup:new{
        align = "center",
        vs,
        self.timer_widget,
        vs,
        stats_w,
        vs2,
        card_frame,
        vs2,
        action_btns,
    }
end

-- ---------------------------------------------------------------------------
-- Status
-- ---------------------------------------------------------------------------

function TabouScreen:updateStatus(msg)
    if msg then ScreenBase.updateStatus(self, msg); return end
    local parts = {}
    for _, t in ipairs(self.teams) do
        parts[#parts + 1] = t.name .. " " .. t.score
    end
    ScreenBase.updateStatus(self, table.concat(parts, "  |  "))
end

function TabouScreen:onClose()
    self:_stopCountdown()
    ScreenBase.onClose(self)
end

return TabouScreen
