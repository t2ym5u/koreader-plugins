-- Produces fireworks.koplugin/images/fireworks.png (English README screenshot):
-- a solo game with two AI teammates, Black variant, late in the game, on your turn.
-- cd "$KOREADER_EMU" && SEED=7 RENDER_DPI=300 STATE_FILE=$REPO/scripts/dev/scenes/fireworks.lua \
--   ./luajit $REPO/scripts/dev/render_screen.lua fireworks out.png 1080 1440 en
local scr = ...
local AI = dofile(scr.plugin.path .. "/ai.lua")
-- What the setup menus do: solo mode, 3 players, Black variant; then Start.
scr:_setSetting("solo", true)
scr:_setSetting("num_players", 3)
scr:_setSetting("variant", "black")
scr:onNewGame()
-- Your moves are the bot's choice, until a handful of cards are left.
local g = scr.game
while not g.over and #g.deck > tonumber(os.getenv("DECK_LEFT") or 6) do
    scr:doAction(AI.choose(g, g.current))
    g = scr.game
end
scr:onReady()
