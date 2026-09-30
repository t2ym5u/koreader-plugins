-- Head-to-head harness for Connect 4. Both engines are deterministic, so each
-- game opens with a few random legal drops or every match replays one game.
local S = "/private/tmp/claude-501/-Users-tomar-Projets-github-koreader-plugins/487f35ff-a2f5-4368-bdc2-a86fd3f6edcf/scratchpad/ai/"
local R = "/Users/tomar/Projets/github/koreader-plugins/"
local A = assert(loadfile(os.getenv("A") or (S .. "connect4_base.lua")))()
local B = assert(loadfile(os.getenv("B") or (R .. "connect4.koplugin/board.lua")))()
local DA = tonumber(os.getenv("DEPTH_A") or os.getenv("DEPTH") or "5")
local DB = tonumber(os.getenv("DEPTH_B") or os.getenv("DEPTH") or "5")
local GAMES = tonumber(os.getenv("GAMES") or "20")
local OPENING = tonumber(os.getenv("OPENING") or "4")
math.randomseed(tonumber(os.getenv("SEED") or "20260930"))

local function askMove(Class, live, depth)
    local b = Class:new(); b:reset()
    for r = 1, #live.grid do for c = 1, #live.grid[r] do b.grid[r][c] = live.grid[r][c] end end
    b.turn, b.status = live.turn, live.status
    return b:getAIMove(depth)
end

local function randomOpening(live, plies)
    for _ = 1, plies do
        local cols = {}
        for c = 1, 7 do if live.grid[1][c] == 0 then cols[#cols+1] = c end end
        if #cols == 0 then return end
        if live:dropPiece(cols[math.random(#cols)]) ~= "ok" then return end
    end
end

local wa, wb, dr_, t_a, t_b, n_a, n_b, max_a, max_b = 0,0,0,0,0,0,0,0,0
for g = 1, GAMES do
    local live = A:new(); live:reset()
    randomOpening(live, OPENING)
    local a_is_p1 = (g % 2 == 1)
    local result = "draw"
    while live.status == "playing" do
        local a_to_move = ((live.turn == 1) == a_is_p1)
        local t0 = os.clock()
        local col = askMove(a_to_move and A or B, live, a_to_move and DA or DB)
        local dt = os.clock() - t0
        if a_to_move then t_a=t_a+dt; n_a=n_a+1; if dt>max_a then max_a=dt end
        else t_b=t_b+dt; n_b=n_b+1; if dt>max_b then max_b=dt end end
        if not col then break end
        local res = live:dropPiece(col)
        if res == "won" then result = a_to_move and "A" or "B" break end
        if res ~= "ok" then break end
    end
    if result == "A" then wa=wa+1 elseif result == "B" then wb=wb+1 else dr_=dr_+1 end
    io.write(result == "A" and "A" or (result == "B" and "B" or "."))
    io.flush()
end
print()
print(string.format("A@%d vs B@%d, %d parties  ->  A=%d  B=%d  nulles=%d", DA, DB, GAMES, wa, wb, dr_))
print(string.format("temps par coup : A moy %.3fs max %.3fs   B moy %.3fs max %.3fs",
    t_a/math.max(1,n_a), max_a, t_b/math.max(1,n_b), max_b))
