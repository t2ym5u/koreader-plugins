-- threerounds.koplugin/images/threerounds.png: round 2 turn in progress, a monument card.
-- cd "$KOREADER_EMU" && SEED=7 RENDER_DPI=300 STATE_FILE=$REPO/scripts/dev/scenes/threerounds.lua \
--   ./luajit $REPO/scripts/dev/render_screen.lua threerounds out.png 1080 1440 en
local scr = ...
scr:onStartGame()
local g = scr.game
-- Round 1: the teams guess every card.
while g.phase ~= "round_end" do
    if g.phase == "handover" then g:startTurn() end
    g:found()
    if g.phase == "turn" and #g.pool % 9 == 0 then g:endTurn() end
end
scr:onNextRound()
-- Round 2: a turn under way, two cards found, a monument in hand.
scr:onReady()
scr:_stopCountdown()
scr:onFound(); scr:onFound()
for _ = 1, #g.pool do
    if g:currentCard().theme == "monuments" then break end
    g:pass()
end
scr.time_left = 9
