-- ---------------------------------------------------------------------------
-- lessons_mat3.lua — 5 puzzles "Mat en 3"
-- Puzzles 34-35 : les noirs jouent (auto-flip du plateau via board.turn)
-- Sources : Lichess puzzle 4Ftq1, études j0Ay9fAz et JrwLZArS
-- ---------------------------------------------------------------------------

return {

    -- 31. Roi et tour vs tour — le roi prend le pion pour créer un couloir
    -- Lichess puzzle 4Ftq1 (vérifié)
    -- FEN: 7k/R7/5Kpp/8/4p1p1/7P/4r3/8 w - - 0 1
    -- 1.Kf6×g6 Re2-f2  2.Ra7-a8+ Rf2-f8  3.Ra8×f8#
    {
        id=31, category="mat3",
        title="Tour et roi — couloir",
        desc="Les blancs jouent et font mat en 3 coups.",
        fen="7k/R7/5Kpp/8/4p1p1/7P/4r3/8 w - - 0 1",
        solution={
            {fr=3,fc=6,tr=3,tc=7},  -- Kf6×Pg6
            {fr=7,fc=5,tr=7,tc=6},  -- Re2→Rf2 (forcé)
            {fr=2,fc=1,tr=1,tc=1},  -- Ra7→Ra8+
            {fr=7,fc=6,tr=1,tc=6},  -- Rf2→Rf8 (forcé)
            {fr=1,fc=1,tr=1,tc=6},  -- Ra8×Rf8#
        },
        hint="Le roi prend le pion g6, la tour monte en a8, la tour noire bloque et se fait capturer.",
    },

    -- 32. Sacrifice de fou — ouvre c8 au roi, mat du cavalier
    -- Lichess étude j0Ay9fAz (vérifié)
    -- FEN: k7/pp1K4/N7/8/8/8/8/7B w - - 0 1
    -- 1.Bh1-c6! b7×c6  2.Kd7-c8 c6-c5  3.Na6-c7#
    {
        id=32, category="mat3",
        title="Sacrifice de fou, mat du cavalier",
        desc="Les blancs jouent et font mat en 3 coups.",
        fen="k7/pp1K4/N7/8/8/8/8/7B w - - 0 1",
        solution={
            {fr=8,fc=8,tr=3,tc=3},  -- Bh1→Bc6 (sacrifice)
            {fr=2,fc=2,tr=3,tc=3},  -- pb7×Bc6 (forcé)
            {fr=2,fc=4,tr=1,tc=3},  -- Kd7→Kc8
            {fr=3,fc=3,tr=4,tc=3},  -- pc6→c5 (forcé)
            {fr=3,fc=1,tr=2,tc=3},  -- Na6→Nc7#
        },
        hint="Sacrifiez le fou en c6 pour libérer c8 au roi — le cavalier donne mat depuis c7.",
    },

    -- 33. Deux fous — repositionnement puis mat en coin
    -- Lichess étude JrwLZArS, puzzle 2 (vérifié)
    -- FEN: k7/3B4/1K3B2/8/8/8/8/8 w - - 0 1
    -- 1.Bf6-a1 Ka8-b8  2.Ba1-e5+ Kb8-a8  3.Bd7-c6#
    {
        id=33, category="mat3",
        title="Deux fous — mat en coin",
        desc="Les blancs jouent et font mat en 3 coups.",
        fen="k7/3B4/1K3B2/8/8/8/8/8 w - - 0 1",
        solution={
            {fr=3,fc=6,tr=8,tc=1},  -- Bf6→Ba1
            {fr=1,fc=1,tr=1,tc=2},  -- Ka8→Kb8 (forcé)
            {fr=8,fc=1,tr=4,tc=5},  -- Ba1→Be5+
            {fr=1,fc=2,tr=1,tc=1},  -- Kb8→Ka8 (forcé)
            {fr=2,fc=4,tr=3,tc=3},  -- Bd7→Bc6#
        },
        hint="Repositionnez le fou en a1, revenez en e5 pour donner échec, puis Bc6 mate.",
    },

    -- 34. Sacrifice de tour, mat de dame (noirs jouent)
    -- Lichess étude JrwLZArS, puzzle 3 (vérifié)
    -- FEN: k5rr/Ppp5/8/4Q3/1P1P4/3q3P/5PP1/R3R1K1 b - - 0 1
    -- 1...Rg8×g2+  2.Kg1×g2 Qd3×h3+  3.Kg2-g1 Qh3-h1#
    {
        id=34, category="mat3",
        title="Sacrifice de tour, mat de dame",
        desc="Les noirs jouent et font mat en 3 coups.",
        fen="k5rr/Ppp5/8/4Q3/1P1P4/3q3P/5PP1/R3R1K1 b - - 0 1",
        solution={
            {fr=1,fc=7,tr=7,tc=7},  -- Rg8→Rg2+ (sacrifice)
            {fr=8,fc=7,tr=7,tc=7},  -- Kg1×Rg2 (forcé)
            {fr=6,fc=4,tr=6,tc=8},  -- Qd3×Ph3+
            {fr=7,fc=7,tr=8,tc=7},  -- Kg2→Kg1 (forcé)
            {fr=6,fc=8,tr=8,tc=8},  -- Qh3→Qh1#
        },
        hint="Sacrifiez la tour en g2 pour attirer le roi, prenez h3 avec échec, puis dame en h1 mat.",
    },

    -- 35. Sacrifice de dame, mat de tour (noirs jouent)
    -- Lichess étude JrwLZArS, puzzle 4 (vérifié)
    -- FEN: 4k2r/Q5pp/3bp3/4n3/1r5q/8/PP2B1PP/R1B2R1K b - - 0 1
    -- 1...Qh4×h2+  2.Kh1×h2 Ne5-f3+  3.Kh2-h3 Rb4-h4#
    {
        id=35, category="mat3",
        title="Sacrifice de dame, mat de tour",
        desc="Les noirs jouent et font mat en 3 coups.",
        fen="4k2r/Q5pp/3bp3/4n3/1r5q/8/PP2B1PP/R1B2R1K b - - 0 1",
        solution={
            {fr=5,fc=8,tr=7,tc=8},  -- Qh4×Ph2+ (sacrifice dame)
            {fr=8,fc=8,tr=7,tc=8},  -- Kh1×Qh2 (forcé)
            {fr=4,fc=5,tr=6,tc=6},  -- Ne5→Nf3+
            {fr=7,fc=8,tr=6,tc=8},  -- Kh2→Kh3 (forcé)
            {fr=5,fc=2,tr=5,tc=8},  -- Rb4→Rh4#
        },
        hint="Sacrifiez la dame en h2, cavalier en f3 donne échec, tour en h4 mate.",
    },
}
