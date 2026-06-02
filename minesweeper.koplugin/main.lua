local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = _dir .. "?.lua;" .. _dir .. "common/?.lua;" .. package.path

local PluginBase       = require("plugin_base")
local _                = require("gettext")
local MinesweeperScreen = require("screen")

local Minesweeper = PluginBase:extend{
    name      = "minesweeper",
    menu_text = _("Minesweeper"),
    menu_hint = "tools",
}

function Minesweeper:createScreen()
    return MinesweeperScreen:new{ plugin = self }
end

return Minesweeper
