-- ---------------------------------------------------------------------------
-- lessons.lua — 30 chess puzzles for Cours d'échecs
--
-- Grid coordinates: r=1 top (rank 8), r=8 bottom (rank 1)
--                   c=1 = a-file, c=8 = h-file
-- Chess-to-grid conversion:  sq XN  ->  r = 9 - N,  c = file_index(X)
--   a1=r8c1  e1=r8c5  h1=r8c8
--   a8=r1c1  e8=r1c5  h8=r1c8
-- ---------------------------------------------------------------------------

return {

    -- =========================================================
    -- MAT EN 1 (8 puzzles) — white to move and mate in 1
    -- =========================================================

    -- 1. Back-rank mate
    -- FEN: Kg1 Ra1 / Kg8 pf7 pg7 ph7
    -- Ra8# (r8c1 -> r1c1): rank-8 covers. King: g8->h7 blocked by pawn; f8 rank-8.
    {
        id=1, category="mat1",
        title="Mat de la dernière rangée",
        desc="Les blancs jouent et font mat en 1 coup.",
        fen="6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1",
        solution={ {fr=8,fc=1,tr=1,tc=1} },
        hint="La tour remonte sur la 8ème rangée — le roi est enfermé par ses propres pions.",
    },

    -- 2. Rook + King corner mate
    -- FEN: Ka8 / Ra1 Kb7
    -- Ra8# (r8c1 -> r1c1). Ka8 squares: b8(Kb7 adj covers), a7(Kb7 adj covers).
    {
        id=2, category="mat1",
        title="Tour et roi, mat en coin",
        desc="Les blancs jouent et font mat en 1 coup.",
        fen="k7/1K6/8/8/8/8/8/R7 w - - 0 1",
        solution={ {fr=8,fc=1,tr=1,tc=1} },
        hint="La tour va en a8 — le roi blanc couvre b8 et a7.",
    },

    -- 3. Two rooks mate (king + rook at b6 drive black king to corner)
    -- FEN: Ka8 / Ka6 Rb6
    -- Rb8# (r3c2 -> r1c2): Ka8 check via rank-8; a7 adj to Ka6; b7 adj to Ka6 diag.
    {
        id=3, category="mat1",
        title="Mat avec deux tours (roi et tour)",
        desc="Les blancs jouent et font mat en 1 coup.",
        fen="k7/8/KR6/8/8/8/8/8 w - - 0 1",
        solution={ {fr=3,fc=2,tr=1,tc=2} },
        hint="La tour monte en b8 — le roi blanc couvre a7 et b7.",
    },

    -- 4. Queen mate — Qg7#
    -- FEN: Kh8 / Qf6 Kg6
    -- Qg7# (r3c6 -> r2c7). Kh8: g8 covered by Qg7 g-file; h7 covered by Qg7 rank-2.
    {
        id=4, category="mat1",
        title="Mat de la dame en g7",
        desc="Les blancs jouent et font mat en 1 coup.",
        fen="7k/8/5QK1/8/8/8/8/8 w - - 0 1",
        solution={ {fr=3,fc=6,tr=2,tc=7} },
        hint="La dame va en g7 — le roi est pris en étau.",
    },

    -- 5. Queen corner mate — Qa2#
    -- FEN: Ka1 / Qb3 Kc3
    -- Qa2# (r6c2 -> r7c1). Ka1: b1 covered by Qb3 b-file; b2 covered by Qa2 rank-7 and Kc3.
    {
        id=5, category="mat1",
        title="Dame en a2, mat en coin",
        desc="Les blancs jouent et font mat en 1 coup.",
        fen="8/8/8/8/8/1QK5/8/k7 w - - 0 1",
        solution={ {fr=6,fc=2,tr=7,tc=1} },
        hint="La dame va en a2, coinçant le roi noir en a1.",
    },

    -- 6. Two-rook mate (variant)
    -- FEN: Ka8 / Ra1 Rb2 Kd4
    -- Rb8# (r7c2 -> r1c2). Ka8: rank-8 covered by Rb8; a7 covered by Ra1 a-file.
    {
        id=6, category="mat1",
        title="Double tour, mat en coin",
        desc="Les blancs jouent et font mat en 1 coup.",
        fen="k7/8/8/8/3K4/8/1R6/R7 w - - 0 1",
        solution={ {fr=7,fc=2,tr=1,tc=2} },
        hint="La tour monte en b8 — l'autre tour couvre la colonne a.",
    },

    -- 7. Queen + King corner mate — Qa7#
    -- FEN: Ka8 / Qa5 Kc7
    -- Qa7# (r4c1 -> r2c1). Ka8: b8 covered by Kc7 (adj); b7 covered by Qa7 rank-2.
    {
        id=7, category="mat1",
        title="Dame en a7, mat en coin",
        desc="Les blancs jouent et font mat en 1 coup.",
        fen="k7/8/8/Q7/8/8/2K5/8 w - - 0 1",
        solution={ {fr=4,fc=1,tr=2,tc=1} },
        hint="La dame va en a7 — le roi blanc couvre b8 depuis c7.",
    },

    -- 8. Anastasia's mate
    -- FEN: Kh8 pg7 ph7 / Rh1 Nh6 Kg6
    -- Rxh7# (r8c8 -> r2c8). Kh8: g8 covered by Nh6 (knight r3c8 covers r1c7); g7 covered by Kg6.
    {
        id=8, category="mat1",
        title="Mat d'Anastasie",
        desc="Les blancs jouent et font mat en 1 coup.",
        fen="7k/6pp/6NK/8/8/8/8/7R w - - 0 1",
        solution={ {fr=8,fc=8,tr=2,tc=8} },
        hint="La tour prend en h7 — cavalier en h6 couvre g8, roi en g6 couvre g7.",
    },

    -- =========================================================
    -- MAT EN 2 (7 puzzles) — white mates in 2
    -- solution[1]=white  solution[2]=black forced reply  solution[3]=white mate
    -- =========================================================

    -- 9. Queen sacrifice then rook back-rank mate
    -- FEN: Ka8 pa7 pb7 / Qb6 Rc1 Kc4
    -- 1.Qxa7+ Ka8->b8 (a7 occupied; Kc4 not covering b8)
    -- 2.Rc8# Kb8: a8 (Qa7 a-file), b7 own pawn, c8 occupied, c7 (Qa7 rank-2).
    {
        id=9, category="mat2",
        title="Sacrifice de dame, mat en 2",
        desc="Les blancs jouent et font mat en 2 coups.",
        fen="k7/pp6/1Q6/8/2K5/8/8/2R5 w - - 0 1",
        solution={
            {fr=3,fc=2,tr=2,tc=1},
            {fr=1,fc=1,tr=1,tc=2},
            {fr=8,fc=3,tr=1,tc=3},
        },
        hint="Sacrifiez la dame pour dégager la colonne c, puis mat avec la tour.",
    },

    -- 10. Queen sacrifice on e8, rook mates
    -- FEN: Kg8 Re7 pf7 pg7 ph7 / Qh5 Re1 Kg1
    -- 1.Qe8+! Re7xe8 forced (Kg8 can't escape: f8/h8 rank-8; f7/g7/h7 own pawns)
    -- 2.Re1xe8# Kg8: f8/h8 rank-8 covered; f7/g7/h7 own pawns.
    {
        id=10, category="mat2",
        title="Sacrifice de dame en e8",
        desc="Les blancs jouent et font mat en 2 coups.",
        fen="6k1/4rp1p/6p1/7Q/8/8/8/4R1K1 w - - 0 1",
        solution={
            {fr=4,fc=8,tr=1,tc=5},
            {fr=2,fc=5,tr=1,tc=5},
            {fr=8,fc=5,tr=1,tc=5},
        },
        hint="Sacrifiez la dame en e8 — la tour est forcée de reprendre, puis mat.",
    },

    -- 11. Rook ladder mate in 2
    -- FEN: Ka8 / Ra5 Rb1 Ke4
    -- 1.Ra7+ Ka8->b8 (a7 occupied; a7-file covered by Ra7)
    -- 2.Ra7->a8# Kb8: a8 occupied (Ra8 there, check via rank-8), b7 (Rb1 b-file), c8 (Ra8 rank-8).
    {
        id=11, category="mat2",
        title="Échelle de tours (1)",
        desc="Les blancs jouent et font mat en 2 coups.",
        fen="k7/8/8/R7/4K3/8/8/1R6 w - - 0 1",
        solution={
            {fr=4,fc=1,tr=2,tc=1},
            {fr=1,fc=1,tr=1,tc=2},
            {fr=2,fc=1,tr=1,tc=1},
        },
        hint="La tour pousse le roi en b8, puis l'autre tour mate en a8.",
    },

    -- 12. Rook ladder mate in 2 (variant)
    -- FEN: Ka8 / Rc1 Ra1 Kb6
    -- 1.Rc8+ Ka8->a7 (b8 rank-8; a7 free)
    -- 2.Ra8# Ka7: a8 occupied (check via a-file), b8 (Rc8 rank-8), b7 (Kb6 adj), c8 (Rc8 c-file).
    {
        id=12, category="mat2",
        title="Échelle de tours (2)",
        desc="Les blancs jouent et forcent le roi en a7, puis mat.",
        fen="k7/8/1K6/8/8/8/8/R1R5 w - - 0 1",
        solution={
            {fr=8,fc=3,tr=1,tc=3},
            {fr=1,fc=1,tr=2,tc=1},
            {fr=8,fc=1,tr=1,tc=1},
        },
        hint="Forcer le roi en a7 avec une tour, puis mat de la tour en a8.",
    },

    -- 13. Queen sacrifice variant (same pattern as puzzle 10, different queen position)
    -- FEN: Ke8 Re7 pf7 pg7 ph7 / Qg5 Re1 Ke4
    -- 1.Qe8+! Re7xe8 forced; 2.Re1xe8#
    {
        id=13, category="mat2",
        title="Sacrifice de dame, variante",
        desc="Les blancs jouent et font mat en 2 coups.",
        fen="4k3/4rp1p/6p1/6Q1/4K3/8/8/4R3 w - - 0 1",
        solution={
            {fr=4,fc=7,tr=1,tc=5},
            {fr=2,fc=5,tr=1,tc=5},
            {fr=8,fc=5,tr=1,tc=5},
        },
        hint="Même idée : sacrifiez la dame en e8 pour forcer la tour à reprendre.",
    },

    -- 14. Queen drives king, then mates
    -- FEN: Ka1 pa2 / Qd1 Kd3
    -- 1.Qa4+ Ka1->b1 (a2 own pawn; a4 a-file covers Ka1; Kd3 covers b2)
    -- 2.Qa1# Kb1: a1 occupied (check via rank-8), b2 (Qa1 diag r7c2? Qa1 diag (7,2)=b2 YES),
    --   c1 (Qa1 rank-8), c2 (Kd3 adj).
    {
        id=14, category="mat2",
        title="Dame: forcer le roi en b1",
        desc="Les blancs jouent et font mat en 2 coups.",
        fen="8/8/8/8/8/3K4/p7/k2Q4 w - - 0 1",
        solution={
            {fr=8,fc=4,tr=5,tc=1},
            {fr=8,fc=1,tr=8,tc=2},
            {fr=5,fc=1,tr=8,tc=1},
        },
        hint="La dame en a4 force le roi en b1, puis Qa1 mate.",
    },

    -- 15. Two rooks push king then mate
    -- FEN: Ka8 / Rc1 Ra1 Kc5
    -- 1.Rc8+ Ka8->a7 (b8 rank-8; a7 free)
    -- After Ka7: 2.Ra1->a7+? No — 2.Ra8# already achieved in p12.
    -- Use: 1.Rc8+ Ka7; 2.Ra7# — Rc8 covers rank-8+c-file; Ra1->a7 checks Ka7(a-file).
    -- Ka7 squares: a8(Ra7 a-file), b8(Rc8 rank-8), b7(Kc5 adj: Kc5(r=4,c=3) adj (3,2)=b6,(3,3)=c6,(3,4)=d6,(4,2)=b5,(4,4)=d5,(5,2)=b4,(5,3)=c4,(5,4)=d4, NOT b7(r=2,c=2)). Hmm b7 not covered.
    -- Use Kb6 for coverage: FEN: Ka8 / Rc1 Ra1 Kb6
    -- That's puzzle 12. Use Kc6 for coverage:
    -- FEN: Ka8 / Rc1 Ra1 Kc6
    -- 1.Rc8+ Ka7 (b8 rank-8). 2.Ra8# Ka7: a8 occupied (check a-file), b8(Rc8 rank-8), b7(Kc6 adj: Kc6(r=3,c=3) adj (2,2)=b7 YES), c8(Rc8 c-file).
    {
        id=15, category="mat2",
        title="Tour et roi, mat en 2 (variante)",
        desc="Les blancs jouent et font mat en 2 coups.",
        fen="k7/8/2K5/8/8/8/8/R1R5 w - - 0 1",
        solution={
            {fr=8,fc=3,tr=1,tc=3},
            {fr=1,fc=1,tr=2,tc=1},
            {fr=8,fc=1,tr=1,tc=1},
        },
        hint="Rc8 force le roi en a7, Ra8 donne mat — le roi c6 couvre b7.",
    },

    -- =========================================================
    -- TACTIQUE (8 puzzles) — fork, pin, skewer, discovered attack
    -- =========================================================

    -- 16. Knight fork: Nd3->c5+ forks Ke6 and Ra6
    -- FEN: Ke6 Ra6 / Nd3 Ke1
    -- Nc5+ (r6c4->r4c3). Nc5 covers e6(r3c5) and a6(r3c1). Fork!
    {
        id=16, category="tactique",
        title="Fourchette du cavalier",
        desc="Les blancs jouent et gagnent la tour grâce à une fourchette.",
        fen="8/8/r3k3/8/8/3N4/8/4K3 w - - 0 1",
        solution={ {fr=6,fc=4,tr=4,tc=3} },
        hint="Le cavalier peut attaquer le roi et la tour en même temps.",
    },

    -- 17. Absolute pin: Bb5 pins Nc6 to Ke8; Bxc6+
    -- FEN: Ke8 Nc6 / Bb5 Ke1
    -- Bb5 diagonal: (4,2)->(3,3)=Nc6->(2,4)->(1,5)=Ke8. Pin!
    -- Bxc6+ (r4c2->r3c3) wins knight and checks Ke8.
    {
        id=17, category="tactique",
        title="Exploiter le clouage absolu",
        desc="Les blancs jouent et gagnent le cavalier grâce au clouage absolu.",
        fen="4k3/8/2n5/1B6/8/8/8/4K3 w - - 0 1",
        solution={ {fr=4,fc=2,tr=3,tc=3} },
        hint="La pièce clouée sur le roi ne peut pas fuir — capturez-la !",
    },

    -- 18. Rook skewer: Rb5->b6+ skewers Kb8, wins Rb2
    -- FEN: Kb8 Rb2 / Rb5 Ke1
    -- Rb6+ (r4c2->r3c2). Check Kb8(r1c2) via b-file. Kb8 moves (a8,a7,c8,c7).
    -- Then Rb6->b2 wins black rook.
    {
        id=18, category="tactique",
        title="Enfilade de tour",
        desc="Les blancs jouent et gagnent la tour adverse grâce à une enfilade.",
        fen="1k6/8/8/1R6/8/8/1r6/4K3 w - - 0 1",
        solution={ {fr=4,fc=2,tr=3,tc=2} },
        hint="Donnez échec au roi pour qu'il s'écarte et expose la tour derrière lui.",
    },

    -- 19. Discovered attack: Ne5->f7+ reveals Re1 attack on Qe7 and checks Ke8
    -- FEN: Ke8 Qe7 / Ne5 Re1 Ke2
    -- Nf7+ (r4c5->r2c6). Ne5 was blocking Re1 on e-file toward Ke8.
    -- After Ne5 moves: Re1 gives discovered check to Ke8 via e-file (through e7=Qe7).
    -- Ke8 must address check. After king moves: Re1xe7 wins the queen.
    {
        id=19, category="tactique",
        title="Attaque à la découverte",
        desc="Les blancs jouent et gagnent la dame adverse par une attaque à la découverte.",
        fen="4k3/4q3/8/4N3/8/8/4K3/4R3 w - - 0 1",
        solution={ {fr=4,fc=5,tr=2,tc=6} },
        hint="Bougez le cavalier — la tour attaque la dame à la découverte et donne échec.",
    },

    -- 20. Knight fork with queen: Nd5->f6+ forks Ke8 and Qd7
    -- FEN: Ke8 Qd7 / Nd5 Ke1
    -- Nf6+? Nd5(r4c4)->f6(r3c6): diff(-1,2) YES knight move.
    -- Nf6(r3c6) covers: (1,5)=e8 ✓, (1,7)=g8, (2,4)=d7=Qd7 ✓, (4,4)=d5, (4,8)=h5, (5,5)=e4, (5,7)=g4. Fork on Ke8 and Qd7!
    {
        id=20, category="tactique",
        title="Fourchette cavalier sur roi et dame",
        desc="Les blancs jouent et gagnent la dame grâce à une fourchette de cavalier.",
        fen="4k3/3q4/8/3N4/8/8/8/4K3 w - - 0 1",
        solution={ {fr=4,fc=4,tr=3,tc=6} },
        hint="Le cavalier peut-il attaquer le roi et la dame simultanément ?",
    },

    -- 21. Queen fork: Qa1->e5+ forks Ke7 and Ra5 (diagonal attack)
    -- FEN: Ke7 Ra5 / Qa1 Ke1
    -- Qe5+ (r8c1->r4c5). Qa1(r8c1) diagonal: (7,2),(6,3),(5,4),(4,5)=e5. Qe5 via e-file checks Ke7(r2c5)? Qe5(r4c5) and Ke7(r2c5) same file (c=5). YES check.
    -- After Ke7 moves: Qe5 attacks Ra5(r4c1)? Via rank-4: r=4 covers a5(r4c1). YES!
    {
        id=21, category="tactique",
        title="Fourchette de la dame",
        desc="Les blancs jouent et gagnent la tour grâce à une fourchette de la dame.",
        fen="8/4k3/8/r7/8/8/8/Q3K3 w - - 0 1",
        solution={ {fr=8,fc=1,tr=4,tc=5} },
        hint="La dame va en e5 — elle donne échec et attaque la tour en même temps.",
    },

    -- 22. Pin on d-file: Rd1 pins Nd4 to Kd8; Rxd4
    -- FEN: Kd8 Nd4 / Rd1 Ke1
    -- Rxd4 (r8c4->r5c4). Wins knight. Rd4 then checks Kd8 via d-file (+check).
    {
        id=22, category="tactique",
        title="Clouage sur colonne d",
        desc="Les blancs exploitent le clouage pour gagner le cavalier.",
        fen="3k4/8/8/8/3n4/8/8/3RK3 w - - 0 1",
        solution={ {fr=8,fc=4,tr=5,tc=4} },
        hint="Le cavalier est cloué sur la colonne d — capturez-le !",
    },

    -- 23. Skewer on f-file: Rf5->f6+ skewers Kf8, wins Rf2
    -- FEN: Kf8 Rf2 / Rf5 Ke1
    -- Rf6+ (r4c6->r3c6). Check Kf8(r1c6) via f-file. Kf8 moves (e8,g8,e7,g7).
    -- Then Rf6->f2 captures black rook.
    {
        id=23, category="tactique",
        title="Enfilade sur colonne f",
        desc="Les blancs attaquent le roi et gagnent la tour sur la même colonne.",
        fen="5k2/8/8/5R2/8/8/5r2/4K3 w - - 0 1",
        solution={ {fr=4,fc=6,tr=3,tc=6} },
        hint="Donnez échec au roi pour l'obliger à s'écarter et capturez la tour.",
    },

    -- =========================================================
    -- FINALE (7 puzzles) — endgame techniques
    -- =========================================================

    -- 24. K+Q vs K: restrict the king
    {
        id=24, category="finale",
        title="Roi et dame contre roi (1)",
        desc="Les blancs gagnent. Utilisez la dame pour restreindre le roi adverse.",
        fen="8/8/8/4k3/8/8/8/4KQ2 w - - 0 1",
        solution={ {fr=8,fc=6,tr=4,tc=6} },
        hint="La dame restreint le roi adverse sur le bord, puis le roi blanc approche.",
    },

    -- 25. K+Q vs K: closing in for mate
    {
        id=25, category="finale",
        title="Roi et dame contre roi (2)",
        desc="Les blancs jouent et font mat bientôt. Amenez le roi blanc.",
        fen="8/8/8/8/8/8/6k1/6KQ w - - 0 1",
        solution={ {fr=8,fc=7,tr=7,tc=7} },
        hint="Le roi doit approcher pour que la dame puisse donner mat.",
    },

    -- 26. K+R vs K: rook cuts off king
    {
        id=26, category="finale",
        title="Roi et tour contre roi",
        desc="Les blancs gagnent. La tour coupe le roi adverse sur une rangée.",
        fen="8/8/8/8/8/8/8/R3K1k1 w - - 0 1",
        solution={ {fr=8,fc=1,tr=2,tc=1} },
        hint="La tour coupe le roi adverse — puis le roi blanc avance colonne par colonne.",
    },

    -- 27. Pawn endgame: king escort, opposition
    {
        id=27, category="finale",
        title="Opposition — case clé",
        desc="Les blancs jouent et gagnent. Le roi doit escorter le pion à la promotion.",
        fen="8/8/8/4k3/8/4P3/8/4K3 w - - 0 1",
        solution={ {fr=8,fc=5,tr=7,tc=5} },
        hint="Avancez le roi pour prendre l'opposition et atteindre la case clé e6.",
    },

    -- 28. Pawn endgame: race to promote
    {
        id=28, category="finale",
        title="Course à la promotion",
        desc="Les blancs jouent et gagnent la course à la promotion.",
        fen="8/3k4/8/8/8/8/3P4/3K4 w - - 0 1",
        solution={ {fr=8,fc=4,tr=7,tc=4} },
        hint="Le roi blanc doit avancer au plus vite pour escorter son pion.",
    },

    -- 29. Lucena position: building the bridge
    {
        id=29, category="finale",
        title="Position de Lucena — le pont",
        desc="Les blancs gagnent par la technique du pont.",
        fen="3k4/3P4/3K4/8/8/8/8/7R w - - 0 1",
        solution={ {fr=8,fc=8,tr=5,tc=8} },
        hint="Amenez la tour en e-file pour faire barrage — technique du pont de Lucena.",
    },

    -- 30. Philidor position: classic rook endgame
    {
        id=30, category="finale",
        title="Position de Philidor",
        desc="Finale classique de tour. Les blancs avancent — comment progresser ?",
        fen="8/8/3k4/3p4/3P4/8/3K4/3R4 w - - 0 1",
        solution={ {fr=8,fc=4,tr=7,tc=4} },
        hint="Activez le roi et contrôlez les cases clés avec la tour.",
    },
}
