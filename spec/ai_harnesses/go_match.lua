-- The Go AI against a player that picks legal non-eye-filling points at
-- random. Anything that cannot beat that convincingly is not playing Go.
local R = "/Users/tomar/Projets/github/koreader-plugins/"
package.path = R .. "go.koplugin/?.lua;" .. R .. "go.koplugin/common/?.lua;" .. package.path
local Go = assert(loadfile(R .. "go.koplugin/board.lua"))()
math.randomseed(tonumber(os.getenv("SEED") or "20260930"))
local GAMES = tonumber(os.getenv("GAMES") or "20")
local SIZE = os.getenv("SIZE") or "9x9"

local function randomMove(b)
    local color = (b.turn == "black") and 1 or 2
    local opts = {}
    for r = 1, b.n do for c = 1, b.n do
        if b.grid[r][c] == 0 and not b:_isOwnEye(r, c, color) and b:isLegalMove(r, c, color) then
            opts[#opts+1] = { r = r, c = c }
        end
    end end
    if #opts == 0 then return nil end
    return opts[math.random(#opts)]
end

local ai_wins, rnd_wins, draws, t, n, mx = 0, 0, 0, 0, 0, 0
for g = 1, GAMES do
    local b = Go:new{}; b:reset(SIZE)
    local ai_is_black = (g % 2 == 1)
    local moves = 0
    while b.status == "playing" and moves < b.n * b.n * 3 do
        local ai_turn = ((b.turn == "black") == ai_is_black)
        local mv
        if ai_turn then
            local t0 = os.clock(); mv = b:getAIMove()
            local dt = os.clock() - t0; t = t + dt; n = n + 1; if dt > mx then mx = dt end
        else
            mv = randomMove(b)
        end
        if mv then
            if b:placeStone(mv.r, mv.c) ~= "ok" then b:pass() end
        else
            b:pass()
        end
        moves = moves + 1
    end
    local sc = b:scoreTerritory()
    -- White carries the komi, as in computeWinner().
    local black, white = sc.black, sc.white + 6.5
    local ai_score = ai_is_black and black or white
    local op_score = ai_is_black and white or black
    if ai_score > op_score then ai_wins = ai_wins + 1
    elseif op_score > ai_score then rnd_wins = rnd_wins + 1 else draws = draws + 1 end
    io.write(ai_score > op_score and "A" or (op_score > ai_score and "r" or "."))
    io.flush()
end
print()
print(string.format("%s, %d parties : IA=%d  aleatoire=%d  nulles=%d", SIZE, GAMES, ai_wins, rnd_wins, draws))
print(string.format("temps par coup IA : moy %.3fs  max %.3fs", t/math.max(1,n), mx))
