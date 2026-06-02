local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = _dir .. "?.lua;" .. _dir .. "common/?.lua;" .. package.path

local PluginBase = require("plugin_base")
local _          = require("gettext")

local FutoshikiScreen = require("screen")

local FutoshikiPlugin = PluginBase:extend{
    name      = "futoshiki",
    menu_text = _("Futoshiki"),
    menu_hint = "tools",
}

function FutoshikiPlugin:createScreen()
    return FutoshikiScreen:new{ plugin = self }
end

return FutoshikiPlugin
