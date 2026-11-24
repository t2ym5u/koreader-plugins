-- werewolf.koplugin/images/werewolf.png: night 1, the Thief has taken the Seer card (Medieval theme).
-- cd "$KOREADER_EMU" && SEED=7 RENDER_DPI=300 STATE_FILE=$REPO/scripts/dev/scenes/werewolf.lua \
--   ./luajit $REPO/scripts/dev/render_screen.lua werewolf out.png 1080 1440 en
local scr, p = ...
local names = { "Alice", "Bob", "Chloe", "David", "Emma", "Frank", "Grace", "Henry", "Iris", "Jack" }
p:saveSetting("names", names); p:saveSetting("theme", "medieval")
scr.names, scr.theme = names, "medieval"
scr.comp = { werewolf = 3, seer = 1, witch = 1, hunter = 1, cupid = 1, guard = 1, thief = 1 }
scr.comp_auto = false
-- Deal until the Seer is one of the two leftover cards.
local seer
repeat
    scr:onStartGame()
    local ex = scr.game.extra
    seer = ex[1] == "seer" and 1 or ex[2] == "seer" and 2 or nil
until seer
local g = scr.game
while g:dealNext() do end           -- every player has seen their card
scr:_startNight()                   -- first step: the thief
scr:_go({ view = "act", step = g:currentStep(), sel = {}, narr_text = scr.ui.text, title = scr.ui.title })
scr:_actConfirm(seer)               -- takes the Seer card
