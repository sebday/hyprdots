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

Hyprland integration: `~/.config/hypr/{autostart,bindings,evoshell,windows,looks}.lua`.

Secrets: `$EVOSHELL_DATA/secrets.env` (never commit).

Feature CLIs live in `$EVOSHELL_BIN` (`evo-ipc`, `evo-system`, `evo-player`, `evo-bar-*`, `evo-screenshot`, etc.).

## Core files

| File | Role |
|------|------|
| `shell.json` | Idle timers, notification placement, bar layout, side panel side, startup dashboards |
| `shell.qml` | Plugin loading, summon/toggle/hide IPC, dashboard loaders, panel instantiator |
| `pluginManifest.js` | Canonical plugin ids, QML paths, kinds, `keepLoaded` policy |
| `theme.json` | Colour tokens consumed live by `Commons/Theme.qml` |

## Product tree

### Evobar (`evo.bar.*`)

Bar host, registered widgets, hover popups, and bar-side services.

- `Evobar/Bar.qml` — layer-shell bar (`evo.bar`)
- `Evobar/widgets/` — clock, tray, volume, network, github, shopify, system, notifications, command pollers
- `Evobar/Media/` — audio service (`evo.bar.media.audio`), volume/now-playing/library popups
- `Evobar/Network/` — network stats and transmission popups
- `Evobar/Popups/` — calendar, cursor usage, weather, github, system stats, insync, notifications history, stocks, cloudflare
- `Evobar/Steam/` — steam popup

Bar pollers use `evo.bar-*` scripts. The tray widget (`evo.bar.tray`) hosts nested command entries from `shell.json` (weather, cursor, github, stocks, cloudflare, audio, notifications, network).

### Evopanel (`evo.panel.*`)

Floating dashboards and their monitor services.

- `Evopanel/Shopify/` — store dashboard (`evo.panel.shopify`)
- `Evopanel/Evoplayer/` — player dashboard (`evo.panel.player`) and monitor service (`evo.panel.player.monitor`)

Dashboards load on demand via dedicated `Loader`s in `shell.qml`.

### Evoside (`evo.side.*`)

Docked side panel and clipboard.

- `Evoside/Evoside.qml` — dock host (`evo.side`)
- `Evoside/Calculator/` — calculator + tasks UI (`AppCalc`, `AppTasks`); opened with `{"module":"calc"}` or `{"module":"calc","focus":"tasks"}`
- `Evoside/Clipboard/` — clipboard history popup (`evo.side.clipboard`)

Only `calc` is a dock module id. Tasks is a focus target inside the calculator panel, not a separate dock module.

### Evosys (`evo.sys.*`)

System services, launcher, and centered overlays. No bar widgets live here.

- `Evosys/Menu/` — system/app launcher (`evo.sys.menu`)
- `Evosys/Settings/` — settings overlay (`evo.sys.settings`)
- `Evosys/Themes/` — theme carousel (`evo.sys.themes`)
- `Evosys/Wallpaper/` — wallpaper picker + service (`evo.sys.wallpaper`)
- `Evosys/LockScreen/` — idle and lock services (`evo.sys.lock-screen.idle`, `evo.sys.lock-screen.lock`)
- `Evosys/Notifications/Service.qml` — desktop notification server, toast overlay, history persistence (`evo.sys.notifications`)

Notification **history UI** is not in Evosys. It lives in `Evobar/Popups/Notifications/` as `evo.bar.popups.notifications`. The Evosys service owns capture, toasts, unread count, and `$EVOSHELL_STATE/notification-history.json`.

### Commons

Shared QML: `Theme`, `BarHoverPopup`, `CenteredOverlay`, `FramedPanel`, charts, pickers, format helpers.

## Plugin kinds

| Kind | Examples | Notes |
|------|----------|-------|
| `service` | `evo.bar.media.audio`, `evo.sys.notifications`, `evo.panel.player.monitor` | Background IPC/state; loaded at startup |
| `bar` | `evo.bar` | Bar host |
| `menu` | `evo.bar.popups.weather`, `evo.sys.settings` | Hover popup or centered overlay; `open`/`close` |
| `panel` | `evo.side` | Docked side panel |
| `dashboard` | `evo.panel.player` | `FloatingWindow`; lazy-loaded |

Plugin ids use product prefixes: `evo.bar.*`, `evo.panel.*`, `evo.side.*`, `evo.sys.*`.

## Keybindings

Declared in `~/.config/hypr/bindings.lua` and `shell.qml` (`GlobalShortcut`).

| Binding | Action |
|---------|--------|
| Super+Space | System menu (`evo.sys.menu`) |
| Super+B | Settings (`evo.sys.settings`) |
| Super+C | Calculator (`evo.side` → `calc`) |
| Super+N | Tasks (`evo.side` → `calc`, focus `tasks`) |
| Super+V | Clipboard (`evo.side.clipboard`) |
| Super+M | Media library (`evo.bar.media.library`) |
| Super+Home | Wallpaper (`evo.sys.wallpaper`) |
| Super+Alt+Home | Themes (`evo.sys.themes`) |
| Super+L | Lock (`evo-system lock`) |
| Super+R | Restart shell (`evo-system restart`) |

Volume keys call `evo-ipc evo.bar.media.audio` (`stepUp`, `stepDown`, `toggleMute`).

## shell.json sections

- `idle` — screensaver and lock timeouts (seconds)
- `notifications` — toast `output`, `position` (`top`/`bottom`), optional `durationMs`
- `bar` — `output`, `position`, `layout.left|center|right` widget entries
- `panel.side` — dock side (`left`/`right`)
- `dashboards.openOnStart` — plugin ids to open at startup

Bar entries are either catalog widget ids (`evo.bar.clock`) or `type: "command"` pollers with `exec`, `interval`, `onHover`, `onClick`.

## Scripts

- Product-prefixed kebab-case: `evo-bar-weather`, `evo-player`, `evo-system`, `evo-ipc`
- Match the surrounding file for shebang and indentation; new scripts use `#!/usr/bin/env bash`, 2-space indent, `[[ ]]` / `(( ))`
- Shared libs: `evo-player-lib.sh`, `evo-bar-common`, `evo-theme-lib`

Common feature scripts:

| Script | Role |
|--------|------|
| `evo-ipc` | Quickshell IPC wrapper |
| `evo-system` | Shell supervisor, lock, restart, power |
| `evo-player` | Music library and playback |
| `evo-tasks` | Task list backing store |
| `evo-calculator` | Calculator history/eval |
| `evo-clipboard` | Clipboard history |
| `evo-wallpaper` | Wallpaper apply/list |
| `evo-theme` / `evo-theme-lib` | GTK/Nvim/icon theming |
| `evo-layout` | Bar/monitor layout helpers |
| `evo-hyprland` | Hyprland config helpers |
| `evo-screenshot` | Capture and satty annotation |
| `evo-bar-*` | Bar pollers and popup data sources |

## QML conventions

- 4-space indent
- Bar widgets: `Evobar/widgets/` + `BarWidgetCatalog.qml` + `widgets/qmldir`
- Hover popups: `BarHoverPopup` + `*Module.qml`
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

| Path | Contents |
|------|----------|
| `$EVOSHELL_STATE/panel/player` | Evoplayer playlists, likes, queue, `player.json` |
| `$EVOSHELL_CACHE/panel/player` | Art, waveforms, track tags |
| `$EVOSHELL_CACHE/display-art/<hash>.jpg` | Display art copies (atomic write) |
| `$EVOSHELL_STATE/notification-history.json` | Notification history and hide lists |
| `$EVOSHELL_STATE/font.json` | Font picker state |
| `$EVOSHELL_STATE/wallpaper` | Current wallpaper state |

## Shared components

`FramedPanel`, `SectionPanel`, `HoverPopupStatBox`, `HoverPopupStatsGrid`, `FieldsetLegendRow`, `BarHoverPopup`, `CenteredOverlay`, `NotificationCard`, `NotificationsToast`.

## Safety

- Do not start additional Quickshell instances for individual components; use `evo-system restart`
- Do not commit `$EVOSHELL_DATA/secrets.env` or machine-specific monitor names from `shell.json`
- Visual changes are not done until [`agents/skills/visual-verification.md`](agents/skills/visual-verification.md) passes

## Testing

```bash
bash tests/test-plugin-manifest.sh
bash tests/test-evoplayer-art.sh
bash tests/test-static-contracts.sh
evo-ipc shell ping
```

Run the focused tests for the area you changed, then verify in the running UI.
