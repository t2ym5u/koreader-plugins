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

**`sudokukiller` : traité le 2026-09-30.** Il n'appelle pas `createPuzzle`, il
a son propre générateur par cages. Le solveur lit désormais les sommes
(`opts.cages`) et joue les techniques killer : analyse combinatoire de cage,
dernière case d'une cage, et la règle des 45 (innies/outies).

| Difficulté | Déductible avant | Après | Indices |
|---|---|---|---|
| easy | 0/4 | **4/4** | 16 |
| medium | 0/4 | **4/4** | 15 |
| hard / expert | 0/4 | 0/4 — **délibérément** | 1-2 |

Hard et Expert restent **genre-purs** : un vrai Killer Sudoku ne donne aucun
chiffre, les cages disent tout, et `test_board_spec.lua` le fige. Leur ajouter
les indices nécessaires à la déductibilité en ferait un autre jeu — j'ai essayé
et cassé ce test, à raison. Le bouton Astuce y annonce donc honnêtement qu'aucune
déduction purement logique n'est disponible, plutôt que d'en inventer une.

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

**Suite livrée le 2026-09-30 — 4 plugins de plus, soit 22.**

- ~~`minesweeper`, `slitherlink`, `tents` ne stockent pas `self.solution`~~ —
  **faux, et c'est mon relevé qui l'était** : je n'avais cherché que le nom
  `self.solution`. Ils la stockent sous `mines`, `h_sol`/`v_sol` et
  `tents_sol`. `tents` et `minesweeper` utilisent le helper à cases tel quel
  (une correction a été nécessaire : les grilles de `minesweeper` sont
  rectangulaires, le helper supposait `board.n` carré). Son bouton reste muet
  avant le premier clic, les mines n'étant posées qu'à ce moment — sinon il
  « prouverait » n'importe quelle case sûre.
- `slitherlink` et `shikaku` ont reçu une astuce **sur leur propre unité** :
  un segment (horizontal ou vertical — les deux grilles d'arêtes sont
  indépendantes, « L3C4 » seul ne dirait pas laquelle) et un rectangle entier
  (révéler une case ne dirait presque rien, le jeu portant sur l'emplacement
  des bords). `game-common` v1.4.0 ajoute pour cela le hook
  `ScreenBase:describeHintStep` et un champ `tag` distinguant deux coups à la
  même position.

Le libellé vit dans l'écran, pas dans le plateau : un plateau qui formate du
texte d'interface entraîne `ffi/util` de KOReader dans chaque test unitaire
headless qui le touche — ce qui a cassé les specs de `slitherlink` et
`shikaku` quand je l'avais fait dans l'autre sens.

**Terminé le 2026-09-30 — 26 plugins au total.** `bridges`, `numberlink` et
`masyu` ont eux aussi leur astuce :

- `masyu` s'est révélé être une simple grille de booléens (`user_path`), la
  boucle-solution n'étant qu'une liste de cellules : le helper standard
  s'applique.
- `bridges` travaille en ponts entre deux îles. Particularité : **une erreur y
  est impossible** — `tapBridge` plafonne chaque liaison au compte de la
  solution, le joueur ne peut donc qu'être *en retard*, jamais en trop. C'est
  le seul puzzle de la collection sans branche « erreur ».
- `numberlink` révèle un **chemin entier**. Sa solution est pourtant bien une
  grille de couleurs, mais `path_cells[]` garde la route de chaque couleur dans
  l'ordre de parcours : écrire des cases isolées la désynchroniserait.

### Lisibilité sur e-ink monochrome

Remarque de l'utilisateur, vérifiée et fondée. `numberlink` et
`colornonogram` n'utilisent pas de RVB — ce sont déjà des niveaux de gris.
Mais les six teintes de `numberlink` sont espacées de 34/255, soit **environ
deux crans sur une dalle e-ink 16 niveaux** : deux chemins voisins ne se
distinguaient que par la nuance, ce qui sur un écran réflectif est souvent
impossible.

Corrigé : chaque chemin porte désormais **le chiffre de sa paire dans toutes
les cases qu'il traverse**, plus seulement à ses deux extrémités. L'identité ne
dépend plus des gris. Et la bordure « case fausse » était tracée en
`COLOR_GRAY` — exactement la teinte du chemin n°5, donc invisible sur celui-ci ;
elle est noire.

`colornonogram` n'a pas ce défaut : ses trois nuances sont espacées d'environ
85/255, soit cinq crans.

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

**Asymétrie inversée, puis corrigée (2026-09-30).** Le français plafonnait à
7 lettres : ses manches de `numletters` ne pouvaient pas produire de solution
de 8 ou 9 lettres alors que l'anglais le pouvait. La liste FR passe de 47 435 à
**132 778 mots** (3-9 lettres) : les 3-7 restent la liste CC0 Scrabble-valide
d'origine, les 8-9 viennent d'`an-array-of-french-words` (MIT), normalisés de
la même façon. Les deux langues couvrent désormais le tirage complet de 9
jetons. Coût : ~12,4 Mo de table Lua côté français contre 7,4 Mo côté anglais.

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
| `backgammon` | ~~cube de doublement~~ — **fait le 2026-09-30** (v1.2.0). Offert avant de lancer par le propriétaire du videau ; accepter double l'enjeu et transmet le videau, refuser met fin à la partie **à l'enjeu d'avant** — c'est tout l'intérêt du videau. Les parties sont désormais cotées : ×2 sur un gammon, ×3 sur un backgammon. Contre l'ordinateur il n'y a personne à qui passer l'offre, il répond donc lui-même (il prend sauf s'il est à plus d'un quart de retard au pip count) ; il ne propose jamais de doublement de sa propre initiative, car refuser de doubler ne fait jamais perdre une partie alors que doubler mal, si. |
| `checkers` | correct côté profondeur, **mais il a le même bug de racine que les quatre autres** — voir ci-dessous |

### `game-common/search.lua` ❌ NON FAIT — décision argumentée

Le plan prévoyait de mutualiser les cinq alpha-bêta. **Je recommande de ne pas
le faire**, sur la base de ce que la phase E a mesuré.

Le squelette partagé pèse 191 lignes au total (chess 41, othello 42, connect4
45, gomoku 32, checkers 31) — mais les cinq moteurs diffèrent précisément sur
la dimension critique, la façon d'avancer et de défaire un état :

| moteur | avance l'état par |
|---|---|
| `chess` | `_applyMove`/`_undoMove` sur place, avec quiescence et killer moves |
| `othello` | une grille **neuve** par coup |
| `connect4` | une grille **neuve** par coup |
| `gomoku` | écriture sur place dans la grille |
| `checkers` | un **objet de jeu neuf** par coup (`clone`) |

Et chacun porte une règle propre *dans* la boucle : `checkers` ne consomme pas
de profondeur sur un saut multiple, `othello` saute un joueur sans coup sans
consommer de tour, `connect4` court-circuite les gains et blocages immédiats,
`gomoku` ne plafonne ses candidats qu'à la racine. Un squelette générique
devrait passer par des closures pour coups/appliquer/défaire/évaluer — exactement
là où `chess` tire sa vitesse — et rouvrir cinq crochets pour ces
particularités. Plus de code au total, plus lent pour `chess`, et un risque de
régression dont j'ai la preuve directe : sur `gomoku` seul, trois modifications
plausibles ont été mesurées comme des reculs.

**Ce que la duplication a réellement coûté, en revanche, est démontrable : le
même bug de racine existait dans les cinq moteurs** — alpha réinitialisé à
±∞ pour chaque candidat, ce qui jette toutes les coupes entre frères. Quatre
sont corrigés et livrés. Le cinquième, `checkers`, appartient à `kbarni` et
non à ce compte : je l'ai corrigé et mesuré localement, puis **remis en
l'état** — je ne pousse pas chez un tiers sans votre accord.

Mesure sur 23 positions aléatoires à profondeur 5 : **coup identique 23/23,
temps ramené à 63 %**. Le correctif tient en un argument, dans
`CheckersAI.best_move` :

```lua
-- avant
local val = alpha_beta(child, next_depth, -INF, INF, ai_player)
-- après
local val = alpha_beta(child, next_depth, best_val, INF, ai_player)
```

À proposer en amont si vous le souhaitez.

**Bilan de la phase.** Le bug de racine — alpha réinitialisé à chaque candidat,
qui jette toutes les coupes entre frères — était présent dans **les quatre**
moteurs existants. Il achète de la vitesse, jamais de la force. Le seul gain
de force mesuré sur un moteur existant vient d'`othello`, parce qu'il remplace
une estimation par une preuve. Et sur chacun des quatre, la profondeur
supplémentaire que la vitesse rendait envisageable a été refusée sur le pire
temps de coup, pas sur la moyenne.

---

## Phase F — `arrowwords` : un vrai mots fléchés ❌ NON FAIT, et pourquoi

Demandé le 2026-09-30, évalué, **décliné en connaissance de cause**.

**État réel du plugin.** Le commentaire « Auto-generated puzzles (word+clue
bank crossed via greedy fill) » induit en erreur : il n'y a dans le code **ni
générateur ni banque d'indices**. Ces grilles ont été produites hors ligne puis
collées en dur. Le plugin embarque **17 grilles fixes**, point.

**Le verrou n'est pas le code, c'est la donnée.** Écrire le générateur (pose
des cases-définitions, flèches, mots croisés, remplissage) est tout à fait
faisable. Ce qui manque est une banque de couples mot/définition de qualité
mots fléchés. Mesure sur l'existant :

| | |
|---|---|
| cellules-indices dans les 17 grilles | 154 |
| indices **distincts** | **120** |
| « Note de musique » à lui seul | 13 occurrences |

Un générateur nourri de 120 indices produirait des grilles qui se répètent
lourdement — la même limite qu'aujourd'hui, simplement déguisée. Un vrai mots
fléchés demande de l'ordre de 2 000 entrées.

**Les sources automatiques ne conviennent pas.** Vérifié :

- `kaikki.org` (extraction Wiktionary) expose le français **défini en
  anglais** : inutilisable tel quel.
- Le Wiktionnaire français est en CC BY-SA (partage à l'identique, décision de
  licence qui vous revient) et ses gloses font de mauvais indices : circulaires
  (la définition contient le mot), formes fléchies (« Pluriel de… »), prose
  encyclopédique là où il faut une formule courte et univoque.
- Littré et l'Académie 8ᵉ sont dans le domaine public mais datent de 1873 et
  1935 : définitions longues et archaïques.

Transformer des gloses en indices de mots croisés est un travail de curation,
pas d'extraction.

**Ce qui débloquerait.** Une banque au format `{ mot, indice }` d'environ
2 000 entrées — écrite, achetée sous licence, ou constituée peu à peu. Le
générateur se construit ensuite en une session, et les 17 grilles fixes
deviennent un nombre illimité. Sans elle, le mieux honnête reste d'écrire à la
main d'autres grilles comme les 17 actuelles.

Le plugin reste donc mis de côté et son dépôt archivé.

---

## Phase G — `pluginmanager` : suppression sécurisée ✅ FAIT (2026-09-30)

Trouvé le 2026-09-30 en balayant ce qui restait. C'est le point le plus sérieux
de tout ce qui suit.

**3 322 lignes, 12 appels de suppression de fichiers (`os.remove`,
`lfs.rmdir`), zéro test.** C'est aussi le seul plugin qui écrit hors de son
propre répertoire, et il a déjà mordu une fois : le bug de portée de
« Tout supprimer » qui effaçait les plugins de KOReader lui-même (corrigé le
2026-08-04).

### Le garde-fou de `rm_rf` ne fait pas ce qu'il paraît faire

```lua
local function rm_rf(path)
    if not path:find(_plugins_dir, 1, true) then return end
```

`find(…, 1, true)` cherche une **sous-chaîne**, pas un préfixe. Vérifié :

| chemin | garde-fou |
|---|---|
| `…/koreader/plugins/sudoku.koplugin` | passe (voulu) |
| `…/koreader/plugins-backup/mes-sauvegardes` | **passe** |
| `…/koreader/plugins_old` | **passe** |
| `/tmp/ailleurs/…/koreader/plugins` | **passe** |

Un répertoire voisin dont le nom commence par celui des plugins est donc
supprimable. Le chemin vient de `_plugins_dir .. "/" .. entry.dir`, où
`entry.dir` est lu dans le `manifest.json` **récupéré sur le réseau** et n'est
pas assaini : un `dir` contenant `..` sortirait du répertoire sans que le
garde-fou s'y oppose. Ce n'est pas exploitable par un tiers aujourd'hui (le
manifeste est le vôtre), mais c'est de la donnée distante qui construit un
chemin de suppression.

**Corrigé** (v1.4.0). Le test est désormais ancré en préfixe avec séparateur
final, le répertoire des plugins lui-même n'est plus une cible supprimable,
tout segment `..` est refusé, et le nom est validé **là où le chemin est
construit** — pas seulement là où il est supprimé : une suppression au nom
douteux est annoncée comme refusée plutôt que d'échouer en silence.

### Le repli sans `lfs` n'échappe pas le chemin

```lua
os.execute("rm -rf " .. path)
```

Un chemin contenant une espace aurait donné deux cibles à `rm -rf` au lieu
d'une. **Corrigé** : le chemin est mis entre apostrophes simples, les
apostrophes internes étant fermées puis rouvertes.

**Complété le 2026-09-30.** `shellQuote` était appelé pour le `rm -rf` de la
ligne 592 et oublié pour le `mkdir -p` de la ligne 540, dans le même fichier,
sur la même branche de repli et depuis la même source distante. Corrigé.

### Le champ `files` du manifeste n'était pas gardé — et le zip non plus

`pathguard.lua` a été écrit pour le champ `dir` de `manifest.json`, et son
propre commentaire dit pourquoi : *« les chemins qu'il protège sont construits
depuis le champ `dir` de manifest.json, qui arrive par le réseau »*. Le même
raisonnement n'avait jamais été appliqué au champ **`files`**, ni aux entrées
d'une archive téléchargée. Trois sites écrivaient un chemin composé d'une
chaîne choisie ailleurs :

| Site | Source du chemin | Forme dangereuse |
|---|---|---|
| `ensureCommon` | `manifest.json` → `files[]` | `../../evil.lua` |
| `installPlugin` | `manifest.json` → `files[]` | `../../evil.lua` |
| `extract_archive` | entrée du zip téléchargé | `monplugin/../../evil.lua` |

Le troisième est le plus exposé — c'est un **Zip Slip** classique. Le test de
préfixe déjà présent (`entry.path:sub(1, #prefix) == prefix`) ne protège de
rien ici : `monplugin/../../evil.lua` **commence bien** par `monplugin/`, et
ce qui en est extrait est `../../evil.lua`.

**Corrigé** : `PathGuard.filePath(root, rel)` construit le chemin puis le
refuse s'il n'a pas atterri sous `root`. `isSafeName` ne convenait pas — les
entrées portent légitimement un sous-répertoire (`common/i18n.lua`), ce qu'un
nom de plugin n'a pas le droit de faire. Les trois sites passent par lui et
remontent une erreur nommée au lieu d'écrire. `test_pathguard_spec.lua` monte
de 15 à 29 cas ; le dernier vérifie que `filePath` ne rend jamais un chemin
qu'`isWithin` refuserait, pour que les deux gardes ne puissent pas diverger.

**Portée réelle** : le manifeste est servi depuis le dépôt GitHub du projet en
HTTPS, donc rien n'était déclenchable à distance. C'étaient des garde-fous
manquants, pas des failles ouvertes.

### Couverture de tests, plus largement

8 plugins étaient sans test. `pluginmanager` était la seule absence qui
comptait, et elle est couverte. **Les sept autres le sont désormais aussi**, et
j'avais tort de les dire « sans enjeu » : les tests ont trouvé des défauts
réels dans cinq d'entre eux.

| Plugin | Test | Ce qu'il a trouvé |
|---|---|---|
| `quiz` | banque de 3 200 questions | **36 questions en double**, dont 10 avec deux réponses différentes |
| `taboo` | deck de 8 419 cartes | **35 cartes cassées** : 10 interdisent leur propre mot, 12 répètent un interdit, 1 en a six, 11 mots en double |
| `pictionary` | liste de 5 760 mots | rien — la liste est saine |
| `opdsdir` | `sh.lua` | **injection shell** : le nom de fichier vient du catalogue OPDS distant |
| `dashboard` | `format.lua` | rien — les quatre seuils sont justes |
| `startmenu` | `games.lua` | **`name%s*=` matchait aussi `fullname%s*=`** (latent) |
| `doubleornothing` | `round.lua` | `nextTeam` divisait par zéro sans équipe |

Trois d'entre eux n'avaient rien de testable en l'état : la logique était
soudée à `UIManager`. Elle est extraite telle quelle dans `format.lua`,
`games.lua` et `round.lua` — aucun changement de comportement, sauf les deux
corrections ci-dessus.

Le chevauchement entre catégories de `pictionary` (« Shark » est dans *ocean*
et dans *animals*) **n'est pas** un défaut : c'est le principe des catégories
thématiques, et le test ne traque donc que les doublons intra-catégorie. Même
raisonnement pour les cinq paires d'homographes français de `taboo`
(*Poire/Poiré*, *Traite/Traité*, *Granite/Granité*, *Paris/Pâris*,
*Gaia/Gaïa*), listées dans le test plutôt que de relâcher la vérification.

Toute la logique de chemin vit dans `pathguard.lua`, **sans dépendance à
KOReader** : c'est ce qui la rend testable seule, et `test_pathguard_spec.lua`
couvre les 15 cas — chaque forme de voisin et de `..` du tableau ci-dessus.

19 plugins n'avaient pas de `CHANGELOG.md`. **17 en ont un**, reconstruit
depuis les tags et l'historique git de chaque dépôt : chaque version y est
listée avec les commits de fonctionnalité et de correction qu'elle portait
réellement, les bumps de version, ajouts de capture et syncs CI étant écartés
car ils ne disent rien du plugin. Restent `checkers` (dépôt tiers, non modifié)
et `kakuro` (mis de côté).

Vérifié au passage et **sain** : aucun autre plugin ne charge `i18n` par deux
chemins différents (le piège rencontré sur `slitherlink`), et les versions
`_meta.lua` concordent avec le dernier tag sur les 71 plugins.

---

## Hors phases — dette repérée en passant

- ~~`scripts/check_sudoku_common_drift.sh` documente des divergences
  per-plugin de `common/` qui n'existent plus~~ — réécrit le 2026-09-30. Il ne
  compare plus des copies (il n'y en a plus) mais vérifie l'invariant qui
  compte désormais : chaque variante atteint `sudoku-common/` par un symlink
  **committé** (mode git `120000`). Une copie réintroduite, ou un symlink
  seulement présent dans l'arbre de travail, est signalée.
- ~~`spec/README.md` affirme que seuls `sudoku`, `sudokukiller` et `hanoi`
  ont besoin du module LuaJIT `bit`~~ — corrigé en Phase A : les 8 variantes
  sudoku partagent `puzzle_generator.lua`, qui l'exige, et `sudoku-common/`
  a désormais sa propre spec soumise à la même contrainte.
- ~~`dashboard` et `opdsdir` n'ont pas de `.github/workflows/release.yml`~~ —
  soldé le 2026-09-30. `binairo` et `dashboard` ont reçu le workflow qui leur
  manquait (déclenché à la main : il ne se réveille que sur les chemins
  `*.lua`). `opdsdir` était un cas différent, et mon diagnostic initial était
  faux : ce n'était pas un sous-module mais un simple répertoire du monorepo,
  donc sans dépôt à lui. Il en a désormais un, comme tous les autres — avec
  workflow de release, tag, CHANGELOG, fichiers communautaires, topic
  `koreader-plugins` et protection de branche.
  À savoir tant que ce genre de cas existe : `cd <plugin>.koplugin && git …`
  sur un répertoire non-sous-module opère **sur le monorepo**, et une boucle de
  traitement en masse y commettra silencieusement dans le dépôt parent.
  `scripts/new_plugin.sh` refusait par ailleurs tout plugin sans `board.lua`,
  c'est-à-dire précisément les quatre utilitaires (`dashboard`, `startmenu`,
  `pluginmanager`, `opdsdir`) — l'exigence est levée.
- `go.koplugin/README.md` : capture d'écran manquante
  (« *(Screenshot to be added.)* »).
- ~~`galaxies` reste bloqué sur un bug de générateur structurel~~ — **résolu le
  2026-09-30, le plugin est réintégré** (71 plugins au manifeste). La cause
  n'était pas « structurelle et insoluble » mais un choix de repère : le centre
  d'une galaxie était limité au *milieu d'une case*, ce qui force toute région
  à être de taille impaire autour de son centre dans les deux axes — une grille
  n×n ne se pave presque jamais ainsi.

  | | avant | après |
  |---|---|---|
  | n=6 valides | 8/20 | **20/20** |
  | n=7 valides | 0/20 (100 % de repli dégénéré) | **20/20** |
  | n=8 valides | 0/20 (100 % de repli dégénéré) | **20/20** |
  | temps | 0,09-0,40 s/grille | instantané |

  Les centres sont désormais en **coordonnées doublées** — la case (r,c) occupe
  (2r-1, 2c-1) — de sorte qu'un centre peut tomber au milieu d'une case, sur une
  arête ou sur un coin, ce que le jeu a toujours permis. Le pavage croît
  symétriquement, chaque ajout vérifie que sa région reste connexe, et une case
  seule est toujours une galaxie légale : la génération **ne peut plus échouer**,
  la boucle de 3000 essais et son repli ont disparu. Dépôt désarchivé, retiré
  d'`EXCLUDED_PLUGINS` et de `bump_versions.sh`, topic et protection de branche
  appliqués.

- **Statut mal recentré quand son texte s'allonge** — trouvé en vérifiant le
  rendu de `galaxies`, corrigé dans `game-common` v1.4.1. `VerticalGroup` met en
  cache sa taille *et* le décalage de chaque enfant au premier calcul ; les
  écrans construisent leur mise en page puis appellent `updateStatus`, si bien
  que tout statut plus long que celui présent à la construction gardait
  l'ancien centrage et débordait à droite. Je l'avais d'abord pris pour un
  artefact de mon harnais de capture et « corrigé » là ; il se reproduisait via
  la vraie passe de mise en page de `UIManager`, ce qui a montré qu'il était
  réel.
