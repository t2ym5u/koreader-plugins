# ROADMAP

Améliorations planifiées sur la flotte de plugins KOReader. Établi le
2026-09-30 à partir d'un audit de l'état réel du code (voir « Constat »
sous chaque phase — ce sont des faits vérifiés, pas des suppositions).

Ordre = rapport gain/effort décroissant. Chaque phase est indépendante et
livrable seule.

## État au 2026-09-30

Les cinq phases sont livrées, chacune taggée et publiée plugin par plugin.

| Phase | Objet | Portée |
|---|---|---|
| A ✅ | Grilles sudoku solvables par pure logique | `sudoku-common` + 7 variantes |
| B ✅ | Bouton Astuce sur la famille sudoku | 7 plugins |
| C ✅ | Bouton Astuce générique | `game-common` + 18 plugins |
| D ✅ | Dictionnaires anglais | 4 plugins |
| E ✅ | IA des jeux d'opposition | 6 plugins |

Ce qui reste est listé sous « Reste à faire » de la phase E et sous « Hors
phases » en fin de document : rien de commencé, tout mesuré ou constaté.

Les bancs d'essai qui ont servi à la phase E sont dans
`spec/ai_harnesses/` — leur README explique les deux façons de se tromper en
mesurant une IA ici, toutes deux rencontrées.

---

## Phase A — Grilles sudoku solvables par pure logique ✅ FAIT (2026-09-30)

**Constat (mesuré, pas supposé).** `createPuzzle` garantissait l'*unicité* de
la solution et rien de plus. La difficulté n'était qu'un nombre d'indices :

```lua
local ratios = { easy = 0.43, medium = 0.56, hard = 0.65, expert = 0.72 }
```

Mesure sur 20 grilles 9×9 par difficulté, avant le changement :

| Difficulté | Grilles exigeant de **deviner** | Palier réellement requis |
|---|---|---|
| easy | 0/20 | palier 1 |
| medium | 0/20 | palier 1 |
| hard | 1/20 | palier 1 |
| **expert** | **7/20 (35 %)** | palier 1 |

Donc deux défauts distincts : plus d'un tiers des grilles « expert » ne se
résolvaient qu'à l'essai-erreur, et les quatre étiquettes décrivaient la même
expérience avec des nombres d'indices différents.

**Livré.**

1. `sudoku-common/logic_solver.lua` — solveur humain à base de candidats,
   générique sur les « unités » (lignes, colonnes, boîtes **et**
   `extra_regions`, donc sudokux/windoku sans code spécifique) :

   | Palier | Techniques |
   |---|---|
   | 1 | single nu, single caché |
   | 2 | candidats verrouillés, paire nue |
   | 3 | paire cachée, triplet nu, triplet caché, quadruplet nu |
   | 4 | X-Wing, Swordfish, XY-Wing |

2. L'oracle de creusement de `createPuzzle` est devenu « ce qui reste est-il
   encore déductible avec le jeu de techniques autorisé ? ». Comme une grille
   résoluble par pure logique a forcément une solution unique (chaque
   déduction est forcée), ce test **remplace** `countSolutions(...) == 1` au
   lieu de s'y ajouter.

3. `createPuzzle` retourne en second une table d'info (`tier_cap`, `max_tier`,
   `counts`, `clues`). `max_tier` est le palier réellement exigé : il peut
   être inférieur au plafond (une grille 4×4 n'a pas la place pour un X-Wing),
   et c'est reporté honnêtement plutôt que maquillé.

**Résultat.** 0 grille exigeant de deviner, toutes tailles et toutes
difficultés confondues. Et le générateur est nettement **plus rapide**, la
propagation de contraintes rejetant une impasse bien avant un backtracking
complet :

| Grille | Avant | Après |
|---|---|---|
| 12×12 expert | 3,46 s | **0,13 s** |
| 16×16 expert | > 60 s | **1,09 s** |
| 9×9 expert | 0,01 s | 0,04 s |

Gradient d'indices obtenu en 9×9 : 47 / 36 / 29 / 25 (easy → expert).

**Portée réelle.** 7 plugins via le symlink `common/` → `sudoku-common/` :
`sudoku`, `sudokux`, `windoku`, `thermosudoku`, `arrowsudoku`,
`sandwichsudoku`, `betweenlines`. Pour les variantes à contraintes
additionnelles (thermomètres, flèches, sommes sandwich, lignes), la garantie
porte sur la logique du sudoku *classique* seule — leurs indices spécifiques
restent une aide en plus, jamais une béquille nécessaire.

**Non couvert :** `sudokukiller` n'appelle pas `createPuzzle`, il a son propre
générateur par cages (ses commentaires reconnaissent déjà que la déductibilité
y dépend de la géométrie tirée). À traiter séparément — le solveur devrait
apprendre les contraintes de cage pour cela.

**Tests.** `sudoku-common/test_logic_solver_spec.lua`, 27 cas : techniques sur
grilles vérifiées à la main, détection de contradiction, plafond de palier,
**soundness** (aucune technique ne pose jamais une mauvaise valeur ni
n'élimine le bon candidat, vérifié contre la solution sur toutes les tailles),
garantie de déductibilité par taille × difficulté, variantes à régions
supplémentaires, et une grille-témoin réelle produite par l'ancien générateur —
unique mais indéductible — que le nouveau ne peut plus émettre. Les 62 tests
préexistants des 8 plugins sudoku passent toujours.

**Reporté.** La symétrie rotationnelle des indices (esthétique « grille
publiée ») : elle change l'allure de toutes les grilles existantes, ce qui
mérite une décision explicite plutôt qu'un effet de bord. À reprendre avec un
réglage dédié.

---

## Phase B — Bouton Astuce sur la famille sudoku ✅ FAIT (2026-09-30)

**Constat.** Deux plugins seulement avaient déjà un bouton astuce
(`chesscourse`, texte d'aide stocké par leçon ; `wordladder`, révèle le mot
suivant d'un chemin le plus court). Aucun sudoku n'en avait.

**Livré.** Le solveur de la Phase A donne la *bonne* astuce gratuitement : pas
« voici la valeur », mais la déduction disponible et son nom.

`logic_solver.nextPlacement()` — `nextStep()` seul a la mauvaise forme pour un
bouton d'aide : plus de la moitié des techniques ne font qu'éliminer des
candidats, et « on peut exclure un 4 ici » ne sert à rien à qui ne note pas ses
candidats. `nextPlacement` avance donc le solveur à travers ces étapes
préparatoires et s'arrête à la première case *remplissable* — une astuce est
toujours actionnable.

Trois appuis, dans `BaseScreen:onHint` :

1. **où chercher** — nomme la ligne / colonne / bloc qui va céder ;
2. **pourquoi** — nomme la technique et le chiffre, et sélectionne la case ;
3. **la valeur** — l'écrit, annulable comme n'importe quel coup.

Le niveau est déduit en comparant la case visée d'un appui à l'autre, pas
stocké : si le joueur a résolu cette case lui-même entre-temps, l'astuce
suivante repart au niveau 1 au lieu de rester bloquée sur un état périmé.

Garde-fou important : `BaseBoard:findWrongEntry()` refuse toute astuce tant
qu'une valeur saisie contredit la solution. Sans cela le solveur déduirait
depuis une prémisse fausse et donnerait une réponse fausse avec aplomb —
vérifié, ce n'est pas théorique.

**Portée.** 7 plugins. `sudokukiller` est délibérément **exclu** : le solveur
ne connaît que lignes/colonnes/blocs/régions, alors que l'information d'une
grille killer vit dans les sommes de cages. Mesuré de easy à expert, la
déduction classique y place **moins d'1 case sur 65 à 80** avant de caler — un
bouton qui ne fait rien est pire que pas de bouton. Le code partagé est en
place ; il suffira de réintroduire la ligne du bouton quand le solveur saura
lire les cages (même prérequis que pour la garantie Phase A sur ce plugin).

**Correctif i18n au passage.** `common/base_screen.lua` appelait `gettext`
directement, alors que ses ~19 chaînes ne sont connues que de l'`i18n.lua`
vendu dans chaque plugin. Vérifié dans l'émulateur : le gettext de KOReader
renvoie ces chaînes inchangées en français. Toute l'interface partagée des
8 plugins restait donc anglaise sur un appareil français (« Hide result to
keep playing. », « Started a new game. »…). `base_screen` passe désormais par
`i18n` quand il est joignable, avec repli sur l'ancien shim.

**Vérification.** 34 cas dans `test_logic_solver_spec.lua` (dont : une grille
menée à son terme uniquement par astuces, l'annulabilité, le refus quand la
solution est affichée, le refus sur saisie fausse). Puis un test d'intégration
dans l'**émulateur KOReader** avec la vraie chaîne de modules : les 7 plugins
résolvent leur grille de bout en bout par astuces successives, `windoku` (4
régions) et `sudokux` (2 diagonales) compris ; `sudokukiller` renvoie son
message d'échec sans planter ; les messages sortent correctement en français.

La rangée de boutons passe de 4 à 5. Mesuré avec le moteur de mise en page de
KOReader lui-même (il ne tronque pas : il réduit la police) : à la largeur
réelle du pavé, aucun texte n'est coupé en EN/FR/DE/ES ; seuls les libellés
déjà longs perdent un peu de corps (« Notes : inactif » 18 → 16,
« Rückgängig » 18 → 14). Le rétrécissement existait déjà à 4 boutons sur les
mises en page étroites — le 5ᵉ bouton déplace le seuil, il n'introduit pas un
mode de défaillance nouveau.

---

## Phase C — Bouton Astuce générique pour les autres puzzles ✅ FAIT (2026-09-30)

*(Correction du premier audit : j'avais annoncé qu'aucun jeu n'avait de bouton
astuce. C'était faux — `chesscourse` et `wordladder` en ont un depuis
toujours ; mes premières recherches ne ramenaient que le champ de métadonnées
`sorting_hint`. Ces deux-là sont hors périmètre.)*

**La prémisse de cette phase était fausse.** J'avais écrit « un helper partagé
dans `game-common` + ~15 lignes par écran suffit ». À l'inspection, les
modèles d'état n'ont rien de commun : `binairo` garde une grille de valeurs,
`hitori` une grille d'états plus une grille booléenne de solution, `shikaku`
des rectangles, `bridges` des arêtes. Un « révéler `self.solution[r][c]` »
générique ne marche pas.

**Ce qui est réellement générique**, c'est l'interaction, pas les données. D'où
`game-common/hint.lua` : un plateau se décrit **une fois** par une table de
spec et reçoit `findHint`/`applyHint` ; `ScreenBase:onHint` pilote le reste.
Coût réel : ~8 lignes par plateau, 1 ligne par écran.

```lua
Hint.install(BinairoBoard, {
    isEmpty     = function(v) return v == nil end,   -- ici 0 est une vraie valeur
    getUser     = function(b, r, c) return b.cells[r] and b.cells[r][c] end,
    getSolution = function(b, r, c) return b.solution[r][c] end,
    isGiven     = function(b, r, c) return b.given[r] and b.given[r][c] end,
    setCell     = function(b, r, c, v) return b:setCellValue(r, c, v) end,
})
```

**Deux taps**, pas un : le premier dit quelle case va céder, le second agit.
L'écart est tout l'intérêt — qui sait où regarder trouve en général le reste
seul. Et une case qui **contredit** la solution est toujours signalée avant
qu'une nouvelle soit révélée : un joueur qui s'est trompé doit le savoir avant
de bâtir dessus. Sur une erreur, l'astuce **vide** la case au lieu de la
résoudre.

Choix déterministe assumé : `ScreenBase` distingue « montre-moi où » de
« remplis-la » en regardant si la cible a bougé, donc un tirage aléatoire
remettrait à l'étape 1 à chaque appui et ne révélerait jamais rien. La case
proposée est celle qui a le plus de voisins déjà remplis — heuristique de
présentation, pas une preuve de déductibilité (il n'y a pas de solveur ici,
contrairement à `sudoku-common`).

**Deux pièges par plugin**, qui ont demandé de lire la logique de vérification
existante plutôt que de deviner :

- `isEmpty` — la valeur « vide » par défaut (nil / 0 / false) est fausse dès
  que l'une d'elles est une vraie valeur. Le `0` de `binairo` en est une ;
  sans surcharge, l'astuce proposait de « remplir » des cases déjà répondues.
- `equals` — là où le jeu a des annotations facultatives (croix de `nonogram`,
  point de `lightup` ou de `starbattle`), comparer l'état exact ferait passer
  des notes parfaitement correctes pour des erreurs.

**Livré : 18 plugins.**

| Groupe | Plugins |
|---|---|
| Grilles de chiffres | `binairo`, `fillomino`, `hidato`, `numbrix`, `skyscraper`, `futoshiki`, `kenken`, `rippleeffect`, `suguru` |
| Grilles à noircir / marquer | `nonogram`, `colornonogram`, `cave`, `tapa`, `hitori`, `nurikabe`, `lightup`, `battleship`, `starbattle` |

Trois plateaux n'avaient aucun accesseur de cellule (`cave`, `colornonogram`,
`tapa`) et un quatrième non plus (`starbattle`) : ils en ont reçu un, calqué
sur leur méthode de cycle existante et passant par le même historique
d'annulation.

**Non couvert, et pourquoi.**

- `bridges` (arêtes), `numberlink` (chemins), `shikaku` (rectangles),
  `masyu` (boucle) — l'unité de jeu n'est pas la cellule. Chacun demande une
  astuce sur mesure (« voici un pont », « voici un rectangle »), pas ce
  module.
- `minesweeper`, `slitherlink`, `tents` — ne stockent pas `self.solution` du
  tout ; il faudrait la conserver à la génération avant d'espérer révéler
  quoi que ce soit.

**Vérification.** 12 tests unitaires sur `hint.lua` (déterminisme, priorité
aux erreurs, cases données intouchables, `isEmpty`/`equals` personnalisés,
grille menée à son terme). Puis, dans l'**émulateur KOReader**, les 18 plugins
résolvent leur grille de bout en bout par astuces successives — et comme
`findHint` signale aussi toute divergence, « plus aucune astuce » prouve
l'égalité avec la solution. Les suites existantes des 18 passent sans
régression.

---

## Phase D — Dictionnaires anglais ✅ FAIT (2026-09-30)

**Constat.** Asymétrie d'un facteur ~25 entre listes FR et EN :

| Jeu | EN avant | FR |
|---|---|---|
| `boggle`, `boggleparty`, `numletters` (même fichier) | **1 837** | 47 435 |
| `wordle` | **715** (en dur dans `board.lua`) | 5 884 |

Un joueur anglophone se faisait donc refuser des mots parfaitement valides.

**Source retenue : ENABLE**, la liste maîtresse formellement versée au domaine
public par ses auteurs comme « don à la communauté des jeux de mots », avec
pour seule demande d'en créditer l'origine (fait dans l'en-tête de chaque
fichier). Le `/usr/share/dict/words` local a été écarté après examen : son
échantillon de mots de 5 lettres est truffé d'archaïsmes (*sycee*, *khoja*,
*rorty*, *pooka*…), mauvais pour la validation comme pour les réponses.

### boggle / boggleparty / numletters

`words_en.lua` passe de 1 837 à **105 145 mots** (3 à 9 lettres). La borne
haute est 9 parce que `numletters` tire 9 jetons ; la recherche de `boggle`
s'arrête d'elle-même à 8.

Effet mesuré, mêmes 20 grilles avant/après : **24,0 → 108,5 mots trouvables
par grille (×4,5)**, soit désormais le même ordre de grandeur que le français
(79/grille).

Coût : ~7,4 Mo de table Lua quand un jeu de mots est ouvert (contre ~3,3 Mo
pour le français), chargement 0,02 s ici. Les trois plugins passent par
`require("words_en")`, donc une seule copie en mémoire même en enchaînant les
jeux.

`numletters:findSolutions()` balaie tout le dictionnaire à chaque manche ; avec
105 k mots, le `word:upper()` par entrée dominait le coût. La table de
disponibilité est désormais construite en minuscules, comme le dictionnaire :
**33 ms → 9 ms**, mêmes solutions.

### wordle

Le problème n'était pas le nombre de réponses mais la **validation** : une
seule liste de 715 mots servait à la fois de vivier de réponses et de
définition de « est-ce un mot ». `STARE`, `TEARS`, `IRATE`, `NOTES`, `QUIRK`,
`FJORD`, `LYMPH`, `ADIEU` étaient tous refusés.

Séparation en deux listes, comme le fait Wordle lui-même :

- `words_en.lua` — **2 307 réponses**, intersection d'ENABLE et de SCOWL
  taille 35 (mots courants ; licence permissive de Kevin Atkinson, notice
  conservée), moins les pluriels et 3ᵉ personnes du singulier (réponses trop
  faciles) et les mots inadaptés à une grille de jeu — tous restant des
  saisies valides. Les 715 mots historiques sont conservés tels quels, ce qui
  préserve notamment `EMAIL`, absent d'ENABLE.
- `guesses_en.lua` — **6 330 mots** acceptés en saisie mais jamais tirés comme
  réponse.

Le chargeur est désormais unifié : `words_<lang>.lua` + `guesses_<lang>.lua`
optionnel. Le français, qui n'a pas de fichier de saisies, se comporte
exactement comme avant. Au passage, `board.lua` perd la table française morte
qui y était inlinée et passe de ~470 à 252 lignes.

**Dette corrigée en passant.** Les README de `boggle`, `boggleparty` et
`wordle` annonçaient des dictionnaires « EN, FR, DE, ES » : seuls EN et FR ont
jamais existé (`LANG_ORDER = { "en", "fr" }`). Celui de `wordle` annonçait
aussi une longueur de mot configurable (4/5/6) que rien ne règle — et ce
chemin menait à un `math.random(0)`, toutes les listes étant en 5 lettres ;
une garde a été ajoutée.

**Vérification.** 17 tests wordle et 16/16/11 pour boggle/boggleparty/
numletters, plus un test d'intégration dans l'émulateur KOReader : les mots
autrefois refusés sont acceptés, `ZZZZZ` reste refusé, le français est
inchangé, et `numletters` sort bien des solutions longues (*cowrite*, 7).

**Reste à faire.** Le français est plafonné à 7 lettres, si bien que ses
manches de `numletters` ne peuvent pas produire de solution de 8 ou 9 lettres —
l'asymétrie est désormais inversée. À reprendre avec une liste FR CC0 plus
longue.

---

## Phase E — IA des jeux d'opposition ✅ FAIT (2026-09-30)

### `gomoku` ✅ FAIT (2026-09-30) — mais pas pour la raison annoncée

**Mon constat de départ était faux.** J'avais écrit « minimax *sans*
alpha-bêta (cf. commentaire l.265) ». J'avais lu le commentaire, pas le code :
l'élagage alpha-bêta était bien là. Le commentaire, lui, était périmé.

Les vraies faiblesses, trouvées en lisant :

- **À la racine, alpha repartait de −∞ pour chaque candidat**, ce qui jette
  toutes les coupes entre frères — l'essentiel de ce à quoi sert alpha-bêta.
- Le test de cinq-en-ligne était recopié trois fois, sous trois formes
  légèrement différentes.
- Les candidats n'étaient ordonnés nulle part dans la recherche, alors que
  l'élagage est proportionnel à la qualité de l'ordre.

**Résultat livré : force égale, ~3× plus rapide** (0,11 s/coup contre 0,31 s à
profondeur 3). Sur un CPU e-ink, c'est la différence entre un niveau
« difficile » jouable et une attente.

**Ce que la mesure a démenti.** Trois tentatives d'amélioration de la *force*
ont toutes échoué, et c'est le résultat le plus utile de cette phase :

| Tentative | Résultat sur 20 parties |
|---|---|
| Échelle de menaces plus nette (open four ≫ four ≈ open three) | **14-6 contre** — nettement plus faible |
| Plafonner les candidats internes (top-16 par proximité) | 13-7 contre — le bon coup de blocage sortait du top-16 |
| Chercher plus profond (prof. 4 au lieu de 2) avec la version plafonnée | 11-9, sans effet |

En revanche, l'ancienne IA à profondeur 3 bat la même à profondeur 2 (12-8) :
la profondeur aide, mais elle coûte 24× plus cher. C'est exactement ce que le
gain de vitesse achète.

**Leçon méthodologique.** Mon premier banc d'essai annonçait 10-0 en faveur de
la nouvelle version. C'était un artefact : les deux moteurs étant
déterministes, « 10 parties » n'étaient que 2 parties distinctes répétées 5
fois. Avec des ouvertures aléatoires, le même test donne 11-9 — c'est-à-dire
rien. Toute mesure d'IA dans ce dépôt doit varier les ouvertures.

**Conséquence pour la suite : la recherche n'est pas le goulot, l'évaluation
l'est.** Le plan ci-dessous, qui misait surtout sur des gains de recherche,
est à reconsidérer jeu par jeu avec des mesures avant/après.

### `othello` ✅ FAIT (2026-09-30)

Le seul point du plan initial qui promettait une certitude plutôt qu'une
heuristique — et c'est le seul qui a tenu.

**Livré : ~2 parties gagnées sur 3 contre la version précédente, en deux fois
moins de temps par coup** (38-21 et une nulle sur 60 parties à ouvertures
aléatoires ; 0,015 s/coup contre 0,029 s à profondeur 4).

- **Solveur de fin de partie exact.** À 10 cases vides ou moins, l'arbre
  restant tient dans le budget : le moteur cesse d'évaluer et joue la position
  jusqu'au dernier pion. Son choix final est *prouvé*, plus estimé.
- **Seuil fixé à 10, pas plus.** À 13 il joue marginalement mieux mais un coup
  a pris **10,8 s** sur un poste de bureau — une minute devant l'écran sur un
  CPU e-ink. À 10, le pire coup mesuré est à 0,21 s.
- **Même bug de racine qu'à `gomoku`** : alpha et bêta repartaient de leurs
  extrêmes à chaque candidat, jetant toutes les coupes entre frères. Corrigé —
  c'est de là que vient le gain de vitesse.

Les pénalités de cases X et C et les poids par phase n'ont pas été tentées :
après l'expérience `gomoku`, toucher une évaluation calibrée sans mesure est
le meilleur moyen de livrer une régression, et le solveur exact apportait déjà
le gain visé.

### `connect4` ✅ FAIT (2026-09-30)

Même bug de racine. Corrigé, **jeu identique** — vérifié : les deux versions
choisissent la même colonne sur 289 positions aléatoires sur 289 — pour un
tiers de temps en moins (0,006 s/coup contre 0,009 s).

Profondeurs laissées telles quelles. Chercher plus profond aide bien ici
(prof. 7 bat prof. 5 par 10-6-4, prof. 8 bat prof. 7 par 11-7-2) mais la
prof. 8 fait passer le pire coup de 0,47 s à 1,47 s, et la prof. 9 à 15,5 s.
L'ordonnancement centre-d'abord que le plan proposait d'ajouter existait déjà.

### `chess` ✅ FAIT (2026-09-30)

Le plus gros gain de vitesse des quatre : **jeu identique, en un quart du
temps**. Sur « difficile », le pire coup passe de 4,2 s à environ 1 s.

Subtilité propre à ce moteur : il collecte délibérément les coups à score égal
pour en tirer un au hasard (de la variété). Propager la fenêtre naïvement
aurait fait échouer bas ces coups et cette collecte aurait cessé de trouver
des égalités — silencieusement. La fenêtre est donc élargie d'une unité de
part et d'autre, ce qui est sûr parce que `_evaluate()` est entière.

Profondeurs inchangées (1/2/3). La prof. 4 semble plus forte (3-1 et 6
indécises sur 10 parties) mais son pire coup a pris 14,8 s.

### `go` ✅ FAIT (2026-09-30) — IA créée

Le jeu n'avait aucune IA. Celle-ci est délibérément **débutante** plutôt
qu'une mauvaise tentative de moteur fort : ni recherche ni playouts. Une
recherche au go ne vaut que ce que vaut sa capacité à distinguer un groupe
vivant d'un groupe mort, et peu profonde sur un CPU e-ink elle joue moins bien
que des règles de conduite claires.

Ce qu'elle comprend, c'est ce qui fait perdre les débutants : les captures
disponibles, ses propres groupes en atari, les groupes adverses qu'elle peut
mettre en atari, les pierres jouées droit dans la capture, le bord — et
surtout ne jamais combler ses propres yeux, qui est la façon dont un débutant
tue un groupe vivant. Le test d'œil ignore les diagonales, donc elle ne
reconnaît pas les faux yeux : simplification connue, pas un oubli.

**19-1 contre un joueur aléatoire sur 20 parties en 9×9, à 0,001 s/coup.**
Elle joue les Blancs pour laisser le premier coup au joueur.

### `backgammon` ✅ FAIT (2026-09-30) — IA créée + deux règles manquantes

Trois manques que le README admettait, dont deux étaient des **règles**, pas
des fonctionnalités :

- Un tour doit utiliser autant de dés qu'il le peut légalement, et quand un
  seul des deux est jouable ce doit être le plus grand. Ni l'un ni l'autre
  n'était appliqué : on pouvait discrètement esquiver la moitié gênante d'un
  tirage gênant. Les deux découlent d'une seule question — combien de dés
  peut-on encore jouer d'ici — résolue par une petite anticipation.
- Le tirage d'ouverture décide qui commence, au lieu que les Blancs partent
  toujours. Volontairement hors de `reset()`, qui reste déterministe pour
  qu'un test ou un rechargement puisse poser une position sans que les dés
  décident de quoi que ce soit.
- **IA** : un tour au backgammon est une *séquence*, pas un coup. Le moteur
  énumère toutes les séquences légales que les dés permettent et évalue la
  position que chacune laisse — course, points faits et primes, blots pondérés
  par la facilité à les frapper, pions à la barre et sortis. Aucune
  anticipation du jet adverse : moyenner sur 21 jets coûte bien plus que ça ne
  rapporte ici. **20-0 contre un joueur aléatoire**, 0,02 s/tour, 0,84 s au
  pire (doublé, quatre pions à placer).

Un bug mérite d'être nommé : `_restore()` reconstruisait la liste des dés dans
une table neuve pendant que `_maxPlayable()` l'itérait, laissant l'itérateur
parcourir une copie orpheline — il n'examinait donc que le premier dé. La
règle *paraissait* implémentée et ne l'était pas.

Toujours pas de cube de doublement.

### Reste à faire

| Jeu | État |
|---|---|
| `checkers` | alpha-bêta profondeur 5, correct — rien à faire |
| tous | mutualisation dans un `game-common/search.lua` (alpha-bêta + table de transposition + budget temps) au lieu de cinq implémentations. Les bancs d'essai tête-à-tête à ouvertures aléatoires devraient y aller aussi : ce sont eux qui ont évité de livrer plusieurs régressions. |
| `backgammon` | cube de doublement (fonctionnalité, pas règle manquante) |

**Bilan de la phase.** Le bug de racine — alpha réinitialisé à chaque candidat,
qui jette toutes les coupes entre frères — était présent dans **les quatre**
moteurs existants. Il achète de la vitesse, jamais de la force. Le seul gain
de force mesuré sur un moteur existant vient d'`othello`, parce qu'il remplace
une estimation par une preuve. Et sur chacun des quatre, la profondeur
supplémentaire que la vitesse rendait envisageable a été refusée sur le pire
temps de coup, pas sur la moyenne.

---

## Hors phases — dette repérée en passant

- `scripts/check_sudoku_common_drift.sh` documente des divergences
  per-plugin de `common/` qui n'existent plus : les 8 variantes sont
  aujourd'hui des symlinks committés vers `sudoku-common/` (mode git
  `120000`). Le script et ses commentaires sont obsolètes.
- ~~`spec/README.md` affirme que seuls `sudoku`, `sudokukiller` et `hanoi`
  ont besoin du module LuaJIT `bit`~~ — corrigé en Phase A : les 8 variantes
  sudoku partagent `puzzle_generator.lua`, qui l'exige, et `sudoku-common/`
  a désormais sa propre spec soumise à la même contrainte.
- `dashboard` et `opdsdir` n'ont pas de `.github/workflows/release.yml` :
  `scripts/sync_workflow.sh` les a manqués, et ils ne publient donc aucune
  release depuis leur propre dépôt (le monorepo, lui, les publie normalement).
  Découvert le 2026-09-30 quand `binairo` a livré une v1.1.0 sans release —
  corrigé pour lui, pas pour les deux autres. Noter aussi que ce workflow ne se
  déclenche que sur les chemins `*.lua` : ajouter le fichier de workflow ne
  suffit pas à rattraper la release en cours, il faut un `workflow_dispatch`.
- `go.koplugin/README.md` : capture d'écran manquante
  (« *(Screenshot to be added.)* »).
- `galaxies` reste bloqué sur un bug de générateur structurel (n=8), cf.
  `docs/generator_robustness_audit.md`.
