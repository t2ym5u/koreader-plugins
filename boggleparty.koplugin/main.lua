local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
-- _dir contains board.lua / words_*.lua as symlinks (dev) or copied files (installed zip)
package.path = _dir .. "?.lua;" .. _dir .. "common/?.lua;" .. _dir .. "../game-common/?.lua;" .. package.path

local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local PluginBase  = require("plugin_base")
local _           = require("gettext")
local PartyScreen = lrequire("screen")

local BoggleParty = PluginBase:extend{
    name      = "boggleparty",
    menu_text = _("Boggle Party"),
    menu_hint = "tools",
}

function BoggleParty:createScreen()
    return PartyScreen:new{ plugin = self }
end

return BoggleParty
