# Agent guide

Quickshell desktop shell for Hyprland — Evobar, Evopanel, Evoside, Evosys. One long-running instance (`quickshell -n -c evoshell`), supervised by `evo-system start`, controlled via `evo-ipc`.

Read the matching task guide before starting work:

- [`agents/skills/shell-dev.md`](agents/skills/shell-dev.md) — runtime development, reload rules, IPC, logs, Hyprland integration
- [`agents/skills/plugin-development.md`](agents/skills/plugin-development.md) — adding or changing plugins, bar widgets, services, dashboards
- [`agents/skills/visual-verification.md`](agents/skills/visual-verification.md) — required checks for any UI change

## Paths

```bash
EVOSHELL_BIN="${EVOSHELL_BIN:-$HOME/.local/bin}"
EVOSHELL_CONFIG="${EVOSHELL_CONFIG:-$HOME/.config/quickshell/evoshell}"
EVOSHELL_STATE="${EVOSHELL_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/evoshell}"
EVOSHELL_CACHE="${EVOSHELL_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/evoshell}"
EVOSHELL_DATA="${EVOSHELL_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/evoshell}"
```

Hyprland integration: `~/.config/hypr/{autostart,bindings,evoshell,windows}.lua`.

Secrets: `$EVOSHELL_DATA/secrets.env` (never commit).

Feature CLIs live in `$EVOSHELL_BIN` (`evo-ipc`, `evo-system`, `evo-player`, `evo-bar-*`, `evo-screenshot`, etc.).

## Layout

- `shell.json` — bar layout, intervals, hover targets, idle/notifications/dashboards
- `shell.qml` — plugin loading, summon/toggle/hide IPC, dashboard loaders, panel instantiator
- `pluginManifest.js` — canonical plugin ids, QML paths, kinds, `keepLoaded` policy
- `theme.json` → `Commons/Theme.qml` (live colours)

Product tree:

- `Evobar/` — bar, widgets, hover popups, network, media, steam
- `Evopanel/` — Shopify and Evoplayer dashboards
- `Evoside/` — calculator, tasks, clipboard
- `Evosys/` — menu, settings, wallpaper, themes, notifications, lock screen

Plugin ids are product-prefixed (`evo.bar.popups.weather`, `evo.panel.player`, `evo.sys.settings`). Bar pollers use `evo.bar-*` scripts. Dashboards load on demand.

Kinds: **service**, **bar** (`evo.bar`), **menu** (hover popup or centered overlay), **panel** (`evo.side`), **dashboard** (`FloatingWindow`).

## Scripts

- Product-prefixed kebab-case: `evo-bar-weather`, `evo-player`, `evo-system`, `evo-ipc`
- Match the surrounding file for shebang and indentation; new scripts use `#!/usr/bin/env bash`, 2-space indent, `[[ ]]` / `(( ))`
- Shared libs: `evo-player-lib.sh`, `evo-bar-common`, `evo-theme-lib`

## QML

- 4-space indent; bar widgets in `Evobar/widgets/` registered via `BarWidgetCatalog.qml` and `widgets/qmldir`
- Evoside module ids: `calc`, `tasks` (via calc focus). Settings: `evo.sys.settings` centered overlay (Super+B)
- All colours, fonts, spacing, opacity, radius via `Theme.*` — no hardcoded values in QML

## IPC and reload

```bash
evo-ipc shell ping|reloadConfig|summon|hide|toggle <pluginId> [payloadJson]
evo-ipc evo.bar.media.audio stepUp
evo-system restart
journalctl -t evoshell -f
```

| Change | Action |
|--------|--------|
| `shell.json` | `evo-ipc shell reloadConfig` |
| `theme.json`, `hypr-looks.json`, `ui.json` | live |
| `Theme.qml`, `pluginManifest.js`, new widget type, new dashboard loader | `evo-system restart` |
| `evoshell.lua` | Hypr reload; often shell restart too |

## State and cache

- Evoplayer durable state: `$EVOSHELL_STATE/panel/player` (playlists, likes, queue, `player.json`)
- Evoplayer regenerable cache: `$EVOSHELL_CACHE/panel/player` (art, waveforms, track tags)
- Display art copies: `$EVOSHELL_CACHE/display-art/<content-hash>.jpg` (atomic write)

## Shared components

`FramedPanel`, `SectionPanel`, `HoverPopupStatBox`, `HoverPopupStatsGrid`, `FieldsetLegendRow`, `BarHoverPopup`, `CenteredOverlay`.

## Safety

- Do not start additional Quickshell instances for individual components; use `evo-system restart`
- Do not commit `$EVOSHELL_DATA/secrets.env` or machine-specific paths from `shell.json`
- Visual changes are not done until [`agents/skills/visual-verification.md`](agents/skills/visual-verification.md) passes

## Testing

```bash
bash tests/test-plugin-manifest.sh
bash tests/test-evoplayer-art.sh
bash tests/test-static-contracts.sh
evo-ipc shell ping
```

Run the focused tests for the area you changed, then verify in the running UI.
