# crossword.koplugin

A Crossword puzzle plugin for [KOReader](https://github.com/koreader/koreader).


## Screenshot

*(Screenshot to be added.)*

## Rules

Fill the white squares with letters to answer the across and down clues. Letters at intersecting cells must satisfy both words. Tap a cell to select it; tap again to toggle between across and down direction.

## Concept

Classic crossword puzzles: fill the white squares with letters to form words
that match the across and down clues. Clues are shown in a scrollable list
alongside the grid.

## Features

- **Multiple languages** — puzzle packs for EN, FR, DE
- **Grid navigation** — tap a cell to select it; tap a clue to jump to its first cell
- **Direction toggle** — switch between Across and Down with a single tap
- **Check letter / word / grid** — reveal errors without showing the solution
- **Reveal letter / word / grid** — progressively reveal the solution
- **Note mode** — pencil in candidates in small font
- **Auto-advance** — cursor moves to the next empty cell in the word after each entry
- **Symmetrical layout** — standard crossword symmetry for all puzzles
- **Puzzle packs** — bundled .puz / .ipuz file support for community puzzle imports
- **Auto-save** — game state saved and restored on next launch

## Controls

| Action | How |
|--------|-----|
| Select a cell | Tap it |
| Enter a letter | Tap the on-screen keyboard |
| Switch Across / Down | Tap **↔ / ↕** or tap an already-selected cell |
| Jump to clue | Tap it in the clue list |
| Erase a letter | Tap **⌫** |
| Check / Reveal | Tap **Check** or **Reveal** menu |
| New puzzle | Tap **New puzzle** |
| Show rules | Tap **Rules** |

## Why e-ink friendly?

Crossword grids are static between keystrokes. The split layout (grid + clue list)
works well on the portrait form factor of e-readers.

## License

GPL-3.0
