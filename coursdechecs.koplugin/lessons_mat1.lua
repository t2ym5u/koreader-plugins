-- ---------------------------------------------------------------------------
-- lessons_mat1.lua — 8 puzzles "Mat en 1"
-- Coordonnées : r=1 = rangée 8, r=8 = rangée 1 ; c=1 = col a, c=8 = col h
-- ---------------------------------------------------------------------------

return {

    -- 1. Back-rank mate : Ra8#
    -- FEN: Kg1 Ra1 / Kg8 pf7 pg7 ph7
    {
        id=1, category="mat1",
        title="Mat de la dernière rangée",
        desc="Les blancs jouent et font mat en 1 coup.",
        fen="6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1",
        solution={ {fr=8,fc=1,tr=1,tc=1} },
        hint="La tour remonte sur la 8ème rangée — le roi est enfermé par ses propres pions.",
    },

    -- 2. Rook + King corner mate : Ra8#
    -- FEN: Ka8 / Ra1 Kb7
    {
        id=2, category="mat1",
        title="Tour et roi, mat en coin",
        desc="Les blancs jouent et font mat en 1 coup.",
        fen="k7/1K6/8/8/8/8/8/R7 w - - 0 1",
        solution={ {fr=8,fc=1,tr=1,tc=1} },
        hint="La tour va en a8 — le roi blanc couvre b8 et a7.",
    },

    -- 3. Two rooks (Rb6) mate : Rb8#
    -- FEN: Ka8 / Ka6 Rb6
    -- Rb6(r3c2) → b8(r1c2) ; Ka6(r3c1) couvre a7(r2c1) et b7(r2c2)
    {
        id=3, category="mat1",
        title="Mat avec deux tours (roi et tour)",
        desc="Les blancs jouent et font mat en 1 coup.",
        fen="k7/8/KR6/8/8/8/8/8 w - - 0 1",
        solution={ {fr=3,fc=2,tr=1,tc=2} },
        hint="La tour monte en b8 — le roi blanc couvre a7 et b7.",
    },

    -- 4. Queen mate : Qg7#
    -- FEN: Kh8 / Qf6 Kg6
    -- Qf6(r3c6) → g7(r2c7) ; Kh8(r1c8) n'a plus de case : g8 col g, h7 diag Qg7
    {
        id=4, category="mat1",
        title="Mat de la dame en g7",
        desc="Les blancs jouent et font mat en 1 coup.",
        fen="7k/8/5QK1/8/8/8/8/8 w - - 0 1",
        solution={ {fr=3,fc=6,tr=2,tc=7} },
        hint="La dame va en g7 — le roi est pris en étau.",
    },

    -- 5. Queen corner mate : Qa2#
    -- FEN: Ka1 / Qb3 Kc3
    -- Qb3(r6c2) → a2(r7c1) ; Ka1(r8c1) : b1 col b Qb3, b2 diag Qa2, a2 occupé
    {
        id=5, category="mat1",
        title="Dame en a2, mat en coin",
        desc="Les blancs jouent et font mat en 1 coup.",
        fen="8/8/8/8/8/1QK5/8/k7 w - - 0 1",
        solution={ {fr=6,fc=2,tr=7,tc=1} },
        hint="La dame va en a2, coinçant le roi noir en a1.",
    },

    -- 6. Two-rook corner mate : Rb8#
    -- FEN: Ka8 / Ra1 Rb2 Kd4
    -- Rb2(r7c2) → b8(r1c2) ; Ra1(r8c1) couvre col a ; Kd4 éloigné
    {
        id=6, category="mat1",
        title="Double tour, mat en coin",
        desc="Les blancs jouent et font mat en 1 coup.",
        fen="k7/8/8/8/3K4/8/1R6/R7 w - - 0 1",
        solution={ {fr=7,fc=2,tr=1,tc=2} },
        hint="La tour monte en b8 — l'autre tour couvre la colonne a.",
    },

    -- 7. Queen + King corner mate : Qa7#
    -- FEN: Ka8 / Qa5 Kc7
    -- Qa5(r4c1) → a7(r2c1) ; Ka8(r1c1) : b8 adj Kc7, b7 diag Qa7, a8 col a
    {
        id=7, category="mat1",
        title="Dame en a7, mat en coin",
        desc="Les blancs jouent et font mat en 1 coup.",
        fen="k7/8/8/Q7/8/8/2K5/8 w - - 0 1",
        solution={ {fr=4,fc=1,tr=2,tc=1} },
        hint="La dame va en a7 — le roi blanc couvre b8 depuis c7.",
    },

    -- 8. Anastasia's mate : Rxh7#
    -- FEN: Kh8 pg7 ph7 / Rh1 Nh6 Kg6
    -- Rh1(r8c8) → h7(r2c8) ; Kh8(r1c8) : g8 couvert Nh6, g7 couvert Kg6, h6 occupé N
    {
        id=8, category="mat1",
        title="Mat d'Anastasie",
        desc="Les blancs jouent et font mat en 1 coup.",
        fen="7k/6pp/6NK/8/8/8/8/7R w - - 0 1",
        solution={ {fr=8,fc=8,tr=2,tc=8} },
        hint="La tour prend en h7 — cavalier en h6 couvre g8, roi en g6 couvre g7.",
    },
}
