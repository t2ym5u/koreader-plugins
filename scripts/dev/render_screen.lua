-- Headless render of a plugin's game screen to a PNG (no SDL window).
--
--   scripts/dev/kolua.sh render_screen.lua <plugin_id> <out.png> <w> <h> [lang]
--   (= cd "$KOREADER_EMU" && ./luajit "$REPO/scripts/dev/render_screen.lua" ...)
--
-- Loads <REPO>/<id>.koplugin like PluginLoader does, calls createScreen()
-- (or showGame() and takes the shown widget), paints it on a white w x h
-- 8-bit page and writes the PNG. Each run starts from fresh settings in
-- $WORK/render/<id>_<lang>/ (the game's own settings file lands there).
--
-- Env:
--   RENDER_DPI  screen DPI (default 212 = Kobo Aura 758x1024; 300 = Libra/Clara HD)
--   SEED        math.randomseed before the screen is created (default 7)
--   KEEP=1      keep the previous settings of this id/lang instead of wiping them
--   MODE        argument passed to showGame(MODE) when there is no createScreen
--   CAT         saved as the plugin's category_<lang> setting (word games)
--   SETUP       Lua run BEFORE the screen exists, locals: p (plugin), H (headless.lua)
--               e.g. SETUP='p:saveSetting("difficulty", "hard")'
--   STATE       Lua run AFTER the screen exists, locals: scr, p, shown, H.
--               It may `return` a widget to paint on top (centred), e.g. a menu:
--               STATE='scr:onNewGame()'
--               STATE='scr:openDifficultyMenu(); return shown[#shown]'
--               STATE='scr:onStartTurn(); scr:onReveal()'        (quiz)
--   STATE_FILE  same as STATE but a file whose chunk receives (scr, p, shown, H)
--               as `...` -- for multi-step scenes; copy one per screenshot.
--   TAP         "x,y;x,y" taps sent as Gesture events after a first paint
--   OVERLAY=last  paint the last widget passed to UIManager:show on top
-- Prints "ok <out>" on success; diagnostics go to stderr.
local here = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/") or "."
local H = dofile(here .. "/headless.lua")
local env = H.env

local id, out, W, Hh, lang = arg[1], arg[2], tonumber(arg[3]), tonumber(arg[4]), arg[5] or "en"
if not (id and out and W and Hh) then
    io.stderr:write("usage: render_screen.lua <plugin_id> <out.png> <w> <h> [lang]\n"); os.exit(2)
end
H.init{
    settings = H.WORK .. "/render/" .. id .. "_" .. lang,
    fresh = env("KEEP") ~= "1",
    lang = lang, w = W, h = Hh, dpi = tonumber(env("RENDER_DPI") or 212),
}
local BB, Screen = H.BB, H.Screen
local shown = H.stub_uimanager()

local menu_items = {}
local fake_ui = { menu = { registerToMainMenu = function(_, plugin)
    if plugin.addToMainMenu then pcall(plugin.addToMainMenu, plugin, menu_items) end
end } }
local p = H.load_plugin(id, nil, fake_ui)
local mi = menu_items[id]
if mi then io.stderr:write(("menu: %s (sorting_hint=%s)\n"):format(tostring(mi.text), tostring(mi.sorting_hint))) end

if p.saveSetting then
    p:saveSetting("lang", lang)
    if env("CAT") then p:saveSetting("category_" .. lang, env("CAT")) end
end
local function chunk(src, name, ...)
    local f = assert(loadstring(src, name))
    return f(...)
end
if env("SETUP") then chunk("local p, H = ...; " .. env("SETUP"), "=SETUP", p, H) end

math.randomseed(tonumber(env("SEED") or 7))
local scr
if p.createScreen then
    scr = p:createScreen()
elseif p.showGame then
    p:showGame(env("MODE")); scr = p.screen or shown[#shown]
end
assert(scr, "no screen: plugin has neither createScreen nor showGame")

local overlay
if env("STATE") then
    overlay = chunk("local scr, p, shown, H = ...; " .. env("STATE"), "=STATE", scr, p, shown, H)
end
if env("STATE_FILE") then
    overlay = assert(loadfile(env("STATE_FILE")))(scr, p, shown, H) or overlay
end
scr = p.screen or scr -- some actions recreate the screen
if env("STATE") or env("STATE_FILE") then
    if scr.buildLayout then scr:buildLayout() end
end
if env("TAP") then
    local Event = require("ui/event")
    local Geom = require("ui/geometry")
    H.paint(scr) -- every widget learns its position
    for x, y in env("TAP"):gmatch("(%d+),(%d+)") do
        scr:handleEvent(Event:new("Gesture", { ges = "tap", time = 0,
            pos = Geom:new{ x = tonumber(x), y = tonumber(y), w = 0, h = 0 } }))
        H.paint(scr)
    end
end
if env("OVERLAY") == "last" and shown[#shown] ~= scr then overlay = overlay or shown[#shown] end
if type(overlay) ~= "table" or not overlay.paintTo then overlay = nil end
H.paint(scr, out, overlay and { overlay } or nil)
print("ok " .. out)
os.exit(0)
