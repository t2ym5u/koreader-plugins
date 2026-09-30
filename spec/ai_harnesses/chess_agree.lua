-- Same position, same seed: the two engines must choose the same move, and the
-- new one must be faster. Both pick randomly among moves tied at the best
-- score, so the RNG is reseeded identically before each call.
local S = "/private/tmp/claude-501/-Users-tomar-Projets-github-koreader-plugins/487f35ff-a2f5-4368-bdc2-a86fd3f6edcf/scratchpad/ai/"
local R = "/Users/tomar/Projets/github/koreader-plugins/"
local A = assert(loadfile(R .. "chess.koplugin/_board_baseline_tmp.lua"))()
local B = assert(loadfile(R .. "chess.koplugin/board.lua"))()

local function key(m)
    if not m then return "nil" end
    return string.format("%s%s-%s%s|%s", tostring(m.fr), tostring(m.fc),
        tostring(m.tr), tostring(m.tc), tostring(m.special))
end

local DEPTH = tonumber(os.getenv("DEPTH") or "3")
local same, diff, ta, tb, n = 0, 0, 0, 0, 0
for trial = 1, 40 do
    -- Build a position by letting the baseline play a few random legal moves.
    local a = A:new(); a:reset()
    math.randomseed(1000 + trial)
    local plies = math.random(0, 12)
    for _ = 1, plies do
        local legal = a:getLegalMoves()
        if #legal == 0 or a.status ~= "playing" then break end
        local m = legal[math.random(#legal)]
        a:makeMove(m.fr, m.fc, m.tr, m.tc)
    end
    if a.status == "playing" then
        local b = B:new(); b:reset()
        for r = 1, 8 do for c = 1, 8 do b.sq[r][c] = a.sq[r][c] end end
        b.turn, b.status = a.turn, a.status
        if a.castling then b.castling = { wk=a.castling.wk, wq=a.castling.wq, bk=a.castling.bk, bq=a.castling.bq } end
        b.ep_r, b.ep_c = a.ep_r, a.ep_c

        math.randomseed(7)
        local t0 = os.clock(); local ma = a:getAIMove(DEPTH); ta = ta + os.clock() - t0
        math.randomseed(7)
        t0 = os.clock(); local mb = b:getAIMove(DEPTH); tb = tb + os.clock() - t0
        n = n + 1
        if key(ma) == key(mb) then same = same + 1 else diff = diff + 1
            if diff <= 3 then print("  divergence: " .. key(ma) .. "  vs  " .. key(mb)) end
        end
    end
end
print(string.format("positions=%d  meme coup=%d  divergentes=%d", n, same, diff))
print(string.format("temps total : ancienne %.2fs   nouvelle %.2fs  (%.0f%% du temps)", ta, tb, tb/ta*100))
