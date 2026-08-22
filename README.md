# Evoshell

A Quickshell desktop shell for Hyprland - thank you Vaxry.
## Prerequisites

Evoshell targets **Hyprland** and requires **quickshell**, **jq**, and **pass** at minimum. Clipboard, screenshots, themes, and bar integrations need additional packages.

See [docs/packages.md](docs/packages.md) for the full list (required, recommended, and optional). Install from the repo with:

```bash
sudo pacman -S --needed $(grep -vE '^#|^$' packages.txt)
```

For a full desktop bootstrap, use the [hyprdots installer](https://github.com/sebday/hyprdots) instead.

## Install

```bash
bash scripts/install
```

Defaults:
- Source → clone location (`EVOSHELL_ROOT`, Quickshell `-p` target)
- Public defaults → `config/shell.json` in the repo
- Local overrides → `$EVOSHELL_CONFIG/overrides.json` (default `~/.config/evoshell/overrides.json`)
- Layout/integration overrides → `evo-config` and `evo-layout` write overrides only, never tracked defaults
- Runtime state → `$EVOSHELL_STATE/` (default `~/.local/state/evoshell/`)
- Cache → `$EVOSHELL_CACHE/` (default `~/.cache/evoshell/`)
- Secrets → `pass` entries under `evoshell/` (`pass init <gpg-id>`); never put tokens in overrides
- CLIs → `$EVOSHELL_LIB/evo-*` (default `~/.local/lib/evoshell/bin/` after `scripts/install`)
- Themes → `~/.themes` symlink to `$EVOSHELL_ROOT/themes`
- Services → `~/.config/systemd/user/evoshell.service`, `darkhttpd.service`
- Hypr module → loaded from repo via `package.path` (see `hypr/README.md`)

Path env vars (`EVOSHELL_BIN`, `EVOSHELL_CONFIG`, `EVOSHELL_STATE`, `EVOSHELL_CACHE`) are resolved in [`bin/evo-paths-lib`](bin/evo-paths-lib) for bash and [`commons/Util.qml`](commons/Util.qml) for QML. Storage path constants and JSON helpers live in [`bin/evo-storage-lib`](bin/evo-storage-lib).

See `config/overrides.example.json` for monitor output names, Home Assistant entities, Shopify stores, startup dashboards, and other machine-specific settings. Copy the pieces you need into `~/.config/evoshell/overrides.json`, or configure most of them from **Settings** (`evo.sys.settings`).

### Configuration split

| Layer | Path | Contents |
|-------|------|----------|
| Built-in defaults | `shell.qml` | Safe fallbacks when JSON is missing |
| Public defaults | `config/shell.json` | Portable bar layout, tray structure, idle lock timer |
| Local overrides | `$EVOSHELL_CONFIG/overrides.json` | Monitors, startup dashboards, HA entity lists, Shopify stores |
| Local settings | `$EVOSHELL_CONFIG/` | `ui.json`, `weather.json`, `media.json`, `font.json`, `hypr-looks.json` |
| Runtime state | `$EVOSHELL_STATE/` | Session restore, library indexes, notification history, generated theme |
| Cache | `$EVOSHELL_CACHE/` | Bar poller cache, menu previews, bar chart history, Evoplayer art |
| Secrets | `pass` (`evoshell/github/token`, `home-assistant/*`, …) | API tokens and URLs — not in JSON |

Writers: `evo-layout` (bar/notifications/panel side), `evo-config` (integrations, startup, idle, tray widgets), feature CLIs (`evo-bar-weather settings`, `evo-tasks settings`, …).

Settings panel also covers idle lock timer and bar tray widget toggles or poll intervals. Advanced bar layout structure (adding widgets, custom `onClick` handlers) remains JSON in `overrides.json` for power users.

### Config files (`$EVOSHELL_CONFIG/`)

| File | Contents |
|------|----------|
| `overrides.json` | Bar/notifications layout, panel side, HA, idle, tray, dashboards, Shopify |
| `ui.json` | Fieldset rounding |
| `weather.json` | Weather city / coordinates |
| `media.json` | TV/films folder paths |
| `font.json` | Font family |
| `hypr-looks.json` | Hyprland looks + Theme bindings (rounding, gaps, opacity) |

### State files (`$EVOSHELL_STATE/`)

| File / dir | Contents |
|------|----------|
| `session.json` | Side panel open state, module, focus |
| `theme.json` | Generated colour tokens for `commons/Theme.qml` |
| `wallpaper/` | Current wallpaper state |
| `media-library.json`, `media-plays.json` | Film/TV library index and play history |
| `notification-history.json` | Notification history and hide lists |

### Cache (`$EVOSHELL_CACHE/`)

| Path | Contents |
|------|----------|
| `bar/` | Bar poller JSON cache |
| `bar-history/` | BTC/SPCX chart history (`btc-history.json`, etc.) |
| `menu-cache/` | Warmed menu preview thumbnails |

## Evoplayer

Requires [Evoplayer](https://github.com/sebday/evoplayer). Install links it automatically when the repo is present:

```bash
EVOPLAYER_ROOT=~/projects/evoplayer bash scripts/link-evoplayer
```

## Dev

Set `EVOSHELL_BIN=$PWD/bin` when running from the repo without install symlinks.

```bash
EVOSHELL_ROOT=$PWD EVOSHELL_BIN=$PWD/bin EVO_SKIP_EVOPLAYER=1 bash tests/test-static-contracts.sh
bash tests/test-plugin-manifest.sh
bash tests/test-menu-list.sh
bash tests/test-evo-layout-side.sh
bash tests/test-evo-theme-obsidian.sh
bash tests/test-evo-tasks-vault.sh
bash tests/test-evo-config.sh
evo system restart
journalctl --user -t evoshell -f
```

See `AGENTS.md` for plugin ids, IPC, and development workflow.

See [CONTRIB.md](CONTRIB.md) for commit message and branching conventions.
