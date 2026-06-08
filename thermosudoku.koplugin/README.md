# Thermo Sudoku — KOReader Plugin

> Standard 9×9 Sudoku where thermometer-shaped lines are drawn on the grid — digits must strictly increase from the bulb (round end) to the tip.

## Rules

- Standard 9×9 Sudoku: each row, column, and 3×3 box contains digits 1–9 exactly once.
- For every thermometer drawn on the grid, the values along it must be strictly increasing from the bulb (filled circle) toward the tip.
- If any two adjacent filled cells on a thermometer violate the increasing order, both are highlighted as conflicts.

## How to Play

1. Tap a cell to select it.
2. Tap a digit button to fill it in.
3. Use **Note** mode to pencil in candidates.
4. **Check** highlights errors in red.
5. **New game** generates a fresh puzzle with randomly placed thermometers.

## Thermometer Constraint

Each puzzle contains 5 or more thermometers. A thermometer is a sequence of cells shown with a round bulb at one end and a line (tube) leading to the tip. The digit in each cell must be greater than the digit in the previous cell along the thermometer, starting from the bulb.

Example: a thermometer with bulb value 2 might continue with 4, 7 — each step strictly larger.

Empty cells along a thermometer are ignored for conflict detection; only consecutive filled cells are compared.

## Settings

| Setting | Options | Default |
|---------|---------|---------|
| Difficulty | Easy / Medium / Hard | Medium |
