-- What each plugin costs at KOReader startup: module load (PluginLoader._load)
-- and instantiation (createPluginInstance), heap retained after a full GC (KB)
-- and wall time (ms), with ALL plugins enabled like on a device.
--
--   scripts/dev/kolua.sh startup_cost.lua                 # per-plugin table + sums
--   TOTALS=1 scripts/dev/kolua.sh startup_cost.lua        # whole-startup heap/time
--   TOTALS=1 ONLY_BUILTIN=1 scripts/dev/kolua.sh startup_cost.lua  # baseline: KOReader's own plugins only
--
-- Plugins come from the emulator's plugins/ dir (dev symlinks made by
-- scripts/link_plugins.sh) plus, for any monorepo plugin not linked there, a
-- symlink in $WORK/startup/extra (passed as extra_plugin_paths).
-- Set-aside plugins and simpleui are disabled. Startup opens the file
-- manager on an empty $WORK/startup/home. PluginManager gets the local
-- manifest.json as its cached catalogue (no network).
--
-- Env: TOTALS=1 (no per-plugin GC instrumentation: real totals, 5 fresh
--      FileManager re-opens timed), ONLY_BUILTIN=1, UILANG=fr (UI language),
--      OUT=file.tsv (per-plugin rows: name loadKB loadms initKB initms re-ms).
-- Per-plugin numbers include a full GC per step, so their ms are only good
-- for ranking; use TOTALS=1 vs TOTALS=1 ONLY_BUILTIN=1 for the real cost.
local here = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/") or "."
local H = dofile(here .. "/headless.lua")
local env = H.env
local BASE = H.WORK .. "/startup"
local HOME, EXTRA = BASE .. "/home", BASE .. "/extra"
H.rmrf(EXTRA); H.mkdir(HOME); H.mkdir(EXTRA)

H.init{
    settings = BASE .. "/settings", fresh_reader = true, lang = env("UILANG"),
    w = 758, h = 1024, dpi = 212,
}
local lfs = require("libs/libkoreader-lfs")
local ours = {}
for _, id in ipairs(H.repo_plugins()) do
    ours[id] = true
    local name = id .. ".koplugin"
    if not lfs.attributes("plugins/" .. name, "mode") then
        os.execute("ln -s " .. H.sh_quote(H.REPO .. "/" .. name) .. " " .. H.sh_quote(EXTRA .. "/" .. name))
    end
end
G_reader_settings:saveSetting("extra_plugin_paths", { EXTRA })
local dis = { simpleui = true }
for id in pairs(H.SET_ASIDE) do dis[id] = true end
if env("ONLY_BUILTIN") then for id in pairs(ours) do dis[id] = true end end
G_reader_settings:saveSetting("plugins_disabled", dis)

local UIManager = require("ui/uimanager")
local time = require("ui/time")
do
    local f = assert(io.open(H.REPO .. "/manifest.json")); local s = f:read("*a"); f:close()
    local pm = require("luasettings"):open(H.SETTINGS .. "/pluginmanager.lua")
    pm:saveSetting("manifest_json", s); pm:saveSetting("last_check", os.time()); pm:flush()
end
local mem = H.mem
local function ms(t0) return time.to_ms(time.since(t0)) end

local PluginLoader = require("pluginloader")
if env("TOTALS") then
    local m0 = mem(); local t0 = time.now()
    local FileManager = require("apps/filemanager/filemanager")
    FileManager:showFiles(HOME)
    UIManager:_repaint()
    print(string.format("TOTAL startup %d ms, heap %.0f KB (from %.0f), plugins enabled=%d%s",
        ms(t0), mem(), m0, #PluginLoader.enabled_plugins, env("ONLY_BUILTIN") and " (ONLY_BUILTIN)" or ""))
    local fm = FileManager.instance
    local K = 5; local t1 = time.now()
    for _ = 1, K do fm:onClose(); FileManager:showFiles(HOME); fm = FileManager.instance; UIManager:_repaint() end
    print(string.format("TOTAL fresh FileManager %.0f ms each, heap %.0f KB", ms(t1) / K, mem()))
    os.exit(0)
end

local PER = {}
local function rec(name)
    PER[name] = PER[name] or { name = name, lms = 0, lkb = 0, ims = 0, ikb = 0, rms = 0 }
    return PER[name]
end
local orig_load = PluginLoader._load
PluginLoader._load = function(self, t)
    for _, v in ipairs(t) do
        local m0 = mem(); local t0 = time.now()
        orig_load(self, { v })
        local r = rec(v.name); r.lms = ms(t0); r.lkb = mem() - m0
    end
end
local orig_create = PluginLoader.createPluginInstance
local phase = "init"
PluginLoader.createPluginInstance = function(self, plugin, attr)
    local m0 = mem(); local t0 = time.now()
    local a, b = orig_create(self, plugin, attr)
    local dt = ms(t0)
    local r = rec(plugin.name)
    if phase == "init" then r.ims = dt; r.ikb = mem() - m0 else r.rms = dt end
    return a, b
end

local FileManager = require("apps/filemanager/filemanager")
FileManager:showFiles(HOME)
phase = "re" -- second FileManager: instantiation only (modules are cached)
FileManager.instance:onClose(); FileManager:showFiles(HOME)

local rows = {}
for name, r in pairs(PER) do if ours[name] then rows[#rows + 1] = r end end
table.sort(rows, function(a, b) return a.lkb + a.ikb > b.lkb + b.ikb end)
local out = env("OUT") and assert(io.open(env("OUT"), "w"))
local fmt = "%-16s %8s %6s %8s %6s %6s %8s"
print(string.format(fmt, "plugin", "loadKB", "loadms", "initKB", "initms", "re-ms", "totKB"))
local S = { lkb = 0, lms = 0, ikb = 0, ims = 0, rms = 0 }
for _, r in ipairs(rows) do
    print(string.format("%-16s %8.0f %6d %8.0f %6d %6d %8.0f", r.name, r.lkb, r.lms, r.ikb, r.ims, r.rms, r.lkb + r.ikb))
    for k in pairs(S) do S[k] = S[k] + r[k] end
    if out then out:write(string.format("%s\t%.0f\t%d\t%.0f\t%d\t%d\n", r.name, r.lkb, r.lms, r.ikb, r.ims, r.rms)) end
end
print(string.format("%-16s %8.0f %6d %8.0f %6d %6d %8.0f", "SUM(" .. #rows .. ")", S.lkb, S.lms, S.ikb, S.ims, S.rms, S.lkb + S.ikb))
if out then out:close() end
os.exit(0)
