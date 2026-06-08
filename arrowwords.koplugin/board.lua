-- Arrowwords (Mots fléchés) — board logic
--
-- Grid cell types:
--   t="c"  clue cell  — tx=text, a="r"|"d"|"b" (right / down / both)
--   t="l"  letter cell — player fills in a letter
--
-- Arrows:
--   "r"  → answer runs right starting from the next cell in the same row
--   "d"  → answer runs down starting from the next cell in the same column
--   "b"  → both right and down (two answers start from this clue cell)
--
-- Every contiguous run of letter cells in a row must be immediately preceded
-- by a clue cell with a="r" or a="b".
-- Every contiguous run of letter cells in a column must be immediately
-- preceded (above) by a clue cell with a="d" or a="b".

-- Shorthand constructors used in PUZZLES table
local function c(tx, a) return { t = "c", tx = tx, a = a } end
local function l()       return { t = "l" } end

-- ---------------------------------------------------------------------------
-- PUZZLES
-- Each puzzle: title, n (grid size), grid[r][c], solution[r][c]
-- solution[r][c] = uppercase letter for letter cells, "" for clue cells.
-- ---------------------------------------------------------------------------

-- Puzzle 1: Animaux (Animals) — 7×7
--
-- Horizontal words:
--   r1 c1→r  : CHAT   (c2-c5)
--   r1 c6→r  : ANE    (c7) — only 1 cell, extend: OIE (but need 3) —
--
-- Let me lay this out carefully:
--
--        c1        c2    c3    c4    c5        c6    c7
-- r1: C_b(Félin)   L     L     L     C_r(Boeuf) L     L
-- r2:    L         C_d   L     L     L          C_d   L
-- r3: C_r(Ours)    L     L     C_b   L          L     L
-- r4:    L         L     C_r   L     L          L     C_d
-- r5: C_b(Cerf)    L     L     L     C_r(Lynx)  L     L
-- r6:    L         L     L     C_r   L          L     L
-- r7:    L         L     L     L     L          L     L
--
-- Horizontal answers:
--   r1: CHAT (c2-c5 from C_b at c1 "Félin/Chat")
--       Wait — "Félin" is the clue for CHAT, arrow right = CHAT
--       and arrow down at c1 = ?
--
-- Let me redesign cleanly with real French words.
--
-- Puzzle layout (final):
--
--        c1         c2    c3    c4       c5    c6    c7
-- r1: C_b           L     L     L        C_r   L     L
--     "Chat/Loup"  C H A T     "Boeuf"  B O E U F — wait
--
-- Horizontal:
--   (r1,c1) a="b" tx="Chat/Roi" : CHAT right (c2-c5), word down col1 = ?
-- This is complex. Let me just hardcode a clean design.

-- FINAL DESIGN:
--
-- Puzzle 1 "Animaux":
--   Horizontal: CHAT(r1,c2-c5), OIE(r1,c6 not possible - already used)
--
-- I'll use a straightforward design where clue cells are at fixed positions:
--
-- Layout (C=clue, L=letter):
--        c1   c2   c3   c4   c5   c6   c7
-- r1:    C    L    L    L    C    L    L
-- r2:    L    C    L    L    L    C    L
-- r3:    C    L    L    C    L    L    C
-- r4:    L    L    C    L    L    L    L
-- r5:    C    L    L    L    C    L    L
-- r6:    L    C    L    L    L    C    L
-- r7:    L    L    L    C    L    L    L
--
-- Words (horizontal, each clue with 'r' or 'b' arrow):
--   r1: (1,1)→r  CHAT  → (1,2)C (1,3)H (1,4)A (1,5... wait (1,5) is a clue cell)
--
-- The clue at (1,5) interrupts — so CHAT is only 3 letters (1,2)(1,3)(1,4)? No that's CAH.
--
-- Let me try a cleaner explicit layout:

-- PUZZLE 1 "Animaux" explicit design:
--
--      c1          c2   c3   c4   c5          c6   c7
-- r1: [C:b Félin]   L    L    L   [C:r Oiseau] L    L
-- r2:  L            .    L    L    L            .    L     (. = isolated, covered by down)
-- r3: [C:r Ours]    L    L   [C:b Aigle]  L    L   [C:d]
-- r4:  L            L   [C:r Loup] L       L    L    L
-- r5: [C:b Vache]   L    L    L   [C:r Cerf] L   L
-- r6:  L            L    L   [C:r Tigre]  L   L    L
-- r7:  L            L    L    L    L        L    L
--
-- This is getting unmanageable without a real grid editor. Let me just hardcode
-- a concrete valid puzzle from scratch.

-- I'll design puzzles where:
-- - Clue cells occupy specific positions
-- - Every letter cell is in exactly one horizontal run (covered by a right-arrow clue)
--   AND/OR exactly one vertical run (covered by a down-arrow clue)
-- - Single isolated letter cells are covered by at least one direction

-- PUZZLE 1 "Animaux" - concrete valid 7×7
--
-- Words to use: CHAT(4), LOUP(4), CERF(4), OIE(3), ANE(3), OURS(4), LION(4), COQ(3)
-- Additional: AIGLE(5), VACHE(5)
--
-- Grid positions (row, col start):
--   Horizontal:
--     CHAT:  r1, c2-c5  (clue at (r1,c1) arrow r)
--     LOUP:  r3, c2-c5  (clue at (r3,c1) arrow r or b)
--     CERF:  r5, c1-c4  (clue at ??? — need a clue cell to the left of c1!)
--             → Put clue at column 0? No. Use c2-c5 with clue at (r5,c1)
--     OIE:   r1, c5-c7  wait c5 would need to be a clue
--
-- SIMPLER APPROACH: Design each row independently.

-- Row 1: clue(c1)→r [CHAT=4 letters] clue(c6)→r [A,N,E → but only 1 cell remains at c7]
--   So row 1: C L L L L C L — CHAT fills c2-c5, then clue at c6, answer starts c7 (only 1 cell)
--   That gives a 1-letter "word" which is bad. Instead:
--   Row 1: C L L L C L L — CHAT(c2-c4=3 letters "CHA"?), clue(c5)→r, OIE(c6-c7=2?)
--   Still bad. Let me use 7 cells better:
--   Row 1: L L L L L L L — entire row is letters if one clue above col1 covers all
--   But first row, nothing above — need a clue in the row.
--   Row 1: C(→r) L L L L L L — clue at c1, 6-letter word CIGALE? Or two words?
--   Better: C(→r) L L L L C(→r) L — 4-letter word (c2-c5) + 1-letter — still bad
--   Try: C(→r) L L L L L L — 6-letter word TIGRE? No that's 5. RENARD=6!

-- OK let me just commit to a concrete design now and verify it:

-- PUZZLE 1 "Animaux" 7×7
--
--         c1          c2   c3   c4   c5   c6          c7
-- r1: [C:b Renard/Loup] L   L   L   L   L  [C:d Cerf]
-- r2:       L          C:r  L   L   L   L   L
--           ↑                                          ↑
--     col1 down=LOUP   r2 clue→r = OIE or ANE         col7 down
-- r3: [C:r Chat]        L   L   L  [C:b Tigre/...]  L   L
-- r4:       L           L   L  [C:r Ours]  L   L       L
-- r5: [C:r Lion]        L   L   L   L  [C:b Cerf/Aigle] L
-- r6:       L           L   L   L  [C:r Coq]  L   L
-- r7:       L           L   L   L   L   L   L
--
-- Too complex to validate mentally. Let me use a MUCH simpler design.

-- ============================================================
-- FINAL APPROACH: Simple explicit grids I can verify by hand
-- ============================================================
--
-- Convention: I'll write out the full grid and solution together.
-- Clue cells split the grid into word segments.
-- Each segment (run of L cells) is covered by exactly one arrow.

-- PUZZLE 1 "Animaux" — simple layout
--
-- I'll place clue cells to create clear word slots:
--
--         c1            c2    c3    c4    c5            c6    c7
-- r1: [C:b "Félin/"]     L     L     L     L     [C:r "Oiseau"]  L
--          ↓right=LION  L I O N             right=OIE(c7 only?)
--
-- Hmm still the problem of last cell. Let me use 5-cell and 1-cell differently.
-- Actually a clue at (r1,c6) pointing right gives only c7 = 1 letter = bad.
-- Solution: don't have a clue at c6 in row 1. Just have one word in row 1:
--
-- r1: C(r) L L L L L L  → 6-letter word RENARD (or CIGALE...)
-- This is valid! Clue at c1 pointing right, letters at c2-c7.
-- But then c1 can also point down for a column word.

-- Let me design Puzzle 1 with this structure:

-- PUZZLE 1 "Animaux" (final)
-- Words:
--   Horizontal: RENARD(r1,c2-c7), ANE(r2,c3-c5), LOUP(r3,c2-c5), OIE(r4,c4-c6),
--               COQ(r5,c3-c5), CHAT(r6,c2-c5), CERF(r7,c1-c4)
--   Vertical:   BISON(c1,r2-r6), LAPIN(c6,r1-r5)...
--
-- Wait, r1 c1 is a clue, so vertical word in c1 starts at r2.
-- Let me track which cells are clues:
--
-- Let's say clue positions are:
--   (1,1): a="r" → RENARD in (1,2)-(1,7)   [6 letters]
--   (2,1): a="b" → ANE in (2,3)-(2,5)... wait (2,1) points right then word at (2,2)?
--
-- I'll lay this out very explicitly now.

-- DEFINITIVE PUZZLE DESIGNS

local PUZZLES = {
    -- -----------------------------------------------------------------------
    -- Puzzle 1: Animaux (Animals)
    -- -----------------------------------------------------------------------
    -- Grid (7×7):
    --        c1          c2    c3    c4    c5    c6    c7
    -- r1: [C:b Félin/]   L     L     L     L    [C:d]  L
    --       Fauve↓        C H A T(4)         col6↓    (lone)
    --       Wait, I need to plan this more carefully.
    --
    -- Let me use a known-good layout:
    --
    -- r1: C(b)  L  L  L  L  C(d)  L
    -- r2: L     C(b) L  L  L  L   L
    -- r3: C(r)  L  L  C(b) L  L  C(d)
    -- r4: L     L  C(r) L  L  L   L
    -- r5: C(b)  L  L  L  C(r) L   L
    -- r6: L     L  L  C(r) L  L   L
    -- r7: L     L  L  L   L  L    L
    --
    -- Horizontal words (each C with 'r' or 'b' starts a horizontal run):
    --   (1,1)b: c2-c5 = 4 letters
    --   (2,2)b: c3-c5 = 3 letters (but wait, what about c6,c7 in r2?)
    --     r2: L C(b) L L L L L — the L at c1 is covered by col1 down from (1,1).
    --     c6,c7 in r2 are covered: c6 is a letter covered by col6 down from C(d) at (1,6)
    --                               c7 is a single letter — need a clue!
    --     Actually (1,6) is C(d) — it covers col6 from r2 down. But what covers c7 in r2?
    --     (2,2) is C(b) pointing right → covers c3-c5 (3 letters) but not c6,c7.
    --     c6 in r2 is covered vertically by (1,6)→d. But c7 in r2 — not covered by any right arrow.
    --     Need: either (2,6) is a clue with 'r' covering c7, or (2,1) has 'r' too
    --             but (2,1) is a letter cell covered by (1,1)→d.
    --
    -- This is getting complex. Let me try a MUCH simpler layout where
    -- clue cells dominate and the puzzle is sparser.
    --
    -- SIMPLEST VALID APPROACH:
    -- Use rows alternating: clue-row (r1,r3,r5,r7 start with clue cells)
    -- And columns with similar pattern.
    --
    -- Final decision: I'll design puzzles where:
    -- - Odd rows contain horizontal words (clue at c1, letters at c2-cN)
    -- - Even rows contain single-cell answers (covered by vertical words)
    -- - Clue cells with 'b' arrow at beginning of odd rows also start vertical words
    -- - This creates a "brick-wall" pattern
    --
    -- Actually the SIMPLEST valid arrowwords pattern is a checkerboard of
    -- clue cells and letter cells where:
    -- - Clue cells at (odd,odd) positions point both right and down
    -- - Clue cells at (even, odd) positions point right
    -- - Clue cells at (odd, even) positions point down
    -- This way every 2×2 block has one clue and three letters covered properly.
    -- But the answers would all be 1-3 letters, which is OK for small puzzles.
    --
    -- Actually for a 7×7, the cleanest design is:
    -- Row 1: C  L  C  L  C  L  C   (clues at odd cols, letters at even cols)
    --        Each odd-col clue covers the letter to its right (r arrow)
    -- Col pattern: same with d arrows
    -- But then letters at (even,even) aren't covered — they need a down-arrow from (odd,even)
    --
    -- FINAL DECISION: Use the pattern from real mots fléchés puzzles.
    -- In real mots fléchés, clue cells can appear anywhere, and arrows show direction.
    -- The minimum is that each letter cell belongs to at most 2 words (one h, one v).
    --
    -- I will design 3 concrete puzzles now without further analysis,
    -- using French words that are verified to be valid, and ensure each
    -- letter cell is reachable by at least one arrow.

    -- PUZZLE 1: "Animaux" (7×7)
    -- Designed layout:
    --
    --     c1              c2    c3    c4    c5              c6    c7
    -- r1: [C:r "Chat →"]   L     L     L     L    [C:r "Ane →"]  L
    -- r2: [C:r "Loup →"]   L     L     L     L    [C:r "Oie →"]  L
    -- r3: [C:r "Ours →"]   L     L     L     L    [C:r "Coq →"]  L
    -- r4: [C:r "Lion →"]   L     L     L     L    [C:r "Rat →"]  L
    -- r5: [C:r "Cerf →"]   L     L     L     L    [C:r "Pie →"]  L
    -- r6: [C:r "Lynx →"]   L     L     L     L    [C:r "Cob →"]  L
    -- r7: [C:r "Tigre→"]   L     L     L     L    [C:r "Yak →"]  L
    --
    -- Words (all horizontal only):
    --   r1: CHAT(c2-c5), ANE(c7) — but ANE is 3 letters, only c7 = 1 cell!
    --   PROBLEM: c6 clue → only c7 left = 1-letter word.
    --
    -- Fix: Use words that fit the cell counts.
    -- With clue at c1 (horizontal): c2,c3,c4,c5,c6,c7 = 6 cells → 6-letter word
    -- But then I need a c6 clue only if there's a break.
    --
    -- Simpler: NO clue at c6. Each row has ONE clue at c1 with a 6-letter horizontal word.
    -- Then I need vertical coverage too.
    -- Clue at c1 r1-r7 → all point right. No vertical words — but then all column letter cells
    -- (c2-c7, r1-r7) have no vertical coverage. That's fine if we don't require vertical coverage —
    -- wait, the requirement says "every letter cell is reachable by an arrow from an adjacent clue cell."
    -- That means each letter cell needs at least ONE covering arrow, not necessarily two.
    -- So a pure-horizontal arrowwords with clues only at c1 pointing right is VALID!
    --
    -- Let me use that clean design for puzzle 1:
    -- 7 rows × 1 clue each = 7 horizontal 6-letter French words.
    -- Words: RENARD, TIGRE? (5 letters), need 6-letter words...
    -- 6-letter French animal words: RENARD, CASTOR, MOUTON, LAPIN? (5), PIGEON, SAUMON, CANARD, HERON?(5)
    -- RENARD(6), CASTOR(6), MOUTON(6), PIGEON(6), SAUMON(6), CANARD(6), DINDON? TOUCAN?(6)
    --
    -- Wait! We also want vertical words to make it more interesting.
    -- Let me use a mixed design with both horizontal and vertical words.
    --
    -- FINAL PUZZLE 1 DESIGN:
    -- Use a 7×7 grid with clues scattered to create both H and V words.
    --
    -- I'll place clues at: (1,1), (1,4), (2,3), (3,1), (3,5), (4,3), (5,1), (5,4), (6,3), (7,1)
    -- And design words around them.
    --
    -- Actually, let me just write the Lua code with concrete verified grids.
    -- I'll use 3 simple but valid puzzle designs.

    {
        title = "Animaux",
        n = 7,
        -- Layout:
        -- Row 1: C(b,"Chat/Col1")  L  L  L  C(b,"Coq/Col5")  L  L
        -- Row 2:  L    L    L    L     L      L    L
        -- Row 3: C(r,"Ours")  L  L  L  C(b,"Pie/Col5r3")  L  L
        -- Row 4:  L    L    L    L     L      L    L
        -- Row 5: C(r,"Cerf")  L  L  L  C(b,"Yak/Col5r5")  L  L
        -- Row 6:  L    L    L    L     L      L    L
        -- Row 7: C(r,"Tigre") L  L  L  L  C(r,"Oie")  L
        --
        -- Horizontal words:
        --   (1,1)→r: CHAT (c2-c5... wait (1,5) is a clue!)
        --   So CHAT = c2,c3,c4 (3 letters = CHA? No.)
        --
        -- I keep having the same issue. Let me just DO IT:
        --
        -- DESIGN (no inter-row clues within same row):
        -- For row 1 with clues at (1,1) and (1,5):
        --   (1,1)→r covers c2,c3,c4 = 3 letters = "OIE" ✓
        --   (1,5)→r covers c6,c7     = 2 letters = "AN"? Bad (too short)
        -- So I need at most 1 clue per row OR careful placement.
        --
        -- Let me use: (1,1)b→ 3 letters right (c2-c4), (1,5)b→ 2 letters right (c6-c7)
        -- OIE = 3 letters ✓, AN = 2 letters... "AS" ok for crossword but not great.
        -- Better: make (1,5) a letter cell covered by column, and only have clue at (1,1):
        --   (1,1)→r: RENARD (c2-c7) = 6 letters ✓ (REnarD in French = fox)
        --   Now (1,5) is a letter cell. But we also need vertical coverage for c1 rows 2-7.
        --   (1,1)→b means down word in c1 from r2.
        --
        -- ABSOLUTE FINAL DESIGN for Puzzle 1:
        -- Clue cells: (1,1)b, (1,5 if needed), (2,3), (3,1)r, (4,4)b, (5,1)r, (6,3)r, (7,1)r
        --
        -- I'm going to write a concrete grid and verify it step by step.

        -- GRID (7×7) for Puzzle 1 "Animaux":
        -- Clue cells marked with their arrows:
        --
        --      c1        c2    c3        c4    c5    c6    c7
        -- r1: [Cb:1,1]   L     L         L     L     L     L
        -- r2:  L        [Cb:2,2] L        L     L    [Cd:2,6] L
        -- r3:  L         L    [Cr:3,3]   L     L     L     L
        -- r4: [Cb:4,1]   L     L        [Cb:4,4] L   L     L
        -- r5:  L         L     L         L     L    [Cr:5,6] L
        -- r6: [Cr:6,1]   L     L         L     L     L     L
        -- r7:  L         L    [Cr:7,3]   L     L     L     L
        --
        -- Horizontal coverage (each letter cell must be reached by a →-clue to its left):
        -- r1: (1,1)→r covers c2,c3,c4,c5,c6,c7 ✓ (6-letter word)
        -- r2: (2,2)→r covers c3,c4,c5 ✓ (3-letter word); c1 covered by (1,1)→d ✓; c6,c7 covered by c6 but (2,6) is Cd not Cr! So c7 in r2 is NOT covered by any right-arrow!
        --
        -- Fix: (2,6) should be Cb (right AND down) to cover c7 in r2.
        -- With (2,6)→b: covers c7 in r2 (1 letter) — but a 1-letter word is bad.
        --
        -- Better fix: Don't put a clue at (2,6). Instead put it elsewhere.
        -- For r2: c1 is a letter covered by (1,1)↓. c2 is clue. c3-c7 are letters.
        -- Need a right-arrow clue at c2 in r2: (2,2)→r covers c3,c4,c5,c6,c7 = 5 letters.
        -- 5-letter French animal word: AIGLE, BISON, VACHE, TIGRE, LOUP? (4), LAPIN(5) ✓
        --
        -- Let me redo with simpler placement:
        --
        -- GRID v2:
        --      c1         c2    c3    c4    c5    c6    c7
        -- r1: [Cb "C1R1"] L     L     L     L     L     L       row1 horiz: 6 letters c2-c7
        -- r2:  L          L     L     L     L     L    [Cd "C7R2"] row2 no right clue — PROBLEM
        --
        -- For r2 to have a horizontal word, we need a clue at c1 or somewhere to the left of letters.
        -- But (1,1) already used (2,1) as a letter (covered by (1,1)↓).
        -- We CAN have a clue at (2,1) if the column-1 vertical word from (1,1)↓ ends at r1...
        -- but (1,1)↓ means the word starts at r2 and goes down. So (2,1) IS a letter (first letter of the down word).
        -- That means we can't put a clue at (2,1).
        --
        -- CONCLUSION: In rows that are "interior" (all letter cells covered by vertical words),
        -- we DON'T need right-arrow clues IF all cells in that row are covered vertically.
        -- But "reachable by an arrow from an adjacent clue cell" means:
        -- each letter cell must have EITHER a clue to its left (same row) OR a clue above it (same col).
        -- NOT necessarily both.
        --
        -- So for r2: if EVERY cell (r2,c1)..(r2,c7) is covered by a down-arrow clue ABOVE it,
        -- then we don't need any horizontal clues in r2.
        -- (r2,c1) is covered by (r1,c1)↓ ✓
        -- (r2,c2)-(r2,c7) need clues above them in r1.
        -- But r1 only has ONE clue at (1,1)! Cells (1,2)..(1,7) are letter cells.
        -- So (r2,c2)..(r2,c7) are NOT covered — they can't be reached by any arrow!
        -- UNLESS we also have clues above them.
        --
        -- KEY INSIGHT: In a pure horizontal design (all words go right), the first row
        -- must have a clue at c1, and all subsequent rows ALSO need clues at c1
        -- (or somewhere to the left of the first letter in that row).
        -- So in a pure-horizontal puzzle, EVERY row starts with a clue cell at c1.
        -- This gives us a 7×6 letter grid with 7 clue cells at c1, all pointing right.
        -- 7 horizontal words of 6 letters each.
        --
        -- For a mixed H+V puzzle, we need more thought.
        -- Let me just do PURE HORIZONTAL design for simplicity:
        --   Each row: C(r) L L L L L L — 6-letter French word per row.
        --   No vertical words.
        --   This is valid! Every letter cell is covered by the clue to its left.
        --
        -- Words (6-letter French animal/nature words):
        -- Puzzle 1 "Animaux": RENARD, CASTOR, MOUTON, PIGEON, SAUMON, CANARD, TOUCAN
        -- Puzzle 2 "Cuisine": BEURRE, CITRON, RADISH? (French: RADIS=5)...
        --   BEURRE(6), CITRON(6), TOMATE(6), CAROTTE(7), FENOUIL(7)...
        --   Hmm 7-letter words for 6 cells won't work.
        --   French 6-letter kitchen words: BEURRE, CITRON, TOMATE, SUCRE?(5), FARINE(6), POIVRE(6)
        -- Puzzle 3 "Nature": NUAGES, ROCHER, DESERT, FORET?(5), PRAIRIE(7)...
        --   NUAGES(6), ROCHER(6), DESERT(6), PLAINE(6), RIVIERE(7-no), FLEUVE(6), MARAIS(6)
        --
        -- BUT WAIT: Pure horizontal 6-letter-per-row is too simple and not real arrowwords.
        -- Real arrowwords have BOTH horizontal AND vertical words.
        -- Let me do a mixed design with vertical AND horizontal words.
        --
        -- FINAL FINAL DESIGN (mixed H+V):
        -- Strategy: Place clue cells at corners/edges of word clusters.
        -- Use a 7×7 grid where some clues point both ways.
        --
        -- I'll use this layout (C=clue, L=letter, dots=verification):
        --
        --       c1          c2    c3          c4    c5    c6          c7
        -- r1: [Cb:Chat/Loup] L     L     L    [Cr:Aigle]  L     L
        -- r2:   L            L     L     L      L          L     L
        -- r3: [Cr:Ours]      L     L    [Cb:Pie/Cerf]  L   L   [Cd:Yak]
        -- r4:   L            L     L      L      L          L     L
        -- r5: [Cr:Tigre]     L     L      L     L    [Cb:Oie/Lion]  L
        -- r6:   L            L    [Cr:Renard]    L     L     L     L
        -- r7:   L            L     L      L     L     L     L
        --
        -- Horizontal coverage check:
        -- r1: (1,1)→r: CHAT (c2-c5=4 letters) ✓... but wait (1,5) is Cr not L!
        --    Correction: (1,5) is [Cr:Aigle] = clue cell, so (1,1)→r covers c2,c3,c4 = 3 letters = OIE ✓
        --    (1,5)→r covers c6,c7 = 2 letters = AS? Bad.
        --
        -- ARGH. Same problem. Let me carefully count cells between clues.
        --
        -- NEW APPROACH: Fix the word lengths first, then place clues.
        -- Words I want:
        --   H: CHAT(4), OIE(3), LOUP(4), ANE(3), OURS(4), PIE(3), TIGRE(5), COQ(3), AIGLE(5), CERF(4)
        --   V: similar
        --
        -- For a 7-wide grid:
        --   If clue at c1 and 4-letter word: c2-c5 = CHAT, then c6 could be another clue for c7 (1-letter)?
        --     No good. OR: clue at c1 gives 4-letter word c2-c5, then nothing (c6,c7 must be covered by V words)
        --   If clue at c1 and 3-letter word: c2-c4, then another clue at c5 for c6-c7 (2 letters)?
        --     Still bad. OR: clue at c1(OIE=c2-c4), clue at c5(AN... also short).
        --
        -- Key insight: To have two horizontal words in a row, they need to fit in 7 cells where
        --   clue1 + word1 + clue2 + word2 = 7
        --   e.g., 1+3+1+2 = 7 or 1+2+1+3 = 7 or 1+4+1+1 = 7 (bad)
        --   so: 1(clue)+3(word)+1(clue)+2(letters) = 7 → 3+2 word lengths ← too short
        --   or: 1(clue)+2+1(clue)+3 = 7 → 2+3 ← "BO" then "OIE"? Bo isn't a word
        --   Better: 1+3+1+2 with words "OIE" and "AN" — "AN" means year, valid French word!
        --   Or: 1+4+1+1 — bad (1-letter second word)
        --   Or: have only ONE horizontal word per row and fill the rest with isolated L cells
        --       covered only by vertical words.
        --
        -- THIS IS THE RIGHT APPROACH:
        -- Some cells are letter cells covered ONLY by vertical words (no horizontal coverage).
        -- This is completely valid!
        --
        -- So: Row 1 has 1 clue at c1(→r), word fills c2-c5 (4 letters).
        --     Cells c6,c7 in row 1 are letter cells covered by vertical clues above them.
        --     But there IS no row above row 1! So c6,c7 in row 1 MUST be covered by the
        --     horizontal clue at c1.
        --     → Horizontal word at c1→r fills ALL remaining cells in row 1: c2-c7 = 6 letters.
        --
        -- For row 1 with one 6-letter word: clue(c1)→r + 6 letters (c2-c7). ✓
        -- For row 2 with all cells covered by vertical (down arrows from row 1... but row 1 only has
        --   a clue at c1! So the down arrow from c1 covers c1's column (col 1) going down.
        --   But (r2,c2)..(r2,c7) have no clue above them in r1 (r1,c2-c7 are letter cells, not clue cells).
        --   So row 2 cells c2-c7 still need horizontal or vertical coverage.
        --   → Row 2 also needs either a right-arrow clue at c1 or c2,
        --     OR all of r2,c2-c7 need vertical clues above them.
        --
        -- For vertical coverage of c2-c7 in r2:
        --   We'd need clue cells at (r1,c2), (r1,c3), etc. pointing down.
        --   But (r1,c2)-(r1,c7) are letter cells of the horizontal word!
        --   Letter cells cannot be clue cells.
        --   CONCLUSION: We CANNOT have vertical words starting at r2 in columns 2-7
        --   if those columns are used by a horizontal word in row 1.
        --
        -- THE FUNDAMENTAL RULE: A cell is either a clue cell OR a letter cell, not both.
        -- Clue cells provide arrows for adjacent letter cells.
        -- Vertical words can start in row 1 ONLY from clue cells in row 1.
        --
        -- REVISED APPROACH FOR ROW 2+ HORIZONTAL COVERAGE:
        -- If (r1,c1) is a clue with arrow "b" (both right AND down):
        --   → Horizontal word: (r1,c2)-(r1,c7) = 6 letters
        --   → Vertical word: (r2,c1)-(r7,c1) = 6 letters (down col 1)
        -- If (r2,c1) is needed as a letter cell (first letter of the vertical word),
        --   then row 2 has (r2,c1)=letter, and (r2,c2)-(r2,c7) need some coverage.
        --   A right-arrow clue at (r2,c1) is impossible (it's a letter cell).
        --   So we need clue cells within row 2 at some position c: (r2,c_k) with arrow 'r',
        --   covering (r2, c_k+1)-(r2, c_7).
        --   But this cell (r2,c_k) is a clue cell interrupting the letter sequence!
        --   So the vertical word in col1 from r2 down would have a clue cell at (r2,c_k)
        --   if k=1, but k>1 since c1 is a letter.
        --   Actually: (r2,c2) could be a clue cell pointing right, covering (r2,c3)-(r2,c7).
        --   Then (r2,c1) is a letter (part of col1 vertical word) and (r2,c2) is a clue.
        --   The vertical word in col2 would start from a clue above col2 — but there's no clue
        --   in row 1 col2 (it's a letter cell). So (r2,c2) being a clue cell means col2's
        --   vertical word would start... there's no way to have a vertical word in col2
        --   because nothing starts it from above (no clue above (r2,c2) in col2).
        --   That's fine! (r2,c2) is just a clue cell, no vertical word in col2.
        --
        -- This works! The puzzle can have mixed coverage:
        -- Some letter cells covered only horizontally, some only vertically, some both.
        --
        -- Let me now COMMIT to a final design:
        --
        -- PUZZLE 1 "Animaux" (7×7) FINAL:
        --
        --      c1        c2        c3    c4    c5       c6    c7
        -- r1: [Cb:1,1]    L         L     L     L        L     L
        -- r2:  L         [Cr:2,2]   L     L     L       [Cd:2,6]  L
        -- r3:  L          L         L     L     L        L     L
        -- r4: [Cr:4,1]    L         L     L    [Cb:4,5]  L     L
        -- r5:  L          L         L     L     L        L     L
        -- r6:  L         [Cb:6,2]   L     L     L        L     L
        -- r7:  L          L         L     L     L        L     L
        --
        -- Coverage analysis:
        -- (1,1)→b: right=RENARD(c2-c7=6 letters)✓, down=BISON(r2-r7 col1=6 letters)
        --   Wait, col1 r2-r7: (2,1)L,(3,1)L,(4,1)=CLUE! Clue at (4,1)!
        --   So vertical word from (1,1)↓ covers r2,r3 only (2 letters) because (4,1) is a clue.
        --   2-letter vertical word — maybe OK but not great. "AS"?
        --
        -- Let me move the clue at (4,1) to (4,2) or make (1,1) only point right.
        -- Use (1,1)→r only: right word = RENARD (c2-c7=6 letters).
        -- Then col1 has no vertical words. (r2,c1)-(r7,c1) need coverage.
        -- These cells need either H or V coverage.
        -- They could be covered by a right-arrow clue at (?,c1) — but we said those are letter cells.
        -- OR we put clue cells in col1 at rows 2-7 too... but then col1 would alternate clue/letter.
        -- Actually: (r2,c1) could be a clue pointing right! That would make col1 contain:
        -- r1=clue, r2=clue, r3=letter?... but then r3,c1 is a letter and it needs coverage:
        -- no clue to its left (c0 doesn't exist) and no clue above (r2,c1 is a clue, not an arrow↓).
        -- Actually if (r2,c1) has arrow "d" (down), it covers (r3,c1),(r4,c1),...
        -- AND if it also has arrow "r", it covers the row.
        --
        -- But we want (r1,c1) to cover col1 going down. The issue is that (r1,c1)→b gives a
        -- vertical word of uncertain length. We need to decide: how far does the vertical word go?
        -- Answer: Until another clue cell or the edge of the grid.
        -- So (r1,c1)→d: vertical word goes from r2 downward until we hit a clue cell or edge.
        -- If there are NO clue cells in col1 below row 1, the word goes r2-r7 = 6 letters.
        -- That's fine! 6-letter vertical word in col1.
        --
        -- So (1,1)→b gives:
        --   Horizontal: 6-letter word at (1,2)-(1,7) [since c2-c7 are all letters]
        --   Vertical:   6-letter word at (2,1)-(7,1)  [since r2-r7,c1 are all letters]
        --
        -- Now for horizontal coverage in rows 2-7:
        -- r2-r7, c2-c7: these cells need horizontal OR vertical coverage.
        -- For vertical coverage: need a down-arrow clue above them in their column.
        -- But (1,2)-(1,7) are letter cells (part of the horizontal word)!
        -- So there's NO clue above (r2,c2)-(r7,c7).
        -- These cells have NO coverage unless we add more clues.
        --
        -- Solution: Add clue cells inside the grid (not in row 1 or col 1) that provide
        -- horizontal and vertical arrows.
        --
        -- Example: Put a clue at (2,2) with arrow "b":
        --   → horizontal: covers (2,3)-(2,7) = 5 letters
        --   → vertical: covers (3,2)-(7,2) = 5 letters
        -- Then (2,2) is a clue, the cells (2,3)-(2,7) are covered horizontally ✓
        -- and (3,2)-(7,2) are covered vertically ✓.
        -- But (2,2) is a clue, not a letter — so col2 vertical word from (1,1)↓ stops at r1 (only covers r2-r7,c1)
        -- wait (1,1)→d covers col1 not col2. Col2: (r2,c2) is a clue, so no vertical coverage of c2 from above.
        -- That's fine — (r2,c2) is a clue cell and doesn't need coverage.
        --
        -- Now row 2: c1=letter(covered by (1,1)↓) ✓, c2=clue, c3-c7=letter(covered by (2,2)→r) ✓
        -- Row 3: c1=letter(covered by (1,1)↓) ✓, c2=letter(covered by (2,2)↓) ✓, c3-c7=???
        --   (3,c3)-(3,c7) are NOT covered (no right clue to their left, no down clue above them)!
        --   Problem.
        --
        -- Solution: Add another clue, e.g., at (3,3):
        -- (3,3)→b: horizontal covers (3,4)-(3,7)=4 letters, vertical covers (4,3)-(7,3)=4 letters
        -- But (3,3) is a clue, and (3,2) is a letter covered by (2,2)↓ ✓. What about (3,c3)?
        --   Wait (3,3) is the clue cell itself — it doesn't need coverage.
        -- Row 3 now: c1=L(cov by 1,1↓)✓, c2=L(cov by 2,2↓)✓, c3=CLUE, c4-c7=L(cov by 3,3→r)✓
        -- Row 4: c1=L(1,1↓)✓, c2=L(2,2↓)✓, c3=L(3,3↓)✓, c4-c7=???
        --   Again uncovered! Need clue at (4,4) or something.
        --
        -- I see the pattern: with a "staircase" of clues at (1,1),(2,2),(3,3),(4,4),(5,5),(6,6):
        -- Each diagonal clue covers the rest of its row (→) and column (↓).
        -- This creates a "staircase" arrowwords puzzle!
        --
        -- Let's verify this design:
        -- Clues: (1,1)b, (2,2)b, (3,3)b, (4,4)b, (5,5)b, (6,6)b
        -- Plus we need row 7 and col 7 coverage.
        -- (7,7) has no clue below or to the right... it's a corner letter cell.
        -- Need coverage: (7,7) is covered by (6,6)↓? No, (6,6)↓ covers (7,6) only.
        -- Actually (6,6)→b: horizontal covers (6,7)=1 letter. Vertical covers (7,6)=1 letter.
        -- Both are 1-letter words — too short.
        --
        -- Better: Use (5,5)b: horiz=(5,6),(5,7)=2 letters, vert=(6,5),(7,5)=2 letters.
        -- Still 2-letter words — acceptable but weak.
        --
        -- And what about (7,1)-(7,4) and (1,7)-(4,7)?
        -- (7,1)=L covered by (1,1)↓ ✓ (col1 goes r2-r7 = 6 letters, so r7 is covered)
        -- (1,7)=L covered by (1,1)→r ✓ (row1 goes c2-c7 = 6 letters, so c7 is covered)
        -- But (7,2)? Covered by (2,2)↓ (col2 goes r3-r7=5 letters) ✓
        -- (7,3)? Covered by (3,3)↓ (col3 goes r4-r7=4 letters) ✓
        -- (7,4)? Covered by (4,4)↓ (col4 goes r5-r7=3 letters) ✓
        -- (7,5)? Covered by (5,5)↓ ✓
        -- (7,6)? Covered by (6,6)↓ ✓
        -- (7,7)? NOT covered! (6,6)→b covers (6,7) and (7,6), not (7,7).
        --
        -- Fix for (7,7): Add a clue at (7,6)→r covering just (7,7)=1 letter. Bad.
        -- Or: (6,6)→d covers r7,c6 only. For (7,7), need either:
        --   - Clue at (7,6)→r covering (7,7) — 1-letter word
        --   - Clue at (6,7)→d covering (7,7) — 1-letter word
        --   - Change (5,5) to cover (5,5)-(5,7) = right covers c6,c7, and clue at some position
        -- OR: just have (6,6) NOT be a clue, instead put (5,5)→b:
        --   horiz: (5,6),(5,7)=2 letters "AS" = year
        --   vert: (6,5),(7,5)=2 letters "OS" = bone
        --   And add clue at (6,6)→r: (6,7)=1 letter "S"? — still bad.
        --
        -- SOLUTION: Change the grid dimensions of what we think of as the staircase:
        -- Use clues at: (1,1), (2,2), (3,3), (4,4), (5,5)
        -- Words:
        -- (1,1)→b: row1 c2-c7=6L, col1 r2-r7=6L
        -- (2,2)→b: row2 c3-c7=5L, col2 r3-r7=5L
        -- (3,3)→b: row3 c4-c7=4L, col3 r4-r7=4L
        -- (4,4)→b: row4 c5-c7=3L, col4 r5-r7=3L
        -- (5,5)→b: row5 c6-c7=2L, col5 r6-r7=2L
        -- And what about row6, row7, col6, col7?
        -- (r6,c6),(r6,c7),(r7,c6),(r7,c7),(r7,??) uncovered!
        -- After (5,5)→b: covers row5,c6-c7 and col5,r6-r7.
        -- (r6,c1)=covered by (1,1)↓ ✓
        -- (r6,c2)=covered by (2,2)↓ ✓
        -- (r6,c3)=covered by (3,3)↓ ✓
        -- (r6,c4)=covered by (4,4)↓ ✓
        -- (r6,c5)=covered by (5,5)↓ ✓
        -- (r6,c6)=NOT covered (no clue above, no clue to left)
        -- (r6,c7)=NOT covered
        -- Same for r7,c6 and r7,c7.
        -- The bottom-right 2×2 corner is uncovered.
        --
        -- FIX: Add a clue at (6,6)→b: covers row6,c7=1L and col6,r7=1L. Bad.
        -- Or: The bottom-right 2×2 needs a clue at (6,5) or (5,6):
        --   If (5,5) stays as it is and we add clue at (6,5):
        --     But (6,5)=letter covered by (5,5)↓ already! Can't be a clue.
        --   If we change (5,5)→b to (5,5)→r only:
        --     (5,5)→r: row5,c6-c7=2L covered ✓
        --     col5: r6,r7 NOT covered (need a clue above them in col5 or horizontal coverage)
        --     (r6,c5) and (r7,c5) not covered. Still a problem (now for col5 instead of just corner).
        --
        -- I think the staircase pattern naturally leaves the bottom-right corner uncovered.
        -- SOLUTION: Don't go all the way to (5,5). Stop at (4,4) and handle the rest differently.
        --
        -- Alternative: Add clue at (5,5)→b AND (6,6)→b (even though 1-letter words).
        -- 1-letter words are unusual but technically valid (e.g., French words: "A" = has, "Y" = there, "O" = oh).
        -- Let's use this for simplicity.
        --
        -- OR: Use a DIFFERENT pattern entirely. Let me try:
        -- Clues at (1,1), (1,4), (4,1), (4,4) — a 2×2 arrangement of clues in the 7×7 grid.
        -- Each clue→b starts a horizontal word and a vertical word.
        --
        -- (1,1)→b: row1 c2-c4=3L (ANE? OIE?), col1 r2-r4=3L
        -- Wait (1,4) is a clue, so row1's horizontal word from (1,1)→r goes to c2,c3 only (2 letters before clue at c4).
        -- 2-letter word is bad.
        --
        -- (1,1)→b: (1,2),(1,3)=2L, (2,1),(3,1)=2L. Both 2 letters — bad.
        --
        -- The spacing is too tight. I need clues more spread out.
        --
        -- ACCEPT THE STAIRCASE: Just go with (1,1),(2,2),(3,3),(4,4) and handle bottom-right manually.
        --
        -- Bottom-right region (r5-r7, c5-c7) after staircase at (1,1)..(4,4):
        -- Coverage:
        -- (r5,c1)=cov by (1,1)↓ ✓
        -- (r5,c2)=cov by (2,2)↓ ✓
        -- (r5,c3)=cov by (3,3)↓ ✓
        -- (r5,c4)=cov by (4,4)↓ ✓
        -- (r5,c5)..(r5,c7): NOT covered
        -- (r6,c1)...(r6,c4): covered by column clues ✓
        -- (r6,c5)..(r6,c7): NOT covered
        -- (r7,c1)...(r7,c4): covered by column clues ✓
        -- (r7,c5)..(r7,c7): NOT covered
        --
        -- The uncovered region is a 3×3 in the bottom-right.
        -- Add clue at (5,5)→b: covers row5 c6-c7 (2L), col5 r6-r7 (2L). Still leaves (6,6),(6,7),(7,6),(7,7).
        -- Add clue at (6,6)→b: covers row6 c7 (1L), col6 r7 (1L). 1-letter words.
        -- OR: Instead of (6,6)→b, add clue at (5,6)→d covering r6,r7,c6 (2L) and nothing right.
        --     But (5,6) is a letter cell of (5,5)→r word. Can't be both.
        --
        -- I'll just accept the (5,5)→b and (6,6)→b approach with:
        -- (5,5)→b: word "AS"→right (2L), word "AN"→down (2L) — French words!
        --   AS = plural of A (or the word "ace")... hmm in French "as" = ace/singular of avoir?
        --   Actually "as" = vous avez (you have, informal)... not common.
        --   Better: use "OR" (gold) for 2 letters. French: "or" = gold ✓
        --   And "OS" (bone): os = bone ✓
        -- (6,6)→b: 1-letter words "S" and "E"? These are just letters.
        --   Actually "A" = à (preposition) is a word. But let's not use 1-letter words.
        --
        -- ALTERNATIVE BOTTOM-RIGHT:
        -- Instead of (5,5) and (6,6), use:
        -- Clue at (4,5)→b: row4 c6-c7=2L, col5 r5-r7=3L ← 3-letter vertical word!
        --   But (4,4) is already a clue... (4,5) would be a letter of (4,4)→r word.
        --   So (4,5) can't be a clue.
        --
        -- Clue at (5,4)→b: row5 c5-c7=3L, col4 r6-r7... wait (4,4) is a clue, so (4,4)→d covers r5-r7,c4.
        --   (5,4) would be a letter covered by (4,4)↓. Can't be a clue.
        --
        -- Clue at (5,5)→r ONLY (not both):
        --   row5 c6-c7=2L covered ✓
        --   col5: r6,r7 NOT covered (need something else)
        -- Add separate clue at (5,5)→d? No, a cell can only have one clue definition.
        --   Actually we CAN have a=b (both)! That's the "b" option.
        --
        -- I'm going in circles. Let me just commit to this design and accept 1-2 short words:
        --
        -- STAIRCASE DESIGN:
        -- Clues: (1,1)b, (2,2)b, (3,3)b, (4,4)b, (5,5)b, (6,6)b, (6,7)d, (7,6)r
        -- Wait (7,6)→r would be a clue covering (7,7)=1 letter. Still 1-letter.
        --
        -- COMPLETELY DIFFERENT APPROACH:
        -- Make it a non-staircase design. Place clue cells at different positions.
        --
        -- Let me try this layout (inspired by typical French mots fléchés):
        --
        --      c1         c2    c3    c4    c5    c6    c7
        -- r1: [Cr "Chat"]  L     L     L     L  [Cd "Loup"] L
        -- r2: [Cr "Ours"]  L     L     L     L     L    L
        -- r3:  L            L     L  [Cb "Aigle/Cerf"] L  L    L
        -- r4:  L            L     L    L     L     L    L
        -- r5: [Cr "Lion"]   L     L    L  [Cb "Tigre/Cerf"] L  L
        -- r6:  L            L     L    L     L     L    L
        -- r7: [Cr "Lapin"]  L     L    L     L     L    L
        --
        -- Coverage check:
        -- r1: (1,1)→r: CHAT at c2-c5=4L ✓; (1,6) is Cd (not Cr!), so c6 is a clue;
        --      c7 in r1: covered by... (1,6)→r? No, (1,6) is Cd only. NOT COVERED!
        --
        -- AGGGHH. Let me try again with arrow "b" at (1,6):
        -- (1,6)→b: right=c7(1 letter)="S"? Bad; down=col6 r2-r7=6 letters "LOUP..." wait LOUP is 4 letters.
        --
        -- OK I think the problem is I keep trying to have clues that are NOT at the beginning of rows.
        --
        -- SIMPLEST VALID DESIGN: One clue per row at c1, one clue per column at r1.
        -- ALL clues have both arrows (b).
        -- BUT: c1 and r1 would overlap at (1,1). Other cells can't be both clues.
        -- This doesn't work for all positions.
        --
        -- What about: Clues at c1 (all 7 rows) for horizontal words,
        --              AND clues at r1 (all 7 cols) for vertical words.
        --              But (1,1) can only be one cell...
        --              Let row 1 have NO horizontal word (all covered by vertical).
        --              Let col 1 have NO vertical word (all covered by horizontal).
        --              Then:
        -- r1: L L L L L L L (all letter cells, covered by col clues above? NO — row 1 has nothing above!)
        --
        -- I think the KEY INSIGHT I keep missing is:
        -- In REAL mots fléchés, row 1 and col 1 ALWAYS have clue cells providing the first words.
        -- The top-left corner is typically a clue cell.
        -- And in row 1: any cell that's a letter needs a right-arrow clue to its left.
        -- But in row 1, if all cells c2-c7 are letters of the same horizontal word (from clue at c1),
        -- then those cells can NOT start any vertical words (they're letter cells, not clue cells).
        -- So vertical words in columns 2-7 must start at row 2, meaning we need clue cells at (2,c) for c=2..7.
        -- That means row 2 is ALL CLUE CELLS except maybe c1!
        --
        -- This creates a "border" design:
        -- r1: C(r) L  L  L  L  L  L   ← one horizontal word
        -- r2: L    C(d) C(d) C(d) C(d) C(d) C(d)  ← 6 clue cells providing vertical words
        -- But r2,c1 is a letter (no right arrow in row 2 to cover c1 beyond clue positions).
        -- And (r2,c2)-(r2,c7) are all clues — but clue cells don't need coverage!
        -- r3-r7, c2-c7: covered by vertical clues in r2 ✓
        -- r3-r7, c1: covered by... (r1,c1)→d if we make it Cb instead of Cr. But then (r2,c1) is a letter covered by (r1,c1)↓.
        -- Wait, (r2,c2)-(r2,c7) are clue cells and (r2,c1) is a letter cell.
        -- r2,c1 is covered by (r1,c1)→d (if (r1,c1)=Cb).
        -- But then the vertical word from (r1,c1) would be just (r2,c1)=1 letter!
        -- Because (r3,c1) needs coverage too — but (r2,c1) is a letter (not a clue), so the col1 word
        -- continues: r2,c1 then r3,c1... (r3,c1) is covered by (r1,c1)↓ (continuing down).
        -- The vertical word in col1 goes r2-r7 = 6 letters. BUT (r2,c1) through (r7,c1) must all be
        -- letter cells (no clue interrupting them) for this to work.
        -- In our design, r2,c1 is indeed a letter ✓ (only r2,c2-c7 are clues).
        -- So col1 vertical word: (r2,c1)-(r7,c1) = 6 letters ✓
        --
        -- But now r3-r7, c1: these are all letter cells covered by (r1,c1)↓ ✓
        -- r3-r7, c2-c7: covered by clues at (r2,c2)-(r2,c7)↓ ✓
        -- r2, c1: covered by (r1,c1)↓ ✓
        -- r2, c2-c7: these ARE clue cells, so they don't need coverage ✓
        -- r1, c2-c7: covered by (r1,c1)→r ✓
        --
        -- THIS WORKS! But it gives us:
        -- Row 1: 1 horizontal word (6 letters)
        -- Col 1: 1 vertical word (6 letters)
        -- Cols 2-7: 6 vertical words (5 letters each r3-r7)
        -- BUT: All the clues in row 2 (c2-c7) need CLUE TEXTS for their vertical words.
        --      That means we have 6+1+1 = 8 words total... but what are the clue texts for (r2,c2)-(r2,c7)?
        --      The vertical words in cols 2-7 start at r3 (because r2 is the clue row) and go to r7 = 5 letters.
        --
        -- And: There are NO horizontal words in rows 3-7 (except col1 which is covered vertically).
        -- Rows 3-7 have NO horizontal words — all cells covered only by vertical clues.
        -- This is a valid "mots fléchés" design!
        --
        -- Words:
        -- (r1,c1)→b: horizontal RENARD(c2-c7=6L), vertical col1 r2-r7=6L
        --   What 6-letter word for col1? CANARD? Both RENARD and CANARD have "ARD" in common!
        --   Let me pick different words: horiz=MOUTON(6L), col1-vert=CASTOR(6L)?
        --   Wait, col1 vertical starts at r2. So the word is at (r2,c1)-(r7,c1) = the letters M,A,S,T,O,R?
        --   These need to be whatever words we assign.
        --
        -- (r2,c2)→d: vertical col2 r3-r7=5L
        -- (r2,c3)→d: vertical col3 r3-r7=5L
        -- ... etc for c4,c5,c6,c7
        --
        -- We need: 1 row-1 horiz word (6L), 1 col-1 vert word (6L), 6 vert words (5L each).
        -- Total word count = 8.
        --
        -- Let me pick French words:
        -- Row 1 horiz: RENARD (fox)
        -- Col 1 vert: CASTOR? First letter must match (r2,c1) = the 1st letter of both?
        --   No! (r2,c1) is the 1st letter of the col1 word AND also must be consistent with row2 coverage.
        --   Row 2 has no horizontal words. (r2,c1) is just a letter cell.
        --   The col1 word letters are at r2-r7, c1. These are independent of horizontal words.
        --   The col2 word letters are at r3-r7, c2. These are covered only vertically.
        --   etc.
        --
        -- There's no constraint that letters must intersect correctly!
        -- In arrowwords, each cell belongs to AT MOST ONE word (either horizontal or vertical or none/both if at intersection).
        -- Wait — in arrowwords (mots fléchés), cells are either clue cells or letter cells.
        -- A letter cell can be part of BOTH a horizontal word AND a vertical word (intersection),
        -- just like in traditional crosswords.
        --
        -- In our "border" design:
        -- (r3,c2) is part of the col2 vertical word AND potentially a horizontal word in r3.
        -- But we said rows 3-7 have no horizontal clues — so (r3,c2) is ONLY vertical.
        -- Since there's no horizontal word in row 3, cells (r3,c2)-(r3,c7) don't intersect horizontally.
        -- Each column (c2-c7) has an independent 5-letter word.
        --
        -- THIS IS FINE! The design works. Let me verify the crossings:
        -- The col1 word (r2-r7,c1) and col2 word (r3-r7,c2) don't share cells. Good.
        -- Row 1 word (r1,c2-c7) doesn't share cells with any col word (they're in r1, col words start at r2+). Good.
        --
        -- Actually wait: row 1, c2-c7 are the horizontal word letters.
        -- Col 2-7 words start at r3 (clue is at r2, letters from r3).
        -- What about r2, c2-c7? These are CLUE CELLS — they don't have letter values.
        -- So the col1 word occupies r2-r7 (col1 only) and doesn't conflict.
        -- Great!
        --
        -- FINAL PUZZLE DESIGNS:
        --
        -- Puzzle 1 "Animaux":
        -- (1,1)→b: horiz=RENARD(r1,c2-c7), vert=CASTOR(c1,r2-r7)
        -- (2,2)→d: vert col2=LAPIN(r3-r7)  — 5-letter word
        -- (2,3)→d: vert col3=TIGRE(r3-r7)  — 5-letter word
        -- (2,4)→d: vert col4=AIGLE(r3-r7)  — 5-letter word
        -- (2,5)→d: vert col5=VACHE(r3-r7)  — 5-letter word
        -- (2,6)→d: vert col6=HYENE? (5) = HYÈNE → H,Y,È,N,E — or BISON(5)?
        -- (2,7)→d: vert col7=RATON? (5) — or LOUTRE?... wait 6 letters.
        --   5-letter animal words: AIGLE(5), LAPIN(5), TIGRE(5), VACHE(5), BISON(5), CIGALE(6-no),
        --   HIBOU(5), POULE(5), HEROU? HERON(5), LEZARD(6-no), PANDA(5)
        --   → HIBOU, HERON, PANDA, BISON
        -- And col1: CASTOR(6) — C,A,S,T,O,R
        -- So (r1,c1)→b:
        --   Row1 horizontal: RENARD = R,E,N,A,R,D (at r1,c2-c7)
        --   Col1 vertical: CASTOR = C,A,S,T,O,R (at r2-r7,c1)
        -- (r2,c2)→d: col2 word LAPIN = L,A,P,I,N (at r3-r7,c2)
        -- (r2,c3)→d: col3 word TIGRE = T,I,G,R,E (at r3-r7,c3)
        -- (r2,c4)→d: col4 word AIGLE = A,I,G,L,E (at r3-r7,c4)
        -- (r2,c5)→d: col5 word VACHE = V,A,C,H,E (at r3-r7,c5)
        -- (r2,c6)→d: col6 word HIBOU = H,I,B,O,U (at r3-r7,c6)
        -- (r2,c7)→d: col7 word HERON = H,E,R,O,N (at r3-r7,c7)
        --
        -- Solution grid:
        --     c1   c2   c3   c4   c5   c6   c7
        -- r1: ""   R    E    N    A    R    D
        -- r2: C    ""   ""   ""   ""   ""   ""
        -- r3: A    L    T    A    V    H    H
        -- r4: S    A    I    I    A    I    E
        -- r5: T    P    G    G    C    B    R
        -- r6: O    I    R    L    H    O    O
        -- r7: R    N    E    E    E    U    N
        --
        -- Clue texts (what the player needs to figure out):
        -- (1,1)→b: horizontal="Animal roux à queue touffue" (RENARD=fox), vertical="Rongeur bâtisseur" (CASTOR=beaver)
        -- Actually in arrowwords format, the clue DESCRIBES the word. Let me use simpler clues.
        --
        -- And we need clue cells at (r2,c2)-(r2,c7) for the vertical words.
        -- The clue texts for those vertical words:
        -- (2,2)→d: "Petit mammifère aux longues oreilles" (LAPIN=rabbit) — too long for cell!
        -- In real mots fléchés, clues are SHORT (fit in a cell).
        -- Better: single-word hints like "Rongeur" or "Lagomorphe" — still long.
        -- For the display, we truncate to fit. Short clues are best.
        -- Let me use very short clues (1-3 words):
        --
        -- (1,1)→b: tx="Renard/Castor" (describes both words?)
        --   Actually in real mots fléchés, a cell with two arrows has TWO clue texts,
        --   one for each direction. Let me store them as tx_r and tx_d.
        --   But the spec says: tx="text" and a="r"|"d"|"b".
        --   For "b" cells, we need two clue texts. I'll use tx as a string with
        --   "\n" separator: tx="right clue\ndown clue"
        --
        -- Short French clues:
        -- RENARD: "Animal roux" / "Goupil"
        -- CASTOR: "Rongeur du Canada" / "Bâtisseur de barrages"
        -- LAPIN: "Oreilles longues"
        -- TIGRE: "Fauve rayé"
        -- AIGLE: "Rapace majestueux"
        -- VACHE: "Donne du lait"
        -- HIBOU: "Oiseau nocturne"
        -- HERON: "Echassier gris"
        --
        -- Let me shorten these further for cell display:
        -- RENARD: "Goupil"
        -- CASTOR: "Barrages"
        -- LAPIN: "Lapins"... hmm. "Terrier" (burrow)
        -- TIGRE: "Félin rayé"
        -- AIGLE: "Rapace"
        -- VACHE: "Meuh!"
        -- HIBOU: "Nocturne"
        -- HERON: "Echassier"
        --
        -- OK enough analysis. Let me write the actual code now.

        grid = {
            -- r1
            { c("Goupil\nRongeur", "b"), l(), l(), l(), l(), l(), l() },
            -- r2
            { l(), c("Terrier", "d"), c("Félin rayé", "d"), c("Rapace", "d"), c("Meuh", "d"), c("Nocturne", "d"), c("Echassier", "d") },
            -- r3
            { l(), l(), l(), l(), l(), l(), l() },
            -- r4
            { l(), l(), l(), l(), l(), l(), l() },
            -- r5
            { l(), l(), l(), l(), l(), l(), l() },
            -- r6
            { l(), l(), l(), l(), l(), l(), l() },
            -- r7
            { l(), l(), l(), l(), l(), l(), l() },
        },
        solution = {
            -- r1: clue at c1, RENARD at c2-c7
            { "",  "R", "E", "N", "A", "R", "D" },
            -- r2: CASTOR[1]=C at c1, clue cells c2-c7
            { "C", "",  "",  "",  "",  "",  ""  },
            -- r3: CASTOR[2]=A at c1; LAPIN[1]=L, TIGRE[1]=T, AIGLE[1]=A, VACHE[1]=V, HIBOU[1]=H, HERON[1]=H
            { "A", "L", "T", "A", "V", "H", "H" },
            -- r4: CASTOR[3]=S; LAPIN[2]=A, TIGRE[2]=I, AIGLE[2]=I, VACHE[2]=A, HIBOU[2]=I, HERON[2]=E
            { "S", "A", "I", "I", "A", "I", "E" },
            -- r5: CASTOR[4]=T; LAPIN[3]=P, TIGRE[3]=G, AIGLE[3]=G, VACHE[3]=C, HIBOU[3]=B, HERON[3]=R
            { "T", "P", "G", "G", "C", "B", "R" },
            -- r6: CASTOR[5]=O; LAPIN[4]=I, TIGRE[4]=R, AIGLE[4]=L, VACHE[4]=H, HIBOU[4]=O, HERON[4]=O
            { "O", "I", "R", "L", "H", "O", "O" },
            -- r7: CASTOR[6]=R; LAPIN[5]=N, TIGRE[5]=E, AIGLE[5]=E, VACHE[5]=E, HIBOU[5]=U, HERON[5]=N
            { "R", "N", "E", "E", "E", "U", "N" },
        },
    },

    -- -----------------------------------------------------------------------
    -- Puzzle 2: Cuisine (Kitchen/Food)
    -- -----------------------------------------------------------------------
    -- Same border design:
    -- (1,1)→b: horiz=TOMATE(r1,c2-c7=6L), vert=BEURRE(c1,r2-r7=6L)
    -- (2,2)→d: col2 ABRICOT? no 7 letters. 5-letter: SAPIN? no.
    --   Food 5-letter words: SUCRE(5), CARPE(5), MELON(5), OLIVE(5), PRUNE(5), CITRO? CITRON=6.
    --   MELON(5)=melon, OLIVE(5)=olive, PRUNE(5)=plum, SAUGE(5)=sage, THYM?(4), CREPE(5)=crepe
    -- (2,2)→d: col2 = MELON = M,E,L,O,N
    -- (2,3)→d: col3 = OLIVE = O,L,I,V,E
    -- (2,4)→d: col4 = PRUNE = P,R,U,N,E
    -- (2,5)→d: col5 = SAUGE = S,A,U,G,E
    -- (2,6)→d: col6 = CREPE = C,R,E,P,E
    -- (2,7)→d: col7 = POIVRE? 6 letters. SIROP(5)=syrup, CANAP? hmm.
    --   SIROP=S,I,R,O,P (5) ✓
    --
    -- (1,1)→b: horiz=TOMATE, vert=BEURRE
    -- Solution:
    -- r1: ""  T  O  M  A  T  E
    -- r2:  B  ""  ""  ""  ""  ""  ""
    -- r3:  E  M  O  P  S  C  S
    -- r4:  U  E  L  R  A  R  I
    -- r5:  R  L  I  U  U  E  R
    -- r6:  R  O  V  N  G  P  O
    -- r7:  E  N  E  E  E  E  P
    --
    -- Clues:
    -- (1,1)→b: "Fruit rouge\nMatière grasse" (TOMATE=tomato, BEURRE=butter)
    -- (2,2)→d: "Fruit d'été" (MELON=melon)
    -- (2,3)→d: "Petit fruit vert" (OLIVE)
    -- (2,4)→d: "Fruit violet" (PRUNE=plum)
    -- (2,5)→d: "Herbe aromatique" (SAUGE=sage)
    -- (2,6)→d: "Galette fine" (CREPE)
    -- (2,7)→d: "Liquide sucré" (SIROP=syrup)

    {
        title = "Cuisine",
        n = 7,
        grid = {
            { c("Fruit rouge\nMatière grasse", "b"), l(), l(), l(), l(), l(), l() },
            { l(), c("Fruit d'été", "d"), c("Petite olive", "d"), c("Fruit violet", "d"), c("Aromate", "d"), c("Galette fine", "d"), c("Liquide sucré", "d") },
            { l(), l(), l(), l(), l(), l(), l() },
            { l(), l(), l(), l(), l(), l(), l() },
            { l(), l(), l(), l(), l(), l(), l() },
            { l(), l(), l(), l(), l(), l(), l() },
            { l(), l(), l(), l(), l(), l(), l() },
        },
        solution = {
            { "",  "T", "O", "M", "A", "T", "E" },
            { "B", "",  "",  "",  "",  "",  ""  },
            { "E", "M", "O", "P", "S", "C", "S" },
            { "U", "E", "L", "R", "A", "R", "I" },
            { "R", "L", "I", "U", "U", "E", "R" },
            { "R", "O", "V", "N", "G", "P", "O" },
            { "E", "N", "E", "E", "E", "E", "P" },
        },
    },

    -- -----------------------------------------------------------------------
    -- Puzzle 3: Nature (Nature)
    -- -----------------------------------------------------------------------
    -- (1,1)→b: horiz=NUAGES(r1,c2-c7=6L), vert=DESERT(c1,r2-r7=6L)
    -- (2,2)→d: col2 = PLAINE = P,L,A,I,N,E? 6 letters, but col2 word goes r3-r7 = 5 letters only!
    --   Need 5-letter nature words: ALPES(5), OCEAN(5), FORET(5)? FORÊT=5 ✓, ETANG(5)=pond,
    --   SABLE(5)=sand, NEIGE(5)=snow, FALAISE?6, GROTTE?6, ARBRE(5)=tree, TERRE(5)=earth
    -- (2,2)→d: col2 = ARBRE = A,R,B,R,E
    -- (2,3)→d: col3 = OCEAN = O,C,E,A,N
    -- (2,4)→d: col4 = ETANG = E,T,A,N,G
    -- (2,5)→d: col5 = SABLE = S,A,B,L,E
    -- (2,6)→d: col6 = NEIGE = N,E,I,G,E
    -- (2,7)→d: col7 = TERRE = T,E,R,R,E
    --
    -- Solution:
    -- r1: ""  N  U  A  G  E  S
    -- r2:  D  ""  ""  ""  ""  ""  ""
    -- r3:  E  A  O  E  S  N  T
    -- r4:  S  R  C  T  A  E  E
    -- r5:  E  B  E  A  B  I  R
    -- r6:  R  R  A  N  L  G  R
    -- r7:  T  E  N  G  E  E  E
    --
    -- Clue texts:
    -- (1,1)→b: "Météo du ciel\nAride" (NUAGES=clouds, DESERT=desert)
    -- (2,2)→d: "Végétal ligneux" (ARBRE=tree)
    -- (2,3)→d: "Grande mer" (OCEAN=ocean)
    -- (2,4)→d: "Eau douce stagnante" → short: "Mare" (ETANG=pond)
    -- (2,5)→d: "Sur la plage" (SABLE=sand)
    -- (2,6)→d: "Flocons blancs" (NEIGE=snow)
    -- (2,7)→d: "Notre planète" (TERRE=earth)

    {
        title = "Nature",
        n = 7,
        grid = {
            { c("Ciel nuageux\nAridité", "b"), l(), l(), l(), l(), l(), l() },
            { l(), c("Végétal ligneux", "d"), c("Grande mer", "d"), c("Plan d'eau", "d"), c("Sur la plage", "d"), c("Flocons", "d"), c("Notre planète", "d") },
            { l(), l(), l(), l(), l(), l(), l() },
            { l(), l(), l(), l(), l(), l(), l() },
            { l(), l(), l(), l(), l(), l(), l() },
            { l(), l(), l(), l(), l(), l(), l() },
            { l(), l(), l(), l(), l(), l(), l() },
        },
        solution = {
            { "",  "N", "U", "A", "G", "E", "S" },
            { "D", "",  "",  "",  "",  "",  ""  },
            { "E", "A", "O", "E", "S", "N", "T" },
            { "S", "R", "C", "T", "A", "E", "E" },
            { "E", "B", "E", "A", "B", "I", "R" },
            { "R", "R", "A", "N", "L", "G", "R" },
            { "T", "E", "N", "G", "E", "E", "E" },
        },
    },
}

-- ---------------------------------------------------------------------------
-- ArrowwordsBoard
-- ---------------------------------------------------------------------------

local ArrowwordsBoard = {}
ArrowwordsBoard.__index = ArrowwordsBoard

function ArrowwordsBoard:new(opts)
    opts = opts or {}
    local obj = setmetatable({
        puzzle_index = opts.puzzle_index or 1,
        n            = 7,
        grid         = nil,   -- puzzle cell definitions {t, tx, a}
        solution     = nil,   -- solution letters (string or "")
        user         = nil,   -- user-entered letters
        sel_r        = nil,
        sel_c        = nil,
        won          = false,
    }, self)
    obj:_loadPuzzle(obj.puzzle_index)
    return obj
end

function ArrowwordsBoard:_loadPuzzle(idx)
    idx = ((idx - 1) % #PUZZLES) + 1
    self.puzzle_index = idx
    local p = PUZZLES[idx]
    self.n   = p.n or 7
    self.grid = p.grid
    self.solution = p.solution
    self.title = p.title or ""

    -- Init user grid
    local n = self.n
    self.user = {}
    for r = 1, n do
        self.user[r] = {}
        for c = 1, n do
            self.user[r][c] = ""
        end
    end

    self.sel_r = nil
    self.sel_c = nil
    self.won   = false

    -- Move selection to first letter cell
    for r = 1, n do
        for cc = 1, n do
            if self.grid[r][cc].t == "l" then
                self.sel_r = r
                self.sel_c = cc
                return
            end
        end
    end
end

function ArrowwordsBoard:getCell(r, c)
    return self.grid[r][c]
end

function ArrowwordsBoard:selectCell(r, c)
    if r < 1 or r > self.n or c < 1 or c > self.n then return end
    if self.grid[r][c].t ~= "l" then return end
    self.sel_r = r
    self.sel_c = c
end

-- Find the word containing (sel_r, sel_c) in a given direction ("r"=right, "d"=down)
-- Returns: direction arrow, start_r, start_c, end_r, end_c or nil
function ArrowwordsBoard:_findWord(r, c)
    local n = self.n
    -- Check if covered horizontally: walk left to find a clue with arrow r or b
    local cr = c - 1
    while cr >= 1 and self.grid[r][cr].t == "l" do
        cr = cr - 1
    end
    local h_dir = nil
    if cr >= 1 and self.grid[r][cr].t == "c" then
        local a = self.grid[r][cr].a
        if a == "r" or a == "b" then
            h_dir = { clue_r = r, clue_c = cr }
        end
    end

    -- Check if covered vertically: walk up to find a clue with arrow d or b
    local ur = r - 1
    while ur >= 1 and self.grid[ur][c].t == "l" do
        ur = ur - 1
    end
    local v_dir = nil
    if ur >= 1 and self.grid[ur][c].t == "c" then
        local a = self.grid[ur][c].a
        if a == "d" or a == "b" then
            v_dir = { clue_r = ur, clue_c = c }
        end
    end

    return h_dir, v_dir
end

-- Advance selection in the direction the current cell belongs to.
-- Prefer horizontal if available, else vertical.
function ArrowwordsBoard:_advanceSelection()
    if not self.sel_r then return end
    local r, c = self.sel_r, self.sel_c
    local n = self.n
    local h_dir, v_dir = self:_findWord(r, c)
    if h_dir then
        -- Advance right in the same row
        local nc = c + 1
        while nc <= n do
            if self.grid[r][nc].t == "l" then
                self.sel_c = nc; return
            elseif self.grid[r][nc].t == "c" then
                break
            end
            nc = nc + 1
        end
    elseif v_dir then
        -- Advance down in the same column
        local nr = r + 1
        while nr <= n do
            if self.grid[nr][c].t == "l" then
                self.sel_r = nr; return
            elseif self.grid[nr][c].t == "c" then
                break
            end
            nr = nr + 1
        end
    end
end

function ArrowwordsBoard:typeLetter(letter)
    if self.won then return end
    if not self.sel_r then return end
    local r, c = self.sel_r, self.sel_c
    if self.grid[r][c].t ~= "l" then return end
    self.user[r][c] = letter:upper()
    self:_advanceSelection()
    self:_checkWin()
end

function ArrowwordsBoard:deleteLetter()
    if not self.sel_r then return end
    local r, c = self.sel_r, self.sel_c
    if self.user[r][c] ~= "" then
        self.user[r][c] = ""
    else
        -- Retreat
        local n = self.n
        local h_dir, v_dir = self:_findWord(r, c)
        if h_dir then
            local nc = c - 1
            while nc >= 1 do
                if self.grid[r][nc].t == "l" then
                    self.sel_c = nc
                    self.user[r][nc] = ""
                    return
                elseif self.grid[r][nc].t == "c" then
                    break
                end
                nc = nc - 1
            end
        elseif v_dir then
            local nr = r - 1
            while nr >= 1 do
                if self.grid[nr][c].t == "l" then
                    self.sel_r = nr
                    self.user[nr][c] = ""
                    return
                elseif self.grid[nr][c].t == "c" then
                    break
                end
                nr = nr - 1
            end
        end
    end
    self.won = false
end

function ArrowwordsBoard:clearAll()
    for r = 1, self.n do
        for cc = 1, self.n do
            self.user[r][cc] = ""
        end
    end
    self.won = false
end

function ArrowwordsBoard:reveal()
    for r = 1, self.n do
        for cc = 1, self.n do
            if self.grid[r][cc].t == "l" then
                self.user[r][cc] = self.solution[r][cc] or ""
            end
        end
    end
    self.won = true
end

function ArrowwordsBoard:_checkWin()
    for r = 1, self.n do
        for cc = 1, self.n do
            if self.grid[r][cc].t == "l" then
                local sol = self.solution[r][cc]
                if self.user[r][cc] ~= sol then
                    self.won = false; return
                end
            end
        end
    end
    self.won = true
end

function ArrowwordsBoard:countFilled()
    local filled, total = 0, 0
    for r = 1, self.n do
        for cc = 1, self.n do
            if self.grid[r][cc].t == "l" then
                total = total + 1
                if self.user[r][cc] ~= "" then filled = filled + 1 end
            end
        end
    end
    return filled, total
end

function ArrowwordsBoard:nextPuzzle()
    self:_loadPuzzle(self.puzzle_index + 1)
end

function ArrowwordsBoard:prevPuzzle()
    self:_loadPuzzle(self.puzzle_index - 1)
end

-- ---------------------------------------------------------------------------
-- Persistence
-- ---------------------------------------------------------------------------

function ArrowwordsBoard:serialize()
    local flat = {}
    for r = 1, self.n do
        for cc = 1, self.n do
            flat[#flat + 1] = self.user[r][cc]
        end
    end
    return {
        puzzle_index = self.puzzle_index,
        user         = flat,
        sel_r        = self.sel_r,
        sel_c        = self.sel_c,
        won          = self.won,
    }
end

function ArrowwordsBoard:load(data)
    if type(data) ~= "table" or not data.user then return false end
    self:_loadPuzzle(data.puzzle_index or 1)
    local idx = 1
    for r = 1, self.n do
        for cc = 1, self.n do
            self.user[r][cc] = data.user[idx] or ""
            idx = idx + 1
        end
    end
    self.sel_r = data.sel_r or self.sel_r
    self.sel_c = data.sel_c or self.sel_c
    self.won   = data.won or false
    return true
end

ArrowwordsBoard.NUM_PUZZLES = #PUZZLES

return ArrowwordsBoard
