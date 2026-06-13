# Cours d'échecs — Plan des 30 leçons

Fichier source : `lessons.lua` (agrège `lessons_mat1.lua`, `lessons_mat2.lua`, `lessons_tactique.lua`, `lessons_finale.lua`)

Coordonnées grille : r=1 = rangée 8 (noir), r=8 = rangée 1 (blanc) ; c=1 = colonne a, c=8 = colonne h.
Format solution : `{fr, fc, tr, tc}` — de/vers. Les coups aux indices impairs sont joués automatiquement (réponse adverse).

---

## Mat en 1 — `lessons_mat1.lua` (8 puzzles)

| #  | Titre                          | Pièce clé | Idée                                    |
|----|--------------------------------|-----------|-----------------------------------------|
|  1 | Mat de la dernière rangée      | Tour       | Ra8# — roi enfermé par ses propres pions |
|  2 | Tour et roi, mat en coin       | Tour       | Ra8# — roi blanc couvre b8 et a7        |
|  3 | Mat avec deux tours            | Tour       | Rb8# — roi blanc couvre a7 et b7        |
|  4 | Mat de la dame en g7           | Dame       | Qg7# — étau dame + roi                  |
|  5 | Dame en a2, mat en coin        | Dame       | Qa2# — roi coincé en a1                 |
|  6 | Double tour, mat en coin       | Tour       | Rb8# + Ra1 couvre colonne a              |
|  7 | Dame en a7, mat en coin        | Dame       | Qa7# — roi blanc couvre b8 depuis c7    |
|  8 | Mat d'Anastasie                | Tour+Cav  | Rxh7# — cavalier couvre g8, roi g7      |

---

## Mat en 2 — `lessons_mat2.lua` (7 puzzles)

| #  | Titre                           | Idée                                              |
|----|---------------------------------|---------------------------------------------------|
|  9 | Sacrifice de dame, mat en 2     | Qxa7+ puis Rc8#                                   |
| 10 | Sacrifice de dame en e8         | Qe8+! Rxe8 forcé puis Rxe8#                       |
| 11 | Échelle de tours (1)            | Ra7+ force Ka7→Kb8, puis Ra8#                     |
| 12 | Échelle de tours (2)            | Rc8+ force Ka7, puis Ra8#                         |
| 13 | Sacrifice de dame, variante     | Même thème que #10, position décalée              |
| 14 | Dame : forcer le roi en b1      | Qa4+ Ka→b1, puis Qa1#                             |
| 15 | Tour et roi, mat en 2 (variante)| Rc8+ Ka7, puis Ra8# — roi c6 couvre b7            |

---

## Tactique — `lessons_tactique.lua` (8 puzzles)

| #  | Titre                              | Thème         | Idée                                       |
|----|------------------------------------|---------------|--------------------------------------------|
| 16 | Fourchette du cavalier             | Fourchette    | Nc5+ attaque Ke6 et Ra6 simultanément      |
| 17 | Exploiter le clouage absolu        | Clouage       | Bb5 cloue Nc6 sur Ke8 → Bxc6+             |
| 18 | Enfilade de tour                   | Enfilade      | Rb6+ force le roi, puis Rxb2               |
| 19 | Attaque à la découverte            | Découverte    | Nf7+ découvre Re1 attaquant Qe7            |
| 20 | Fourchette cavalier roi+dame       | Fourchette    | Nf6+ attaque Ke8 et Qd7                    |
| 21 | Fourchette de la dame              | Fourchette    | Qe5+ donne échec et attaque Ra5            |
| 22 | Clouage sur colonne d              | Clouage       | Rd1 cloue Nd4 sur Kd8 → Rxd4              |
| 23 | Enfilade sur colonne f             | Enfilade      | Rf6+ force le roi, puis Rxf2               |

---

## Finale — `lessons_finale.lua` (7 puzzles)

| #  | Titre                          | Thème               | Idée                                           |
|----|--------------------------------|---------------------|------------------------------------------------|
| 24 | Roi et dame contre roi (1)     | Restriction         | Dame restreint, roi approche                   |
| 25 | Roi et dame contre roi (2)     | Rapprochement       | Roi s'approche pour matifier                   |
| 26 | Roi et tour contre roi         | Coupure             | Tour coupe le roi sur une rangée               |
| 27 | Opposition — case clé          | Opposition          | Roi escorte le pion, atteint e6                |
| 28 | Course à la promotion          | Course              | Roi blanc avance pour escorter                 |
| 29 | Position de Lucena — le pont   | Technique Lucena    | Tour en e-file, barrage (pont)                 |
| 30 | Position de Philidor           | Technique Philidor  | Roi actif, contrôle des cases clés avec la tour|

---

## Mat en 3 — `lessons_mat3.lua` (5 puzzles)

Sources : Lichess puzzle 4Ftq1, études j0Ay9fAz et JrwLZArS. Puzzles 34-35 : noirs jouent.

| #  | Titre                          | Thème                          | Idée                                         |
|----|--------------------------------|--------------------------------|----------------------------------------------|
| 31 | Tour et roi — couloir          | Roi actif + tour               | Kxg6 ouvre le couloir, Ra8+ puis Rxf8#       |
| 32 | Sacrifice de fou, mat du cavalier | Sacrifice + mat étouffé     | Bc6! bxc6 Kc8 c5 Nc7#                       |
| 33 | Deux fous — mat en coin        | Restriction progressive        | Bf6-a1, Be5+, Bc6# — deux fous convergent    |
| 34 | Sacrifice de tour, mat de dame | Sacrifice + corridor (noirs)   | Rxg2+ Kxg2 Qxh3+ Kg1 Qh1#                   |
| 35 | Sacrifice de dame, mat de tour | Sacrifice + cavalier (noirs)   | Qxh2+ Kxh2 Nf3+ Kh3 Rh4#                    |

## À implémenter — Ouverture (prévu)

| #  | Titre (prévu)              | Thème              |
|----|----------------------------|--------------------|
| 37 | Gambit du roi              | e4 e5 f4           |
| 38 | Défense sicilienne         | e4 c5              |
| 39 | Ruy Lopez                  | e4 e5 Nf3 Nc6 Bb5  |
| 40 | Piège de l'ouverture       | Éviter les pièges  |
