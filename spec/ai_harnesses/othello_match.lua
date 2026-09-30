-- Head-to-head harness for Othello, same shape as the Gomoku one: both
-- engines are deterministic, so each game opens with a few random legal moves
-- or every match would replay one position.
local S = "/private/tmp/claude-501/-Users-tomar-Projets-github-koreader-plugins/487f35ff-a2f5-4368-bdc2-a86fd3f6edcf/scratchpad/ai/"
local R = "/Users/tomar/Projets/github/koreader-plugins/"

local A = assert(loadfile(os.getenv("A") or (S .. "othello_base.lua")))()
local B = assert(loadfile(os.getenv("B") or (R .. "othello.koplugin/board.lua")))()
local DEPTH_A = tonumber(os.getenv("DEPTH_A") or os.getenv("DEPTH") or "4")
local DEPTH_B = tonumber(os.getenv("DEPTH_B") or os.getenv("DEPTH") or "4")
local GAMES   = tonumber(os.getenv("GAMES") or "20")
local OPENING = tonumber(os.getenv("OPENING") or "6")
math.randomseed(tonumber(os.getenv("SEED") or "20260930"))

local function askMove(Class, live, depth)
    local b = Class:new()
    b:reset()
    for r = 1, 8 do for c = 1, 8 do b.grid[r][c] = live.grid[r][c] end end
    b.turn, b.status = live.turn, live.status
    return b:getAIMove(depth)
end

local function randomOpening(live, plies)
    for _ = 1, plies do
        local mv = live:getValidMoves(live.turn)
        if not mv or #mv == 0 then return end
        local pick = mv[math.random(#mv)]
        if live:placeDisk(pick.r, pick.c) == "invalid" then return end
        if live.status ~= "playing" then return end
    end
end

local wa, wb, dr_, t_a, t_b, n_a, n_b = 0, 0, 0, 0, 0, 0, 0
local max_a, max_b = 0, 0
for g = 1, GAMES do
    local live = A:new(); live:reset()
    randomOpening(live, OPENING)
    local a_is_black = (g % 2 == 1)
    while live.status == "playing" do
        local a_to_move = ((live.turn == "black") == a_is_black)
        local t0 = os.clock()
        local mv = askMove(a_to_move and A or B, live, a_to_move and DEPTH_A or DEPTH_B)
        local dt = os.clock() - t0
        if a_to_move then t_a = t_a + dt; n_a = n_a + 1; if dt > max_a then max_a = dt end
        else t_b = t_b + dt; n_b = n_b + 1; if dt > max_b then max_b = dt end end
        if not mv then break end
        if live:placeDisk(mv[1], mv[2]) == "invalid" then break end
    end
    local black, white = live:countDiscs()
    local a_discs = a_is_black and black or white
    local b_discs = a_is_black and white or black
    if a_discs > b_discs then wa = wa + 1
    elseif b_discs > a_discs then wb = wb + 1
    else dr_ = dr_ + 1 end
    io.write(a_discs > b_discs and "A" or (b_discs > a_discs and "B" or "."))
    io.flush()
end
print()
print(string.format("A@%d vs B@%d, %d parties  ->  A=%d  B=%d  nulles=%d", DEPTH_A, DEPTH_B, GAMES, wa, wb, dr_))
print(string.format("temps par coup : A moy %.3fs max %.3fs   B moy %.3fs max %.3fs",
    t_a / math.max(1, n_a), max_a, t_b / math.max(1, n_b), max_b))
