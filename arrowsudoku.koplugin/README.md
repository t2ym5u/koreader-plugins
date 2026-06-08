# Arrow Sudoku — KOReader Plugin

> Standard 9×9 Sudoku where arrow clues are drawn on the grid — the digit in the circle at the tail of each arrow must equal the sum of all digits along the arrow's path.

## Rules

- Standard 9×9 Sudoku: each row, column, and 3×3 box contains digits 1–9 exactly once.
- For every arrow drawn on the grid, the digit in the circle (tail cell) equals the sum of the digits in all cells along the arrow shaft.
- Conflicts are flagged when all shaft cells of an arrow are filled and their sum does not match the required value.

## How to Play

1. Tap a cell to select it.
2. Tap a digit button to fill it in.
3. Use **Note** mode to pencil in candidates.
4. **Check** highlights errors in red.
5. **New game** generates a fresh puzzle with randomly placed arrows.

## Arrow Constraint

Each puzzle contains 5–8 arrows. An arrow consists of:
- A **circle** (tail) cell whose digit equals the sum of the path.
- A **shaft** of 2–3 cells whose digits must add up to the circle's value.

The conflict check fires only once all shaft cells are filled. If the sum is wrong, the shaft cells and the circle are all highlighted in red.

## Settings

| Setting | Options | Default |
|---------|---------|---------|
| Difficulty | Easy / Medium / Hard | Medium |
