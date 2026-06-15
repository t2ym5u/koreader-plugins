local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = _dir .. "?.lua;" .. _dir .. "common/?.lua;" .. _dir .. "../game-common/?.lua;" .. package.path

local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local PluginBase       = require("plugin_base")
local _                = require("gettext")
local CrosswordScreen  = lrequire("screen")

local Crossword = PluginBase:extend{
    name      = "crossword",
    menu_text = _("Crossword"),
    menu_hint = "tools",
}

function Crossword:createScreen()
    return CrosswordScreen:new{ plugin = self }
end

return Crossword
