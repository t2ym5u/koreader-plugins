local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = _dir .. "?.lua;" .. _dir .. "common/?.lua;" .. package.path

local PluginBase = require("plugin_base")
local _          = require("gettext")

local MastermindScreen = require("screen")

-- ---------------------------------------------------------------------------
-- MastermindPlugin
-- ---------------------------------------------------------------------------

local MastermindPlugin = PluginBase:extend{
    name      = "mastermind",
    menu_text = _("Mastermind"),
    menu_hint = "tools",
}

function MastermindPlugin:createScreen()
    return MastermindScreen:new{
        plugin = self,
    }
end

return MastermindPlugin
