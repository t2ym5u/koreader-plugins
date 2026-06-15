local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = _dir .. "?.lua;" .. _dir .. "common/?.lua;" .. _dir .. "../game-common/?.lua;" .. package.path

local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local DataStorage     = require("datastorage")
local LuaSettings     = require("luasettings")
local UIManager       = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _               = require("gettext")

local board_module       = lrequire("board")
local ArrowSudokuBoard   = board_module.ArrowSudokuBoard
local DEFAULT_DIFFICULTY = board_module.DEFAULT_DIFFICULTY

local ArrowSudokuScreen = lrequire("screen")

local ArrowSudoku = WidgetContainer:extend{
    name        = "arrowsudoku",
    is_doc_only = false,
}

function ArrowSudoku:ensureSettings()
    if not self.settings_file then
        self.settings_file = DataStorage:getSettingsDir() .. "/arrowsudoku.lua"
    end
    if not self.settings then
        self.settings = LuaSettings:open(self.settings_file)
    end
end

function ArrowSudoku:init()
    self:ensureSettings()
    self.ui.menu:registerToMainMenu(self)
end

function ArrowSudoku:addToMainMenu(menu_items)
    menu_items.arrowsudoku = {
        text         = _("Arrow Sudoku"),
        sorting_hint = "tools",
        callback     = function() self:showGame() end,
    }
end

function ArrowSudoku:getBoard()
    if not self.board then
        self:ensureSettings()
        self.board = ArrowSudokuBoard:new()
        local state = self.settings:readSetting("state")
        if not self.board:load(state) then
            self.board:generate(DEFAULT_DIFFICULTY)
        end
    end
    return self.board
end

function ArrowSudoku:saveState()
    if not self.board then return end
    self:ensureSettings()
    self.settings:saveSetting("state", self.board:serialize())
    self.settings:flush()
end

function ArrowSudoku:showGame()
    if self.screen then return end
    self.screen = ArrowSudokuScreen:new{
        board  = self:getBoard(),
        plugin = self,
    }
    UIManager:show(self.screen)
end

function ArrowSudoku:onScreenClosed()
    self.screen = nil
end

return ArrowSudoku
