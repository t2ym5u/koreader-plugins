local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = _dir .. "?.lua;" .. _dir .. "common/?.lua;" .. package.path

local PluginBase   = require("plugin_base")
local _            = require("gettext")

local KakuroScreen = require("screen")

local Kakuro = PluginBase:extend{
    name      = "kakuro",
    menu_text = _("Kakuro"),
    menu_hint = "tools",
}

function Kakuro:createScreen()
    return KakuroScreen:new{ plugin = self }
end

return Kakuro
