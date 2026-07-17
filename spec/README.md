# spec

Unit tests for the game plugins, run with [busted](https://lunarmodules.github.io/busted/).

## Running tests

From the project root:

```sh
busted spec/
```

To run a single spec file:

```sh
busted spec/sudoku_spec.lua
```

Note: `sudoku_spec.lua` and `sudokukiller_spec.lua` require the LuaJIT `bit`
module (their `puzzle_generator.lua` uses a bitmask-MRV solver) and will
error under plain PUC-Lua unless `busted` is also installed under a LuaJIT
rocks tree (`busted --lua=luajit ...`). All other specs run under plain Lua.

## Files

| File | What it tests |
|------|--------------|
| `helper.lua` | Shared test utilities (gettext mock, `preloadFile`, `copyGrid`) |
| `backgammon_spec.lua` | Backgammon move legality, hitting, bearing off, win detection |
| `bridges_spec.lua` | Bridges (Hashiwokakero) island/bridge generator and win check |
| `futoshiki_spec.lua` | Futoshiki solver and constraint checks |
| `galaxies_spec.lua` | Galaxies generator, cycle/undo, win check (1 pending: known symmetry bug) |
| `game2048_spec.lua` | 2048 board logic and merge rules |
| `go_spec.lua` | Go capture/liberty flood-fill, ko rule, territory scoring |
| `hitori_spec.lua` | Hitori solver |
| `kakuro_spec.lua` | Kakuro solver |
| `kenken_spec.lua` | KenKen cage solver |
| `masyu_spec.lua` | Masyu loop generator and win check (1 pending: known perturbLoop bug) |
| `mastermind_spec.lua` | Mastermind scoring logic |
| `minesweeper_spec.lua` | Minesweeper mine placement and reveal |
| `nonogram_spec.lua` | Nonogram line solver |
| `numberlink_spec.lua` | Numberlink solver |
| `nurikabe_spec.lua` | Nurikabe solver |
| `shikaku_spec.lua` | Shikaku rectangle generator and placement rules |
| `skyscraper_spec.lua` | Skyscraper Latin-square generator and visibility clues |
| `slitherlink_spec.lua` | Slitherlink solver |
| `solitaire_spec.lua` | Klondike deal, move validation, undo, checksum-guarded save/load |
| `sudoku_spec.lua` | Sudoku generator and solver |
| `sudokukiller_spec.lua` | Killer Sudoku cage solver |
| `tapa_spec.lua` | Tapa shading generator and clue computation |
| `wordladder_spec.lua` | Word Ladder puzzle generation, moves and win check |

## Helper API

```lua
local H = require("spec/helper")

H.unload("module_name")               -- evict from package.loaded
H.preloadFile("alias", "path/to.lua") -- load a file under a given name
H.copyGrid(src, n)                     -- deep-copy an n×n grid
```
