local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
-- Parent of "pluginmanager.koplugin/" is the KOReader plugins root.
local _plugins_dir = _dir:match("^(.*)/[^/]+/$") or (_dir .. "..")

local ButtonDialog    = require("ui/widget/buttondialog")
local ConfirmBox      = require("ui/widget/confirmbox")
local InfoMessage     = require("ui/widget/infomessage")
local UIManager       = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _               = require("gettext")

local MANIFEST_URL = "https://raw.githubusercontent.com/t2ym5u/koreader-plugins/master/manifest.json"

-- ---------------------------------------------------------------------------
-- PluginManager
-- ---------------------------------------------------------------------------

local PluginManager = WidgetContainer:extend{
    name        = "pluginmanager",
    is_doc_only = false,
    -- _manifest   : table parsed from manifest.json after first fetch
    -- _last_check : timestamp of last successful manifest fetch
}

-- ---------------------------------------------------------------------------
-- Network
-- ---------------------------------------------------------------------------

local function fetch_url(url)
    local ok1, https = pcall(require, "ssl.https")
    if not ok1 then return nil, _("ssl.https not available") end
    local ok2, ltn12 = pcall(require, "ltn12")
    if not ok2 then return nil, _("ltn12 not available") end
    local chunks = {}
    local result, status = https.request{
        url      = url,
        sink     = ltn12.sink.table(chunks),
        verify   = "none",
        protocol = "tlsv1_2",
    }
    if result and status == 200 then
        return table.concat(chunks)
    end
    return nil, string.format(_("HTTP %s"), tostring(status or "?"))
end

-- ---------------------------------------------------------------------------
-- JSON  (rapidjson is bundled with KOReader)
-- ---------------------------------------------------------------------------

local function parse_json(str)
    local ok, json = pcall(require, "rapidjson")
    if not ok then return nil, _("rapidjson not available") end
    local ok2, data = pcall(json.decode, str)
    if ok2 then return data end
    return nil, _("JSON parse error")
end

-- ---------------------------------------------------------------------------
-- Version comparison
-- ---------------------------------------------------------------------------

local function is_newer(a, b)
    local function parts(v)
        local t = {}
        for n in (v or "0"):gmatch("%d+") do t[#t + 1] = tonumber(n) end
        return t
    end
    local ap, bp = parts(a), parts(b)
    for i = 1, math.max(#ap, #bp) do
        local ai, bi = ap[i] or 0, bp[i] or 0
        if bi > ai then return true end
        if bi < ai then return false end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Filesystem helpers
-- ---------------------------------------------------------------------------

local function get_lfs()
    local ok, lfs = pcall(require, "libs/libkoreader-lfs")
    if not ok then ok, lfs = pcall(require, "lfs") end
    return ok and lfs or nil
end

local function mkdir_p(path)
    local lfs = get_lfs()
    if lfs then
        local parts = {}
        local p = path:gsub("/$", "")
        while p and p ~= "" and p ~= "/" do
            table.insert(parts, 1, p)
            p = p:match("^(.*)/[^/]+$")
        end
        for _, seg in ipairs(parts) do
            if lfs.attributes(seg, "mode") ~= "directory" then
                lfs.mkdir(seg)
            end
        end
    else
        os.execute("mkdir -p " .. path)
    end
end

local function write_file(path, content)
    local f, err = io.open(path, "wb")
    if not f then return false, err end
    f:write(content)
    f:close()
    return true
end

-- Recursively delete a path. Only operates inside _plugins_dir for safety.
local function rm_rf(path)
    if not path:find(_plugins_dir, 1, true) then return end
    local lfs = get_lfs()
    if lfs then
        local mode = lfs.attributes(path, "mode")
        if mode == "directory" then
            for f in lfs.dir(path) do
                if f ~= "." and f ~= ".." then rm_rf(path .. "/" .. f) end
            end
            lfs.rmdir(path)
        elseif mode then
            os.remove(path)
        end
    else
        os.execute("rm -rf " .. path)
    end
end

-- Extract name / fullname / version from a _meta.lua by pattern, not by loading.
local function read_meta(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local src = f:read("*a")
    f:close()
    return {
        name     = src:match('name%s*=%s*"([^"]+)"'),
        fullname = src:match('fullname%s*=[^"]*"([^"]*)"'),
        version  = src:match('version%s*=%s*"([^"]+)"'),
    }
end

-- ---------------------------------------------------------------------------
-- Installed-plugin scan
-- ---------------------------------------------------------------------------

function PluginManager:scanInstalled()
    local lfs = get_lfs()
    if not lfs then return {} end
    local installed = {}
    local ok, iter = pcall(lfs.dir, _plugins_dir)
    if not ok then return {} end
    for entry in iter do
        if entry:match("%.koplugin$") and entry ~= "pluginmanager.koplugin" then
            local meta = read_meta(_plugins_dir .. "/" .. entry .. "/_meta.lua")
            if meta and meta.name then
                installed[meta.name] = {
                    version  = meta.version or "?",
                    fullname = meta.fullname or meta.name,
                    dir      = entry,
                }
            end
        end
    end
    return installed
end

-- ---------------------------------------------------------------------------
-- Manifest fetch
-- ---------------------------------------------------------------------------

function PluginManager:fetchManifest()
    local notice = InfoMessage:new{ text = _("Fetching plugin list\u{2026}") }
    UIManager:show(notice)
    UIManager:scheduleIn(0.2, function()
        UIManager:close(notice)
        local body, err = fetch_url(MANIFEST_URL)
        if not body then
            UIManager:show(InfoMessage:new{
                text    = _("Network error:") .. "\n" .. (err or "?"),
                timeout = 5,
            })
            return
        end
        local manifest, jerr = parse_json(body)
        if not manifest or not manifest.plugins then
            UIManager:show(InfoMessage:new{
                text    = _("Manifest error:") .. "\n" .. (jerr or _("unexpected format")),
                timeout = 5,
            })
            return
        end
        self._manifest   = manifest
        self._last_check = os.time()

        -- Quick summary
        local installed = self:scanInstalled()
        local n_update, n_new = 0, 0
        for _, p in ipairs(manifest.plugins) do
            local inst = installed[p.id]
            if not inst then
                n_new = n_new + 1
            elseif is_newer(inst.version, p.version) then
                n_update = n_update + 1
            end
        end
        local parts = {}
        if n_update > 0 then parts[#parts+1] = string.format(_("%d update(s) available"), n_update) end
        if n_new    > 0 then parts[#parts+1] = string.format(_("%d new plugin(s)"), n_new) end
        if #parts   == 0 then parts[#parts+1] = _("All installed plugins are up to date.") end
        UIManager:show(InfoMessage:new{
            text    = table.concat(parts, "\n"),
            timeout = 4,
        })
    end)
end

-- ---------------------------------------------------------------------------
-- Install / update
-- ---------------------------------------------------------------------------

function PluginManager:ensureCommon(manifest)
    local gc_dir = _plugins_dir .. "/game-common"
    local lfs    = get_lfs()
    if lfs and lfs.attributes(gc_dir, "mode") == "directory" then
        local vf = io.open(gc_dir .. "/.version", "r")
        if vf then
            local v = vf:read("*l"); vf:close()
            if not is_newer(v or "0", manifest.common.version) then return true end
        end
    end
    mkdir_p(gc_dir)
    local base = manifest.raw_base_url .. manifest.common.dir .. "/"
    for _, fname in ipairs(manifest.common.files) do
        local body, err = fetch_url(base .. fname)
        if not body then
            return false, string.format("game-common/%s: %s", fname, err)
        end
        write_file(gc_dir .. "/" .. fname, body)
    end
    write_file(gc_dir .. "/.version", manifest.common.version)
    return true
end

function PluginManager:installPlugin(plugin_info, manifest)
    local plugin_dir = _plugins_dir .. "/" .. plugin_info.dir
    mkdir_p(plugin_dir)

    local base = manifest.raw_base_url .. plugin_info.dir .. "/"
    for _, fname in ipairs(plugin_info.files) do
        local body, err = fetch_url(base .. fname)
        if not body then
            return false, string.format(_("Download failed: %s — %s"), fname, err)
        end
        local ok, werr = write_file(plugin_dir .. "/" .. fname, body)
        if not ok then
            return false, string.format(_("Write failed: %s — %s"), fname, werr)
        end
    end

    if plugin_info.has_common then
        local common_path = plugin_dir .. "/common"
        local lfs  = get_lfs()
        local mode = lfs and lfs.attributes(common_path, "mode")
        if mode ~= "link" and mode ~= "directory" then
            local rc = os.execute("ln -sf ../game-common " .. common_path .. " 2>/dev/null")
            if rc ~= 0 then
                local gc_dir = _plugins_dir .. "/game-common"
                mkdir_p(common_path)
                if lfs and lfs.attributes(gc_dir, "mode") == "directory" then
                    for fname in lfs.dir(gc_dir) do
                        if fname:match("%.lua$") then
                            local src = io.open(gc_dir .. "/" .. fname, "rb")
                            if src then
                                local data = src:read("*a"); src:close()
                                write_file(common_path .. "/" .. fname, data)
                            end
                        end
                    end
                end
            end
        end
    end
    return true
end

function PluginManager:_doInstall(plugin_info, manifest)
    local msg = InfoMessage:new{
        text = string.format(_("Installing %s\u{2026}"), plugin_info.fullname),
    }
    UIManager:show(msg)
    UIManager:scheduleIn(0.2, function()
        UIManager:close(msg)
        if plugin_info.has_common and manifest.common then
            local ok, err = self:ensureCommon(manifest)
            if not ok then
                UIManager:show(InfoMessage:new{
                    text    = _("game-common error:") .. "\n" .. (err or "?"),
                    timeout = 5,
                })
                return
            end
        end
        local ok, err = self:installPlugin(plugin_info, manifest)
        if ok then
            UIManager:show(InfoMessage:new{
                text    = string.format(
                    _("%s v%s installed.\nRestart KOReader to activate it."),
                    plugin_info.fullname, plugin_info.version
                ),
                timeout = 6,
            })
        else
            UIManager:show(InfoMessage:new{
                text    = _("Install failed:") .. "\n" .. (err or "?"),
                timeout = 5,
            })
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Remove
-- ---------------------------------------------------------------------------

function PluginManager:_doRemove(fullname, plugin_dir)
    local path = _plugins_dir .. "/" .. plugin_dir
    rm_rf(path)
    UIManager:show(InfoMessage:new{
        text    = string.format(
            _("%s removed.\nRestart KOReader to complete uninstallation."),
            fullname
        ),
        timeout = 5,
    })
end

-- ---------------------------------------------------------------------------
-- Per-plugin action dialogs
-- ---------------------------------------------------------------------------

-- Dialog for an installed plugin: Update (if newer exists) + Remove.
function PluginManager:showInstalledDialog(plugin_info, inst_info, has_update)
    local dlg
    local buttons = {}

    if has_update then
        local pref = plugin_info
        buttons[#buttons + 1] = {{
            text = string.format(_("Update to v%s"), plugin_info.version),
            callback = function()
                UIManager:close(dlg)
                self:_doInstall(pref, self._manifest)
            end,
        }}
    end

    local iref = inst_info
    local pref = plugin_info
    buttons[#buttons + 1] = {{
        text = _("Remove"),
        callback = function()
            UIManager:close(dlg)
            UIManager:show(ConfirmBox:new{
                text       = string.format(
                    _("Remove %s?\nAll plugin files will be deleted."),
                    iref.fullname
                ),
                ok_text    = _("Remove"),
                ok_callback = function()
                    self:_doRemove(iref.fullname, iref.dir)
                end,
            })
        end,
    }}

    buttons[#buttons + 1] = {{
        text     = _("Cancel"),
        callback = function() UIManager:close(dlg) end,
    }}

    local title = string.format("%s  v%s", inst_info.fullname, inst_info.version)
    if has_update then
        title = title .. string.format("  \u{2192}  v%s", plugin_info.version)
    end
    dlg = ButtonDialog:new{ title = title, buttons = buttons }
    UIManager:show(dlg)
end

-- Dialog for a not-yet-installed plugin: Install.
function PluginManager:showAvailableDialog(plugin_info)
    local dlg
    dlg = ButtonDialog:new{
        title   = string.format("%s  v%s", plugin_info.fullname, plugin_info.version),
        buttons = {
            {{
                text = _("Install"),
                callback = function()
                    UIManager:close(dlg)
                    self:_doInstall(plugin_info, self._manifest)
                end,
            }},
            {{
                text     = _("Cancel"),
                callback = function() UIManager:close(dlg) end,
            }},
        },
    }
    UIManager:show(dlg)
end

-- ---------------------------------------------------------------------------
-- Dynamic menu
-- ---------------------------------------------------------------------------

function PluginManager:buildMenuItems()
    local installed = self:scanInstalled()
    local items = {}

    -- Refresh / fetch button
    local fetch_label
    if self._last_check then
        local age_min = math.floor((os.time() - self._last_check) / 60)
        fetch_label = string.format(_("Refresh list (last: %d min ago)"), age_min)
    else
        fetch_label = _("Fetch plugin list")
    end
    items[#items + 1] = {
        text     = fetch_label,
        callback = function() self:fetchManifest() end,
    }

    if self._manifest then
        -- Build two buckets: installed (known in manifest) and available.
        local installed_entries = {}
        local available_entries = {}
        local known_ids = {}

        for _, p in ipairs(self._manifest.plugins) do
            known_ids[p.id] = true
            local inst = installed[p.id]
            if inst then
                installed_entries[#installed_entries + 1] = {
                    plugin     = p,
                    inst       = inst,
                    has_update = is_newer(inst.version, p.version),
                }
            else
                available_entries[#available_entries + 1] = p
            end
        end

        -- Plugins installed locally but not in the manifest.
        local local_only = {}
        for id, inst in pairs(installed) do
            if not known_ids[id] then
                local_only[#local_only + 1] = inst
            end
        end

        -- Sort alphabetically.
        local cmp = function(a, b)
            return (a.plugin and a.plugin.fullname or a.fullname or "")
                 < (b.plugin and b.plugin.fullname or b.fullname or "")
        end
        table.sort(installed_entries, cmp)
        table.sort(available_entries, function(a, b) return a.fullname < b.fullname end)
        table.sort(local_only,        function(a, b) return a.fullname < b.fullname end)

        -- Section: Installed (from manifest)
        if #installed_entries > 0 then
            items[#items + 1] = {
                text    = string.format(_("\u{2014} Installed (%d) \u{2014}"), #installed_entries),
                enabled = false,
            }
            for _, e in ipairs(installed_entries) do
                local entry = e
                local label = entry.inst.fullname .. "  v" .. entry.inst.version
                if entry.has_update then
                    label = label .. "  \u{2192}  v" .. entry.plugin.version
                end
                items[#items + 1] = {
                    text     = label,
                    callback = function()
                        self:showInstalledDialog(entry.plugin, entry.inst, entry.has_update)
                    end,
                }
            end
        end

        -- Section: Local-only (not in manifest)
        if #local_only > 0 then
            items[#items + 1] = {
                text    = _("\u{2014} Installed (not in repo) \u{2014}"),
                enabled = false,
            }
            for _, inst in ipairs(local_only) do
                local iref = inst
                items[#items + 1] = {
                    text     = iref.fullname .. "  v" .. iref.version,
                    callback = function()
                        UIManager:show(ConfirmBox:new{
                            text       = string.format(
                                _("Remove %s?\nAll plugin files will be deleted."),
                                iref.fullname
                            ),
                            ok_text    = _("Remove"),
                            ok_callback = function()
                                self:_doRemove(iref.fullname, iref.dir)
                            end,
                        })
                    end,
                }
            end
        end

        -- Section: Available to install
        if #available_entries > 0 then
            items[#items + 1] = {
                text    = string.format(_("\u{2014} Available (%d) \u{2014}"), #available_entries),
                enabled = false,
            }
            for _, p in ipairs(available_entries) do
                local pref = p
                items[#items + 1] = {
                    text     = pref.fullname .. "  v" .. pref.version,
                    callback = function() self:showAvailableDialog(pref) end,
                }
            end
        end

    else
        -- Manifest not yet fetched: show only locally-installed plugins.
        local local_entries = {}
        for _, inst in pairs(installed) do
            local_entries[#local_entries + 1] = inst
        end
        table.sort(local_entries, function(a, b) return a.fullname < b.fullname end)

        if #local_entries > 0 then
            items[#items + 1] = {
                text    = string.format(_("\u{2014} Installed (%d) \u{2014}"), #local_entries),
                enabled = false,
            }
            for _, inst in ipairs(local_entries) do
                local iref = inst
                items[#items + 1] = {
                    text     = iref.fullname .. "  v" .. iref.version,
                    callback = function()
                        UIManager:show(ConfirmBox:new{
                            text       = string.format(
                                _("Remove %s?\nAll plugin files will be deleted."),
                                iref.fullname
                            ),
                            ok_text    = _("Remove"),
                            ok_callback = function()
                                self:_doRemove(iref.fullname, iref.dir)
                            end,
                        })
                    end,
                }
            end
        else
            items[#items + 1] = {
                text    = _("No plugins installed yet."),
                enabled = false,
            }
        end
    end

    return items
end

-- ---------------------------------------------------------------------------
-- KOReader plugin lifecycle
-- ---------------------------------------------------------------------------

function PluginManager:init()
    self.ui.menu:registerToMainMenu(self)
end

function PluginManager:addToMainMenu(menu_items)
    menu_items.pluginmanager = {
        text                 = _("Plugin Manager"),
        sorting_hint         = "tools",
        sub_item_table_func  = function() return self:buildMenuItems() end,
    }
end

return PluginManager
