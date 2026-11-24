-- Produces gamebook.koplugin/images/gamebook.png (English README screenshot):
-- "The Ravens of the Tower", section 1, with its three choices and the stats line.
-- cd "$KOREADER_EMU" && SEED=7 RENDER_DPI=300 STATE_FILE=$REPO/scripts/dev/scenes/gamebook.lua \
--   ./luajit $REPO/scripts/dev/render_screen.lua gamebook out.png 1080 1440 en
local scr = ...
-- Tap the story in the library.
for _i, e in ipairs(scr.all_stories) do
    if e.path:match("tower_en%.lua$") then scr:onPickStory(e.key) end
end
assert(scr.phase == "play", "tower_en story not found")
