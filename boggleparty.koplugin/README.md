# boggleparty.koplugin

A **Boggle Party** display plugin for [KOReader](https://github.com/koreader/koreader) — put your e-reader in the middle of the table and play Boggle with pen and paper.

## Concept

Everyone grabs a sheet of paper. The e-reader shows the letter grid and a countdown timer. When time's up, players read their lists aloud: words found by more than one player are cancelled. Then tap **Solutions** to reveal every valid word on the grid.

No typing during the game — just eyes on the grid and pencil on paper.

## Features

- **Large grid** — letters fill the screen for easy reading across a table
- **Countdown timer** — 2, 3, 4 or 5 minutes (configurable); auto-reveals solutions at zero
- **Solutions view** — all possible words grouped by length with totals
- **Two languages** — EN and FR dictionaries (borrowed from `boggle.koplugin`)
- **E-ink friendly** — grid is static during play; only the timer digit refreshes (fast/A2 mode)

## Scoring (standard Boggle)

| Length | Points |
|--------|--------|
| 3      | 1      |
| 4      | 1      |
| 5      | 2      |
| 6      | 3      |
| 7      | 5      |
| 8+     | 11     |

At the end, cancel any word found by more than one player, then total your remaining words.

## Controls

| Button | Action |
|--------|--------|
| **New** | New grid + restart timer |
| **Solutions** | Stop timer and reveal all words immediately |
| **Lang** | Switch EN / FR (starts a new game) |
| **Time** | Choose duration (2 / 3 / 4 / 5 min) |
| **Rules** | Show rules reminder |
| **Close** | Exit |

## Installation

### Via KOReader Plugin Manager

Add this entry to the plugin manager's manifest, or install from the release zip:

```
boggleparty.koplugin/ → KOReader plugins/ folder
game-common/          → alongside plugins/ (shared library)
```

> **Note:** the zip already bundles `board.lua`, `words_en.lua` and `words_fr.lua`
> from `boggle.koplugin`, so you do **not** need to install boggle separately.

### Manual

1. Download `boggleparty.zip` from [Releases](../../releases).
2. Extract to your KOReader `plugins/` directory.
3. Restart KOReader — **Boggle Party** appears in the Tools menu.

## Development

`boggleparty.koplugin/` lives inside the
[koreader-plugins](https://github.com/t2ym5u/koreader-plugins) monorepo.
`board.lua`, `words_en.lua` and `words_fr.lua` are symlinks to `boggle.koplugin/`
in the dev tree; they are copied as real files into the distribution zip.

## License

GPL-3.0
