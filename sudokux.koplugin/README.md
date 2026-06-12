# sudokux.koplugin

A Sudoku-X plugin for [KOReader](https://github.com/koreader/koreader).

## Screenshot

*(Screenshot to be added.)*

## Rules

Standard 9×9 Sudoku rules plus a **diagonal constraint**: each of the two main diagonals (top-left to bottom-right, and top-right to bottom-left) must also contain every digit 1–9 exactly once.

## Features

- **Three difficulty levels** — Easy, Medium, Hard
- **Diagonal highlighting** — main diagonals shown with a light background
- **Note mode** — pencil in candidate digits
- **Check** — highlights incorrect cells and diagonal conflicts
- **Reveal solution** — shows the full solution
- **Undo** — step back through your moves
- **Auto-save** — game state saved and restored on next launch

## Installation

1. Download `sudokux.koplugin.zip` from the [latest release](../../releases/latest).
2. Extract into the `plugins/` folder of your KOReader data directory.
3. Restart KOReader.
4. Open the menu → **Tools** → **Sudoku X**.

## Controls

| Action | How |
|--------|-----|
| Select a cell | Tap it |
| Enter a digit | Tap the digit button |
| Erase a cell | Tap **Erase** |
| Toggle note mode | Tap **Note: Off / On** |
| Undo last move | Tap **Undo** |
| Check progress | Tap **Check** |
| New game | Tap **New game** |
| Change difficulty | Tap **Diff** |
| Show rules | Tap **Rules** |

## License

GPL-3.0 — see [LICENSE](LICENSE).
