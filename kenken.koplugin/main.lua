local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = _dir .. "?.lua;" .. _dir .. "common/?.lua;" .. package.path

local PluginBase   = require("plugin_base")
local _            = require("gettext")
local KenKenScreen = require("screen")

local KenKen = PluginBase:extend{
    name      = "kenken",
    menu_text = _("KenKen"),
    menu_hint = "tools",
}

function KenKen:createScreen()
    return KenKenScreen:new{ plugin = self }
end

return KenKen
