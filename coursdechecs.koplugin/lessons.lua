-- ---------------------------------------------------------------------------
-- lessons.lua — agrège les 30 leçons depuis les fichiers par catégorie.
-- Ajouter une catégorie : créer lessons_<cat>.lua et l'ajouter à la liste.
-- ---------------------------------------------------------------------------

local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lload(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local all = {}
for _, src in ipairs({
    "lessons_mat1",
    "lessons_mat2",
    "lessons_mat3",
    "lessons_tactique",
    "lessons_finale",
}) do
    for _, lesson in ipairs(lload(src)) do
        all[#all + 1] = lesson
    end
end
return all
