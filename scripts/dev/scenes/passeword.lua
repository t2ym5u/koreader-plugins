-- Produces passeword.koplugin/images/passeword.png (English): the final's -- 1080x1440 at 300 dpi
-- "Level 2 cleared!" stop-or-continue choice, joker available.
--   cd "$KOREADER_EMU" && RENDER_DPI=300 STATE_FILE=$REPO/scripts/dev/scenes/passeword.lua \
--     ./luajit $REPO/scripts/dev/render_screen.lua passeword out.png 1080 1440 en
local scr = ...
local g = scr.game
scr:applyPlayerNames("Alice\nBen\nChloe\nDominic")
scr:onStartGame()
-- Qualification: team A (Alice & Ben) misses every word, team B finds them all.
while g.phase == "handover" do
    local team_b = g.slot == 2
    scr:onReady()
    while g.phase == "turn" do
        if team_b then scr:onFound() else scr:onForbidden() end
    end
end
scr:onQualNext()      -- qual_over -> final_handover (Chloe & Dominic)
-- Final: clear levels 1 and 2, each with 5 words found.
for _level = 1, 2 do
    if g.phase == "decision" then scr:onContinue() end
    scr:onFinalReady()
    while g.phase == "final_turn" do scr:onFinalFound() end
end
scr:_stopCountdown()
