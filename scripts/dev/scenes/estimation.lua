-- Produces estimation.koplugin/images/estimation.png (English README screenshot):
-- question 1 (litres of water for 1 kg of beef) revealed, four players' guesses, the closest one starred.
-- cd "$KOREADER_EMU" && SEED=12 RENDER_DPI=300 STATE_FILE=$REPO/scripts/dev/scenes/estimation.lua \
--   ./luajit $REPO/scripts/dev/render_screen.lua estimation out.png 1080 1440 en
local scr, p = ...
p:saveSetting("player_names", { "Alice", "Bob", "Chloe", "David" }) -- as the names editor does
scr:_setAndRestart("players", "nplayers", 4)                      -- Players: 4 (new game)
local answer = scr:_question().answer
-- Each player in turn: hand-over, type a guess on the keypad, OK.
for _i, f in ipairs({ 0.2, 0.93, 1.3, 2.5 }) do
    scr:onReady()
    for d in tostring(math.floor(answer * f + 0.5)):gmatch("%d") do scr:onDigit(tonumber(d)) end
    scr:onValidateGuess()
end
