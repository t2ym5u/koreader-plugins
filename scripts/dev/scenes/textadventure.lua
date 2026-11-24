-- Produces textadventure.koplugin/images/textadventure.png (English): Colossal -- 1080x1440 at 300 dpi
-- Cave (Advent.z5, Inform port, IF Archive games/zcode/Advent.z5) at the grate,
-- after >look and >inventory. No story is bundled: point STORY at the file.
--   cd "$KOREADER_EMU" && RENDER_DPI=300 STORY=/path/to/Advent.z5 STATE_FILE=$REPO/scripts/dev/scenes/textadventure.lua \
--     ./luajit $REPO/scripts/dev/render_screen.lua textadventure out.png 1080 1440 en
local scr = ...
local story = os.getenv("STORY") or (scr.data_dir .. "/Advent.z5")
assert(io.open(story, "rb"), "no story file: set STORY=/path/to/Advent.z5")
scr:openStory(story)
-- From the end of the road: lamp and keys from the building, down the valley
-- to the grate, then the two commands the image shows.
scr:sendCommand("in")
scr:submit("take lamp")
scr:submit("take keys")
for _i, cmd in ipairs{ "out", "s", "s", "s", "look", "inv" } do scr:sendCommand(cmd) end
