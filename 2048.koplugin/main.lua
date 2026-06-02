local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = _dir .. "?.lua;" .. _dir .. "common/?.lua;" .. package.path

local PluginBase  = require("plugin_base")
local _           = require("gettext")
local Game2048Screen = require("screen")

local Game2048 = PluginBase:extend{
    name      = "2048",
    menu_text = _("2048"),
    menu_hint = "tools",
}

function Game2048:createScreen()
    return Game2048Screen:new{ plugin = self }
end

return Game2048
