-- usage: luajit i18n_conflicts.lua <game-common/i18n.lua> <plugin/i18n_fr.lua>...
-- (normally run through check_i18n.sh, which builds the file list)
--
-- All plugins share one `require("i18n")` slot (game-common's i18n, extended
-- by every plugin's i18n_fr.lua table), so one English key can only have one
-- translation per language across the whole fleet. Prints every key that two
-- files translate differently, then "conflicts: N". Exit 1 if N > 0.
-- Pure Lua 5.1 / LuaJIT: no KOReader environment needed.
package.preload["gettext"] = function() return function(s) return s end end
local LANGS = { "fr", "es", "de" }
local function load_table(path)
  local f = assert(io.open(path)); local src = f:read("*a"); f:close()
  if path:match("game%-common/i18n%.lua$") then
    local body = src:match("local S = (%b{})")
    return assert(loadstring("return " .. body))()
  end
  local chunk = loadstring(src, "@" .. path)
  if not chunk then return {} end
  local ok, t = pcall(chunk)
  return ok and type(t) == "table" and t or {}
end
local seen, n = {}, 0
for i = 1, #arg do
  local t = load_table(arg[i])
  for k, v in pairs(t) do
    if type(v) == "table" then
      local prev = seen[k]
      if prev then
        for _, l in ipairs(LANGS) do
          if v[l] and prev.v[l] and v[l] ~= prev.v[l] then
            n = n + 1
            print(("CONFLICT %q [%s]: %s=%q vs %s=%q"):format(k, l, prev.file, prev.v[l], arg[i], v[l]))
          end
        end
      else
        seen[k] = { v = v, file = arg[i] }
      end
    end
  end
end
print("conflicts: " .. n)
os.exit(n > 0 and 1 or 0)
