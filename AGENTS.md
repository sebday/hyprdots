# Agent guide

Quickshell desktop shell for Hyprland — Evobar, Evopanel, Evoside, Evosys. One long-running instance (`quickshell -n -p ~/projects/hyprdots`), supervised by `evo system start`, controlled via `evo ipc`.

Read the matching task guide before starting work:

- [`agents/skills/shell-dev.md`](agents/skills/shell-dev.md) — runtime development, reload rules, IPC, logs, Hyprland integration
- [`agents/skills/plugin-development.md`](agents/skills/plugin-development.md) — adding or changing plugins, bar widgets, services, dashboards
- [`agents/skills/visual-verification.md`](agents/skills/visual-verification.md) — required checks for any UI change

## Paths

```bash
EVOSHELL_ROOT="${EVOSHELL_ROOT:-$HOME/projects/hyprdots}"
EVOSHELL_LIB="${EVOSHELL_LIB:-$HOME/.local/lib/evoshell/bin}"
EVOPLAYER_LIB="${EVOPLAYER_LIB:-$HOME/.local/lib/evoplayer}"
EVOSHELL_BIN="${EVOSHELL_BIN:-$EVOSHELL_LIB}"
EVOSHELL_CONFIG="${EVOSHELL_CONFIG:-$HOME/.config/evoshell}"
EVOSHELL_STATE="${EVOSHELL_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/evoshell}"
EVOSHELL_CACHE="${EVOSHELL_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/evoshell}"
EVOSHELL_PASS_PREFIX="${EVOSHELL_PASS_PREFIX:-evoshell}"
```

Hyprland integration: `hypr/` module loaded via `package.path` (see [`hypr/README.md`](hypr/README.md)). Set `EVOSHELL_ROOT` if the repo is not at `~/projects/hyprdots`.

Secrets: `pass`, looked up by `bin/evo-secrets-lib` (`evoshell/` first, then `omarchy/`). This machine's entries are under `omarchy/` (`omarchy/github/token`, `omarchy/cloudflare/read-all`, `omarchy/cursor/token`). Initialize with `pass init <gpg-id>` and insert entries manually. Cloudflare panel API calls use that read token; deploy/tail still run `wrangler` in a terminal with wrangler's own project credentials. Local deploy/rollback discovers Wrangler projects by scanning `~/projects`, `~/src`, `~/dev`, and `~/code` (plus the parent of `EVOSHELL_ROOT` when set); override with `evo-config tray set-field cloudflare projectsRoot /path`.

Brave `web.telegram.org` notifications route through evoshell when Brave uses **native dbus notifications** (`NativeNotifications` in `brave-flags.conf`) and starts via `evo-brave-launch` so it probes dbus after evoshell owns `org.freedesktop.Notifications` — otherwise Chromium falls back to in-browser popup windows for the session.

Feature bash scripts should toast via `evoshell_notify` from [`bin/evo-paths-lib`](bin/evo-paths-lib) (wraps `evo-notification-send`; also `evo notify send`). QML plugins use `showBrief()` on `evo.sys.notifications`. Shell IPC: `evo ipc evo.sys.notifications send "Title" "Body"` or `sendJson` with `{title, body, glyph?, exec?, durationMs?}`.

Shell config is `$EVOSHELL_ROOT/config/shell.json`, with built-in fallbacks in `shell.qml` when that file is missing or invalid. `evo-layout` and `evo-config` write `config/shell.json`.

| Store | Examples | Set via |
|-------|----------|---------|
| `config/shell.json` | monitors, `dashboards.openOnStart`, HA entity lists, idle timers, bar tray widgets | Settings panel, `evo-config`, `evo-layout` |
| State | TV/films paths, weather location | Settings panel, `evo-bar-library`, `evo-bar-weather` |
| pass | GitHub, Cursor, Cloudflare tokens | `omarchy/...` in the password store (`evo-config secrets status`) |

Feature scripts live in `$EVOSHELL_LIB` (`_system`, `_ipc`, `evo-bar-*`, etc.). Public CLI: `~/.local/bin/evo`. Path defaults in [`bin/evo-paths-lib`](bin/evo-paths-lib). Player binary: `~/.local/lib/evoplayer/evoplayer`.

### Data stores (sqlite vs json)

| Feature | Storage | Notes |
|---------|---------|-------|
| Film/TV library | JSON in `$EVOSHELL_STATE/` (`media-library.json`, `media-plays.json`) | No sqlite; `evo-bar-library` scans filesystem |
| Evoplayer library | sqlite in evoplayer cache (`library.sqlite3`) | Owned by evoplayer repo, not evoshell |

Optional config modules (e.g. Shopify under `$EVOSHELL_CONFIG/modules/`) may bring their own sqlite readers and CLIs; see [`config/modules/manifest.example.json`](config/modules/manifest.example.json).

## Core files

| File | Role |
|------|------|
| `config/shell.json` | Live shell config (bar layout, monitors, tray, integrations) |
| `$EVOSHELL_CONFIG/modules/manifest.json` | Optional local module overlay (dashboards, tray widgets, hover panels) |
| `$EVOSHELL_STATE/theme.json` | Generated colour tokens for `commons/Theme.qml` |
| `shell.qml` | Plugin loading, summon/toggle/hide IPC, dashboard loaders, panel instantiator |
| `pluginManifest.js` | Ids and helpers. QML paths for discovered modules live in `modules/*/manifest.json` |

## Product tree

### Evobar (`evo.bar.*`)

Bar host and registered widgets only.

- `modules/bar/Bar.qml` — layer-shell bar (`evo.bar`)
- `modules/bar/widgets/` — bar host chrome (`BarSection`, command entries)

Bar pollers use `evo.bar-*` scripts. Widgets live in `modules/<name>/` and are placed from `config/shell.json`. The status tray is `evo.tray`.

Plain bar glyphs use `Theme.barIconColor` with `Theme.barIconOpacity` at rest; `BarIconPulse` signals attention (traffic, errors, warnings) with `Theme.barIconColorActive` and an opacity pulse. Dials and workspace focus may keep semantic colors.

### Evopanels (`evo.panels.*`, `evo.bar.media.*`, `evo.bar.network.*`)

Panel UIs opened from bar icons (hover popups).

- `evopanels/weather/`, `github/`, `system/`, `notifications/`, `cloudflare/`, `homeassistant/`, etc. — hover popups
- `evopanels/media/` — volume, now-playing, library popups
- `evopanels/network/` — stats and transmission popups
- `evopanels/steam/`, `calendar/`, `insync/`, `cursor/`, `stocks/`

### Evoplayer (`evo.panels.player.*`)

- `vendor/evoplayer/qml/panel/` — player dashboard (`evo.panels.player`) and monitor service (`evo.panels.player.monitor`)

Dashboards load on demand via `Loader`s in `shell.qml` (built-in player + optional `$EVOSHELL_CONFIG/modules/` overlays).

### Floating panels

- `modules/calculator/` — calculator overlay (`evo.calculator`), centered like the clipboard
- `modules/clipboard/` — clipboard history popup (`evo.side.clipboard`)

UI prefs (fieldset rounding) live in `$EVOSHELL_CONFIG/ui.json`. Obsidian themes sync to all vaults in `~/.config/obsidian/obsidian.json` on theme switch.

### Evosys (`evo.sys.*`)

System services, launcher, and centered overlays. No bar widgets live here.

- `modules/menu/` — system/app launcher (`evo.sys.menu`)
- `modules/settings/` — settings overlay (`evo.sys.settings`)
- `modules/themes/` — theme carousel (`evo.sys.themes`)
- `modules/wallpaper/` — wallpaper picker + service (`evo.sys.wallpaper`)
- `modules/lock/` — lock screen and idle timer (`evo.lock`)
- `modules/audio/Service.qml` — volume/audio backend (`evo.sys.media.audio`)
- `modules/monitors/` — notification server (`evo.sys.notifications`) and per-monitor layout

Notification **history UI** is `modules/notifications/` (`evo.panels.notifications`). Monitors owns capture, toasts, unread count, and notification history.

Shell warnings/errors from `journalctl --user -t evoshell` are polled by `evo-shell-log-watch` and stored as history entries with source `shell` (notifications panel **system** filter). User journal warnings/errors (`journalctl --user -p warning`) are polled in the same watcher with source `journal`. Config: `notifications.shellLogs` (`enabled`, `pollIntervalMs`, `dedupeWindowSec`, `userJournal`). History only — no popup toasts for shell logs.

### Commons

Shared QML: `Theme`, `BarHoverPanel`, `CenteredOverlay`, `FramedPanel`, charts, pickers, format helpers.

## Plugin kinds

| Kind | Examples | Notes |
|------|----------|-------|
| `service` | `evo.sys.media.audio`, `evo.sys.notifications`, `evo.panels.player.monitor` | Background IPC/state; loaded at startup |
| `bar` | `evo.bar` | Bar host |
| `menu` | `evo.calculator`, `evo.sys.settings` | Centered overlay or hover popup; `open`/`close` |
| `panel` | `evo.osd` | Layer-shell surface such as the on-screen display |
| `dashboard` | `evo.panels.player` | `FloatingWindow`; lazy-loaded |

Plugin ids use product prefixes: `evo.bar.*`, `evo.panels.*`, `evo.side.*`, `evo.sys.*`.

## Keybindings

Hyprland loads evoshell integration via `hypr/init.lua`, which includes [`hypr/bindings.lua`](hypr/bindings.lua). That file defines evoshell panel toggles, media/volume keys, screenshots, and desktop window-management binds.

Additional shortcuts may be declared in `shell.qml` (`GlobalShortcut`).

The runner **Reference** list (bindings, shell commands) is auto-generated from `hypr/bindings.lua` and any optional `~/.config/hypr/bindings.lua` via `evo-menu-list bindings`.

Evoshell overlays close with **Esc** (system menu and media library step back or clear filters first).

| Binding | Action |
|---------|--------|
| Super+B | Settings (`evo.sys.settings`) — Looks tab |
| Super+Space | System menu (`evo.sys.menu`) — Programs, Looks, Displays, Widgets, Packages |
| Super+Return | Terminal |
| Super+Alt+Return | Quake console (`special:qconsole`) |
| Super+W | Close active window |
| Super+C | Calculator (`evo.calculator`) |
| Super+V | Clipboard (`evo.side.clipboard`) |
| Super+Home | Wallpaper (`evo.sys.wallpaper`) |
| Super+Alt+Home | Themes (`evo.sys.themes`) |
| Super+L | Lock (`evo system lock`) |
| Super+F5 | Restart shell (`evo system restart`) |
| Super+Tab | Cycle workspace |
| Super+P | Colour picker (`hyprpicker`) |
| Super+Alt+K | Toggle workspace float mode (per-workspace) |
| Print | Screenshot (`omasnap`) |

Volume keys call `evo ipc evo.sys.media.audio` (`stepUp`, `stepDown`, `toggleMute`).

## shell.json sections

- `idle` — lock timeout (seconds)
- `notifications` — toast `output`, `position` (`top`/`bottom`), optional `durationMs`, optional `shellLogs` (`enabled`, `pollIntervalMs`, `dedupeWindowSec`, `userJournal`)
- `bar` — `output`, `position`, `layout.left|center|right` widget entries
- `dashboards.openOnStart` — optional fallback list for `evo-panel-hypr restore-dashboards` (Hypr autostart usually passes explicit ids)

Bar entries are module ids (`evo.clock`) or `type: "command"` pollers with `exec`, `interval`, `onHover`, `onClick`.

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
| `evo-calculator` | Calculator history/eval |
| `evo-clipboard` | Clipboard history |
| `evo-wallpaper` | Wallpaper apply/list |
| `evo-theme` / `evo-theme-lib` | GTK/Nvim/icon theming |
| `evo-layout` | Bar/monitor layout helpers |
| `evo-hyprland` | Hyprland config helpers |
| `evo-notification-send` | Canonical dbus toast sender (`--glyph`, `--image`, `--exec`) |
| `evo-brave-launch` | Start Brave after the session notification server is ready |
| `evo-bar-*` | Bar pollers and popup data sources |

## QML conventions

- 4-space indent
- Bar widgets: `modules/<name>/` with a `manifest.json` `bar-widget` entry
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
| `config/shell.json` | `evo system restart` or `evo ipc shell reloadConfig` |
| `theme.json` | live |
| `$EVOSHELL_CONFIG/hypr-looks.json`, `$EVOSHELL_CONFIG/ui.json` | live |
| `Theme.qml`, `pluginManifest.js`, new widget type, new dashboard loader | `evo system restart` |
| `hypr/` module | Hypr reload; often shell restart too |

`reloadConfig` IPC restarts the shell (same as Super+F5), not an in-process config reload.

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
| Panel path | `vendor/evoplayer/qml/panel/` |
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
bash tests/test-evo-theme-obsidian.sh
bash ~/projects/evoplayer/tests/test-evoplayer-art
bash ~/projects/evoplayer/tests/test-evoplayer-cli
bash tests/test-static-contracts.sh
evo ipc shell ping
```

Run the focused tests for the area you changed, then verify in the running UI.
