# KOReader Plugins

> ⚠️ **Stability notice** — Tested on **Kobo** devices running KOReader. Other devices (Kindle, PocketBook, Android) may work but are untested.

A collection of 65 game and utility plugins for [KOReader](https://koreader.rocks/).

**→ Full documentation: [docs/README.md](docs/README.md)**

---

## Quick install

1. Download a plugin zip from [`dist/`](dist/) (or [`koreader-games-full.zip`](dist/koreader-games-full.zip) for everything at once)
2. Extract into your KOReader `plugins/` directory
3. Restart KOReader

Or install the [Plugin Manager](dist/pluginmanager.zip) to browse and update plugins from the device.

## Build

```bash
./scripts/build_release.sh            # build all plugins → dist/
./scripts/build_release.sh fifteen    # build a single plugin
```

## Scripts

| Script | Purpose |
|---|---|
| `scripts/build_release.sh` | Build distributable zips from `manifest.json` |
| `scripts/bump_versions.sh` | Bump versions in all submodules, tag and push |
| `scripts/link_plugins.sh` | Symlink plugins into a local KOReader install for development |
| `scripts/sync_workflow.sh` | Sync the CI workflow template to all submodules |
| `scripts/trigger_packages.sh` | Trigger GHCR package publishing on all plugin repos |

## Language support

All plugins auto-detect the KOReader display language (French / English). See [docs/README.md](docs/README.md#-language-support) for details.

## Licence

Each plugin is released under its own licence. See the individual plugin repositories for details.
