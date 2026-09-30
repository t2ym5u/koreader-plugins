-- The AI against a player that picks legal moves at random. A positional
-- engine that cannot beat random convincingly is not doing anything.
local R = "/Users/tomar/Projets/github/koreader-plugins/"
local BG = assert(loadfile(R .. "backgammon.koplugin/board.lua"))()
math.randomseed(tonumber(os.getenv("SEED") or "20260930"))
local GAMES = tonumber(os.getenv("GAMES") or "20")

local function playRandomTurn(b)
    while #b.remaining_dice > 0 and b.status == "playing" do
        local opts = {}
        for _, d in ipairs(b.remaining_dice) do
            for _, m in ipairs(b:getLegalMoves(d)) do opts[#opts+1] = { from = m.from, die = d } end
        end
        if #opts == 0 then b:endTurn() return end
        local pick = opts[math.random(#opts)]
        if b:applyMove(pick.from, pick.die) == "invalid" then b:endTurn() return end
    end
end

local function playAITurn(b)
    local turn = b:getAITurn()
    if #turn == 0 then b:endTurn() return end
    for _, mv in ipairs(turn) do
        if b.status ~= "playing" or #b.remaining_dice == 0 then break end
        if b:applyMove(mv.from, mv.die) == "invalid" then break end
    end
    if b.status == "playing" and #b.remaining_dice > 0 then b:endTurn() end
end

local ai_wins, rnd_wins, t_ai, n_ai, max_ai = 0, 0, 0, 0, 0
for g = 1, GAMES do
    local b = BG:new(); b:reset(); b:rollOpening()
    local ai_color = (g % 2 == 1) and "white" or "black"
    local plies = 0
    while b.status == "playing" and plies < 800 do
        if #b.remaining_dice == 0 then b:rollDice() end
        if b.status ~= "playing" then break end
        if #b.remaining_dice == 0 then plies = plies + 1 end
        if #b.remaining_dice > 0 then
            if b.turn == ai_color then
                local t0 = os.clock(); playAITurn(b)
                local dt = os.clock() - t0
                t_ai = t_ai + dt; n_ai = n_ai + 1; if dt > max_ai then max_ai = dt end
            else
                playRandomTurn(b)
            end
        end
        plies = plies + 1
    end
    if b.winner == ai_color then ai_wins = ai_wins + 1
    elseif b.winner then rnd_wins = rnd_wins + 1 end
    io.write(b.winner == ai_color and "A" or (b.winner and "r" or ".")); io.flush()
end
print()
print(string.format("%d parties : IA=%d  aleatoire=%d  inachevees=%d",
    GAMES, ai_wins, rnd_wins, GAMES - ai_wins - rnd_wins))
print(string.format("temps par tour IA : moy %.3fs  max %.3fs (%d tours)", t_ai/math.max(1,n_ai), max_ai, n_ai))
