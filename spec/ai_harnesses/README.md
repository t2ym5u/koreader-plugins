# ai_harnesses

Head-to-head harnesses used to measure the game AIs during the phase E work
(see `docs/ROADMAP.md`). Not part of the `busted` suite — they are run by hand
with `luajit`, and they take minutes rather than seconds.

They are kept because measuring an AI change here is easy to get wrong, and
these encode what went wrong.

## Randomised openings are not optional

Every AI in this repo picks moves deterministically. A match starting from the
initial position therefore replays **one** game per colour assignment, however
many "games" the harness claims to run.

The first gomoku harness reported **10-0** for a rewrite. With randomised
openings the same comparison gave 11-9 — i.e. nothing. The "10 games" had been
2 distinct games replayed 5 times. Every harness here opens each game with a
handful of random legal moves, and alternates colours.

## Report the worst move time, not the average

Averages hid every trap in phase E. `othello`'s exact endgame at 13 empty
squares averaged fine and spent **10.8s** on one move; `chess` at depth 4,
**14.8s**; `connect4` at depth 9, **15.5s**. On an e-ink CPU that is what a
player feels, so each harness prints `max` alongside `moy`.

## Files

| File | Purpose |
|---|---|
| `gomoku_match.lua`, `othello_match.lua`, `c4_match.lua`, `chess_match.lua` | engine vs engine, `A=`/`B=` paths and `DEPTH_A`/`DEPTH_B` from the environment |
| `bg_match.lua`, `go_match.lua` | the new engines against a random legal-move player |
| `c4_agree.lua`, `chess_agree.lua` | do two versions pick the *same* move? The right test when a change is meant to be behaviour-preserving — far sharper than a match, which would only measure opening bias |
| `bg_rule.lua` | backgammon's dice-usage rule on hand-built positions |

Typical use:

```sh
cd spec/ai_harnesses
A=/path/to/baseline_board.lua B=../../othello.koplugin/board.lua \
  GAMES=30 DEPTH=4 SEED=4242 luajit othello_match.lua
```

Save the baseline with `git show HEAD:board.lua > baseline.lua` before editing.
Note that plugins loading siblings through `_dir` (chess, tapa, nurikabe) must
have their baseline copied *into the plugin directory*, or their own `require`s
will not resolve.
