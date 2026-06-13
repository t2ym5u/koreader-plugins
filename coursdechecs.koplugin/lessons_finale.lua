-- ---------------------------------------------------------------------------
-- lessons_finale.lua — 7 puzzles de finale
-- Pour chaque puzzle, la solution indique le premier coup instructif.
-- Les finales nécessitent plusieurs coups précis : la solution guide le premier.
-- ---------------------------------------------------------------------------

return {

    -- 24. K+Q vs K : restrict the king
    -- FEN: Ke5 / Ke1 Qf1
    -- Qf1(r8c6)→f5(r4c6) coupe le roi adverse sur 4 rangs supérieurs
    {
        id=24, category="finale",
        title="Roi et dame contre roi (1)",
        desc="Les blancs gagnent. Utilisez la dame pour restreindre le roi adverse.",
        fen="8/8/8/4k3/8/8/8/4KQ2 w - - 0 1",
        solution={ {fr=8,fc=6,tr=4,tc=6} },
        hint="La dame restreint le roi adverse sur le bord, puis le roi blanc approche.",
    },

    -- 25. K+Q vs K : closing in for mate
    -- FEN: Kg2 / Kg1 Qh1
    -- Kg1(r8c7)→g7(r2c7) rapproche le roi pour permettre le mat
    {
        id=25, category="finale",
        title="Roi et dame contre roi (2)",
        desc="Les blancs jouent et font mat bientôt. Amenez le roi blanc.",
        fen="8/8/8/8/8/8/6k1/6KQ w - - 0 1",
        solution={ {fr=8,fc=7,tr=7,tc=7} },
        hint="Le roi doit approcher pour que la dame puisse donner mat.",
    },

    -- 26. K+R vs K : rook cuts off king
    -- FEN: Kg1 / Ra1 Ke1
    -- Ra1(r8c1)→a2(r7c1) coupe le roi noir sur la rangée supérieure
    {
        id=26, category="finale",
        title="Roi et tour contre roi",
        desc="Les blancs gagnent. La tour coupe le roi adverse sur une rangée.",
        fen="8/8/8/8/8/8/8/R3K1k1 w - - 0 1",
        solution={ {fr=8,fc=1,tr=7,tc=1} },
        hint="La tour coupe le roi adverse — puis le roi blanc avance colonne par colonne.",
    },

    -- 27. Pawn endgame : opposition, key square e6
    -- FEN: Ke5 / Ke1 pe3
    -- Ke1(r8c5)→e2(r7c5) prend l'opposition et s'approche de la case clé e6
    {
        id=27, category="finale",
        title="Opposition — case clé",
        desc="Les blancs jouent et gagnent. Le roi doit escorter le pion à la promotion.",
        fen="8/8/8/4k3/8/4P3/8/4K3 w - - 0 1",
        solution={ {fr=8,fc=5,tr=7,tc=5} },
        hint="Avancez le roi pour prendre l'opposition et atteindre la case clé e6.",
    },

    -- 28. Pawn race : king escorts pawn
    -- FEN: Kd7 / Kd1 pd2
    -- Kd1(r8c4)→d2(r7c4) escorte le pion vers la promotion
    {
        id=28, category="finale",
        title="Course à la promotion",
        desc="Les blancs jouent et gagnent la course à la promotion.",
        fen="8/3k4/8/8/8/8/3P4/3K4 w - - 0 1",
        solution={ {fr=8,fc=4,tr=7,tc=4} },
        hint="Le roi blanc doit avancer au plus vite pour escorter son pion.",
    },

    -- 29. Lucena position : building the bridge
    -- FEN: Kd8 pd7 Kd6 / Rh1
    -- Rh1(r8c8)→h5(r4c8) prépare le pont pour faire barrage
    {
        id=29, category="finale",
        title="Position de Lucena — le pont",
        desc="Les blancs gagnent par la technique du pont.",
        fen="3k4/3P4/3K4/8/8/8/8/7R w - - 0 1",
        solution={ {fr=8,fc=8,tr=4,tc=8} },
        hint="Amenez la tour en 5ème rangée pour faire barrage — technique du pont de Lucena.",
    },

    -- 30. Philidor position : classic rook endgame defence/advance
    -- FEN: Kd6 pd5 pd4 Kd2 Rd1
    -- Rd1(r8c4)→d2(r7c4) active le roi et contrôle les cases clés
    {
        id=30, category="finale",
        title="Position de Philidor",
        desc="Finale classique de tour. Les blancs avancent — comment progresser ?",
        fen="8/8/3k4/3p4/3P4/8/3K4/3R4 w - - 0 1",
        solution={ {fr=8,fc=4,tr=7,tc=4} },
        hint="Activez le roi et contrôlez les cases clés avec la tour.",
    },
}
