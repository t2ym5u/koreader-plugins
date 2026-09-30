-- Do the two engines choose the same column? Root pruning must not change the
-- move, only the time taken to find it.
local S = "/private/tmp/claude-501/-Users-tomar-Projets-github-koreader-plugins/487f35ff-a2f5-4368-bdc2-a86fd3f6edcf/scratchpad/ai/"
local R = "/Users/tomar/Projets/github/koreader-plugins/"
local A = assert(loadfile(S .. "connect4_base.lua"))()
local B = assert(loadfile(R .. "connect4.koplugin/board.lua"))()
math.randomseed(99)
local same, diff, checked = 0, 0, 0
for trial = 1, 300 do
    local a = A:new(); a:reset()
    local plies = math.random(0, 14)
    for _ = 1, plies do
        local cols = {}
        for c = 1, 7 do if a.grid[1][c] == 0 then cols[#cols+1] = c end end
        if #cols == 0 or a.status ~= "playing" then break end
        a:dropPiece(cols[math.random(#cols)])
    end
    if a.status == "playing" then
        local b = B:new(); b:reset()
        for r = 1, #a.grid do for c = 1, 7 do b.grid[r][c] = a.grid[r][c] end end
        b.turn, b.status = a.turn, a.status
        local ca = a:getAIMove(5)
        local cb = b:getAIMove(5)
        checked = checked + 1
        if ca == cb then same = same + 1 else diff = diff + 1 end
    end
end
print(string.format("positions testees=%d  meme colonne=%d  divergentes=%d", checked, same, diff))
