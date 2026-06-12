-- ---------------------------------------------------------------------------
-- OthelloScreen — full-screen UI for Othello/Reversi
-- ---------------------------------------------------------------------------

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

local MenuHelper  = require("menu_helper")
local ScreenBase  = require("screen_base")

local OthelloBoard       = lrequire("board")
local OthelloBoardWidget = lrequire("board_widget")

local DeviceScreen = Device.screen

-- Difficulty → minimax depth
local DIFF_DEPTH = { easy = 2, medium = 4, hard = 6 }

-- ---------------------------------------------------------------------------
-- OthelloScreen
-- ---------------------------------------------------------------------------

local GAME_RULES_EN = _([[
Othello (Reversi) — Rules

Two players alternate placing discs on the board.

When you place a disc, any straight line (horizontal, vertical, or diagonal) of opponent discs bounded between your new disc and one of your existing discs is flipped to your colour.

Rules:
• You must flip at least one opponent disc per move.
• If you have no valid move, your turn is skipped.
• The game ends when the board is full or neither player can move.

The player with the most discs of their colour at the end wins.
]])

local GAME_RULES_FR = [[
Othello (Reversi) — Règles

Les deux joueurs placent alternativement des pions sur le plateau.

Quand vous placez un pion, toute ligne droite (horizontale, verticale ou diagonale) de pions adverses encadrée entre votre nouveau pion et un de vos pions existants est retournée à votre couleur.

Règles :
• Vous devez retourner au moins un pion adverse par coup.
• Si vous n'avez aucun coup valide, votre tour est passé.
• La partie se termine quand le plateau est plein ou qu'aucun joueur ne peut jouer.

Le joueur ayant le plus de pions de sa couleur à la fin gagne.
]]

local OthelloScreen = ScreenBase:extend{}

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

function OthelloScreen:init()
    local state   = self.plugin:loadState()
    self.board    = OthelloBoard:new()
    if not self.board:load(state) then
        self.board:reset()
    end
    ScreenBase.init(self)  -- calls buildLayout()
    -- Trigger AI if it's the AI's first turn
    if self:_isAITurn() then
        UIManager:scheduleIn(0.1, function() self:triggerAI() end)
    end
end

function OthelloScreen:serializeState()
    return self.board:serialize()
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

function OthelloScreen:buildLayout()
    local board = self.board

    self.board_widget = OthelloBoardWidget:new{
        board        = board,
        onCellAction = function(r, c) self:onCellAction(r, c) end,
    }

    local is_landscape = self:isLandscape()
    local sw = DeviceScreen:getWidth()

    local board_frame = FrameContainer:new{
        padding = Size.padding.default,
        margin  = Size.margin.default,
        self.board_widget,
    }

    local board_frame_size = self.board_widget.size
        + (Size.padding.default + Size.margin.default) * 2

    local button_width
    if is_landscape then
        local right_w = sw - board_frame_size - Size.span.horizontal_default * 2
        button_width  = math.max(right_w - Size.span.horizontal_default, 100)
    else
        button_width = math.floor(sw * 0.92)
    end

    -- Top button row: New | Players | Color | Difficulty | Close
    local top_buttons = ButtonTable:new{
        width                 = button_width,
        shrink_unneeded_width = true,
        buttons = {{
            { text = _("Nouveau"),
              callback = function() self:onNewGame() end },
            { text = self:_getPlayersButtonText(),
              callback = function() self:openPlayersMenu() end,
              id = "players_btn" },
            { text = self:_getColorButtonText(),
              callback = function() self:openColorMenu() end,
              id = "color_btn" },
            { text = self:_getDiffButtonText(),
              callback = function() self:openDifficultyMenu() end,
              id = "diff_btn" },
            self:makeRulesButtonConfig(GAME_RULES_EN, GAME_RULES_FR),
            self:makeCloseButtonConfig(),
        }},
    }

    -- Bottom button row: Pass
    local bottom_buttons = ButtonTable:new{
        width                 = button_width,
        shrink_unneeded_width = true,
        buttons = {{
            { text = _("Passer"),
              callback = function() self:onPass() end },
        }},
    }

    self.top_buttons    = top_buttons
    self.bottom_buttons = bottom_buttons

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
-- Helpers: is it the AI's turn?
-- ---------------------------------------------------------------------------

function OthelloScreen:_isAITurn()
    if self.board.status ~= "playing" then return false end
    local players = self.plugin:getSetting("players", 1)
    if players ~= 1 then return false end
    local player_color = self.plugin:getSetting("player_color", "black")
    -- AI plays the opposite color from the human player
    local ai_color = (player_color == "black") and "white" or "black"
    return self.board.turn == ai_color
end

-- ---------------------------------------------------------------------------
-- Cell interaction
-- ---------------------------------------------------------------------------

function OthelloScreen:onCellAction(r, c)
    local board = self.board
    if board.status ~= "playing" then return end

    -- In 1-player mode, only accept input when it's the human's turn
    if not self:_isHumanTurn() then return end

    local result = board:placeDisk(r, c)

    if result == "invalid" then
        return  -- ignore invalid taps silently

    elseif result == "ok" then
        self.board_widget:refresh()
        self.plugin:saveState(self:serializeState())
        self:updateStatus()
        if self:_isAITurn() then
            self:triggerAI()
        end

    elseif result == "skip" then
        -- Current player's turn was preserved (opponent had no moves)
        self.board_widget:refresh()
        self.plugin:saveState(self:serializeState())
        self:showMessage(_("L'adversaire passe son tour !"), 2)
        self:updateStatus()
        -- Check if AI would still need to play (shouldn't happen in skip case,
        -- but handle edge cases)
        if self:_isAITurn() then
            self:triggerAI()
        end

    elseif result == "ended" then
        self.board_widget:refresh()
        self.plugin:saveState(self:serializeState())
        self:updateStatus()
        self:onGameEnd()
    end
end

-- In 1-player mode: returns true if it's the human player's turn.
-- In 2-player mode: always true.
function OthelloScreen:_isHumanTurn()
    local players = self.plugin:getSetting("players", 1)
    if players ~= 1 then return true end
    local player_color = self.plugin:getSetting("player_color", "black")
    return self.board.turn == player_color
end

-- ---------------------------------------------------------------------------
-- Pass button — manually skip turn (for 2P or when stuck)
-- ---------------------------------------------------------------------------

function OthelloScreen:onPass()
    local board = self.board
    if board.status ~= "playing" then return end

    local valid = board:getValidMoves(board.turn)
    if #valid > 0 then
        self:showMessage(_("Vous avez des coups valides disponibles !"), 2)
        return
    end

    -- No valid moves: the player must pass
    -- Simulate by calling _advanceTurn directly
    local result = board:_advanceTurn()
    self.board_widget:refresh()
    self.plugin:saveState(self:serializeState())
    self:updateStatus()

    if result == "ended" then
        self:onGameEnd()
    elseif self:_isAITurn() then
        self:triggerAI()
    end
end

-- ---------------------------------------------------------------------------
-- AI
-- ---------------------------------------------------------------------------

function OthelloScreen:triggerAI()
    if self.board.status ~= "playing" then return end
    if not self:_isAITurn() then return end

    self:updateStatus(_("L'IA reflechit..."))
    local diff  = self.plugin:getSetting("difficulty", "medium")
    local depth = DIFF_DEPTH[diff] or 4

    UIManager:scheduleIn(0.05, function()
        if self.board.status ~= "playing" then return end

        local result = self.board:applyAIMove(depth)
        self.board_widget:refresh()
        self.plugin:saveState(self:serializeState())

        if result == "ended" then
            self:updateStatus()
            self:onGameEnd()
        elseif result == "skip" then
            -- AI's turn was kept because opponent (human) had no moves
            self:showMessage(_("Vous n'avez pas de coup valide, l'IA rejoue !"), 2)
            self:updateStatus()
            -- AI plays again (schedule to avoid deep recursion)
            UIManager:scheduleIn(0.5, function() self:triggerAI() end)
        else
            self:updateStatus()
        end
    end)
end

-- ---------------------------------------------------------------------------
-- New game
-- ---------------------------------------------------------------------------

function OthelloScreen:onNewGame()
    self.board = OthelloBoard:new()
    self.board:reset()
    self.plugin:saveState(self.board:serialize())
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
    if self:_isAITurn() then
        UIManager:scheduleIn(0.1, function() self:triggerAI() end)
    end
end

-- ---------------------------------------------------------------------------
-- Game end
-- ---------------------------------------------------------------------------

function OthelloScreen:onGameEnd()
    local board = self.board
    local bc, wc = board:countDiscs()
    local msg
    if board.winner == "black" then
        msg = string.format(_("Noirs gagnent ! %d - %d"), bc, wc)
    elseif board.winner == "white" then
        msg = string.format(_("Blancs gagnent ! %d - %d"), wc, bc)
    else
        msg = string.format(_("Egalite ! %d - %d"), bc, wc)
    end
    self:showMessage(msg, 4)
end

-- ---------------------------------------------------------------------------
-- Status bar
-- ---------------------------------------------------------------------------

function OthelloScreen:updateStatus(msg)
    local status
    if msg then
        status = msg
    elseif self.board.status == "ended" then
        local bc, wc = self.board:countDiscs()
        local winner = self.board.winner
        if winner == "black" then
            status = string.format(_("Noirs gagnent ! Noirs: %d  Blancs: %d"), bc, wc)
        elseif winner == "white" then
            status = string.format(_("Blancs gagnent ! Noirs: %d  Blancs: %d"), bc, wc)
        else
            status = string.format(_("Egalite ! Noirs: %d  Blancs: %d"), bc, wc)
        end
    else
        local bc, wc  = self.board:countDiscs()
        local turn    = (self.board.turn == "black") and _("Noirs") or _("Blancs")
        local players = self.plugin:getSetting("players", 1)
        local diff    = self.plugin:getSetting("difficulty", "medium")
        local dlabel  = MenuHelper.DIFFICULTY_LABELS[diff] or diff
        if players == 1 then
            local pcol     = self.plugin:getSetting("player_color", "black")
            local ai_col   = (pcol == "black") and "white" or "black"
            local ai_label = (ai_col == "black") and _("(IA=Noirs)") or _("(IA=Blancs)")
            status = string.format("%s joue  N: %d  B: %d  %s %s",
                turn, bc, wc, dlabel, ai_label)
        else
            status = string.format("%s joue  Noirs: %d  Blancs: %d",
                turn, bc, wc)
        end
    end
    ScreenBase.updateStatus(self, status)
end

-- ---------------------------------------------------------------------------
-- Button label helpers
-- ---------------------------------------------------------------------------

function OthelloScreen:_getPlayersButtonText()
    local players = self.plugin:getSetting("players", 1)
    return players == 1 and _("1 joueur") or _("2 joueurs")
end

function OthelloScreen:_getColorButtonText()
    local players = self.plugin:getSetting("players", 1)
    if players ~= 1 then return _("Couleur") end
    local pcol = self.plugin:getSetting("player_color", "black")
    return (pcol == "black") and _("Je=Noirs") or _("Je=Blancs")
end

function OthelloScreen:_getDiffButtonText()
    local diff   = self.plugin:getSetting("difficulty", "medium")
    local dlabel = MenuHelper.DIFFICULTY_LABELS[diff] or diff
    return dlabel
end

-- ---------------------------------------------------------------------------
-- Menus
-- ---------------------------------------------------------------------------

function OthelloScreen:openPlayersMenu()
    MenuHelper.openPickerMenu{
        title      = _("Mode de jeu"),
        items      = {
            { id = 1, text = _("1 joueur (contre IA)") },
            { id = 2, text = _("2 joueurs") },
        },
        current_id = self.plugin:getSetting("players", 1),
        on_select  = function(id)
            self.plugin:saveSetting("players", id)
            local btn = self.top_buttons and self.top_buttons:getButtonById("players_btn")
            if btn then btn:setText(self:_getPlayersButtonText(), btn.width) end
            -- Also update the color button label visibility
            local cbtn = self.top_buttons and self.top_buttons:getButtonById("color_btn")
            if cbtn then cbtn:setText(self:_getColorButtonText(), cbtn.width) end
            self:updateStatus()
        end,
        parent = self,
    }
end

function OthelloScreen:openColorMenu()
    local players = self.plugin:getSetting("players", 1)
    if players ~= 1 then
        self:showMessage(_("Uniquement disponible en mode 1 joueur."), 2)
        return
    end
    MenuHelper.openPickerMenu{
        title      = _("Votre couleur"),
        items      = {
            { id = "black", text = _("Noirs (joue en premier)") },
            { id = "white", text = _("Blancs (joue en second)") },
        },
        current_id = self.plugin:getSetting("player_color", "black"),
        on_select  = function(id)
            self.plugin:saveSetting("player_color", id)
            local btn = self.top_buttons and self.top_buttons:getButtonById("color_btn")
            if btn then btn:setText(self:_getColorButtonText(), btn.width) end
            self:updateStatus()
            -- Start a new game with the new color assignment
            self:onNewGame()
        end,
        parent = self,
    }
end

function OthelloScreen:openDifficultyMenu()
    MenuHelper.openDifficultyMenu{
        current   = self.plugin:getSetting("difficulty", "medium"),
        on_select = function(id)
            self.plugin:saveSetting("difficulty", id)
            local btn = self.top_buttons and self.top_buttons:getButtonById("diff_btn")
            if btn then btn:setText(self:_getDiffButtonText(), btn.width) end
            self:updateStatus()
        end,
        parent = self,
    }
end

return OthelloScreen
