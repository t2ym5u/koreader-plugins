-- ---------------------------------------------------------------------------
-- lessons_mat2.lua — 7 puzzles "Mat en 2"
-- Format solution : {blanc1, noir_forcé, blanc2} — les coups impairs (indices 2,4…)
-- sont rejoués automatiquement par le moteur comme réponse adverse.
-- ---------------------------------------------------------------------------

return {

    -- 9. Queen sacrifice then rook back-rank mate
    -- FEN: Ka8 pa7 pb7 / Qb6 Rc1 Kc4
    -- 1.Qxa7+ Kb8 (a8 Qa7 col a) 2.Rc8#
    {
        id=9, category="mat2",
        title="Sacrifice de dame, mat en 2",
        desc="Les blancs jouent et font mat en 2 coups.",
        fen="k7/pp6/1Q6/8/2K5/8/8/2R5 w - - 0 1",
        solution={
            {fr=3,fc=2,tr=2,tc=1},   -- Qxa7+
            {fr=1,fc=1,tr=1,tc=2},   -- Ka8→Kb8 (forcé)
            {fr=8,fc=3,tr=1,tc=3},   -- Rc8#
        },
        hint="Sacrifiez la dame pour dégager la colonne c, puis mat avec la tour.",
    },

    -- 10. Queen sacrifice on e8, rook mates
    -- FEN: Kg8 Re7 pf7 pg7 ph7 / Qh5 Re1 Kg1
    -- 1.Qe8+! Rxe8 (forcé : Kg8 bloqué par ses pions) 2.Rxe8#
    {
        id=10, category="mat2",
        title="Sacrifice de dame en e8",
        desc="Les blancs jouent et font mat en 2 coups.",
        fen="6k1/4rp1p/6p1/7Q/8/8/8/4R1K1 w - - 0 1",
        solution={
            {fr=4,fc=8,tr=1,tc=5},   -- Qe8+
            {fr=2,fc=5,tr=1,tc=5},   -- Rxe8 (forcé)
            {fr=8,fc=5,tr=1,tc=5},   -- Rxe8#
        },
        hint="Sacrifiez la dame en e8 — la tour est forcée de reprendre, puis mat.",
    },

    -- 11. Rook ladder mate in 2
    -- FEN: Ka8 / Ra5 Rb1 Ke4
    -- 1.Ra7+ Kb8 (a8 col a, a7 occupé) 2.Rb8# (Rb1→b8 ; Kb8 : a8 Ra7 col a, c8 Rb8 col b? non, rang 1)
    -- Correction : 1.Ra7+ Ka8→Kb8 2.Rb7→Rb8# (Kb8 : a8 Ra7 col a, c8 Rb8 rang 1, b7 occupé)
    {
        id=11, category="mat2",
        title="Échelle de tours (1)",
        desc="Les blancs jouent et font mat en 2 coups.",
        fen="k7/8/8/R7/4K3/8/8/1R6 w - - 0 1",
        solution={
            {fr=4,fc=1,tr=2,tc=1},   -- Ra7+
            {fr=1,fc=1,tr=1,tc=2},   -- Ka8→Kb8 (forcé)
            {fr=7,fc=2,tr=1,tc=2},   -- Rb8#
        },
        hint="La tour pousse le roi en b8, puis l'autre tour mate en b8.",
    },

    -- 12. Rook ladder mate in 2 (variant)
    -- FEN: Ka8 / Rc1 Ra1 Kb6
    -- 1.Rc8+ Ka8→Ka7 (b8 rang 1) 2.Ra8# (Ka7 : a8 Ra8 col a, b8 Rc8 rang 1, b7 Kb6 adj)
    {
        id=12, category="mat2",
        title="Échelle de tours (2)",
        desc="Les blancs jouent et forcent le roi en a7, puis mat.",
        fen="k7/8/1K6/8/8/8/8/R1R5 w - - 0 1",
        solution={
            {fr=8,fc=3,tr=1,tc=3},   -- Rc8+
            {fr=1,fc=1,tr=2,tc=1},   -- Ka8→Ka7 (forcé)
            {fr=8,fc=1,tr=1,tc=1},   -- Ra8#
        },
        hint="Forcer le roi en a7 avec une tour, puis mat de la tour en a8.",
    },

    -- 13. Queen sacrifice variant (same theme as #10, different queen position)
    -- FEN: Ke8 Re7 pf7 pg7 ph7 / Qg5 Re1 Ke4
    -- 1.Qe8+! Rxe8 (forcé) 2.Rxe8#
    {
        id=13, category="mat2",
        title="Sacrifice de dame, variante",
        desc="Les blancs jouent et font mat en 2 coups.",
        fen="4k3/4rp1p/6p1/6Q1/4K3/8/8/4R3 w - - 0 1",
        solution={
            {fr=4,fc=7,tr=1,tc=5},   -- Qe8+
            {fr=2,fc=5,tr=1,tc=5},   -- Rxe8 (forcé)
            {fr=8,fc=5,tr=1,tc=5},   -- Rxe8#
        },
        hint="Même idée : sacrifiez la dame en e8 pour forcer la tour à reprendre.",
    },

    -- 14. Queen drives king to b1, then mates
    -- FEN: Ka1 pa2 / Qd1 Kd3
    -- 1.Qa4+ Ka1→Kb1 (a2 pion noir, a4 col a couvre Ka1) 2.Qa1# (Kb1 : b2 diag Qa1, c1 rang Qa1, c2 Kd3 adj)
    {
        id=14, category="mat2",
        title="Dame : forcer le roi en b1",
        desc="Les blancs jouent et font mat en 2 coups.",
        fen="8/8/8/8/8/3K4/p7/k2Q4 w - - 0 1",
        solution={
            {fr=8,fc=4,tr=5,tc=1},   -- Qa4+
            {fr=8,fc=1,tr=8,tc=2},   -- Ka1→Kb1 (forcé)
            {fr=5,fc=1,tr=8,tc=1},   -- Qa1#
        },
        hint="La dame en a4 force le roi en b1, puis Qa1 mate.",
    },

    -- 15. Two rooks push king then mate (variant of #12)
    -- FEN: Ka8 / Rc1 Ra1 Kc6
    -- 1.Rc8+ Ka8→Ka7 (b8 rang 1) 2.Ra8# (Ka7 : a8 Ra8, b8 Rc8 rang, b7 Kc6 adj r3c3→r2c2=b7)
    {
        id=15, category="mat2",
        title="Tour et roi, mat en 2 (variante)",
        desc="Les blancs jouent et font mat en 2 coups.",
        fen="k7/8/2K5/8/8/8/8/R1R5 w - - 0 1",
        solution={
            {fr=8,fc=3,tr=1,tc=3},   -- Rc8+
            {fr=1,fc=1,tr=2,tc=1},   -- Ka8→Ka7 (forcé)
            {fr=8,fc=1,tr=1,tc=1},   -- Ra8#
        },
        hint="Rc8 force le roi en a7, Ra8 donne mat — le roi c6 couvre b7.",
    },
}
