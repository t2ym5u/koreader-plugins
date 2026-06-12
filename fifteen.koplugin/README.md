# fifteen.koplugin

A 15-Puzzle (Sliding Puzzle) plugin for [KOReader](https://github.com/koreader/koreader).


## Screenshot

*(Screenshot to be added.)*

## Rules

Slide numbered tiles (1–15) in a 4×4 grid into the empty space to arrange them in order from top-left to bottom-right, with the empty space in the bottom-right corner. Only tiles adjacent to the empty space can move.

## Concept

The classic sliding puzzle: arrange 15 numbered tiles in a 4×4 grid by sliding
them into the single empty space. Solve it in as few moves as possible.

## Features

- **Grid sizes** — 3×3 (8-puzzle), 4×4 (classic 15-puzzle), 5×5 (24-puzzle)
- **Scramble guarantee** — only solvable configurations are generated
- **Move counter** — tracks the number of slides
- **Timer** — elapsed time displayed; best time and fewest moves stored per grid size
- **Optimal hint** — shows which tile to slide next on the optimal solution path
- **Image mode** — tiles show a scrambled picture instead of numbers
- **Auto-save** — in-progress game restored on next launch

## Controls

| Action | How |
|--------|-----|
| Slide a tile | Tap it (if it is adjacent to the empty space) |
| Request a hint | Tap **Hint** |
| New game | Tap **New game** |
| Change grid size | Tap **Grid** |
| Show rules | Tap **Rules** |

## Why e-ink friendly?

Each move is a single tile slide requiring only two cells to be redrawn.
The puzzle is entirely turn-based with no continuous animation needed.

## License

GPL-3.0
