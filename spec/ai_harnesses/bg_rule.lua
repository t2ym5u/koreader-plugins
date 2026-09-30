local R = "/Users/tomar/Projets/github/koreader-plugins/"
local BG = assert(loadfile(R .. "backgammon.koplugin/board.lua"))()
local function empty(b)
    for i = 1, 24 do b.points[i] = { color = nil, count = 0 } end
    b.bar = { white = 0, black = 0 }; b.off = { white = 0, black = 0 }
end
local function ok(cond) return cond and "OK" or "ECHEC" end

-- Black moves upward. One checker on 1; both 1->3 (die 2) and 1->7 (die 6)
-- are open, but 9 is blocked, so whichever die is played first strands the
-- other. The rule says the higher die must be the one played.
local b = BG:new(); b:reset(); empty(b)
b.points[1] = { color = "black", count = 1 }
b.points[9] = { color = "white", count = 2 }
b.turn = "black"; b.remaining_dice = { 2, 6 }
local total, best = b:_maxPlayable()
local n2, n6 = #b:getLegalMoves(2), #b:getLegalMoves(6)
print(string.format("un seul de jouable : max=%d de_impose=%s | 2 -> %d coups, 6 -> %d coups  %s",
    total, tostring(best), n2, n6, ok(total == 1 and best == 6 and n2 == 0 and n6 == 1)))

-- Same shape, but now the lower die is the only one that can be played at
-- all: it must be offered.
local c = BG:new(); c:reset(); empty(c)
c.points[1] = { color = "black", count = 1 }
c.points[7] = { color = "white", count = 2 }   -- blocks the 6
c.turn = "black"; c.remaining_dice = { 2, 6 }
print(string.format("seul le petit de peut jouer : 2 -> %d, 6 -> %d  %s",
    #c:getLegalMoves(2), #c:getLegalMoves(6), ok(#c:getLegalMoves(2) > 0 and #c:getLegalMoves(6) == 0)))

-- Opening position: both dice always playable, nothing may be refused.
local d = BG:new(); d:reset()
d.turn = "black"; d.remaining_dice = { 3, 5 }
print(string.format("position de depart 3+5 : max=%d, 3 -> %d coups, 5 -> %d coups  %s",
    (d:_maxPlayable()), #d:getLegalMoves(3), #d:getLegalMoves(5),
    ok(select(1, d:_maxPlayable()) == 2 and #d:getLegalMoves(3) > 0 and #d:getLegalMoves(5) > 0)))
