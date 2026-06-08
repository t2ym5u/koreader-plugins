# Cryptogram

> **Status: stub — not yet implemented**

## Description

A substitution cipher puzzle: each letter is replaced by another, and the player must decode the original message.

## Files to create

- `board.lua` — game logic, puzzle generator, serialize/load
- `board_widget.lua` — grid rendering and tap gestures
- `screen.lua` — full-screen layout (buttons + board)
- `main.lua` — PluginBase entry point

## Notes

Word-based puzzle — may reuse word lists from hangman/wordle/boggle.
