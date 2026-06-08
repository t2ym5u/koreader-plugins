# Between Lines Sudoku

> **Status: stub — not yet implemented**

## Description

Sudoku where lines connect two circles. Digits on each line must be strictly between the values of the two endpoint circles.

## Files to create

- `board.lua` — game logic, puzzle generator, serialize/load
- `board_widget.lua` — grid rendering and tap gestures
- `screen.lua` — full-screen layout (buttons + board)
- `main.lua` — PluginBase entry point

## Notes

Shares rules with sudoku.koplugin; extend SudokuBoard base or copy and add variant constraints.
