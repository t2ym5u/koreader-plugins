-- Shared bootstrap for the headless KOReader dev tools in scripts/dev/.
--
-- Must run under the emulator's LuaJIT, from the emulator dir (the dir that
-- holds ./luajit, setupkoenv.lua, frontend/, plugins/):
--     cd "$KOREADER_EMU" && ./luajit "$REPO/scripts/dev/<tool>.lua" ...
-- (scripts/dev/kolua.sh does the cd for you).
--
-- Usage from a tool:
--     local H = dofile(<dir of this file> .. "headless.lua")
--     H.init{ settings = H.WORK .. "/x", fresh = true, lang = "fr", w = 758, h = 1024, dpi = 212 }
--
-- Env:
--   REPO  monorepo root (default: two dirs above this file)
--   WORK  scratch dir for settings/outputs (default ${TMPDIR:-/tmp}/koplugins-dev)
local H = {}

local here = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/[^/]*$") or "."
if here:sub(1, 1) ~= "/" then
    local pwd = os.getenv("PWD") or io.popen("pwd"):read("*l")
    here = pwd .. "/" .. here
end
H.DEV_DIR = here
local function env(k) local v = os.getenv(k); if v == "" then return nil end; return v end
H.env = env
local function realpath(p)
    local f = io.popen("cd '" .. p .. "' 2>/dev/null && pwd -P")
    local r = f and f:read("*l"); if f then f:close() end
    return r or p
end
H.REPO = env("REPO") or realpath(here .. "/../..")
H.WORK = env("WORK") or ((env("TMPDIR") or "/tmp"):gsub("/$", "") .. "/koplugins-dev")

-- Plugins that are never loaded/tested by the dev tools.
H.SET_ASIDE = { kakuro = true, arrowwords = true, startmenu = true,
                boggleparty = true, doubleornothing = true, _skeleton = true }

function H.sh_quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
function H.mkdir(p) os.execute("mkdir -p " .. H.sh_quote(p)) end
function H.rmrf(p) os.execute("rm -rf " .. H.sh_quote(p)) end

function H.mem() collectgarbage("collect"); collectgarbage("collect"); return collectgarbage("count") end

-- Every <id> with a <id>.koplugin dir in the monorepo, minus set-aside ones.
function H.repo_plugins(include_set_aside)
    local lfs = require("libs/libkoreader-lfs")
    local ids = {}
    for e in lfs.dir(H.REPO) do
        local n = e:match("^(.+)%.koplugin$")
        if n and (include_set_aside or not H.SET_ASIDE[n]) then ids[#ids + 1] = n end
    end
    table.sort(ids)
    return ids
end

-- opts: settings (dir, required), fresh (wipe it first), reader (file name
-- inside settings, default reader.lua), lang, w, h, dpi, no_keyboard.
function H.init(opts)
    require("setupkoenv")
    require("dbg"):turnOff()
    local logger = require("logger"); logger:setLevel(logger.levels.err)
    local sdir = assert(opts.settings, "settings dir required")
    if opts.fresh then H.rmrf(sdir) end
    H.mkdir(sdir)
    H.SETTINGS = sdir
    local DataStorage = require("datastorage")
    DataStorage.getSettingsDir = function() return sdir end
    G_defaults = require("luadefaults"):open(sdir .. "/defaults.lua")
    local reader = sdir .. "/" .. (opts.reader or "reader.lua")
    if opts.fresh_reader then os.remove(reader) end
    G_reader_settings = require("luasettings"):open(reader)
    if opts.lang then G_reader_settings:saveSetting("language", opts.lang) end
    if opts.before_device then opts.before_device() end
    einkfb = require("ffi/framebuffer"); einkfb.dummy = true
    local BB = require("ffi/blitbuffer")
    local Device = require("device")
    -- Kobo-like: no keyboard, so menus show no Q/W/E shortcut boxes.
    if opts.no_keyboard ~= false then Device.hasKeyboard = function() return false end end
    local Screen = Device.screen
    Screen:init()
    Screen.bb:free(); Screen.bb = BB.new(opts.w or 758, opts.h or 1024, BB.TYPE_BB8)
    Screen:setDPI(opts.dpi or 212)
    Device.input.dummy = true
    require("document/canvascontext"):init(Device)
    H.BB, H.Device, H.Screen = BB, Device, Screen
    return H
end

-- Stub UIManager so widgets are collected instead of shown and nothing is
-- scheduled. Returns the list of shown widgets and a queue of deferred
-- nextTick/tickAfterNext callbacks (flush with H.flush()).
function H.stub_uimanager(opts)
    opts = opts or {}
    local UIManager = require("ui/uimanager")
    local shown, q = {}, {}
    UIManager.show = function(_, w) shown[#shown + 1] = w end
    if opts.close ~= false then UIManager.close = function() end end
    UIManager.setDirty = function() end
    UIManager.scheduleIn = function() end
    if opts.queue then
        UIManager.nextTick = function(_, f) q[#q + 1] = f end
        UIManager.tickAfterNext = function(_, f) q[#q + 1] = f end
    else
        UIManager.nextTick = function() end
        UIManager.tickAfterNext = function() end
    end
    H.shown, H.queue = shown, q
    return shown, q
end

function H.flush(max)
    local q, n = H.queue, 0
    while #q > 0 and n < (max or 50) do table.remove(q, 1)(); n = n + 1 end
end

-- Load a plugin's main.lua the way PluginLoader does (plugin dir first on
-- package.path while main.lua runs, appended afterwards) and instantiate it.
function H.load_plugin(id, root, ui)
    root = root or (H.REPO .. "/" .. id .. ".koplugin")
    local saved = package.path
    package.path = root .. "/?.lua;" .. saved
    local Plugin = dofile(root .. "/main.lua")
    package.path = saved .. ";" .. root .. "/?.lua"
    ui = ui or { menu = { registerToMainMenu = function() end } }
    return Plugin:new{ ui = ui, path = root, name = id }, Plugin
end

-- Paint a widget (and optional overlays, centred) on a white page and write a PNG.
function H.paint(w, out, overlays)
    local Screen, BB = H.Screen, H.BB
    Screen.bb:fill(BB.COLOR_WHITE)
    w:paintTo(Screen.bb, 0, 0)
    for _, o in ipairs(overlays or {}) do
        if o ~= w and o.paintTo then
            local sz = o.getSize and o:getSize() or { w = 0, h = 0 }
            o:paintTo(Screen.bb, math.floor((Screen.bb:getWidth() - sz.w) / 2),
                math.floor((Screen.bb:getHeight() - sz.h) / 2))
        end
    end
    if out then Screen.bb:writePNG(out) end
end

return H
