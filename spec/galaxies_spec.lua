local H = require("spec/helper")

describe("GalaxiesBoard", function()
    local Board

    setup(function()
        package.path = "game-common/?.lua;galaxies.koplugin/?.lua;" .. package.path
        Board = require("board")
    end)

    teardown(function()
        H.unload("board", "grid_utils", "undo_stack")
    end)

    -- Board:new() auto-generates internally (unlike most other games) — do not
    -- call :generate() again right after construction unless intentionally
    -- re-randomizing.
    local function newBoard(n)
        math.randomseed(42)
        return Board:new{ n = n or 6 }
    end

    describe("construction", function()
        it("creates a 6×6 board by default and auto-generates", function()
            local b = Board:new()
            assert.are.equal(6, b.n)
            assert.is_not_nil(b.centers)
            assert.is_true(b.num_galaxies >= 3)
        end)

        it("exposes SIZES / DEFAULT_N", function()
            assert.are.same({6, 8}, Board.SIZES)
            assert.are.equal(6, Board.DEFAULT_N)
        end)
    end)

    describe("generate", function()
        it("assigns every cell to a galaxy in the solution", function()
            local b = newBoard(6)
            for r = 1, b.n do
                for c = 1, b.n do
                    local g = b.solution_region[r][c]
                    assert.is_true(g >= 1 and g <= b.num_galaxies)
                end
            end
        end)

        -- KNOWN BUG (see project memory, not fixed here -- see the 2026-07-17
        -- investigation): generateGalaxies' step 4 assigns leftover cells to
        -- their nearest center by Manhattan distance alone, with no check
        -- that the cell's 180-degree rotation partner ends up in the same
        -- galaxy. Empirically this violates rotational symmetry in every
        -- sampled generation (30/30 at n=6), so "solution_region is fully
        -- symmetric" is NOT an invariant of the current generator and is not
        -- asserted here. checkWin() itself never compares against
        -- solution_region (it only validates the player's own coloring), so
        -- this doesn't block play the way a stricter comparison would, but
        -- the "reveal solution" picture can be wrong, and some generated
        -- puzzles may have no valid solution at all under the given centers.
        pending("solution_region rotational symmetry is not currently guaranteed by the generator (see project memory)")

        it("user_region starts fully unassigned", function()
            local b = newBoard(6)
            for r = 1, b.n do
                for c = 1, b.n do
                    assert.are.equal(0, b.user_region[r][c])
                end
            end
        end)
    end)

    describe("cycleCell (simple forward-only cycle)", function()
        it("cycles 0→1→...→N→0", function()
            local b = newBoard(6)
            local N = b.num_galaxies
            local r, c = 1, 1
            for i = 1, N do
                b:cycleCell(r, c)
                assert.are.equal(i, b.user_region[r][c])
            end
            b:cycleCell(r, c)
            assert.are.equal(0, b.user_region[r][c])
        end)
    end)

    describe("tapCell (documented wrap-around quirk)", function()
        it("cycles 1..N but does not return to 0 for N>1 (known quirk vs cycleCell)", function()
            local b = newBoard(6)
            local N = b.num_galaxies
            assert.is_true(N > 1, "test assumes n=6 always yields num_galaxies > 1")
            local r, c = 2, 2
            for i = 1, N do
                b:tapCell(r, c)
                assert.are.equal(i, b.user_region[r][c])
            end
            -- One more tap: wraps to 1, not 0, because `next == cur` only
            -- triggers the reset-to-0 branch when N == 1.
            b:tapCell(r, c)
            assert.are.equal(1, b.user_region[r][c])
        end)
    end)

    describe("undoMove", function()
        it("restores the previous value and clears won", function()
            local b = newBoard(6)
            b:cycleCell(1, 1)
            local ok = b:undoMove()
            assert.is_true(ok)
            assert.are.equal(0, b.user_region[1][1])
            assert.is_false(b.won)
        end)

        it("returns false when there is nothing to undo", function()
            local b = newBoard(6)
            assert.is_false(b:undoMove())
        end)
    end)

    describe("reveal / clearUser / countUnassigned", function()
        it("countUnassigned equals n*n on a fresh board", function()
            local b = newBoard(6)
            assert.are.equal(b.n * b.n, b:countUnassigned())
        end)

        it("reveal copies the solution into user_region and wins", function()
            local b = newBoard(6)
            b:reveal()
            assert.are.equal(0, b:countUnassigned())
            assert.is_true(b.won)
            for r = 1, b.n do
                for c = 1, b.n do
                    assert.are.equal(b.solution_region[r][c], b.user_region[r][c])
                end
            end
        end)

        it("clearUser resets user_region and won", function()
            local b = newBoard(6)
            b:reveal()
            b:clearUser()
            assert.are.equal(b.n * b.n, b:countUnassigned())
            assert.is_false(b.won)
        end)
    end)

    describe("serialize / load", function()
        it("round-trips centers, solution and user state", function()
            local b = newBoard(6)
            b:cycleCell(1, 1)
            local data = b:serialize()
            local b2 = Board:new{ n = 6 }
            local ok = b2:load(data)
            assert.is_true(ok)
            assert.are.equal(b.n, b2.n)
            assert.are.equal(b.num_galaxies, b2.num_galaxies)
            assert.are.equal(b.user_region[1][1], b2.user_region[1][1])
        end)

        it("load returns false for invalid data", function()
            local b = Board:new()
            assert.is_false(b:load(nil))
            assert.is_false(b:load({}))
        end)
    end)
end)
