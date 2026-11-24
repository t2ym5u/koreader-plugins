-- wordpyramid.koplugin/images/wordpyramid.png: a whole game played out, the Great Pyramid won (jackpot).
-- cd "$KOREADER_EMU" && SEED=3 RENDER_DPI=300 STATE_FILE=$REPO/scripts/dev/scenes/wordpyramid.lua \
--   ./luajit $REPO/scripts/dev/render_screen.lua wordpyramid out.png 1080 1440 en
local scr = ...
local g = scr.game
g.players = { "Alice", "Bob", "Chloe", "David" }
g:startGame()
-- Every round played with the game's own actions; clues hit about 2 times in 3.
local function hit() return math.random(3) ~= 1 end
for _ = 1, 2000 do
    local ph = g.phase
    if ph == "game_over" then break
    elseif ph == "intro" then g:beginStage()
    elseif ph == "pick" then
        for i = 1, #g.st.options do if g:canPick(i) then g:pick(i); break end end
    elseif ph == "handover" then g:startTurn()
    elseif ph == "turn" then
        if hit() then g:found() elseif g.play.kind == "clock" then g:forbidden() else g:wrong() end
    elseif ph == "answer" then g:answer(hit())
    elseif ph == "bid" then g:placeBid(nil)
    elseif ph == "result" then g:continue()
    elseif ph == "final_handover" then g:finalStart()
    elseif ph == "final_turn" then g:finalFound()
    end
end
assert(g.phase == "game_over", "game did not end: " .. tostring(g.phase))
scr:_save()
