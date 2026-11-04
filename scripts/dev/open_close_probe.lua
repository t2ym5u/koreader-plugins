-- Smoke test + memory probe of one plugin's game screen lifecycle:
-- load (like PluginLoader), init, open screen, new game, [SWITCH], close,
-- reopen, close. Prints heap deltas (KB, after full GC, relative to "init")
-- and how much memory the plugin's own modules still hold after close
-- (approx. data reachable ONLY from package.loaded entries under the plugin
-- dir: word lists, banks, caches that a close should have released).
--
--   scripts/dev/kolua.sh open_close_probe.lua <plugin_id> [lang] [mode]
--     lang  game/UI language (default en); mode: passed to showGame(mode), e.g. party
--
-- Env:
--   SWITCH='<lua>'  run once after the first new game, locals scr, p
--                   (e.g. a language or mode switch: SWITCH='p:saveSetting("lang","fr"); scr:onNewGame()')
--   NONEW=1         skip the onNewGame step
--   WARM=<id>       probe this plugin first so shared modules (game-common,
--                   KOReader widgets) are already loaded and not charged to the
--                   probed plugin (default hanoi; WARM= to disable)
--   FINDREF=1       when the screen is still referenced after close, print up
--                   to 3 reference paths from the registry/stack to it
--   SEED            math.randomseed (default 7)
-- Output: a "FAIL <id> <step>: <traceback>" line and exit 1 on any error,
-- else one summary line per probed plugin and exit 0.
local here = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/") or "."
local H = dofile(here .. "/headless.lua")
local env = H.env
local id, lang, mode = arg[1], arg[2] or "en", arg[3]
if not id then io.stderr:write("usage: open_close_probe.lua <plugin_id> [lang] [mode]\n"); os.exit(2) end
H.init{ settings = H.WORK .. "/probe/" .. id .. "_" .. lang, fresh = true, lang = lang, w = 758, h = 1024, dpi = 212 }
math.randomseed(tonumber(env("SEED") or 7))
local UIManager = require("ui/uimanager")
local BB, Device = H.BB, H.Device
local mem = H.mem

-- retained(prefix): approx KB reachable only from package.loaded entries
-- whose key starts with prefix (the plugin's lrequire'd modules).
local function retained(prefix)
    local own = {}
    for k, v in pairs(package.loaded) do
        if type(k) == "string" and k:sub(1, #prefix) == prefix then own[k] = v end
    end
    local seen = {}
    local stack = { debug.getregistry() }
    while #stack > 0 do
        local o = stack[#stack]; stack[#stack] = nil
        local t = type(o)
        if (t == "table" or t == "function" or t == "userdata" or t == "thread") and not seen[o] then
            seen[o] = true
            if t == "table" then
                if o == package.loaded then
                    for k, v in next, o do if not own[k] then stack[#stack + 1] = v end end
                elseif o ~= seen then
                    for k, v in next, o do stack[#stack + 1] = k; stack[#stack + 1] = v end
                end
                local mt = getmetatable(o); if mt then stack[#stack + 1] = mt end
            elseif t == "function" then
                local i = 1
                while true do local n, v = debug.getupvalue(o, i); if not n then break end; stack[#stack + 1] = v; i = i + 1 end
            end
        end
    end
    local bytes, strs = 0, {}
    stack = {}
    for _, v in pairs(own) do stack[#stack + 1] = v end
    while #stack > 0 do
        local o = stack[#stack]; stack[#stack] = nil
        local t = type(o)
        if t == "string" then
            if not strs[o] then strs[o] = true; bytes = bytes + #o + 24 end
        elseif (t == "table" or t == "function") and not seen[o] then
            seen[o] = true
            if t == "table" then
                bytes = bytes + 56
                for k, v in next, o do bytes = bytes + 16; stack[#stack + 1] = k; stack[#stack + 1] = v end
                local mt = getmetatable(o); if mt then stack[#stack + 1] = mt end
            else
                bytes = bytes + 64
                local i = 1
                while true do local n, v = debug.getupvalue(o, i); if not n then break end; stack[#stack + 1] = v; i = i + 1 end
            end
        end
    end
    return bytes / 1024
end

-- findref(target): print paths from the registry (and the stack) to target.
local function findref(target, maxn)
    local seen = setmetatable({}, { __mode = "k" })
    local queue = { { debug.getregistry(), "REG" } }
    local head, found = 1, 0
    seen[queue[1][1]] = true
    for lvl = 2, 30 do
        local info = debug.getinfo(lvl, "f"); if not info then break end
        queue[#queue + 1] = { info.func, "STACK" .. lvl .. "fn" }
        local i = 1
        while true do
            local n, v = debug.getlocal(lvl, i); if not n then break end
            if rawequal(v, target) then print("  REF: stack " .. lvl .. " local " .. n) end
            if type(v) == "table" or type(v) == "function" then queue[#queue + 1] = { v, "STACK" .. lvl .. "." .. n } end
            i = i + 1
        end
    end
    while head <= #queue and found < (maxn or 3) do
        local obj, path = queue[head][1], queue[head][2]; queue[head] = false; head = head + 1
        local function visit(v, p)
            if rawequal(v, target) then print("  REF: " .. p); found = found + 1; return end
            local tv = type(v)
            if (tv == "table" or tv == "function" or tv == "userdata" or tv == "thread") and not seen[v] then
                seen[v] = true; queue[#queue + 1] = { v, p }
            end
        end
        local t = type(obj)
        if t == "table" then
            for k, v in next, obj do
                visit(v, path .. "." .. tostring(k):sub(1, 40))
                if type(k) ~= "string" then visit(k, path .. "[key]") end
            end
            local mt = getmetatable(obj); if mt then visit(mt, path .. ".<mt>") end
        elseif t == "function" then
            local i = 1
            while true do local n, v = debug.getupvalue(obj, i); if not n then break end; visit(v, path .. "^" .. n); i = i + 1 end
        elseif t == "userdata" then
            local mt = getmetatable(obj); if mt then visit(mt, path .. ".<umt>") end
        end
    end
end

local function pkgcount() local n = 0; for _ in pairs(package.loaded) do n = n + 1 end; return n end

local function run(pid, pmode)
    local root = H.REPO .. "/" .. pid .. ".koplugin"
    local m_start = mem()
    local saved = package.path
    package.path = root .. "/?.lua;" .. saved
    local Plugin = dofile(root .. "/main.lua")
    package.path = saved .. ";" .. root .. "/?.lua"
    local m_load = mem()
    local p = Plugin:new{ ui = { menu = { registerToMainMenu = function() end } }, path = root, name = pid }
    local m_init = mem()
    local function step(name, f)
        local ok, err = xpcall(f, debug.traceback)
        if not ok then print("FAIL " .. pid .. " " .. name .. ": " .. tostring(err)); os.exit(1) end
    end
    local function paint(w)
        if w and w.paintTo then Device.screen.bb:fill(BB.COLOR_WHITE); w:paintTo(Device.screen.bb, 0, 0) end
    end
    local weak = setmetatable({}, { __mode = "v" })
    local function cycle(tag)
        local scr
        step("open" .. tag, function()
            if p.showGame then p:showGame(pmode) else UIManager:show(p:createScreen()) end
            scr = p.screen; assert(scr, "no p.screen after showGame"); paint(scr)
        end)
        local m_open = mem()
        if scr.onNewGame and env("NONEW") ~= "1" then
            step("newgame" .. tag, function() scr:onNewGame(); paint(p.screen or scr) end)
        end
        scr = p.screen or scr
        local sw = env("SWITCH")
        if sw and tag == "1" and pid == id then
            step("switch", function()
                assert(loadstring("local scr, p = ...; " .. sw, "=SWITCH"))(scr, p)
                scr = p.screen or scr; paint(scr)
            end)
        end
        local m_play = mem()
        step("close" .. tag, function()
            if scr.closeScreen then scr:closeScreen()
            else UIManager:close(scr); if p.onScreenClosed then p:onScreenClosed() end end
        end)
        -- drop UIManager's own references to the closed widget
        UIManager._window_stack = {}
        UIManager._task_queue = {}
        UIManager._refresh_stack = {}; UIManager._dirty = {}; UIManager._refresh_func_stack = {}
        weak[1] = scr
        scr = nil
        return m_open, m_play
    end
    local function closed()
        local m = mem()
        if weak[1] then
            print("  (" .. pid .. ": screen still referenced after close)")
            if env("FINDREF") then findref(weak[1]) end
        end
        return m
    end
    local n0 = pkgcount()
    local o1, p1 = cycle("1"); local c1 = closed()
    local n1 = pkgcount()
    local o2, _ = cycle("2"); local c2 = closed()
    local ret = retained(root .. "/")
    print(string.format("%-14s %s load %+5.0f init %+4.0f | open %+6.0f play %+6.0f closed %+6.0f | reopen %+6.0f closed %+6.0f  (KB vs init) +%d modules; plugin modules hold ~%.0f KB after close",
        pid, lang, m_load - m_start, m_init - m_load, o1 - m_init, p1 - m_init, c1 - m_init, o2 - m_init, c2 - m_init, n1 - n0, ret))
end

local warm = os.getenv("WARM") or "hanoi"
if warm ~= "" and warm ~= id then run(warm, nil) end
run(id, mode)
os.exit(0)
