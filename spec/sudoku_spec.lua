local H = require("spec/helper")

describe("SudokuBoard", function()
    local Mod

    setup(function()
        -- Use sudoku-common's grid_utils (different API from game-common's)
        H.unload("grid_utils")
        package.preload["grid_utils"] = function()
            local chunk = assert(loadfile("sudoku-common/grid_utils.lua"))
            return chunk()
        end
        package.path = "sudoku-common/?.lua;sudoku.koplugin/?.lua;" .. package.path
        Mod = require("board")
    end)

    teardown(function()
        H.unload("board", "grid_utils", "base_board", "puzzle_generator")
        package.preload["grid_utils"] = nil
    end)

    local SudokuBoard  = nil
    local getGridConfig = nil

    before_each(function()
        SudokuBoard   = Mod.SudokuBoard
        getGridConfig = Mod.getGridConfig
    end)

    describe("getGridConfig", function()
        it("returns correct config for 9x9", function()
            local cfg = getGridConfig("9x9")
            assert.are.equal(9, cfg.n)
            assert.are.equal(3, cfg.box_rows)
            assert.are.equal(3, cfg.box_cols)
        end)

        it("returns correct config for 4x4", function()
            local cfg = getGridConfig("4x4")
            assert.are.equal(4, cfg.n)
            assert.are.equal(2, cfg.box_rows)
            assert.are.equal(2, cfg.box_cols)
        end)

        it("falls back to 9x9 for unknown id", function()
            local cfg = getGridConfig("unknown")
            assert.are.equal(9, cfg.n)
        end)
    end)

    describe("SudokuBoard:new", function()
        it("creates a 9×9 board by default", function()
            local b = SudokuBoard:new()
            assert.are.equal(9, b.n)
            assert.are.equal(3, b.box_rows)
            assert.are.equal(3, b.box_cols)
        end)

        it("creates a 4×4 board when requested", function()
            local cfg = getGridConfig("4x4")
            local b = SudokuBoard:new(cfg)
            assert.are.equal(4, b.n)
        end)

        it("starts with empty user grid", function()
            local b = SudokuBoard:new()
            for r = 1, b.n do
                for c = 1, b.n do
                    assert.are.equal(0, b.user[r][c])
                end
            end
        end)
    end)

    describe("generate", function()
        it("fills solution and creates a partial puzzle", function()
            math.randomseed(42)
            local b = SudokuBoard:new()
            b:generate("easy")
            -- Solution must be fully filled
            for r = 1, b.n do
                for c = 1, b.n do
                    assert.is_true(b.solution[r][c] > 0,
                        ("solution[%d][%d] should be non-zero"):format(r, c))
                end
            end
        end)

        it("solution is a valid 9×9 sudoku (rows, cols, boxes)", function()
            math.randomseed(1)
            local b = SudokuBoard:new()
            b:generate("easy")
            local n = b.n
            -- Check rows
            for r = 1, n do
                local seen = {}
                for c = 1, n do seen[b.solution[r][c]] = true end
                for d = 1, n do assert.is_true(seen[d], "row " .. r .. " missing " .. d) end
            end
            -- Check cols
            for c = 1, n do
                local seen = {}
                for r = 1, n do seen[b.solution[r][c]] = true end
                for d = 1, n do assert.is_true(seen[d], "col " .. c .. " missing " .. d) end
            end
        end)

        it("isGiven returns true for puzzle cells", function()
            math.randomseed(42)
            local b = SudokuBoard:new()
            b:generate("easy")
            local n = b.n
            local found = false
            for r = 1, n do
                for c = 1, n do
                    if b:isGiven(r, c) then found = true; break end
                end
            end
            assert.is_true(found)
        end)
    end)

    describe("setValue / undo (via BaseBoard)", function()
        local function solvedBoard()
            math.randomseed(42)
            local b = SudokuBoard:new(getGridConfig("4x4"))
            b:generate("easy")
            return b
        end

        it("setValue writes to a free cell and recalcs conflicts", function()
            local b = solvedBoard()
            local n = b.n
            local r, c
            for rr = 1, n do
                for cc = 1, n do
                    if not b:isGiven(rr, cc) then r, c = rr, cc; goto done end
                end
            end
            ::done::
            b:setSelection(r, c)
            local ok = b:setValue(1)
            assert.is_true(ok)
            assert.are.equal(1, b.user[r][c])
        end)

        it("setValue rejects given cells", function()
            local b = solvedBoard()
            local n = b.n
            for r = 1, n do
                for c = 1, n do
                    if b:isGiven(r, c) then
                        b:setSelection(r, c)
                        local ok, reason = b:setValue(1)
                        assert.is_false(ok)
                        assert.is_not_nil(reason)
                        return
                    end
                end
            end
        end)

        it("undo restores previous value", function()
            local b = solvedBoard()
            local n = b.n
            local r, c
            for rr = 1, n do
                for cc = 1, n do
                    if not b:isGiven(rr, cc) then r, c = rr, cc; goto done end
                end
            end
            ::done::
            b:setSelection(r, c)
            b:setValue(1)
            assert.is_true(b:canUndo())
            b:undo()
            assert.are.equal(0, b.user[r][c])
        end)
    end)

    describe("recalcConflicts", function()
        it("marks duplicate values in the same row as conflicts", function()
            local b = SudokuBoard:new(getGridConfig("4x4"))
            -- Manually insert duplicate values in row 1
            b.user[1][1] = 1
            b.user[1][2] = 1
            b:recalcConflicts()
            assert.is_true(b.conflicts[1][1])
            assert.is_true(b.conflicts[1][2])
        end)

        it("clears conflicts when duplicates removed", function()
            local b = SudokuBoard:new(getGridConfig("4x4"))
            b.user[1][1] = 1
            b.user[1][2] = 1
            b:recalcConflicts()
            b.user[1][2] = 2
            b:recalcConflicts()
            assert.is_false(b.conflicts[1][1])
            assert.is_false(b.conflicts[1][2])
        end)
    end)

    describe("isSolved", function()
        it("returns false for a generated puzzle before any user input", function()
            math.randomseed(42)
            local b = SudokuBoard:new(getGridConfig("4x4"))
            b:generate("easy")
            assert.is_false(b:isSolved())
        end)

        it("returns true when user matches solution with no conflicts", function()
            math.randomseed(42)
            local b = SudokuBoard:new(getGridConfig("4x4"))
            b:generate("easy")
            local n = b.n
            for r = 1, n do
                for c = 1, n do
                    if not b:isGiven(r, c) then
                        b.user[r][c] = b.solution[r][c]
                    end
                end
            end
            b:recalcConflicts()
            assert.is_true(b:isSolved())
        end)
    end)

    describe("serialize / load", function()
        it("round-trips board state", function()
            math.randomseed(42)
            local b = SudokuBoard:new(getGridConfig("4x4"))
            b:generate("easy")
            local n = b.n
            local r, c
            for rr = 1, n do
                for cc = 1, n do
                    if not b:isGiven(rr, cc) then r, c = rr, cc; goto done end
                end
            end
            ::done::
            b:setSelection(r, c)
            b:setValue(2)
            local data = b:serialize()

            local b2 = SudokuBoard:new(getGridConfig("4x4"))
            local ok = b2:load(data)
            assert.is_true(ok)
            assert.are.equal(b.n, b2.n)
            assert.are.equal(2, b2.user[r][c])
            for rr = 1, n do
                for cc = 1, n do
                    assert.are.equal(b.solution[rr][cc], b2.solution[rr][cc])
                end
            end
        end)

        it("load returns false for invalid data", function()
            local b = SudokuBoard:new()
            assert.is_false(b:load(nil))
            assert.is_false(b:load({}))
        end)
    end)
end)
