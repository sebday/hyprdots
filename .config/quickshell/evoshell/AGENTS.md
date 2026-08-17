# Agent guide

House rules for contributing to evoshell. Architecture and plugin model live in `skills/evoshell/SKILL.md` — start here for *how* to change things, not *what* exists.

## Where to look

| Topic | Location |
|-------|----------|
| Architecture, plugin map, pitfalls | `skills/evoshell/SKILL.md` (symlinked at `~/.cursor/skills/evoshell`) |
| House rules (this file) | `AGENTS.md` |
| End-user install and features | `~/README.md` |
| Hyprland layer rules | `~/.config/hypr/evoshell.lua` |
| Shell scripts | `~/.local/bin/evo-*` |

## Canonical paths

Prefer these over re-deriving paths from `$HOME`:

```bash
EVOSHELL_BIN="${EVOSHELL_BIN:-$HOME/.local/bin}"
EVOSHELL_CONFIG="${EVOSHELL_CONFIG:-$HOME/.config/quickshell/evoshell}"
EVOSHELL_STATE="${EVOSHELL_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/evoshell}"
EVOSHELL_CACHE="${EVOSHELL_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/evoshell}"
EVOSHELL_DATA="${EVOSHELL_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/evoshell}"
```

Hyprland bindings may use full paths when `PATH` is unreliable.

## Bash style

Scripts under `~/.local/bin/evo-*`:

- 2-space indentation, no tabs
- Shebang: `#!/bin/bash` (not `#!/usr/bin/env bash`)
- Bash 5 style: `[[ ]]` for string/file tests, `(( ))` for numeric tests
- In `[[ ]]`, don't quote variables but do quote string literals (e.g. `[[ $cmd == "bar" ]]`)
- Prefer full `if`/`else` over relying on `exec`/`exit` to make code unreachable
- Quote paths that contain spaces instead of escaping with `\`
- Scripts meant to be sourced (e.g. `evo-bar-common`, `evo-theme-lib`) omit `set -e` unless intentional

## Command naming

All evoshell commands start with `evo-`. Use the prefix that matches purpose:

| Prefix | Purpose | Examples |
|--------|---------|----------|
| `evo-bar-*` | Bar poll wrappers only (one JSON line stdout) | `evo-bar-weather`, `evo-bar-github` |
| `evo-dash-*` | Dashboard / Hypr window control (not bar data) | `evo-dash-hypr`, `evo-dash-player`, `evo-dash-btop` |
| `evo-theme-*` | Theme generation and apply | `evo-theme`, `evo-theme-gtk` |
| `evo-system-*` | Session maintenance | `evo-system-cleanup`, `evo-system-backup` |
| `evo-menu-*` | Launcher helpers | `evo-menu-list`, `evo-menu-thumb` |
| bare `evo-*` | Feature CLIs matching plugin domains | `evo-network`, `evo-ipc`, `evo-player`, `evo-film` |

New bar widgets: thin `evo-bar-*` wrapper → feature CLI `bar` subcommand when the domain has a feature CLI.

Plugin IDs use `evo.<feature>` with dots for variants (`evo.shopify_diy`, `evo.transmission.add`). Tray audio: `evo.volume` + `bar-volume`, `evo.media` + `bar-media`; tray media click toggles dashboard `evo.player` via `evo-dash-player`. Layer namespaces: `evo-<kebab>` from plugin id (`.` → `-`, `_` → `-`).

Feature CLI ↔ plugin: `evo-player` = music backend (`evo.player`); `evo-film` = film/TV library (`evo.library` overlay). Do not use `evo-media` (collides with `evo.media` MPRIS popup).

Dashboard window titles match plugin ids (`evo.shopify`, `evo.player`). Toggle via `evo-ipc shell toggle evo.shopify` — no bespoke `shopifyOpen` IPC.

## Prefer project helpers

Use existing helpers instead of raw equivalents:

| Task | Use |
|------|-----|
| Shell IPC | `evo-ipc` (not raw `quickshell ipc`) |
| Bar JSON helpers | source `evo-bar-common` |
| Theme paths / apply | source `evo-theme-lib` |
| Restart shell | `evo-system-restart` or `evo-system restart` |
| Reload bar layout | `evo-ipc shell reloadConfig` |
| Notifications | evoshell `evo.notifications` service via IPC |
| Secrets | `~/.local/share/evoshell/secrets.env` (never commit) |

Don't add defensive presence checks for commands that ship with the default install set.

## Config refresh vs restart

| Change | Action |
|--------|--------|
| `shell.json` layout, intervals, hover targets | `evo-ipc shell reloadConfig` |
| `theme.json` colours | live — `Theme.qml` watches the file |
| New/edited plugin in `shell.qml` `pluginTable` | full shell restart |
| New bar widget type (`qmldir`, `BarWidgetCatalog`) | full shell restart |
| Hyprland layer rules (`evoshell.lua`) | Hypr reload; often needs shell restart too |

When unsure, restart. `reloadConfig` only reloads `shell.json`.

## Menu and panel IDs

- Panel module ids are canonical (`calc`, `clipboard`, `settings`). Do not add new aliases.
- Legacy `"tools"` → `"calc"` exists for compatibility only — do not add more.
- Static menu entries live in `plugins/menu/MenuEntries.js`. Keep names stable.

## QML conventions

QML in this directory:

- 4-space indentation (match existing files)
- New bar widgets: register in `plugins/bar/widgets/qmldir` and `BarWidgetCatalog.qml` — not `BarSection.qml`
- `BarWidgetCatalog` root must be `Item`, not `QtObject`
- `import Quickshell` when using `Quickshell.execDetached` or env
- Streaming bar data (e.g. cava): `SplitParser`, not interval polling
- `CommandWidget` bar scripts print one JSON line; hover popups may read `lastPayload`

## Typography

All font sizes live in `Commons/Theme.qml` and derive from `fontPixelSize` in `theme.json` (default **13**). Use the generic `Theme.fontSize*` scale everywhere — bar, panel, hover popup, menu, lock screen, and overlays share the same tokens. Do not add surface-specific font properties (`hoverPopupBody`, `panelTitle`, etc.) or hardcoded `font.pixelSize` numbers.

### Config

| Token | Source |
|-------|--------|
| `Theme.fontFamily` | `theme.json` |
| `Theme.fontBold` | `true` (fixed) |
| `Theme.fontPixelSize` | `theme.json` — base for the whole scale |

### Scale (`Theme.fontSize*`)

| Token | Formula | px @13 | Typical use |
|-------|---------|--------|-------------|
| `fontSizeXxs` | max(8, base − 3) | 10 | Fine print, dim labels |
| `fontSizeXs` | max(9, base − 2) | 11 | Detail text |
| `fontSizeS` | max(9, base − 1) | 12 | Chart axes, bar secondary, small panel text |
| `fontSizeM` | base | 13 | Body, bar, default |
| `fontSizeL` | base + 1 | 14 | Labels, hints, secondary |
| `fontSizeXl` | base + 2 | 15 | Stat emphasis |
| `fontSize2xl` | base + 3 | 16 | Section titles, icons |
| `fontSize3xl` | base + 5 | 18 | Popup body |
| `fontSize4xl` | base + 7 | 20 | Icons |
| `fontSize5xl` | base + 8 | 21 | Stat values |
| `fontSize6xl` | base + 9 | 22 | Menu list, calc input |
| `fontSize7xl` | fontSizeS × 2 | 24 | Large overlay small text |
| `fontSize8xl` | base × 2 | 26 | Large overlay body |
| `fontSize9xl` | base + 15 | 28 | Lock clock, large titles |
| `fontSizeHero` | base × 3 | 39 | Hero numbers (stocks price, github count) |
| `fontSizeHeroLg` | base × 4 | 52 | Fullscreen hero (weather temp) |

### Rules

- Reference `Theme.fontSize*` directly in QML, or alias at module top for readability (`readonly property int bodyFont: Theme.fontSize3xl`).
- Reuse the same token when panel and popup need the same visual weight (e.g. both use `fontSizeL` for hints).
- Do not use ad-hoc offsets (`statFont + 1`, `bodyFont + 6`) — pick the matching scale step or add a new step in `Theme.qml` if genuinely needed.
- Layout-derived icon sizing (`headerIconSize * 0.72`) is fine; font size itself should still come from the scale.
- Shared components (`HoverPopupStatBox`, `HoverPopupHeader`, `SparklineChart`) must use scale tokens, not local magic numbers.
- Changing `fontPixelSize` in `theme.json` rescales the entire UI — prefer that over one-off pixel tweaks in modules.

## Testing

Run focused checks for the area you changed:

```bash
evo-ipc shell ping                          # shell is up
evo-ipc shell reloadConfig                  # after shell.json edits
.local/bin/evo-bar-weather                  # bar script prints valid JSON
journalctl -t evoshell -f                   # runtime errors
```

Visual/QML changes need manual verification in the running desktop (bar, hover popups, panel, overlays).

## Adding things (checklist)

| Change | Update |
|--------|--------|
| New overlay/menu plugin | `shell.qml` → `pluginTable`; `panelPluginIds` if `keepLoaded` |
| New bar widget | `widgets/qmldir`, `BarWidgetCatalog.qml`, `shell.json` |
| New panel tab | `Panel.qml` → `dockModules`, `plugins/panel/modules/qmldir` |
| New layer namespace | `~/.config/hypr/evoshell.lua` |
| New bar data source | feature CLI + `evo-bar-*` wrapper, source `evo-bar-common` |
