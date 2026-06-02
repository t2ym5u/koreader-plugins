local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = _dir .. "?.lua;" .. _dir .. "common/?.lua;" .. package.path

local PluginBase = require("plugin_base")
local _          = require("gettext")

local HitoriScreen = require("screen")

local HitoriPlugin = PluginBase:extend{
    name      = "hitori",
    menu_text = _("Hitori"),
    menu_hint = "tools",
}

function HitoriPlugin:createScreen()
    return HitoriScreen:new{ plugin = self }
end

return HitoriPlugin
