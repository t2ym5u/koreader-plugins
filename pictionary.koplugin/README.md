# pictionary.koplugin

A **Pictionary Party** display plugin for [KOReader](https://github.com/koreader/koreader) — put your e-reader in the middle of the table and play Pictionary with pen and paper.

## Concept

Teams take turns. The drawer receives the device, sees the word in secret, then draws it on paper while teammates guess. A countdown timer runs. One tap records the result, scores update automatically, and play passes to the next team.

No typing during the game — just the drawer and the device, everyone else watches the paper.

## Features

- **Secret word reveal** — teammates look away while the drawer taps *Show the word*
- **Countdown timer** — 45 s, 1 min, 1:30 or 2 min (configurable)
- **Auto-scored** — ✓ Got it / ✗ Missed advances the team tracker automatically
- **Built-in word bank** — 480 words across 8 categories × 3 difficulties (FR + EN)
- **Category & difficulty filters** — Animals, Food, Sport, Objects… Easy / Medium / Hard / Mixed
- **2–6 teams** — configurable team count
- **E-ink friendly** — only the timer digit refreshes in fast/A2 mode

## Categories

| FR | EN |
|----|----|
| Animaux | Animals |
| Nourriture | Food |
| Sport | Sport |
| Objets | Objects |
| Nature | Nature |
| Métiers | Jobs |
| Voyages | Travel |
| Divertissement | Entertainment |

## Controls

| Button | Action |
|--------|--------|
| **Voir le mot / Show the word** | Reveal the word to the drawer + start timer |
| **✓ Trouvé ! / ✓ Got it!** | Team guessed — +1 point, next team |
| **✗ Raté / ✗ Missed** | Not guessed — 0 points, next team |
| **Options** | Language, teams, timer, category, difficulty, reset |
| **Rules** | Show rules reminder |
| **Close** | Exit |

## Installation

### Via KOReader Plugin Manager

```
pictionary.koplugin/ → KOReader plugins/ folder
game-common/          → alongside plugins/ (shared library)
```

### Manual

1. Download `pictionary.zip` from [Releases](../../releases).
2. Extract to your KOReader `plugins/` directory.
3. Restart KOReader — **Pictionary Party** appears in the Tools menu.

## Development

`pictionary.koplugin/` lives inside the
[koreader-plugins](https://github.com/t2ym5u/koreader-plugins) monorepo.
The word bank (`words.lua`) is self-contained — no external dependencies beyond `game-common`.

## License

GPL-3.0
