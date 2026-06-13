-- ---------------------------------------------------------------------------
-- lessons_tactique.lua — 8 puzzles de tactique
-- Thèmes : fourchette, clouage absolu, enfilade, attaque à la découverte
-- ---------------------------------------------------------------------------

return {

    -- 16. Knight fork : Nc5+ forks Ke6 and Ra6
    -- FEN: Ke6 Ra6 / Nd3 Ke1
    -- Nd3(r6c4)→c5(r4c3) : Nc5 couvre e6(r3c5)=Ke6 et a6(r3c1)=Ra6 → fourchette
    {
        id=16, category="tactique",
        title="Fourchette du cavalier",
        desc="Les blancs jouent et gagnent la tour grâce à une fourchette.",
        fen="8/8/r3k3/8/8/3N4/8/4K3 w - - 0 1",
        solution={ {fr=6,fc=4,tr=4,tc=3} },
        hint="Le cavalier peut attaquer le roi et la tour en même temps.",
    },

    -- 17. Absolute pin : Bb5 pins Nc6 to Ke8 ; Bxc6+
    -- FEN: Ke8 Nc6 / Bb5 Ke1
    -- Bb5(r4c2) diagonale : (r3c3)=Nc6→(r2c4)→(r1c5)=Ke8 — clouage absolu
    -- Bxc6+ gagne le cavalier et donne échec
    {
        id=17, category="tactique",
        title="Exploiter le clouage absolu",
        desc="Les blancs jouent et gagnent le cavalier grâce au clouage absolu.",
        fen="4k3/8/2n5/1B6/8/8/8/4K3 w - - 0 1",
        solution={ {fr=4,fc=2,tr=3,tc=3} },
        hint="La pièce clouée sur le roi ne peut pas fuir — capturez-la !",
    },

    -- 18. Rook skewer : Rb6+ skewers Kb8, wins Rb2
    -- FEN: Kb8 Rb2 / Rb5 Ke1
    -- Rb5(r4c2)→b6(r3c2) : échec Kb8(r1c2) via col b ; Kb8 s'écarte → Rxb2
    {
        id=18, category="tactique",
        title="Enfilade de tour",
        desc="Les blancs jouent et gagnent la tour adverse grâce à une enfilade.",
        fen="1k6/8/8/1R6/8/8/1r6/4K3 w - - 0 1",
        solution={ {fr=4,fc=2,tr=3,tc=2} },
        hint="Donnez échec au roi pour qu'il s'écarte et expose la tour derrière lui.",
    },

    -- 19. Discovered attack : Ne5→f7+ reveals Re1 attacking Qe7
    -- FEN: Ke8 Qe7 / Ne5 Re1 Ke2
    -- Ne5(r4c5)→f7(r2c6) : échappe la colonne e → Re1 découverte sur Ke8 au travers de Qe7
    -- Ke8 doit parer l'échec → Re1×e7 gagne la dame
    {
        id=19, category="tactique",
        title="Attaque à la découverte",
        desc="Les blancs jouent et gagnent la dame adverse par une attaque à la découverte.",
        fen="4k3/4q3/8/4N3/8/8/4K3/4R3 w - - 0 1",
        solution={ {fr=4,fc=5,tr=2,tc=6} },
        hint="Bougez le cavalier — la tour attaque la dame à la découverte et donne échec.",
    },

    -- 20. Knight fork on king and queen : Nf6+ forks Ke8 and Qd7
    -- FEN: Ke8 Qd7 / Nd5 Ke1
    -- Nd5(r4c4)→f6(r3c6) : Nf6 couvre e8(r1c5)=Ke8 et d7(r2c4)=Qd7 → fourchette
    {
        id=20, category="tactique",
        title="Fourchette cavalier sur roi et dame",
        desc="Les blancs jouent et gagnent la dame grâce à une fourchette de cavalier.",
        fen="4k3/3q4/8/3N4/8/8/8/4K3 w - - 0 1",
        solution={ {fr=4,fc=4,tr=3,tc=6} },
        hint="Le cavalier peut-il attaquer le roi et la dame simultanément ?",
    },

    -- 21. Queen fork : Qe5+ forks Ke7 (e-file) and Ra5 (rank 4)
    -- FEN: Ke7 Ra5 / Qa1 Ke1
    -- Qa1(r8c1)→e5(r4c5) diagonale ; Qe5 échec Ke7(r2c5) col e ; attaque Ra5(r4c1) rang 4
    {
        id=21, category="tactique",
        title="Fourchette de la dame",
        desc="Les blancs jouent et gagnent la tour grâce à une fourchette de la dame.",
        fen="8/4k3/8/r7/8/8/8/Q3K3 w - - 0 1",
        solution={ {fr=8,fc=1,tr=4,tc=5} },
        hint="La dame va en e5 — elle donne échec et attaque la tour en même temps.",
    },

    -- 22. Pin on d-file : Rd1 pins Nd4 to Kd8 ; Rxd4
    -- FEN: Kd8 Nd4 / Rd1 Ke1
    -- Rd1(r8c4) col d : Nd4(r5c4) cloué sur Kd8(r1c4) — Rxd4 gagne le cavalier (+échec)
    {
        id=22, category="tactique",
        title="Clouage sur colonne d",
        desc="Les blancs exploitent le clouage pour gagner le cavalier.",
        fen="3k4/8/8/8/3n4/8/8/3RK3 w - - 0 1",
        solution={ {fr=8,fc=4,tr=5,tc=4} },
        hint="Le cavalier est cloué sur la colonne d — capturez-le !",
    },

    -- 23. Skewer on f-file : Rf6+ skewers Kf8, wins Rf2
    -- FEN: Kf8 Rf2 / Rf5 Ke1
    -- Rf5(r4c6)→f6(r3c6) : échec Kf8(r1c6) col f ; Kf8 s'écarte → Rxf2
    {
        id=23, category="tactique",
        title="Enfilade sur colonne f",
        desc="Les blancs attaquent le roi et gagnent la tour sur la même colonne.",
        fen="5k2/8/8/5R2/8/8/5r2/4K3 w - - 0 1",
        solution={ {fr=4,fc=6,tr=3,tc=6} },
        hint="Donnez échec au roi pour l'obliger à s'écarter et capturez la tour.",
    },
}
