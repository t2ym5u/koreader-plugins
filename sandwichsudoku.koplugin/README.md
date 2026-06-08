# Sandwich Sudoku — KOReader Plugin

> Standard 9×9 Sudoku where clue numbers outside the grid show the sum of the digits sandwiched between 1 and 9 in each row and column.

## Rules

- Standard 9×9 Sudoku: each row, column, and 3×3 box contains digits 1–9 exactly once.
- A clue number beside each row/column gives the sum of all digits that appear strictly between 1 and 9 in that row or column.
- The clue applies only to digits between the positions of 1 and 9; 1 and 9 themselves are not included in the sum.
- Conflicts are only flagged once an entire row or column is fully filled and the sandwich sum is wrong.

## How to Play

1. Tap a cell to select it.
2. Tap a digit button to fill it in.
3. Use **Note** mode to pencil in candidates.
4. **Check** highlights errors in red.
5. **New game** generates a fresh puzzle with automatically computed sandwich clues.

## Sandwich Constraint

The row and column clues are shown at the edges of the grid. A clue of 0 means 1 and 9 are adjacent (nothing sandwiched). A clue of 35 means all of 2–8 are between them.

Example row: `4 7 2 **1** 5 3 6 **9** 8` — the sandwich sum is 5 + 3 + 6 = 14 (the cells strictly between 1 and 9).

When a full row or column is filled and its sandwich sum is wrong, all cells from position of 1 to position of 9 (inclusive) are highlighted in red.

## Settings

| Setting | Options | Default |
|---------|---------|---------|
| Difficulty | Easy / Medium / Hard | Medium |
