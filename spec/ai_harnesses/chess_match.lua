-- Head-to-head for chess. One board drives; each engine is asked from its own
-- copy of the position. Openings are randomised because both engines are
-- otherwise near-deterministic.
local R = "/Users/tomar/Projets/github/koreader-plugins/"
local A = assert(loadfile(R .. "chess.koplugin/_board_baseline_tmp.lua"))()
local B = assert(loadfile(R .. "chess.koplugin/board.lua"))()
local DA = tonumber(os.getenv("DEPTH_A") or "3")
local DB = tonumber(os.getenv("DEPTH_B") or "4")
local GAMES = tonumber(os.getenv("GAMES") or "10")
local OPENING = tonumber(os.getenv("OPENING") or "6")
local MAXPLY = tonumber(os.getenv("MAXPLY") or "160")
math.randomseed(tonumber(os.getenv("SEED") or "20260930"))

local function copyInto(dst, src)
    for r = 1, 8 do for c = 1, 8 do dst.sq[r][c] = src.sq[r][c] end end
    dst.turn, dst.status = src.turn, src.status
    if src.castling then
        dst.castling = { wk=src.castling.wk, wq=src.castling.wq,
                         bk=src.castling.bk, bq=src.castling.bq }
    end
    dst.ep_r, dst.ep_c = src.ep_r, src.ep_c
end

local wa, wb, dr_, ta, tb, na, nb, maxa, maxb = 0,0,0,0,0,0,0,0,0
for g = 1, GAMES do
    local live = A:new(); live:reset()
    for _ = 1, OPENING do
        local legal = live:getLegalMoves()
        if #legal == 0 or live.status ~= "playing" then break end
        local m = legal[math.random(#legal)]
        live:makeMove(m.fr, m.fc, m.tr, m.tc, m.promo_piece)
    end
    local a_is_white = (g % 2 == 1)
    local ply, result = 0, "draw"
    while live.status == "playing" and ply < MAXPLY do
        local a_to_move = ((live.turn == "w") == a_is_white)
        local Cls = a_to_move and A or B
        local b = Cls:new(); b:reset(); copyInto(b, live)
        local t0 = os.clock()
        local mv = b:getAIMove(a_to_move and DA or DB)
        local dt = os.clock() - t0
        if a_to_move then ta=ta+dt; na=na+1; if dt>maxa then maxa=dt end
        else tb=tb+dt; nb=nb+1; if dt>maxb then maxb=dt end end
        if not mv then break end
        if not live:makeMove(mv.fr, mv.fc, mv.tr, mv.tc, mv.promo_piece) then break end
        ply = ply + 1
    end
    -- Decide by status when the game ended, otherwise by material.
    if live.status ~= "playing" and live.winner then
        local a_won = (live.winner == "w") == a_is_white
        result = a_won and "A" or "B"
    elseif ply >= MAXPLY then
        local sa, sb = 0, 0
        local MATV = {[1]=1,[2]=3,[3]=3,[4]=3,[5]=5,[6]=9,
                      [7]=1,[8]=3,[9]=3,[10]=3,[11]=5,[12]=9}
        for r = 1, 8 do for c = 1, 8 do
            local p = live.sq[r][c]
            if p ~= 0 and MATV[p] then
                local white_piece = p <= 6
                if (white_piece == a_is_white) then sa = sa + MATV[p] else sb = sb + MATV[p] end
            end
        end end
        if sa > sb + 2 then result = "A" elseif sb > sa + 2 then result = "B" end
    end
    if result == "A" then wa=wa+1 elseif result == "B" then wb=wb+1 else dr_=dr_+1 end
    io.write(result == "A" and "A" or (result == "B" and "B" or "."))
    io.flush()
end
print()
print(string.format("A@%d vs B@%d, %d parties  ->  A=%d  B=%d  nulles/indecises=%d", DA, DB, GAMES, wa, wb, dr_))
print(string.format("temps par coup : A moy %.3fs max %.3fs   B moy %.3fs max %.3fs",
    ta/math.max(1,na), maxa, tb/math.max(1,nb), maxb))
