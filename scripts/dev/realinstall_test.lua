-- Headless full KOReader FileManager start with REAL plugin copies (no dev
-- symlinks), then opens every installed game the ways a user can:
-- Tools -> Games, its own Tools entry, Dashboard launchGame and the Daily
-- Challenge. Normally driven by realinstall_test.sh, which installs the copies.
--
-- Env (set by realinstall_test.sh):
--   ENV    install dir (settings/ and PNGs of each opened screen land there)
--   PATHS  colon-separated extra plugin dirs, in load order (e.g. real:stale)
--   LANG2  UI language (default fr)
--   TAG    label of the run / PNG prefix (default run)
--   ROUNDS how many times every open is repeated (default 2)
--   TRACE=1 print the full traceback of failures
-- Every symlink in the emulator's plugins/ dir is hidden (lfs.dir filter on
-- "plugins"), so only KOReader's own plugins load from there. Prints
-- "RESULT <tag>: N ok, M failed"; exit 1 if anything failed.
local here = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/") or "."
local H = dofile(here .. "/headless.lua")
local env = H.env
local ENV = assert(env("ENV"), "ENV (install dir) required")
local paths = {}
for p in (env("PATHS") or ""):gmatch("[^:]+") do paths[#paths + 1] = p end

local before_device = function()
    local lfs = require("libs/libkoreader-lfs")
    local orig_dir = lfs.dir
    lfs.dir = function(p)
        if p ~= "plugins" then return orig_dir(p) end
        local list = {}
        for e in orig_dir(p) do
            if lfs.symlinkattributes(p .. "/" .. e, "mode") ~= "link" then list[#list + 1] = e end
        end
        local i = 0
        return function() i = i + 1; return list[i] end
    end
    G_reader_settings:saveSetting("extra_plugin_paths", paths)
    G_reader_settings:saveSetting("plugins_disabled", { simpleui = true })
end
H.init{ settings = ENV .. "/settings", fresh = true, lang = env("LANG2") or "fr",
        w = 758, h = 1024, dpi = 212, before_device = before_device }
local lfs = require("libs/libkoreader-lfs")
local BB, Device = H.BB, H.Device
local UIManager = require("ui/uimanager")
local shown = H.stub_uimanager{ queue = true }
local q = H.queue

-- Installed plugin ids (first path wins, like KOReader) and their sources.
local installed, order, src = {}, {}, {}
for _, dir in ipairs(paths) do
    for e in lfs.dir(dir) do
        local id = e:match("^(.+)%.koplugin$")
        if id and not installed[id] then
            installed[id] = dir .. "/" .. e; order[#order + 1] = id
        end
    end
end
table.sort(order)
local function read(p) local f = io.open(p); if not f then return nil end; local s = f:read("*a"); f:close(); return s end

-- Which plugin's copy of a shared module holds the package.loaded slot.
local esc = ENV:gsub("%p", "%%%0")
local function origin(name)
    local m = package.loaded[name]
    if m == nil then return "-" end
    if type(m) ~= "table" then return type(m) end
    local function where(f) return (debug.getinfo(f, "S").source:gsub("^@", ""):gsub("^" .. esc .. "/", "")) end
    for _, v in pairs(m) do if type(v) == "function" then return where(v) end end
    local mt = getmetatable(m)
    if mt and type(mt.__call) == "function" then return where(mt.__call) end
    return "table"
end

local FileManager = require("apps/filemanager/filemanager")
FileManager:showFiles(ENV)
local fm = FileManager.instance
for i = #q, 1, -1 do q[i] = nil end
local inst = {}
for _, id in ipairs(order) do inst[#inst + 1] = id .. "=" .. (fm[id] and "y" or "n") end
print("instances: " .. table.concat(inst, " "))
for _, n in ipairs({ "screen_base", "plugin_base", "i18n", "grid_widget_base", "stats_exporter", "games_menu", "logic_solver" }) do
    print(string.format("  slot %-16s %s", n, origin(n)))
end
local reg = package.loaded["game_common_registry"]
if reg then
    local t = {}
    for k, v in pairs(reg) do if type(v) == "table" and v.lib then t[#t + 1] = k .. "@" .. v.lib .. ":" .. tostring(v.v) end end
    table.sort(t); print("  registry: " .. table.concat(t, " "))
end

local InfoMessage = require("ui/widget/infomessage")
local fails, oks = 0, 0
local TAG = env("TAG") or "run"
local function try(label, f)
    local before = #shown
    local ok, err = xpcall(function() f(); H.flush() end, debug.traceback)
    for i = #q, 1, -1 do q[i] = nil end
    local scr = shown[#shown]
    if ok and #shown > before and scr then
        if getmetatable(scr) == InfoMessage then
            ok, err = false, "only an InfoMessage: " .. tostring(scr.text)
        else
            ok, err = xpcall(function()
                Device.screen.bb:fill(BB.COLOR_WHITE)
                scr:paintTo(Device.screen.bb, 0, 0)
                Device.screen.bb:writePNG(ENV .. "/" .. TAG .. "_" .. label:gsub("[^%w]", "_") .. ".png")
                if scr.onClose then scr:onClose() else UIManager:close(scr) end
            end, debug.traceback)
        end
    elseif ok then
        ok, err = false, "nothing shown"
    end
    if ok then oks = oks + 1 else fails = fails + 1 end
    print(string.format("%-32s %s", label, ok and "OK" or ("FAIL " .. tostring(err):gsub("\n.*", ""))))
    if not ok and env("TRACE") then print(err) end
end

-- Tools -> Games
fm.menu:setUpdateItemTable()
local mi = fm.menu.menu_items
local cats, game_items = {}, {}
if mi.games then
    for _, it in ipairs(mi.games.sub_item_table_func()) do
        cats[#cats + 1] = it.text
        for _, g in ipairs(it.sub_item_table or {}) do game_items[g.text] = g end
    end
end
print("Tools->Games: " .. table.concat(cats, " | "))
local in_games = {}
for _, g in ipairs(mi.games and mi.games.games_list or {}) do in_games[g.id] = g end
local function menuOpen(id)
    local entry = in_games[id]
    local it = entry and game_items[entry.label]
    assert(it, "no Games entry for " .. id .. " (" .. tostring(entry and entry.label) .. ")")
    it.callback()
end

-- What each installed plugin offers (same detection as Dashboard's scan).
local kinds = {}
for _, id in ipairs(order) do
    local main_src = read(installed[id] .. "/main.lua") or ""
    local scr_src = read(installed[id] .. "/screen.lua") or ""
    local daily
    if main_src:find(":showDailyChallenge%(") then daily = "plugin"
    elseif scr_src:find("makeDailyButtonConfig", 1, true) or scr_src:find(":onDailyGame%(") then daily = "screen" end
    local party = main_src:find("%f[%w_]party_mode%s*=%s*true") ~= nil
    kinds[id] = { daily = daily, mode = party and "solo" or nil }
end

local d = fm.dashboard
for round = 1, tonumber(env("ROUNDS") or 2) do
    for _, id in ipairs(order) do
        if fm[id] and id ~= "dashboard" then
            local k = kinds[id]
            if in_games[id] then
                try("menu " .. id .. " #" .. round, function() menuOpen(id) end)
            elseif mi[id] and mi[id].callback then
                try("tools " .. id .. " #" .. round, function() mi[id].callback() end)
            end
            if d and fm[id].showGame then
                try("dash " .. id .. " #" .. round, function() d:launchGame({ id = id, label = id, mode = k.mode }) end)
                if k.daily then
                    try("daily " .. id .. " #" .. round, function()
                        d:launchDaily({ id = id, label = id, daily = k.daily, mode = k.daily == "screen" and k.mode or nil }, false)
                    end)
                end
            end
        end
    end
end

-- Translations: menu texts were translated at load; these go through
-- whichever i18n holds the shared slot now.
local tt = require("i18n")
local tr = {}
for _, id in ipairs(order) do
    local s = read(installed[id] .. "/i18n_fr.lua")
    local k = s and s:match('%["([^"]+)"%]%s*=%s*{%s*fr')
    if k then tr[#tr + 1] = string.format("  %s: %q -> %q", id, k, tt(k)) end
end
tr[#tr + 1] = string.format("  common: %q -> %q", "Games", tt("Games"))
tr[#tr + 1] = string.format("  common: %q -> %q", "New game", tt("New game"))
print("translations (" .. (env("LANG2") or "fr") .. "):\n" .. table.concat(tr, "\n"))
print(string.format("RESULT %s: %d ok, %d failed", TAG, oks, fails))
os.exit(fails > 0 and 1 or 0)
