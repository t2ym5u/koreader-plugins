-- Uniqueness audit result for tatami.koplugin: AUDITED, NO BUG, NO FIX
-- NEEDED. This is a regression guard for the invariant the proof relies
-- on, not a fix verification (there was nothing to fix).
--
-- Run from the repo root:
--   luajit spec/solvability_audits/tatami_solvability_check.lua
--
-- _checkWin() is a literal full-grid comparison to sol_pairs (every cell's
-- domino partner must match exactly). generateTiling()'s own header
-- comment already records an exhaustive search result from an earlier
-- session: of all 36 domino tilings of a 4x4 grid and all 6728 tilings of
-- a 6x6 grid, exactly 2 are free of "tatami cross" violations at each
-- size -- the `horiz=true` and `horiz=false` pinwheel constructions.
-- generate() always produces one of those two.
--
-- The uniqueness question this file answers: given that only 2 valid full
-- solutions exist per size, could a puzzle's revealed "given" dominoes
-- ever be consistent with BOTH of them (making the puzzle genuinely
-- ambiguous between exactly 2 completions)? Checked directly: the two
-- pinwheel tilings (horiz=true vs horiz=false) share ZERO cells in common
-- at either size -- every single cell's domino partner differs between
-- them. That means any non-empty clue reveal instantly and unambiguously
-- identifies which of the two global tilings is the solution, and the
-- rest of the grid is then fully forced (the other tiling is entirely
-- ruled out). Since `selectGivens` always reveals at least one domino
-- (`n_give = math.max(1, ...)`), **every tatami puzzle at every supported
-- size and difficulty is mathematically guaranteed to have a unique
-- solution** -- not just empirically likely, provably certain given the
-- generator's already-constructive (2026-07-27) design. No fix was
-- needed; this file exists to catch a regression if the tiling
-- construction ever changes (e.g. a third valid tiling being introduced,
-- or the two existing ones starting to share cells).
--
-- Exit code is non-zero if the "zero shared cells" invariant ever breaks.

package.preload["gettext"] = function() return function(s) return s end end

-- Reproduce fillPinwheel/generateTiling standalone (board.lua doesn't
-- export its locals) -- kept in exact lockstep with board.lua's own copy;
-- if that construction ever changes, update this too.
local function fillPinwheel(pairs, r0, c0, size, horiz)
    if size <= 0 then return end
    if size == 2 then
        if horiz then
            pairs[r0][c0]         = { r0, c0 + 1 };     pairs[r0][c0 + 1]         = { r0, c0 }
            pairs[r0 + 1][c0]     = { r0 + 1, c0 + 1 };  pairs[r0 + 1][c0 + 1]     = { r0 + 1, c0 }
        else
            pairs[r0][c0]         = { r0 + 1, c0 };      pairs[r0 + 1][c0]         = { r0, c0 }
            pairs[r0][c0 + 1]     = { r0 + 1, c0 + 1 };  pairs[r0 + 1][c0 + 1]     = { r0, c0 + 1 }
        end
        return
    end
    local last = r0 + size - 1
    if horiz then
        for c = c0, last, 2 do
            pairs[r0][c]     = { r0, c + 1 };     pairs[r0][c + 1]     = { r0, c }
            pairs[last][c]   = { last, c + 1 };   pairs[last][c + 1]   = { last, c }
        end
        for r = r0 + 1, last - 1, 2 do
            pairs[r][c0]     = { r + 1, c0 };     pairs[r + 1][c0]     = { r, c0 }
            pairs[r][last]   = { r + 1, last };   pairs[r + 1][last]   = { r, last }
        end
    else
        for r = r0, last, 2 do
            pairs[r][c0]     = { r + 1, c0 };     pairs[r + 1][c0]     = { r, c0 }
            pairs[r][last]   = { r + 1, last };   pairs[r + 1][last]   = { r, last }
        end
        for c = c0 + 1, last - 1, 2 do
            pairs[r0][c]     = { r0, c + 1 };     pairs[r0][c + 1]     = { r0, c }
            pairs[last][c]   = { last, c + 1 };   pairs[last][c + 1]   = { last, c }
        end
    end
    fillPinwheel(pairs, r0 + 1, c0 + 1, size - 2, horiz)
end

local function generateTiling(n, horiz)
    local pairs = {}
    for r = 1, n do pairs[r] = {} end
    fillPinwheel(pairs, 1, 1, n, horiz)
    return pairs
end

local ok = true
for _, n in ipairs({ 4, 6 }) do
    local A = generateTiling(n, true)
    local B = generateTiling(n, false)
    local same, total = 0, n * n
    for r = 1, n do
        for c = 1, n do
            if A[r][c][1] == B[r][c][1] and A[r][c][2] == B[r][c][2] then
                same = same + 1
            end
        end
    end
    local status = same == 0 and "OK" or "FAIL"
    if status == "FAIL" then ok = false end
    print(string.format("[%s] n=%d: cells shared between the 2 valid tilings = %d/%d (must be 0)",
        status, n, same, total))
end

os.exit(ok and 0 or 1)
