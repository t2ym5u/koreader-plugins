# Mots fléchés

> **Status: stub — not yet implemented**

## Description

French-style crossword where arrows inside each cell point to the answer position instead of numbered squares.

## Files to create

- `board.lua` — game logic, puzzle generator, serialize/load
- `board_widget.lua` — grid rendering and tap gestures
- `screen.lua` — full-screen layout (buttons + board)
- `main.lua` — PluginBase entry point

## Notes

Word-based puzzle — may reuse word lists from hangman/wordle/boggle.
