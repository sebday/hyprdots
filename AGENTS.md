# Agent guide

Quickshell desktop shell for Hyprland — Evobar, Evopanel, Evoside, Evosys. One long-running instance (`quickshell -n -p ~/projects/evoshell`), supervised by `evo system start`, controlled via `evo ipc`.

Read the matching task guide before starting work:

- [`agents/skills/shell-dev.md`](agents/skills/shell-dev.md) — runtime development, reload rules, IPC, logs, Hyprland integration
- [`agents/skills/plugin-development.md`](agents/skills/plugin-development.md) — adding or changing plugins, bar widgets, services, dashboards
- [`agents/skills/visual-verification.md`](agents/skills/visual-verification.md) — required checks for any UI change

## Paths

```bash
EVOSHELL_ROOT="${EVOSHELL_ROOT:-$HOME/projects/evoshell}"
EVOSHELL_LIB="${EVOSHELL_LIB:-$HOME/.local/lib/evoshell/bin}"
EVOPLAYER_LIB="${EVOPLAYER_LIB:-$HOME/.local/lib/evoplayer}"
EVOSHELL_BIN="${EVOSHELL_BIN:-$EVOSHELL_LIB}"
EVOSHELL_CONFIG="${EVOSHELL_CONFIG:-$HOME/.config/evoshell}"
EVOSHELL_STATE="${EVOSHELL_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/evoshell}"
EVOSHELL_CACHE="${EVOSHELL_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/evoshell}"
EVOSHELL_PASS_PREFIX="${EVOSHELL_PASS_PREFIX:-evoshell}"
```

Hyprland integration: `hypr/` module loaded via `package.path` (see [`hypr/README.md`](hypr/README.md)). Set `EVOSHELL_ROOT` if the repo is not at `~/projects/evoshell`.

Secrets: `pass` entries under `evoshell/` (e.g. `pass show evoshell/github/token`, `pass show evoshell/cloudflare/token`). Initialize with `pass init <gpg-id>` and insert entries manually. Cloudflare panel API calls require `pass insert evoshell/cloudflare/token`; deploy/tail still run `wrangler` in a terminal with wrangler's own project credentials.

Effective layout config is deep-merged at runtime: built-in defaults → `$EVOSHELL_ROOT/config/shell.json` → `$EVOSHELL_CONFIG/overrides.json`. `evo-layout` and `evo-config` mutate overrides only; see `config/overrides.example.json`.

| Store | Examples | Set via |
|-------|----------|---------|
| Overrides | monitors, `dashboards.openOnStart`, HA entity lists, idle timers, bar tray widgets, startup dashboard toggles (Integrations) | Settings panel, `evo-config`, `evo-layout` |
| State | Obsidian vault, TV/films paths, weather location, side panel open | Settings panel, `evo-tasks`, `evo-bar-library`, `evo-bar-weather` |
| pass | GitHub, Home Assistant, Cloudflare tokens | `pass insert evoshell/...` (Settings shows status only) |

Feature scripts live in `$EVOSHELL_LIB` (`_system`, `_ipc`, `evo-bar-*`, etc.). Public CLI: `~/.local/bin/evo`. Path defaults in [`bin/evo-paths-lib`](bin/evo-paths-lib). Player binary: `~/.local/lib/evoplayer/evoplayer`.

### Data stores (sqlite vs json)

| Feature | Storage | Notes |
|---------|---------|-------|
| Film/TV library | JSON in `$EVOSHELL_STATE/` (`media-library.json`, `media-plays.json`) | No sqlite; `evo-bar-library` scans filesystem |
| Evoplayer library | sqlite in evoplayer cache (`library.sqlite3`) | Owned by evoplayer repo, not evoshell |

Optional config plugins (e.g. Shopify under `$EVOSHELL_CONFIG/plugins/`) may bring their own sqlite readers and CLIs; see [`config/plugins/manifest.example.json`](config/plugins/manifest.example.json).

## Core files

| File | Role |
|------|------|
| `config/shell.json` | Tracked public defaults (bar layout, tray, integrations) |
| `config/overrides.example.json` | Template for local `overrides.json` |
| `$EVOSHELL_CONFIG/overrides.json` | Machine-specific overrides (monitors, HA, startup dashboards, idle, bar.trayWidgets) |
| `$EVOSHELL_CONFIG/plugins/manifest.json` | Optional local plugin overlay (dashboards, tray widgets, hover panels) |
| `$EVOSHELL_STATE/theme.json` | Generated colour tokens for `commons/Theme.qml` |
| `shell.qml` | Plugin loading, summon/toggle/hide IPC, dashboard loaders, panel instantiator |
| `pluginManifest.js` | Canonical plugin ids, QML paths, kinds, `keepLoaded` policy |

## Product tree

### Evobar (`evo.bar.*`)

Bar host and registered widgets only.

- `evobar/Bar.qml` — layer-shell bar (`evo.bar`)
- `evobar/BarWidgetCatalog.qml` — widget registry
- `evobar/widgets/` — clock, tray, volume, network, github, system, notifications, command pollers

Bar pollers use `evo.bar-*` scripts. The tray widget (`evo.bar.tray`) hosts nested command entries from `shell.json` (weather, cursor, github, stocks, cloudflare, audio, notifications, network).

Plain bar glyphs use `Theme.barIconColor` with `Theme.barIconOpacity` at rest; `BarIconPulse` signals attention (traffic, errors, warnings) with `Theme.barIconColorActive` and an opacity pulse. Dials and workspace focus may keep semantic colors.

### Evopanels (`evo.panels.*`, `evo.bar.media.*`, `evo.bar.network.*`)

Panel UIs opened from bar icons (hover popups).

- `evopanels/weather/`, `github/`, `system/`, `notifications/`, `cloudflare/`, `homeassistant/`, etc. — hover popups
- `evopanels/media/` — volume, now-playing, library popups
- `evopanels/network/` — stats and transmission popups
- `evopanels/steam/`, `calendar/`, `insync/`, `cursor/`, `stocks/`

### Evoplayer (`evo.panels.player.*`)

- `evoplayer/` — player dashboard (`evo.panels.player`) and monitor service (`evo.panels.player.monitor`)

Dashboards load on demand via `Loader`s in `shell.qml` (built-in player + optional `$EVOSHELL_CONFIG/plugins/` overlays).

### Evoside (`evo.side.*`)

Docked side panel and clipboard.

- `evoside/Side.qml` — dock host (`evo.side`)
- `evoside/calculator/` — calculator + tasks UI (`AppCalc`, `AppTasks`); opened with `{"module":"calc"}` or `{"module":"calc","focus":"tasks"}`
- `evoside/clipboard/` — clipboard history popup (`evo.side.clipboard`)

Only `calc` is a dock module id. Tasks is a focus target inside the calculator panel, not a separate dock module.

Side position (`left`/`right`) persists in `$EVOSHELL_CONFIG/overrides.json` (`panel.side`) via Settings or `evo-config panel set`. Open state, module, and focus persist in `$EVOSHELL_STATE/session.json` (`sidePanel`) and restore on evoshell startup. UI prefs (fieldset rounding, Obsidian vault) live in `$EVOSHELL_CONFIG/ui.json`.

### Evosys (`evo.sys.*`)

System services, launcher, and centered overlays. No bar widgets live here.

- `evosys/menu/` — system/app launcher (`evo.sys.menu`)
- `evosys/settings/` — settings overlay (`evo.sys.settings`)
- `evosys/themes/` — theme carousel (`evo.sys.themes`)
- `evosys/wallpaper/` — wallpaper picker + service (`evo.sys.wallpaper`)
- `evosys/lockscreen/` — idle and lock services (`evo.sys.lock-screen.idle`, `evo.sys.lock-screen.lock`)
- `evosys/media/audio/Service.qml` — volume/audio backend (`evo.sys.media.audio`)
- `evosys/notifications/Service.qml` — desktop notification server, toast overlay, history persistence (`evo.sys.notifications`)

Notification **history UI** is not in Evosys. It lives in `evopanels/notifications/` as `evo.panels.notifications`. The Evosys service owns capture, toasts, unread count, and `$EVOSHELL_STATE/notification-history.json`.

Shell warnings/errors from `journalctl --user -t evoshell` are polled by `evo-shell-log-watch` and stored as history entries with source `shell` (notifications panel **logs** filter). User journal warnings/errors (`journalctl --user -p warning`) are polled in the same watcher with source `journal`. Config: `notifications.shellLogs` (`enabled`, `pollIntervalMs`, `dedupeWindowSec`, `userJournal`). History only — no popup toasts for shell logs.

### Commons

Shared QML: `Theme`, `BarHoverPanel`, `CenteredOverlay`, `FramedPanel`, charts, pickers, format helpers.

## Plugin kinds

| Kind | Examples | Notes |
|------|----------|-------|
| `service` | `evo.sys.media.audio`, `evo.sys.notifications`, `evo.panels.player.monitor` | Background IPC/state; loaded at startup |
| `bar` | `evo.bar` | Bar host |
| `menu` | `evo.panels.weather`, `evo.sys.settings` | Hover popup or centered overlay; `open`/`close` |
| `panel` | `evo.side` | Docked side panel |
| `dashboard` | `evo.panels.player` | `FloatingWindow`; lazy-loaded |

Plugin ids use product prefixes: `evo.bar.*`, `evo.panels.*`, `evo.side.*`, `evo.sys.*`.

## Keybindings

Hyprland loads evoshell integration via `hypr/init.lua`, which includes [`hypr/bindings.lua`](hypr/bindings.lua). That file defines evoshell panel toggles, media/volume keys, screenshots, and desktop window-management binds.

Additional shortcuts may be declared in `shell.qml` (`GlobalShortcut`).

The system menu **Reference → Bindings** list is auto-generated from `hypr/bindings.lua` and any optional `~/.config/hypr/bindings.lua` via `evo-menu-list bindings`.

Evoshell overlays close with **Esc** (system menu and media library step back or clear filters first).

| Binding | Action |
|---------|--------|
| Super+Space | System menu (`evo.sys.menu`) |
| Super+Return | Terminal |
| Super+W | Close active window |
| Super+B | Settings (`evo.sys.settings`) |
| Super+C | Calculator (`evo.side` → `calc`) |
| Super+N | Tasks (`evo.side` → `calc`, focus `tasks`) |
| Super+V | Clipboard (`evo.side.clipboard`) |
| Super+M | Media library (`evo.panels.media.library`) |
| Super+Home | Wallpaper (`evo.sys.wallpaper`) |
| Super+Alt+Home | Themes (`evo.sys.themes`) |
| Super+L | Lock (`evo system lock`) |
| Super+R | Restart shell (`evo system restart`) |
| Super+Tab | Cycle workspace |
| Print | Screenshot region (`evo-screenshot region`) |
| Super+Print | Annotate screenshot (`evo-screenshot edit`) |
| Alt+Print | Screenshot all monitors (`evo-screenshot stacked`) |

Volume keys call `evo ipc evo.sys.media.audio` (`stepUp`, `stepDown`, `toggleMute`).

## shell.json sections

- `idle` — lock timeout (seconds)
- `notifications` — toast `output`, `position` (`top`/`bottom`), optional `durationMs`, optional `shellLogs` (`enabled`, `pollIntervalMs`, `dedupeWindowSec`, `userJournal`)
- `bar` — `output`, `position`, `layout.left|center|right` widget entries
- `panel.side` — dock side (`left`/`right`)
- `dashboards.openOnStart` — plugin ids to open at startup

Bar entries are either catalog widget ids (`evo.bar.clock`) or `type: "command"` pollers with `exec`, `interval`, `onHover`, `onClick`.

## Scripts

- Product-prefixed kebab-case: `evo-bar-weather`, `evoplayer`, `evo system`, `evo ipc`
- Match the surrounding file for shebang and indentation; new scripts use `#!/usr/bin/env bash`, 2-space indent, `[[ ]]` / `(( ))`
- Shared libs: `evoplayer-lib`, `evo-bar-common`, `evo-theme-lib`

Common feature scripts:

| Script | Role |
|--------|------|
| `evo ipc` | Quickshell IPC wrapper |
| `evo system` | Shell supervisor, lock, restart, power |
| `evoplayer` | Music library and playback (separate repo; see below) |
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
- Bar widgets: `evobar/widgets/` + `BarWidgetCatalog.qml` + `widgets/qmldir`
- Hover popups: `BarHoverPanel` + `*Module.qml`
- All colours, fonts, spacing, opacity, radius via `Theme.*` — no hardcoded values in QML

## IPC and reload

```bash
evo ipc shell ping|reloadConfig|summon|hide|toggle <pluginId> [payloadJson]
evo ipc evo.sys.media.audio stepUp
evo system restart
journalctl --user -t evoshell -f
```

| Change | Action |
|--------|--------|
| `shell.json` / overrides | `evo system restart` or `evo ipc shell reloadConfig` |
| `theme.json` | live |
| `$EVOSHELL_CONFIG/hypr-looks.json`, `$EVOSHELL_CONFIG/ui.json` | live |
| `Theme.qml`, `pluginManifest.js`, new widget type, new dashboard loader | `evo system restart` |
| `hypr/` module | Hypr reload; often shell restart too |

`reloadConfig` IPC restarts the shell (same as Super+R), not an in-process config reload.

## State and cache

| Path | Contents |
|------|----------|
| `$EVOSHELL_CONFIG/ui.json`, `weather.json`, `media.json`, `font.json`, `hypr-looks.json` | Durable settings |
| `$EVOSHELL_STATE/session.json` | Side panel session restore |
| `$EVOSHELL_STATE/panel/player` | Evoplayer playlists, likes, queue, `player.json` |
| `$EVOSHELL_CACHE/bar-history/` | BTC/SPCX chart history |
| `$EVOSHELL_CACHE/menu-cache/` | Menu preview thumbnails |
| `$EVOSHELL_CACHE/panel/player` | Art, waveforms, track tags |
| `$EVOSHELL_CACHE/display-art/<hash>.jpg` | Display art copies (atomic write) |
| `$EVOSHELL_STATE/notification-history.json` | Notification history and hide lists |
| `$EVOSHELL_STATE/wallpaper` | Current wallpaper state |

## Shared components

`FramedPanel`, `SectionPanel`, `HoverPanelStatBox`, `BarHoverPanel`, `CenteredOverlay`, `NotificationCard`, `NotificationsToast`.

## Safety

- Do not start additional Quickshell instances for individual components; use `evo system restart`
- Do not commit pass secrets or machine-specific monitor names in tracked hyprdots config by mistake
- Visual changes are not done until [`agents/skills/visual-verification.md`](agents/skills/visual-verification.md) passes

## Commit messages and branching

Use `type: imperative lowercase subject` — see [CONTRIB.md](CONTRIB.md) for commit format and branch naming (`master` + `<type>/<subject>` topic branches).

## Evoplayer naming

| Layer | Canonical |
|-------|-----------|
| Product / UI brand | **Evoplayer** |
| Panel path | `evoplayer/` |
| Dashboard plugin ids | `evo.panels.player`, `evo.panels.player.monitor` |
| CLI | `evoplayer` |
| Repo | `~/projects/evoplayer` (symlink: `vendor/evoplayer`) |
| State / cache | `$EVOSHELL_STATE/panel/player`, `$EVOSHELL_CACHE/panel/player` |

Dashboard **UI sections**: `menubar`, `nowplaying`, `albumart`, `controls`.

Menubar **tabs** (left to right): `nowplaying`, `filetree`, `playlists`, `stats`, `settings`.

QML split: `DashboardModule.qml` (logic) + `panels/` + `widgets/` under `~/projects/evoplayer/qml/panel/`.

Player source lives in the separate **evoplayer** repo. After clone or pull:

```bash
bash vendor/evoplayer/scripts/install
```

Or from a dev checkout at `~/projects/evoplayer`:

```bash
bash ~/projects/evoplayer/scripts/install
```

## Testing

```bash
bash tests/test-plugin-manifest.sh
bash tests/test-evo-layout-side.sh
bash ~/projects/evoplayer/tests/test-evoplayer-art
bash ~/projects/evoplayer/tests/test-evoplayer-cli
bash tests/test-static-contracts.sh
evo ipc shell ping
```

Run the focused tests for the area you changed, then verify in the running UI.
