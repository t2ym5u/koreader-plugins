-- Uniqueness regression check for slitherlink.koplugin.
--
-- This is NOT a busted spec -- see docs/generator_robustness_audit.md,
-- "Human-solvability audit" section, for why this class of check needs its
-- own tooling separate from `busted spec/`.
--
-- Run from the repo root:
--   luajit spec/solvability_audits/slitherlink_solvability_check.lua
--
-- Background: win-check is a literal comparison to the stored solution
-- (not rule-based). `generate()` built a loop shape (random inside/outside
-- flood-fill boundary) and revealed a flat random fraction of clue
-- numbers, with zero uniqueness verification. Measured pre-fix: real,
-- graduated ambiguity (n=5/easy 9/10 unique down to n=10/hard 1/10 --
-- worse at lower clue density and larger n, as expected).
--
-- The uniqueness counter: backtracking over edges (line/not-line) with
-- two propagation rules -- clue forcing (a cell's decided-line-count
-- hitting its clue value forces the rest) and vertex degree forcing (a
-- dot's final degree must be 0 or 2, so its last undecided incident edge
-- is forced once that's the only way to avoid ending at degree 1). Full
-- validation (single simple loop, no separate sub-loops) is only checked
-- once every edge is decided.
--
-- A first attempt also tried incremental "no premature sub-loop" pruning
-- via union-find (reject a line edge that would close a cycle while
-- edges elsewhere are still undecided) -- this was UNSOUND: it compared
-- against the count of ALL decided edges (line or not), which is
-- essentially never reached until long after the real loop closes, since
-- plenty of unrelated not-line edges elsewhere are usually still
-- undecided -- it rejected the true solution's own closing edge nearly
-- always, caught via the standard sanity check (solver returned 0
-- solutions for the generator's own known-good clues). Dropped in favor
-- of the simpler final-only check; the clue and vertex propagation alone
-- turned out to be strong enough to stay fast without it (sub-100ms even
-- at n=20 for most trials).
--
-- Fixed generate+verify style (nothing to dig beyond which clues get
-- revealed, same shape as hitori/lightup/tapa): escalates the clue-keep
-- ratio in bounded steps (nominal, then higher, then a guaranteed full
-- reveal) for a given loop shape before drawing a fresh one -- a plain
-- "retry the same nominal ratio" loop was already shown not to help
-- elsewhere in this audit when the nominal ratio is itself often
-- ambiguous. Node budget is scaled down for n=20 (the largest grid): an
-- initial uniform budget caused a real worst-case latency problem
-- (~45s at n=20/hard) since much of that budget was being spent on
-- inconclusive attempts that never helped; a smaller budget fails those
-- faster and moves on. 15/15 unique at every size/difficulty after the
-- fix, worst case ~6.65s at n=20/hard (within this fleet's precedent for
-- its hardest settings).
--
-- Exit code is non-zero if any size/difficulty drops below its threshold.

package.preload["gettext"] = function() return function(s) return s end end
package.path = "game-common/?.lua;slitherlink.koplugin/?.lua;" .. package.path
local Board = require("board")

-- Independent cross-check counter (deliberately separate from board.lua's
-- own copy) -- cross-checks the production gate rather than testing a fix
-- against itself.
local function countSolutions(clues, n, limit, node_budget)
    local h = {}
    local v = {}
    for r = 1, n+1 do h[r] = {} end
    for r = 1, n do v[r] = {} end
    local edge_list = {}
    for r = 1, n+1 do for c = 1, n do edge_list[#edge_list+1] = {kind="h",r=r,c=c} end end
    for r = 1, n do for c = 1, n+1 do edge_list[#edge_list+1] = {kind="v",r=r,c=c} end end
    local num_edges = #edge_list
    local function getE(e) if e.kind=="h" then return h[e.r][e.c] else return v[e.r][e.c] end end
    local function setE(e,val) if e.kind=="h" then h[e.r][e.c]=val else v[e.r][e.c]=val end end
    local function cellEdges(r,c)
        return {{kind="h",r=r,c=c},{kind="h",r=r+1,c=c},{kind="v",r=r,c=c},{kind="v",r=r,c=c+1}}
    end
    local function vertexEdges(r,c)
        local es = {}
        if c<=n then es[#es+1]={kind="h",r=r,c=c} end
        if c>1 then es[#es+1]={kind="h",r=r,c=c-1} end
        if r<=n then es[#es+1]={kind="v",r=r,c=c} end
        if r>1 then es[#es+1]={kind="v",r=r-1,c=c} end
        return es
    end
    local decided_count = 0
    local solutions, nodes, exhausted = 0, 0, false
    local function isSingleLoopFinal()
        local total = 0
        for r=1,n+1 do for c=1,n do if h[r][c] then total=total+1 end end end
        for r=1,n do for c=1,n+1 do if v[r][c] then total=total+1 end end end
        if total == 0 then return false end
        for r=1,n+1 do for c=1,n+1 do
            local deg = 0
            if c<=n and h[r][c] then deg=deg+1 end
            if c>1 and h[r][c-1] then deg=deg+1 end
            if r<=n and v[r][c] then deg=deg+1 end
            if r>1 and v[r-1][c] then deg=deg+1 end
            if deg~=0 and deg~=2 then return false end
        end end
        local start_r, start_c
        for r=1,n+1 do for c=1,n do if h[r][c] then start_r,start_c=r,c; goto found end end end
        ::found::
        if not start_r then return false end
        local cur_r,cur_c = start_r,start_c
        local prv_r,prv_c = start_r,start_c+1
        local steps = 0
        repeat
            local nx,ny
            if cur_c<=n and h[cur_r][cur_c] then
                local nr,nc = cur_r,cur_c+1
                if nr~=prv_r or nc~=prv_c then nx,ny=nr,nc end
            end
            if not nx and cur_c>1 and h[cur_r][cur_c-1] then
                local nr,nc = cur_r,cur_c-1
                if nr~=prv_r or nc~=prv_c then nx,ny=nr,nc end
            end
            if not nx and cur_r<=n and v[cur_r][cur_c] then
                local nr,nc = cur_r+1,cur_c
                if nr~=prv_r or nc~=prv_c then nx,ny=nr,nc end
            end
            if not nx and cur_r>1 and v[cur_r-1][cur_c] then
                local nr,nc = cur_r-1,cur_c
                if nr~=prv_r or nc~=prv_c then nx,ny=nr,nc end
            end
            if not nx then return false end
            prv_r,prv_c = cur_r,cur_c
            cur_r,cur_c = nx,ny
            steps = steps + 1
        until (cur_r==start_r and cur_c==start_c)
        return steps == total
    end
    local function setDecided(e,val,changes)
        if getE(e) ~= nil then return getE(e)==val end
        setE(e,val)
        decided_count = decided_count + 1
        changes[#changes+1] = e
        return true
    end
    local function undo(changes)
        for _, e in ipairs(changes) do setE(e,nil); decided_count = decided_count - 1 end
    end
    local function propagate(changes)
        local progressed = true
        while progressed do
            progressed = false
            for r=1,n do for c=1,n do
                local clue = clues[r][c]
                if clue and clue >= 0 then
                    local es = cellEdges(r,c)
                    local have, undecided = 0, {}
                    for _, e in ipairs(es) do
                        local val = getE(e)
                        if val==true then have=have+1
                        elseif val==nil then undecided[#undecided+1]=e end
                    end
                    if have > clue or have + #undecided < clue then return false end
                    if #undecided > 0 then
                        if have == clue then
                            for _, e in ipairs(undecided) do
                                if not setDecided(e,false,changes) then return false end
                            end
                            progressed = true
                        elseif have + #undecided == clue then
                            for _, e in ipairs(undecided) do
                                if not setDecided(e,true,changes) then return false end
                            end
                            progressed = true
                        end
                    end
                end
            end end
            for r=1,n+1 do for c=1,n+1 do
                local es = vertexEdges(r,c)
                local have, undecided = 0, {}
                for _, e in ipairs(es) do
                    local val = getE(e)
                    if val==true then have=have+1
                    elseif val==nil then undecided[#undecided+1]=e end
                end
                if have > 2 then return false end
                if #undecided==0 and have~=0 and have~=2 then return false end
                if #undecided==1 then
                    if have==0 then
                        if not setDecided(undecided[1],false,changes) then return false end
                        progressed = true
                    elseif have==1 then
                        if not setDecided(undecided[1],true,changes) then return false end
                        progressed = true
                    end
                end
            end end
        end
        return true
    end
    local function search()
        if solutions >= limit or exhausted then return end
        nodes = nodes + 1
        if nodes > node_budget then exhausted = true; return end
        local changes = {}
        if not propagate(changes) then undo(changes); return end
        if decided_count == num_edges then
            if isSingleLoopFinal() then solutions = solutions + 1 end
            undo(changes)
            return
        end
        local pick
        for _, e in ipairs(edge_list) do if getE(e)==nil then pick=e; break end end
        if not pick then undo(changes); return end
        for _, val in ipairs({false, true}) do
            local branch_changes = {}
            if setDecided(pick, val, branch_changes) then search() end
            undo(branch_changes)
            if solutions >= limit or exhausted then break end
        end
        undo(changes)
    end
    search()
    return solutions, exhausted
end

local ok = true

local function analyze(n, difficulty, n_trials, node_budget, threshold)
    local unique, ambiguous, inconclusive = 0, 0, 0
    for i = 1, n_trials do
        math.randomseed(i * 7919)
        local b = Board:new({ n = n, difficulty = difficulty })
        b:generate(difficulty)
        local solutions, exhausted = countSolutions(b.clues, n, 2, node_budget)
        if exhausted then inconclusive = inconclusive + 1
        elseif solutions == 1 then unique = unique + 1
        else ambiguous = ambiguous + 1 end
    end
    local rate = unique / n_trials
    local status = rate >= threshold and "OK" or "FAIL"
    if status == "FAIL" then ok = false end
    print(string.format("[%s] n=%d %s: unique=%d/%d ambiguous=%d inconclusive=%d (threshold %.0f%%)",
        status, n, difficulty, unique, n_trials, ambiguous, inconclusive, threshold * 100))
    io.flush()
end

for _, n in ipairs({5, 10, 15, 20}) do
    for _, diff in ipairs({"easy", "medium", "hard"}) do
        analyze(n, diff, 15, 300000, 0.90)
    end
end

os.exit(ok and 0 or 1)
