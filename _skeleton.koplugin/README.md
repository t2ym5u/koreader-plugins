# _skeleton.koplugin

Starter template for new game plugins in this repository.

## Purpose

Copy this directory to `mygame.koplugin/`, rename the identifiers inside, and
you have a working plugin skeleton that already wires up `game-common`.

## Files

| File | Role |
|------|------|
| `main.lua` | Plugin entry point — extends `PluginBase`, declares `name` and `menu_text` |
| `screen.lua` | Full-screen UI — extends `ScreenBase`, implements `buildLayout` |
| `board.lua` | Game state and logic |
| `board_widget.lua` | Board rendering — extends `GridWidgetBase` |
| `_meta.lua` | Plugin metadata for the plugin manager |

## Quick start

```sh
cp -r _skeleton.koplugin mygame.koplugin
cd mygame.koplugin
ln -s ../../game-common common
```

Then replace every occurrence of `mygame` / `MyGame` / `MyGamePlugin` /
`MyGameScreen` with your game's name.

See [`game-common/README.md`](../game-common/README.md) for the full API.

## License

GPL-3.0
