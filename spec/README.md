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

## Files

| File | What it tests |
|------|--------------|
| `helper.lua` | Shared test utilities (gettext mock, `preloadFile`, `copyGrid`) |
| `futoshiki_spec.lua` | Futoshiki solver and constraint checks |
| `game2048_spec.lua` | 2048 board logic and merge rules |
| `hitori_spec.lua` | Hitori solver |
| `kakuro_spec.lua` | Kakuro solver |
| `kenken_spec.lua` | KenKen cage solver |
| `mastermind_spec.lua` | Mastermind scoring logic |
| `minesweeper_spec.lua` | Minesweeper mine placement and reveal |
| `nonogram_spec.lua` | Nonogram line solver |
| `numberlink_spec.lua` | Numberlink solver |
| `nurikabe_spec.lua` | Nurikabe solver |
| `slitherlink_spec.lua` | Slitherlink solver |
| `sudoku_spec.lua` | Sudoku generator and solver |
| `sudokukiller_spec.lua` | Killer Sudoku cage solver |

## Helper API

```lua
local H = require("spec/helper")

H.unload("module_name")               -- evict from package.loaded
H.preloadFile("alias", "path/to.lua") -- load a file under a given name
H.copyGrid(src, n)                     -- deep-copy an n×n grid
```
