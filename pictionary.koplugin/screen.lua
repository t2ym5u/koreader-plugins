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

local MenuHelper  = require("menu_helper")
local ScreenBase  = require("screen_base")
local Words       = lrequire("words")

local DeviceScreen = Device.screen

local DEFAULT_NB_TEAMS = 2
local DEFAULT_DURATION  = 60
local DEFAULT_DIFF      = "mixed"
local DEFAULT_CAT       = "all"

local RULES_EN = _([[
Pictionary Party — Rules

Teams take turns. The current team's drawer receives the device, sees the word privately, then draws it on paper while teammates guess.

• Timer runs during drawing.
• No speaking, no gestures beyond drawing.
• ✓ Got it! = +1 point for the team.
• ✗ Missed = 0 points, next team plays.

First team to reach the agreed score wins!
]])

local RULES_FR = [[
Pictionary Party — Règles

Les équipes jouent à tour de rôle. Le dessinateur reçoit l'appareil, voit le mot en secret, puis le dessine sur papier pendant que ses coéquipiers devinent.

• Le minuteur tourne pendant le dessin.
• Pas de parole, pas de geste autre que le dessin.
• ✓ Trouvé ! = +1 point pour l'équipe.
• ✗ Raté = 0 point, à l'équipe suivante.

La première équipe au score convenu gagne !
]]

-- ---------------------------------------------------------------------------
-- PictionaryScreen
-- ---------------------------------------------------------------------------

local PictionaryScreen = ScreenBase:extend{}

function PictionaryScreen:init()
    self.lang       = self.plugin:getSetting("lang", "fr")
    self.duration   = self.plugin:getSetting("duration", DEFAULT_DURATION)
    self.difficulty = self.plugin:getSetting("difficulty", DEFAULT_DIFF)
    self.category   = self.plugin:getSetting("category", DEFAULT_CAT)
    local nb        = self.plugin:getSetting("nb_teams", DEFAULT_NB_TEAMS)

    self.teams = {}
    for i = 1, nb do
        local default_name = self.lang == "fr" and ("Équipe " .. i) or ("Team " .. i)
        self.teams[i] = {
            name  = self.plugin:getSetting("team_name_" .. i, default_name),
            score = 0,
        }
    end
    self.current_team   = 1
    self.phase          = "ready"
    self.current_word   = ""
    self.time_remaining = self.duration

    ScreenBase.init(self)
end

-- ---------------------------------------------------------------------------
-- Word picking
-- ---------------------------------------------------------------------------

function PictionaryScreen:_pickWord()
    local lang_list = Words[self.lang] or Words.fr
    local pool = {}
    local diffs = self.difficulty == "mixed" and { "e", "m", "h" } or { self.difficulty:sub(1,1) }

    for _, cat in ipairs(lang_list) do
        if self.category == "all" or cat.id == self.category then
            for _, d in ipairs(diffs) do
                local wlist = cat.words[d]
                if wlist then
                    for _, w in ipairs(wlist) do
                        pool[#pool + 1] = { word = w, cat = cat.name }
                    end
                end
            end
        end
    end

    if #pool == 0 then
        return { word = "???", cat = "???" }
    end
    return pool[math.random(#pool)]
end

-- ---------------------------------------------------------------------------
-- Timer
-- ---------------------------------------------------------------------------

function PictionaryScreen:_startCountdown()
    self._tick_gen = (self._tick_gen or 0) + 1
    local gen = self._tick_gen
    UIManager:scheduleIn(1, function() self:_onTick(gen) end)
end

function PictionaryScreen:_stopCountdown()
    self._tick_gen = (self._tick_gen or 0) + 1
end

function PictionaryScreen:_onTick(gen)
    if gen ~= self._tick_gen then return end
    self.time_remaining = math.max(0, self.time_remaining - 1)
    if self.timer_widget then
        self.timer_widget:setText(self:_timerText())
        UIManager:setDirty(self, function() return "fast", self.dimen end)
    end
    if self.time_remaining > 0 then
        UIManager:scheduleIn(1, function() self:_onTick(gen) end)
    end
    -- At zero: timer stops, [✓]/[✗] buttons remain for manual resolution
end

function PictionaryScreen:_timerText()
    local m = math.floor(self.time_remaining / 60)
    local s = self.time_remaining % 60
    return string.format("%d:%02d", m, s)
end

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

function PictionaryScreen:onReveal()
    local entry         = self:_pickWord()
    self.current_word   = entry.word
    self.current_cat    = entry.cat
    self.time_remaining = self.duration
    self.phase          = "drawing"
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
    self:_startCountdown()
end

function PictionaryScreen:onResult(found)
    self:_stopCountdown()
    if found then
        self.teams[self.current_team].score = self.teams[self.current_team].score + 1
    end
    self.current_team = (self.current_team % #self.teams) + 1
    self.phase        = "ready"
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function PictionaryScreen:onResetScores()
    for _, t in ipairs(self.teams) do t.score = 0 end
    self.current_team = 1
    self.phase        = "ready"
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

-- ---------------------------------------------------------------------------
-- Settings menus
-- ---------------------------------------------------------------------------

function PictionaryScreen:openOptionsMenu()
    local is_fr = self.lang == "fr"
    local items = {
        { id = "lang",       text = is_fr and "Langue…"          or "Language…" },
        { id = "teams",      text = is_fr and "Nombre d'équipes…" or "Number of teams…" },
        { id = "duration",   text = is_fr and "Durée du chrono…"  or "Timer duration…" },
        { id = "category",   text = is_fr and "Catégorie…"        or "Category…" },
        { id = "difficulty", text = is_fr and "Difficulté…"       or "Difficulty…" },
        { id = "reset",      text = is_fr and "Remettre les scores à zéro" or "Reset scores" },
    }
    MenuHelper.openPickerMenu{
        title     = is_fr and "Options" or "Options",
        items     = items,
        parent    = self,
        on_select = function(id)
            if     id == "lang"       then self:openLangMenu()
            elseif id == "teams"      then self:openTeamsMenu()
            elseif id == "duration"   then self:openDurationMenu()
            elseif id == "category"   then self:openCategoryMenu()
            elseif id == "difficulty" then self:openDifficultyMenu()
            elseif id == "reset"      then self:onResetScores()
            end
        end,
    }
end

function PictionaryScreen:openLangMenu()
    MenuHelper.openPickerMenu{
        title      = "Language / Langue",
        items      = { { id = "fr", text = "Français" }, { id = "en", text = "English" } },
        current_id = self.lang,
        parent     = self,
        on_select  = function(lang)
            self.lang = lang
            self.plugin:saveSetting("lang", lang)
            -- Update team names only if still at defaults
            for i, t in ipairs(self.teams) do
                local old_default = (lang == "en" and "Équipe " or "Team ") .. i
                if t.name == old_default then
                    t.name = (lang == "fr" and "Équipe " or "Team ") .. i
                end
            end
            self:buildLayout()
            UIManager:setDirty(self, function() return "ui", self.dimen end)
        end,
    }
end

function PictionaryScreen:openTeamsMenu()
    local is_fr = self.lang == "fr"
    local items = {}
    for n = 2, 6 do
        items[#items + 1] = { id = n, text = tostring(n) .. " " .. (is_fr and "équipes" or "teams") }
    end
    MenuHelper.openPickerMenu{
        title      = is_fr and "Nombre d'équipes" or "Number of teams",
        items      = items,
        current_id = #self.teams,
        parent     = self,
        on_select  = function(n)
            local old = #self.teams
            self.plugin:saveSetting("nb_teams", n)
            while #self.teams < n do
                local i = #self.teams + 1
                self.teams[i] = { name = (self.lang == "fr" and "Équipe " or "Team ") .. i, score = 0 }
            end
            while #self.teams > n do
                table.remove(self.teams)
            end
            if self.current_team > #self.teams then self.current_team = 1 end
            self:buildLayout()
            UIManager:setDirty(self, function() return "ui", self.dimen end)
        end,
    }
end

function PictionaryScreen:openDurationMenu()
    local is_fr = self.lang == "fr"
    local items = {
        { id = 45,  text = "0:45" },
        { id = 60,  text = "1:00" },
        { id = 90,  text = "1:30" },
        { id = 120, text = "2:00" },
    }
    MenuHelper.openPickerMenu{
        title      = is_fr and "Durée" or "Duration",
        items      = items,
        current_id = self.duration,
        parent     = self,
        on_select  = function(dur)
            self.duration = dur
            self.plugin:saveSetting("duration", dur)
        end,
    }
end

function PictionaryScreen:openCategoryMenu()
    local is_fr   = self.lang == "fr"
    local lang_list = Words[self.lang] or Words.fr
    local items   = { { id = "all", text = is_fr and "Toutes" or "All" } }
    for _, cat in ipairs(lang_list) do
        items[#items + 1] = { id = cat.id, text = cat.name }
    end
    MenuHelper.openPickerMenu{
        title      = is_fr and "Catégorie" or "Category",
        items      = items,
        current_id = self.category,
        parent     = self,
        on_select  = function(cat)
            self.category = cat
            self.plugin:saveSetting("category", cat)
        end,
    }
end

function PictionaryScreen:openDifficultyMenu()
    local is_fr = self.lang == "fr"
    local items = {
        { id = "mixed", text = is_fr and "Mixte"     or "Mixed" },
        { id = "e",     text = is_fr and "Facile"    or "Easy" },
        { id = "m",     text = is_fr and "Moyen"     or "Medium" },
        { id = "h",     text = is_fr and "Difficile" or "Hard" },
    }
    MenuHelper.openPickerMenu{
        title      = is_fr and "Difficulté" or "Difficulty",
        items      = items,
        current_id = self.difficulty,
        parent     = self,
        on_select  = function(diff)
            self.difficulty = diff
            self.plugin:saveSetting("difficulty", diff)
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

function PictionaryScreen:buildLayout()
    if self.phase == "ready" then
        self:_buildReadyLayout()
    else
        self:_buildDrawingLayout()
    end
    self[1] = self.layout
    self:updateStatus()
end

function PictionaryScreen:_buildReadyLayout()
    local sw         = DeviceScreen:getWidth()
    local sh         = DeviceScreen:getHeight()
    local short_side = math.min(sw, sh)
    local is_fr      = self.lang == "fr"
    local team       = self.teams[self.current_team]

    -- Buttons
    local btn_w = math.floor(sw * 0.92)
    local reveal_text = is_fr and "Voir le mot" or "Show the word"
    local buttons = ButtonTable:new{
        shrink_unneeded_width = true,
        width   = btn_w,
        buttons = {{
            { text = reveal_text, callback = function() self:onReveal() end },
            { text = is_fr and "Options" or "Options", callback = function() self:openOptionsMenu() end },
            self:makeRulesButtonConfig(RULES_EN, RULES_FR),
            self:makeCloseButtonConfig(),
        }},
    }

    -- Team name (large)
    local team_fs = math.max(28, math.floor(short_side * 0.09))
    local team_w  = TextWidget:new{
        text = team.name:upper(),
        face = Font:getFace("cfont", team_fs),
    }

    -- Score line
    local score_parts = {}
    for _, t in ipairs(self.teams) do
        score_parts[#score_parts + 1] = t.name .. " : " .. t.score
    end
    local score_w = TextWidget:new{
        text = table.concat(score_parts, "   "),
        face = Font:getFace("smallinfofont"),
    }

    -- Instruction
    local instr_fs = math.max(16, math.floor(short_side * 0.045))
    local instr    = is_fr and "Passez l'appareil au dessinateur" or "Pass the device to the drawer"
    local instr_w  = TextWidget:new{
        text = instr,
        face = Font:getFace("cfont", instr_fs),
    }

    -- Category / difficulty hint
    local cat_label  = self:_catLabel()
    local diff_label = self:_diffLabel()
    local hint_w = TextWidget:new{
        text = cat_label .. "  ·  " .. diff_label,
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
        hint_w,
        vs2,
        instr_w,
        vs2,
        buttons,
    }
end

function PictionaryScreen:_buildDrawingLayout()
    local sw         = DeviceScreen:getWidth()
    local sh         = DeviceScreen:getHeight()
    local short_side = math.min(sw, sh)
    local is_fr      = self.lang == "fr"
    local team       = self.teams[self.current_team]

    -- Word widget — font size adapts to word length
    local word    = self.current_word
    local base_fs = math.floor(short_side * 0.18)
    local word_fs = #word > 12 and math.floor(base_fs * 0.55)
                 or #word > 8  and math.floor(base_fs * 0.72)
                 or base_fs
    word_fs = math.max(24, math.min(word_fs, 140))

    local word_w = TextWidget:new{
        text = word,
        face = Font:getFace("cfont", word_fs),
    }

    -- Timer
    local timer_fs = math.max(20, math.floor(short_side * 0.11))
    self.timer_widget = TextWidget:new{
        text = self:_timerText(),
        face = Font:getFace("cfont", timer_fs),
    }

    -- Team indicator
    local team_w = TextWidget:new{
        text = team.name,
        face = Font:getFace("smallinfofont"),
    }

    -- Result buttons
    local btn_w = math.floor(sw * 0.92)
    local result_btns = ButtonTable:new{
        shrink_unneeded_width = true,
        width   = btn_w,
        buttons = {{
            { text = is_fr and "✓  Trouvé !" or "✓  Got it!",
              callback = function() self:onResult(true) end },
            { text = is_fr and "✗  Raté" or "✗  Missed",
              callback = function() self:onResult(false) end },
        }},
    }

    local vs  = VerticalSpan:new{ width = Size.span.vertical_large }
    local vs2 = VerticalSpan:new{ width = Size.span.vertical_large * 3 }

    self.layout = VerticalGroup:new{
        align = "center",
        vs,
        team_w,
        vs2,
        word_w,
        vs2,
        self.timer_widget,
        vs2,
        result_btns,
    }
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

function PictionaryScreen:_catLabel()
    if self.category == "all" then
        return self.lang == "fr" and "Toutes catégories" or "All categories"
    end
    local lang_list = Words[self.lang] or Words.fr
    for _, cat in ipairs(lang_list) do
        if cat.id == self.category then return cat.name end
    end
    return self.category
end

function PictionaryScreen:_diffLabel()
    local tbl = {
        mixed = { fr = "Mixte",     en = "Mixed" },
        e     = { fr = "Facile",    en = "Easy" },
        m     = { fr = "Moyen",     en = "Medium" },
        h     = { fr = "Difficile", en = "Hard" },
    }
    local t = tbl[self.difficulty] or tbl.mixed
    return t[self.lang] or t.fr
end

function PictionaryScreen:updateStatus(msg)
    if msg then ScreenBase.updateStatus(self, msg); return end
    local parts = {}
    for _, t in ipairs(self.teams) do
        parts[#parts + 1] = t.name .. " " .. t.score
    end
    ScreenBase.updateStatus(self, table.concat(parts, "  |  "))
end

function PictionaryScreen:onClose()
    self:_stopCountdown()
    ScreenBase.onClose(self)
end

return PictionaryScreen
