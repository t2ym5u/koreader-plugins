# spec

Unit tests used to live here centrally. They've since moved into each
plugin's own directory (e.g. `sudoku.koplugin/test_board_spec.lua`) so that
every `*.koplugin` folder is self-contained and testable on its own, without
depending on this monorepo — each is its own git submodule/repo, and tests
now travel with the code they cover.

## Running a plugin's tests

From inside the plugin's own directory:

```sh
cd sudoku.koplugin
busted
```

Or from the monorepo root, targeting one plugin:

```sh
busted sudoku.koplugin
```

Or every plugin's tests at once, from the monorepo root:

```sh
busted
```

Note: `sudoku.koplugin`, `sudokukiller.koplugin` and `hanoi.koplugin` require
the LuaJIT `bit` module (their generators use a bitmask-based solver) and
will error under plain PUC-Lua unless `busted` is also installed under a
LuaJIT rocks tree (`busted --lua=luajit ...`). All other specs run under
plain Lua.

## What's left here

`solvability_audits/` holds one-off research scripts used while auditing
puzzle-generator uniqueness bugs across the fleet — not part of the busted
suite, kept for historical reference.
