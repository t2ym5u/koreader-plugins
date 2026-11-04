-- LuaJIT `bit` API on top of Lua 5.4+ native bitwise operators (32-bit).
local M = {}
local function t(x) x = math.floor(x) & 0xFFFFFFFF; if x >= 0x80000000 then x = x - 0x100000000 end; return x end
M.tobit = t
function M.band(a, ...) local r = a & 0xFFFFFFFF; for _, v in ipairs({...}) do r = r & (v & 0xFFFFFFFF) end; return t(r) end
function M.bor(a, ...) local r = a & 0xFFFFFFFF; for _, v in ipairs({...}) do r = r | (v & 0xFFFFFFFF) end; return t(r) end
function M.bxor(a, ...) local r = a & 0xFFFFFFFF; for _, v in ipairs({...}) do r = r ~ (v & 0xFFFFFFFF) end; return t(r) end
function M.bnot(a) return t(~a) end
function M.lshift(a, n) return t((a & 0xFFFFFFFF) << (n & 31)) end
function M.rshift(a, n) return t((a & 0xFFFFFFFF) >> (n & 31)) end
function M.arshift(a, n) return t(t(a) >> (n & 31) | ((t(a) < 0 and n > 0) and ~(0xFFFFFFFF >> (n & 31)) or 0)) end
function M.tohex(a, n) n = n or 8; return string.format("%0" .. n .. "x", a & 0xFFFFFFFF):sub(-n) end
return M
