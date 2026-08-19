# Agent guide

Quickshell desktop shell for Hyprland — bar, panel, launcher, hover popups, overlays, services. One instance: `quickshell -c evoshell`, controlled via `evo-ipc`.

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
- `shell.qml` — `pluginTable`, services, summon/toggle IPC
- `theme.json` → `Theme.qml` (live colours)
- Bar widgets run `evo-bar-*` scripts → one JSON line stdout → `CommandWidget.lastPayload` → hover `*Module.qml`
- Hover popups: `Commons/BarHoverPopup.qml`; bar `onHover: "evo.weather"` etc.

Plugin ids: `evo.<feature>`. Directory: `plugins/<feature>/` with `<Feature>.qml`, `<Feature>Module.qml`, or `Service.qml`. Hypr layer: id with `.` → `-`, `_` → `-` (`evo.shopify_diy` → `evo-shopify-diy`); register in `evoshell.lua`. Tray exceptions: `bar-volume`, `bar-media`.

Kinds: **service** (`Service.qml`), **bar** (`evo.bar` + `shell.json`), **hover popup** (`BarHoverPopup` + module), **overlay** (`evo.library`, `evo.theme`), **panel/menu**, **dashboard** (`FloatingWindow` title = plugin id, e.g. `evo.player`).

Feature CLIs: `evo-player` → `evo.player`, `evo-film` → `evo.library`, `evo-network` → `evo.network`. `evo-bar-player` toggles the player dashboard (not the music CLI). No `evo-media` (use `evo-film` for film/TV).

## Scripts

- `evo-*` only; 2-space indent, `#!/bin/bash`, `[[ ]]` / `(( ))`
- `evo-bar-*` — bar pollers (one JSON line) and Hypr helpers (`evo-bar-hypr`, `evo-bar-player`, `evo-bar-btop`)
- `evo-theme-*`, `evo-system-*`, `evo-menu-*` — theme, maintenance, launcher
- Prefer `evo-ipc`, `evo-bar-common`, `evo-theme-lib` over raw equivalents
- New bar widget: thin `evo-bar-*` → feature CLI `bar` subcommand when one exists (`evo-network bar`)

## QML

- 4-space indent; new bar widgets → `widgets/qmldir` + `BarWidgetCatalog.qml` (`Item` root)
- Panel module ids: `calc`, `clipboard` (legacy `"tools"` → `calc` only). Settings: `evo.settings` overlay.

## IPC & reload

```bash
evo-ipc shell ping|reloadConfig|summon|hide|toggle <pluginId>
evo-ipc evo.audio stepUp          # service calls
evo-bar-hypr pin-all|restore-dashboards
evo-system-restart
journalctl -t evoshell -f
```

| Change | Action |
|--------|--------|
| `shell.json` | `evo-ipc shell reloadConfig` |
| `theme.json`, `hypr-looks.json`, `ui.json` | live |
| `Theme.qml`, new plugin in `shell.qml`, new widget type | `evo-system-restart` |
| `evoshell.lua` | Hypr reload; often shell restart too |

## Design tokens

All colours, fonts, spacing, opacity, radius via `Theme.*` — no hardcoded values in QML. Add a token when a value repeats 3+ times or is semantic; layout ratios OK, not font sizes. Token scales and sources: `Commons/Theme.qml` (`theme.json`, `hypr-looks.json`, `ui.json`).

`HoverPopupStatBox` with `icon` set: icon inline before the value on the top line; label centred below. The icon+value row is centred in the box. Without `icon`, value and label are centred as usual.

## Testing

```bash
evo-ipc shell ping
.local/bin/evo-bar-weather    # → valid JSON line
```

Manual check after visual/QML changes: bar popups, panel, player dashboard, overlays, notifications.

### Player now-playing notifications

`plugins/player/Service.qml` polls `evo-player status --json`, runs `evo-player art notify-cache <path>` (copies art to `~/.cache/evoshell/notification-art-<md5>.jpg`), then `evo.notifications.showMedia()` as `localMedia`. Notifies once per track; dedupes path+art; resets dismiss timer on each show.

Debug log: `~/.local/state/evoshell/notification-log.jsonl` (`showMedia`, `popupOpen`, `artReady`, `artError`). Tail during playback to confirm one `showMedia` per track change.

`NotificationArtworkCard` uses `coverArt` (not `art`) — a property named `art` inside a QML `component` shadows the delegate binding.
