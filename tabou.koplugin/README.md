# tabou.koplugin

A **Tabou Party** display plugin for [KOReader](https://github.com/koreader/koreader) — play Taboo around the table with your own card deck.

## Concept

Teams take turns. The active player picks up the device and describes as many words as possible before the timer runs out — without saying any of the forbidden words listed below the main word. Opponents watch for slip-ups and can buzz. Correct guesses score +1, buzzes score −1.

The plugin loads your card deck from a JSON file you place in KOReader's documents folder.

## Features

- **Card display** — main word large, forbidden words clearly listed below
- **Countdown timer** — 30 s to 2 min per round (configurable)
- **Live scoring** — ✓ +1 / ✗ −1 / → Skip, applied instantly; round delta shown at timer end
- **Auto team rotation** — advances to the next team after each round
- **2–6 teams** — configurable team count
- **FR + EN UI** — interface language switchable; loads `tabou_cards_fr.json` or `tabou_cards_en.json` automatically
- **E-ink friendly** — only the timer digit refreshes in fast/A2 mode

## Card JSON format

Create a file named `tabou_cards_fr.json` (or `tabou_cards_en.json`, or `tabou_cards.json`) and copy it to KOReader's **documents** folder (`/sdcard/koreader/` on most devices).

```json
[
  {
    "word": "Éléphant",
    "forbidden": ["Afrique", "Trompe", "Gris", "Barrissements", "Zoo"]
  },
  {
    "word": "Pizza",
    "forbidden": ["Italie", "Fromage", "Four", "Pâte", "Napoli"]
  }
]
```

Each card object must have:
- `"word"` — the word to describe
- `"forbidden"` — array of words that cannot be said

Cards are shuffled on load and wrap around automatically.

## Controls

| Button | Action |
|--------|--------|
| **Commencer la manche / Start round** | Start the timer for the active team |
| **✓ +1 Trouvé / ✓ +1 Got it** | Guessed — +1 to round tally, next card |
| **✗ −1 Grillé / ✗ −1 Buzzed** | Buzzed — −1 to round tally, next card |
| **→ Passer / → Skip** | Skip card, no penalty |
| **■ Fin de manche / ■ End round** | Stop early and apply round score |
| **Options** | Language, teams, timer duration, reset |
| **Rules** | Show rules reminder |
| **Close** | Exit |

## Installation

### Via KOReader Plugin Manager

```
tabou.koplugin/ → KOReader plugins/ folder
game-common/     → alongside plugins/ (shared library)
```

### Manual

1. Download `tabou.zip` from [Releases](../../releases).
2. Extract to your KOReader `plugins/` directory.
3. Copy your `tabou_cards_fr.json` (or `tabou_cards_en.json`) to KOReader's documents folder.
4. Restart KOReader — **Tabou Party** appears in the Tools menu.

## Development

`tabou.koplugin/` lives inside the
[koreader-plugins](https://github.com/t2ym5u/koreader-plugins) monorepo.
No bundled word list — you supply the cards.

## License

GPL-3.0
