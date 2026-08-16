# Agent guide

House rules for contributing to evoshell. Architecture and component maps live in `README.md` — start here for *how* to change things, not *what* exists.

## Where to look

| Topic | Location |
|-------|----------|
| Architecture, plugin map, pitfalls | `README.md` (this directory) |
| Cursor agent procedures | `~/.cursor/skills/evoshell/SKILL.md` |
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
| `evo-bar-*` | Bar poll wrappers (one JSON line stdout) | `evo-bar-weather`, `evo-bar-github` |
| `evo-theme-*` | Theme generation and apply | `evo-theme`, `evo-theme-gtk` |
| `evo-system-*` | Session maintenance | `evo-system-cleanup`, `evo-system-backup` |
| `evo-app-*` | Panel mini-app backends | `evo-app-calc` |
| `evo-menu-*` | Launcher helpers | `evo-menu-list`, `evo-menu-thumb` |
| bare `evo-*` | Feature CLIs, IPC, services | `evo-network`, `evo-ipc`, `evo-media` |

New bar widgets: thin `evo-bar-*` wrapper → feature CLI `bar` subcommand. Do not put fetch/parse logic only in the wrapper.

Plugin IDs use `evo.<feature>` (`evo.calendar`, `evo.panel`). Layer namespaces use `evo-<kebab>` except tray popups (`bar-volume`, `bar-media`).

## Prefer project helpers

Use existing helpers instead of raw equivalents:

| Task | Use |
|------|-----|
| Shell IPC | `evo-ipc` (not raw `quickshell ipc`) |
| Bar JSON helpers | source `evo-bar-common` |
| Theme paths / apply | source `evo-theme-lib` |
| Restart shell | `evo-restart` or `evo-system restart` |
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
- Hover popups: `BarHoverPopup` + `SectionPanel` + `Theme.hoverPopup*` tokens
- `import Quickshell` when using `Quickshell.execDetached` or env
- Clock `format`: Qt tokens (`%a %d %H:%M`), not strftime
- Streaming bar data (e.g. cava): `SplitParser`, not interval polling
- `CommandWidget` bar scripts print one JSON line; hover popups may read `lastPayload`

## Git

- Commits should be atomic (one coherent change)
- Commit messages: lowercase, succinct, describe the change
- Never commit `secrets.env` or other credential files
- Default branch is `master`

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
