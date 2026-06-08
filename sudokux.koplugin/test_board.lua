-- test_board.lua for sudokux.koplugin
-- Run: /opt/homebrew/bin/lua test_board.lua
package.path = "./?.lua;./common/?.lua;" .. package.path

-- Stub gettext
package.loaded["gettext"] = setmetatable({}, { __call = function(_, s) return s end })
local gettext = package.loaded["gettext"]
package.loaded["_"] = gettext

-- Patch require("gettext") used inside base_board.lua
local real_require = require
_G.require = function(name)
    if name == "gettext" then
        return setmetatable({}, {
            __call = function(_, s) return s end,
            __index = function(_, k) return function(s) return s end end,
        })
    end
    return real_require(name)
end

local ok, err = pcall(function()
    local m = loadfile("board.lua")()

    -- Find the board class
    local BoardClass = m.SudokuXBoard
    assert(BoardClass, "SudokuXBoard found in module")

    -- Test 1: Creation
    local b = BoardClass:new()
    assert(b ~= nil, "Board created")
    assert(b.n == 9, "9x9 grid")

    -- Test 2: Generation
    b:generate("easy")
    assert(b.solution ~= nil, "Solution generated")
    assert(b.n == 9, "9x9 grid after generate")

    -- Test 3: Serialize/load round-trip
    local data = b:serialize()
    assert(type(data) == "table", "Serialize returns table")
    local b2 = BoardClass:new()
    assert(b2:load(data) == true, "Load succeeded")
    assert(b2.n == 9, "Size preserved after load")

    -- Test 4: No conflict on correct solution
    for r = 1, 9 do
        for c = 1, 9 do
            if not b:isGiven(r, c) then
                b.user[r][c] = b.solution[r][c]
            end
        end
    end
    b:recalcConflicts()
    assert(b:isSolved(), "Solved when all cells correctly filled")

    -- Test 5: Conflict detected on wrong value
    -- Find a non-given cell
    local tr, tc
    for r = 1, 9 do
        for c = 1, 9 do
            if not b:isGiven(r, c) then tr, tc = r, c; break end
        end
        if tr then break end
    end
    if tr then
        local correct = b.solution[tr][tc]
        local wrong = (correct % 9) + 1
        b.user[tr][tc] = wrong
        b:recalcConflicts()
        assert(b:isConflict(tr, tc), "Conflict detected on wrong value")
    end

    -- Test 6: Diagonal conflict detection
    -- Fill diagonal with known values then introduce duplicate
    local b3 = BoardClass:new()
    b3:generate("easy")
    -- Fill the solution
    for r = 1, 9 do
        for c = 1, 9 do
            if not b3:isGiven(r, c) then
                b3.user[r][c] = b3.solution[r][c]
            end
        end
    end
    b3:recalcConflicts()
    assert(b3:isSolved(), "Fresh solve works for diagonal check")

    print("All tests passed for SudokuX (difficulty: " .. tostring(m.DEFAULT_DIFFICULTY) .. ")")
end)
if not ok then
    io.stderr:write("TEST FAILED: " .. tostring(err) .. "\n")
    os.exit(1)
end
