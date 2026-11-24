-- undercover.koplugin/images/undercover.png: Bob (secret 2 of 6) looking at his word.
-- cd "$KOREADER_EMU" && SEED=7 RENDER_DPI=300 STATE_FILE=$REPO/scripts/dev/scenes/undercover.lua \
--   ./luajit $REPO/scripts/dev/render_screen.lua undercover out.png 1080 1440 en
local scr, p = ...
local names = { "Alice", "Bob", "Chloe", "David", "Emma", "Frank" }
p:saveSetting("names", names)
scr.game = getmetatable(scr.game).new{ names = names, mode = "undercover", undercovers = "auto", mr_white = true }
-- Deal until Bob, the second player, gets a word (not Mr. White).
repeat scr:onStartRound() until scr.game.round.roles[2] ~= "mrwhite"
scr:onShowSecret(); scr:onHideSecret()   -- Alice has seen hers
scr:onShowSecret()                       -- Bob looks at his
