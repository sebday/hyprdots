# Agent guide

Quickshell desktop shell for Hyprland — Evobar, Evopanel, Evoside, Evosys. One instance: `quickshell -c evoshell`, controlled via `evo-ipc`.

## Paths

```bash
EVOSHELL_BIN="${EVOSHELL_BIN:-$HOME/.local/bin}"
EVOSHELL_CONFIG="${EVOSHELL_CONFIG:-$HOME/.config/quickshell/evoshell}"
EVOSHELL_STATE="${EVOSHELL_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/evoshell}"
EVOSHELL_CACHE="${EVOSHELL_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/evoshell}"
EVOSHELL_DATA="${EVOSHELL_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/evoshell}"
```

Hyprland: `~/.config/hypr/{autostart,bindings,evoshell,windows}.lua`. Secrets: `$EVOSHELL_DATA/secrets.env` (never commit).

## Layout

- `shell.json` — bar widgets, intervals, `onHover` plugin ids
- `shell.qml` — loads `pluginManifest.js`, services, summon/toggle IPC
- `pluginManifest.js` — canonical plugin ids, QML paths, namespaces, load policy
- `theme.json` → `Commons/Theme.qml` (live colours)

Product tree:

- `Evobar/` — bar, icons, popups, network, media, steam
- `Evopanel/` — Shopify, Evoplayer dashboards
- `Evoside/` — calculator, tasks, clipboard
- `Evosys/` — menu, settings, wallpaper, themes, notifications, lock screen

Plugin ids are product-prefixed (`evo.bar.popups.weather`, `evo.panel.player`, `evo.sys.settings`). Bar pollers use `evo.bar-*` scripts. Dashboards load on demand.

Kinds: **service**, **bar** (`evo.bar`), **hover popup** (`BarHoverPopup` + module), **overlay**, **panel** (`evo.side`), **dashboard** (`FloatingWindow` title = plugin id).

Feature CLIs: `evo-player`, `evo-bar-library`, `evo-bar-network`, `evo-calculator`, `evo-tasks`, `evo-clipboard`.

## Scripts

- Product-prefixed kebab-case: `evo-bar-weather`, `evo-player`, `evo-system`, `evo-ipc`
- `#!/bin/bash`, 2-space indent, `[[ ]]` / `(( ))`
- Shared libs: `evo-player-lib.sh`, `evo-bar-common`, `evo-theme-lib`

## QML

- 4-space indent; bar widgets in `Evobar/widgets/` + `BarWidgetCatalog.qml`
- Evoside module ids: `calc`, `tasks` (via calc focus). Settings: `evo.sys.settings` centered overlay (Super+B).

## IPC & reload

```bash
evo-ipc shell ping|reloadConfig|summon|hide|toggle <pluginId>
evo-ipc evo.bar.media.audio stepUp
evo-system restart
journalctl -t evoshell -f
```

| Change | Action |
|--------|--------|
| `shell.json` | `evo-ipc shell reloadConfig` |
| `theme.json`, `hypr-looks.json`, `ui.json` | live |
| `Theme.qml`, `pluginManifest.js`, new widget type | `evo-system restart` |
| `evoshell.lua` | Hypr reload; often shell restart too |

## State and cache

- Evoplayer durable state: `$EVOSHELL_STATE/panel/player` (playlists, likes, queue, `player.json`)
- Evoplayer regenerable cache: `$EVOSHELL_CACHE/panel/player` (art, waveforms, track tags)
- Display art copies: `$EVOSHELL_CACHE/display-art/<content-hash>.jpg` (atomic write)

## Design tokens

All colours, fonts, spacing, opacity, radius via `Theme.*` — no hardcoded values in QML. Token scales: `Commons/Theme.qml`.

Shared components: `FramedPanel`, `SectionPanel`, `HoverPopupStatBox`, `HoverPopupStatsGrid`, `FieldsetLegendRow`, `BarHoverPopup`.

## Testing

```bash
bash tests/test-plugin-manifest.sh
bash tests/test-evoplayer-art.sh
bash tests/test-static-contracts.sh
evo-ipc shell ping
```

Manual: bar popups, Evoside calculator/tasks, Evoplayer dashboard art, Evobar now playing, Super+B settings, notifications, lock screen.
