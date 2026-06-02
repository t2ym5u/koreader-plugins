local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = _dir .. "?.lua;" .. _dir .. "common/?.lua;" .. package.path

local PluginBase       = require("plugin_base")
local NonogramScreen   = require("screen")
local _                = require("gettext")

local NonogramPlugin = PluginBase:extend{
    name      = "nonogram",
    menu_text = _("Nonogram"),
    menu_hint = "tools",
}

function NonogramPlugin:createScreen()
    return NonogramScreen:new{ plugin = self }
end

return NonogramPlugin
