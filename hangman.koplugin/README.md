# hangman.koplugin

A Hangman plugin for [KOReader](https://github.com/koreader/koreader).


## Screenshot

*(Screenshot to be added.)*

## Rules

Guess the hidden word letter by letter. Each wrong guess adds a body part to the hangman figure. Reveal the complete word before the figure is drawn — you have a limited number of wrong guesses.

## Concept

Guess the hidden word one letter at a time. Each wrong guess adds a part to
the hangman drawing. Reveal the full word before the drawing is complete to win.

## Features

- **Multiple languages** — word lists for EN, FR, DE, ES
- **Configurable word length** — short (3–5), medium (6–8), long (9+)
- **Difficulty levels** — Easy (8 wrong guesses allowed), Medium (6), Hard (4)
- **Category mode** — words from specific categories (animals, countries, food…)
- **Hint** — reveal one random letter at the cost of one wrong-guess allowance
- **ASCII art drawing** — progressive hangman illustration rendered in monospace
- **Statistics** — win/loss ratio and average guesses
- **Auto-save** — in-progress game restored on next launch

## Controls

| Action | How |
|--------|-----|
| Guess a letter | Tap it on the on-screen alphabet |
| Request a hint | Tap **Hint** |
| New game | Tap **New game** |
| Change language | Tap **Lang** |
| Change difficulty | Tap **Diff** |
| Show rules | Tap **Rules** |

## Why e-ink friendly?

Each guess is a single tap that triggers at most one screen update.
The ASCII art hangman drawing is a natural fit for monospace e-ink rendering.

## License

GPL-3.0
