-- Produces partyquestions.koplugin/images/partyquestions.png (English, party mode): -- 1080x1440 at 300 dpi
--   cd "$KOREADER_EMU" && RENDER_DPI=300 STATE_FILE=$REPO/scripts/dev/scenes/partyquestions.lua \
--     ./luajit $REPO/scripts/dev/render_screen.lua partyquestions out.png 1080 1440 en
local scr, p = ...
-- Players are a setting read at init: save them, then deal fresh decks
-- until the first card is a "Who's most likely to..." one.
local names = { "Alice", "Bruno", "Chloe", "David" }
p:saveSetting("names", names)
scr.names = names
for seed = 1, 500 do
    math.randomseed(seed)
    scr:onNewGame()
    local e = scr.deck:current()
    if e and e[1]:match("^mlt") then break end
end
