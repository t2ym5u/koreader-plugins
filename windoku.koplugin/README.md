# Windoku — KOReader Plugin

> Standard 9×9 Sudoku (also known as NRC Sudoku) with four 3×3 window regions that must each contain digits 1–9 exactly once.

## Rules

- Standard 9×9 Sudoku: each row, column, and 3×3 box contains digits 1–9 exactly once.
- Four additional 3×3 window regions (rows 2–4 and 6–8, columns 2–4 and 6–8) must also each contain digits 1–9 without repetition.

## How to Play

1. Tap a cell to select it.
2. Tap a digit button to fill it in.
3. Use **Note** mode to pencil in candidates.
4. **Check** highlights errors in red.
5. **New game** generates a fresh puzzle.

## Window Regions

The four window regions are the same positions as the hyper-regions in Hyper Sudoku:

| Region | Rows | Columns |
|--------|------|---------|
| Top-left | 2–4 | 2–4 |
| Top-right | 2–4 | 6–8 |
| Bottom-left | 6–8 | 2–4 |
| Bottom-right | 6–8 | 6–8 |

Windoku is equivalent to Hyper Sudoku in rules, but the window boundaries are traditionally drawn with bold lines rather than shading. Any duplicate digit within a window is highlighted in red.

## Settings

| Setting | Options | Default |
|---------|---------|---------|
| Difficulty | Easy / Medium / Hard | Medium |
