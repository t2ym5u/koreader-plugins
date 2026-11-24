-- Produces quiz.koplugin/images/quiz.png (English): question 3 of a 4-player -- 1080x1440 at 300 dpi
-- game, countdown running, scores from the first two questions.
--   cd "$KOREADER_EMU" && RENDER_DPI=300 STATE_FILE=$REPO/scripts/dev/scenes/quiz.lua \
--     ./luajit $REPO/scripts/dev/render_screen.lua quiz out.png 1080 1440 en
local scr, p = ...
for i, name in ipairs{ "Alice", "Ben", "Chloe", "Dan" } do
    p:saveSetting("player_name_" .. i, name)
end
scr:_initPlayers()
-- Two questions played: reveal, +1 to who got it right, next.
for _q, winners in ipairs{ { 1, 3 }, { 1, 2, 3 } } do
    scr:onRevealAnswer()
    for _i, w in ipairs(winners) do scr:onScorePlayer(w) end
    scr:onNextQuestion()
end
-- A few seconds of the countdown go by.
for _s = 1, 12 do scr:_onTick(scr._tick_gen) end
scr:_stopCountdown()
