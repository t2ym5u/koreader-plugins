-- Head-to-head harness: two GomokuBoard implementations take turns choosing
-- moves on one shared board. Colours alternate between games so neither side
-- keeps the first-move advantage.
local S = "/private/tmp/claude-501/-Users-tomar-Projets-github-koreader-plugins/487f35ff-a2f5-4368-bdc2-a86fd3f6edcf/scratchpad/ai/"
local R = "/Users/tomar/Projets/github/koreader-plugins/"

local function load(path)
    local chunk = assert(loadfile(path))
    return chunk()
end

local A_PATH = os.getenv("A") or (S .. "gomoku_base.lua")
local B_PATH = os.getenv("B") or (R .. "gomoku.koplugin/board.lua")
local DEPTH  = tonumber(os.getenv("DEPTH") or "2")
local DEPTH_A = tonumber(os.getenv("DEPTH_A") or tostring(DEPTH))
local DEPTH_B = tonumber(os.getenv("DEPTH_B") or tostring(DEPTH))
local GAMES  = tonumber(os.getenv("GAMES") or "10")

local A = load(A_PATH)
local B = load(B_PATH)

-- One board drives the game; the other implementation only picks moves, so we
-- copy the position into a scratch board of its own class before asking.
local function askMove(Class, live, depth)
    local b = Class:new()
    b:reset()
    for r = 1, live.n do
        for c = 1, live.n do b.grid[r][c] = live.grid[r][c] end
    end
    b.turn   = live.turn
    b.status = live.status
    b.moves  = live.moves
    return b:getAIMove(depth)
end

-- Both engines are deterministic, so without this every game would be the
-- same two positions replayed. A short random opening near the centre gives
-- each game a distinct start; colours still alternate so neither side keeps
-- the first-move advantage.
local OPENING = tonumber(os.getenv("OPENING") or "4")
math.randomseed(tonumber(os.getenv("SEED") or "20260930"))

local function randomOpening(live, plies_wanted)
    local n = live.n
    local mid = math.floor((n + 1) / 2)
    local placed = 0
    local guard = 0
    while placed < plies_wanted and guard < 200 do
        guard = guard + 1
        local r = mid + math.random(-3, 3)
        local c = mid + math.random(-3, 3)
        if r >= 1 and r <= n and c >= 1 and c <= n and live.grid[r][c] == 0 then
            if live:placeStone(r, c) == "ok" then placed = placed + 1 end
        end
    end
    return placed
end

local wins_a, wins_b, draws, plies, t_a, t_b = 0, 0, 0, 0, 0, 0
for g = 1, GAMES do
    local live = A:new(); live:reset()
    randomOpening(live, OPENING)
    local a_is_black = (g % 2 == 1)
    local game_plies = 0
    local result
    while true do
        local black = (live.turn == 1)
        local a_to_move = (black == a_is_black)
        local t0 = os.clock()
        local mv = askMove(a_to_move and A or B, live, a_to_move and DEPTH_A or DEPTH_B)
        local dt = os.clock() - t0
        if a_to_move then t_a = t_a + dt else t_b = t_b + dt end
        if not mv then result = "draw" break end
        local res = live:placeStone(mv.r, mv.c)
        plies = plies + 1
        game_plies = game_plies + 1
        if res == "won" then result = a_to_move and "A" or "B" break end
        if res == "draw" or live.status ~= "playing" then result = "draw" break end
        if game_plies >= 15 * 15 then result = "draw" break end
    end
    if result == "A" then wins_a = wins_a + 1
    elseif result == "B" then wins_b = wins_b + 1
    else draws = draws + 1 end
    io.write(result == "A" and "A" or (result == "B" and "B" or "."))
    io.flush()
end
print()
print(string.format("A@%d vs B@%d, %d parties  ->  A=%d  B=%d  nulles=%d", DEPTH_A, DEPTH_B, GAMES, wins_a, wins_b, draws))
print(string.format("temps par coup : A %.3fs   B %.3fs", t_a / math.max(1, plies/2), t_b / math.max(1, plies/2)))
