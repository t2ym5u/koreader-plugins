-- Add the plugin dir and game-common to the Lua path.
local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = _dir .. "?.lua;" .. _dir .. "common/?.lua;" .. package.path

local PluginBase = require("plugin_base")
local _          = require("gettext")

local MyGameScreen = require("screen")

-- ---------------------------------------------------------------------------
-- MyGamePlugin
-- ---------------------------------------------------------------------------

local MyGamePlugin = PluginBase:extend{
    name      = "mygame",
    menu_text = _("My Game"),
    menu_hint = "tools",
}

function MyGamePlugin:createScreen()
    return MyGameScreen:new{
        plugin = self,
    }
end

return MyGamePlugin
