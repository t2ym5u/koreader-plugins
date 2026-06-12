# sandwichsudoku.koplugin

A Sandwich Sudoku plugin for [KOReader](https://github.com/koreader/koreader).

## Screenshot

*(Screenshot to be added.)*

## Rules

Standard 9×9 Sudoku rules plus **sandwich clues**: each row/column clue shows the sum of all digits sandwiched between the 1 and the 9 in that line. The 1 and 9 themselves are not included in the sum.

## Features

- **Three difficulty levels** — Easy, Medium, Hard
- **Sandwich clue display** — row and column clues shown at grid edges
- **Note mode** — pencil in candidate digits
- **Check** — highlights incorrect cells and sandwich sums
- **Reveal solution** — shows the full solution
- **Undo** — step back through your moves
- **Auto-save** — game state saved and restored on next launch

## Installation

1. Download `sandwichsudoku.koplugin.zip` from the [latest release](../../releases/latest).
2. Extract into the `plugins/` folder of your KOReader data directory.
3. Restart KOReader.
4. Open the menu → **Tools** → **Sandwich Sudoku**.

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
