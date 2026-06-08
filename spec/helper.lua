-- Common test helpers — source this at the top of every spec with:
--   require("spec/helper")
-- Run busted from the project root: busted spec/

-- gettext mock: pure identity so modules that call _("…") still work.
package.preload["gettext"] = function()
    return function(s) return s end
end

-- Unload a module from the cache so the next require picks the right path.
local function unload(...)
    for _, name in ipairs({...}) do
        package.loaded[name]  = nil
        package.preload[name] = nil
    end
end

-- Load a specific file as a named module (bypasses path search).
local function preloadFile(name, path)
    package.preload[name] = function()
        local chunk, err = loadfile(path)
        assert(chunk, "preloadFile: " .. (err or "?"))
        return chunk()
    end
end

-- Utility: deep-copy a 2-D numeric grid.
local function copyGrid(src, n)
    local g = {}
    for r = 1, n do
        g[r] = {}
        for c = 1, n do g[r][c] = src[r][c] end
    end
    return g
end

return {
    unload      = unload,
    preloadFile = preloadFile,
    copyGrid    = copyGrid,
}
