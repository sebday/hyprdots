---
name: evoshell
description: >-
  Develop the evoshell Quickshell desktop shell. Use when editing evoshell QML,
  shell.json, bar widgets, plugins, evo-* scripts, IPC, or Hyprland integration.
---

# Evoshell

Quickshell desktop shell for Hyprland — status bar, panel, launcher, hover popups, overlays, and background services. One running instance: `quickshell -c evoshell`, controlled via `evo-ipc`.

House rules (bash style, naming, git, testing): `AGENTS.md` in this directory.

## Architecture

```
shell.json  →  shell.qml  →  bar / panel / menu  →  user input
     ↑              ↓                                    ↓
  reloadConfig   services                          evo-bar-* / evo-bar-*
     ↑              ↓                                    ↓
theme.json  ←  Theme.qml  ←  ~/.local/state/evoshell  ←  JSON line
```

- **Config** — `shell.json` bar layout (widgets, intervals, `onHover`). `theme.json` → `Theme.qml` (live colours).
- **Core** — `shell.qml`: `pluginTable`, service sync, summon/toggle/hover IPC, bar loader.
- **Surfaces** — `evo.bar` (`BarWidgetCatalog` + layout), `evo.panel` (dock), `evo.menu` (launcher).
- **Bar data** — `CommandWidget` runs `evo-bar-*` scripts; one JSON line stdout; hover popups read `lastPayload`.
- **State** — `~/.local/state/evoshell/` (settings, clipboard, film index, app state).

## Paths

| What | Where |
|------|--------|
| Shell config | `~/.config/quickshell/evoshell/` |
| Scripts | `~/.local/bin/evo-*` |
| IPC | `~/.local/bin/evo-ipc` |
| Hyprland | `~/.config/hypr/{autostart,bindings,evoshell,windows}.lua` |
| Secrets | `~/.local/share/evoshell/secrets.env` (never commit) |
| State / cache | `~/.local/state/evoshell/`, `~/.cache/evoshell/bar/` |

## Naming conventions

### Plugin IDs

- Format: `evo.<feature>` with dots for variants (`evo.shopify_diy`, `evo.transmission.add`).
- Match the feature domain, not legacy abbreviations (`evo.shopify_diy`, not `evo.stats_diy`).
- Panel dock module ids stay unprefixed: `calc`, `settings`, `clipboard` (legacy `"tools"` → `"calc"` only).

### Directories and QML

| Piece | Pattern | Example |
|-------|---------|---------|
| Plugin directory | `plugins/<feature>/` | `plugins/shopify/` |
| Root plugin QML | `<Feature>.qml` | `Shopify.qml`, `Player.qml` |
| Content module | `<Feature>Module.qml` | `GithubModule.qml` |
| `qmldir` module name | same as directory | `module shopify` |
| Service-only plugins | `Service.qml` | `plugins/audio/Service.qml` |

### Layer namespaces (Hyprland)

- Default: plugin id with `.` → `-` and `_` → `-` (`evo.shopify_diy` → `evo-shopify-diy`).
- Tray audio exceptions (documented): `bar-volume`, `bar-media`.
- Register new namespaces in `~/.config/hypr/evoshell.lua`.

### Scripts

| Prefix | Purpose | Examples |
|--------|---------|----------|
| `evo-bar-*` | Bar JSON pollers only (one line stdout) | `evo-bar-weather`, `evo-bar-github` |
| `evo-bar-*` | Dashboard / Hypr window control (not bar data) | `evo-bar-hypr`, `evo-bar-player`, `evo-bar-btop` |
| `evo-theme-*` | Theme generation and apply | `evo-theme-gtk` |
| `evo-system-*` | Session maintenance | `evo-system-cleanup` |
| `evo-menu-*` | Launcher helpers | `evo-menu-list` |
| bare `evo-*` | Feature CLIs matching plugin domains | `evo-network`, `evo-player`, `evo-film` |

New bar widgets: thin `evo-bar-*` → feature CLI `bar` subcommand when the domain has a feature CLI (`evo-network bar`).

### Feature CLI ↔ plugin ID

| CLI | Plugin | Role |
|-----|--------|------|
| `evo-player` | `evo.player` | Local music library + mpv backend |
| `evo-film` | `evo.library` | Film/TV index + playback (not `evo.media`) |
| `evo-network` | `evo.network` | Network status + `bar` subcommand |
| `evo-bar-player` | `evo.player` | Toggle dashboard window (not the music CLI) |

**Do not** use `evo-media` (removed — collided with `evo.media` MPRIS popup). Film/TV uses `evo-film`.

### Dashboard windows

- `FloatingWindow` title = plugin id string (`evo.shopify`, `evo.player`).
- Hypr rules in `windows.lua` match those titles.
- Open/close/toggle via generic IPC: `evo-ipc shell toggle evo.shopify`, `evo-ipc shell hide evo.player`.
- Pin to monitor: `evo-bar-hypr restore-dashboards` (opens shopify + player on ws 10).

### IPC

- Prefer `evo-ipc shell summon|hide|toggle <pluginId>` for all plugins including dashboards.
- Service calls: `evo-ipc evo.audio stepUp`, `evo-ipc evo.lock lock`.
- Legacy short targets still accepted by `evo-ipc`: `wallpaper`, `idle`, `lock`.

## Plugin kinds

| Kind | Examples | Entry |
|------|----------|-------|
| Service | `evo.audio`, `evo.wallpaper`, `evo.idle`, `evo.lock`, `evo.clipboard` | `Service.qml` |
| Bar | `evo.bar` | `Bar.qml` + `shell.json` layout |
| Hover popup | `evo.weather`, `evo.volume`, `evo.media`, `evo.github`, … | `BarHoverPopup` + `*Module.qml` |
| Click action | `evo.system` | `SystemWidget` → `evo-bar-btop` |
| Fullscreen overlay | `evo.library`, `evo.theme`, `evo.wallpaper` | `CenteredOverlay` / `CarouselOverlay` |
| Panel / menu | `evo.panel`, `evo.menu` | `Panel.qml`, `Menu.qml` |
| Dashboard | `evo.shopify`, `evo.player` | `FloatingWindow` |

## Bar scripts

- `evo-bar-*` prints **one JSON line**: `{ "text", "class", … }`.
- Source `evo-bar-common.sh` when sharing cache/helpers.
- `CommandWidget` stores full parse in `lastPayload` for hover popups.
- Poll interval from `shell.json` `interval`. Streaming data (cava): `SplitParser`, not polling.

## Hover popups

- Root: `BarHoverPopup` (`Commons/BarHoverPopup.qml`).
- Bar widget sets `onHover: "evo.weather"` (plugin id).
- Tray: `VolumeWidget` → `evo.volume` / `evo.media`; tray media icon click → `evo-bar-player toggle`.

## Config refresh vs restart

| Change | Action |
|--------|--------|
| `shell.json` layout / intervals / hover | `evo-ipc shell reloadConfig` |
| `theme.json` | live — `Theme.qml` watches file |
| New plugin in `shell.qml`, new bar widget type, new `qmldir` entry | **full restart** (`evo-system-restart`) |
| `evoshell.lua` layer rules | Hypr reload; often needs shell restart too |

## Commands

```bash
evo-ipc shell ping
evo-ipc shell reloadConfig
evo-ipc shell toggle evo.panel '{"module":"settings"}'
evo-ipc shell toggle evo.player
evo-bar-hypr pin-all
evo-system-restart
journalctl -t evoshell -f
```
