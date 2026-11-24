-- Produces categories.koplugin/images/categories.png (English README screenshot):
-- Alice's scoring page in round 1, four players, ten categories.
-- cd "$KOREADER_EMU" && SEED=7 RENDER_DPI=300 STATE_FILE=$REPO/scripts/dev/scenes/categories.lua \
--   ./luajit $REPO/scripts/dev/render_screen.lua categories out.png 1080 1440 en
local scr = ...
-- What the players' dialog and the "Categories" picker do.
scr:applyPlayerNames("Alice\nBob\nChloe\nDavid")
scr.game.nb_categories = 10
scr.plugin:saveSetting("nb_categories", 10)
scr:onDraw()
scr:onStop()
-- Alice's marks: unique / shared / none, as tapped on her scoring page.
local U, S, N = 1, 2, 3
for row, level in ipairs({ U, S, N, U, U, S, N, U, S, U }) do
    scr:onScoreTap(row, level)
end
