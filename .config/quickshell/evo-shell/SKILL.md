---
name: evoshell
description: >-
  Develop the evo-shell Quickshell desktop (bar, panel, plugins, IPC, Hyprland
  integration). Use when the user invokes /evoshell, mentions evo-shell,
  quickshell evo-shell, bar widgets, shell.json, or evo-shell-ipc.
disable-model-invocation: true
---
# Evo shell development

Use this skill when the user invokes `/evoshell` or asks to work on the evo-shell Quickshell desktop.

## On `/evoshell`

1. Load this skill and treat any text after `/evoshell` as the dev task.
2. If there is no task text, ask what they want to change (bar widget, tooltip, panel module, IPC, theme, etc.).
3. Read relevant files under `~/.config/quickshell/evo-shell/` before editing.
4. Prefer minimal diffs; match existing QML/bash patterns.
5. Restart or reload appropriately (see below).

## Paths

| What | Where |
|------|--------|
| Shell config | `~/.config/quickshell/evo-shell/` (`shell.qml`, `shell.json`, `theme.json`) |
| Bar/panel scripts | `~/.local/bin/evo-*` |
| Hypr integration | `~/.config/hypr/{autostart,bindings,evo-shell}.lua` |
| Secrets | `~/.local/share/evo-shell/secrets.env` (`chmod 600`) |
| State | `~/.local/state/evo-shell/` |
| Bar cache | `~/.cache/evo-shell/bar/` |

```bash
evo-launch-shell
~/.local/bin/evo-restart-shell.sh
~/.local/bin/evo-shell-ipc shell reloadConfig   # shell.json only
journalctl -t evo-shell -f
```

## Architecture

```
shell.qml
├── pluginTable + panelPluginIds
├── barLoader → plugins/bar/Bar.qml
├── Instantiator → menu/panel/hover plugins
└── syncServices → background, audio, idle, lock, notifications, clipboard

shell.json → bar.layout (widgets, intervals, onHover)
BarWidgetCatalog → native widgets (evo.clock, evo.github, …)
CommandWidget → exec scripts (evo-bar-*.sh) → JSON line
```

| Kind | Examples | Entry |
|------|----------|--------|
| Service | `evo.audio`, `evo.background`, `evo.idle`, `evo.lock` | `Service.qml` / `Background.qml` |
| Bar | `evo.bar` | `Bar.qml` + `shell.json` layout |
| Hover tooltip | `evo.calendar`, `evo.stats`, `evo.weather`, `evo.cursor` | `BarHoverPopup` + `*Module.qml` |
| Fullscreen overlay | `evo.library`, `evo.theme`, `evo.wallpaper` | `CenteredOverlay` / `PreviewOverlay` |
| Menu | `evo.menu` | Custom `PanelWindow` (`evo-menu`) |
| Panel | `evo.panel` | `Panel.qml` → dock modules `tools`, `clipboard`, `settings` |

## Naming conventions

- **Plugin IDs**: `evo.<feature>` (`evo.calendar`, `evo.panel`)
- **Bar widgets**: `evo.<feature>` in `BarWidgetCatalog` and `shell.json` layout
- **Layer namespaces**: `evo-<kebab>` (`evo-bar`, `evo-calendar`, …) → rules in `~/.config/hypr/evo-shell.lua`
- **IPC service targets**: `evo.audio`, `evo.background`, `evo.idle`, `evo.lock` (legacy `background`/`idle`/`lock` still accepted by `evo-shell-ipc`)

## Registration checklist

| Change | Update |
|--------|--------|
| New overlay/menu plugin | `shell.qml` → `pluginTable` + `panelPluginIds` if `keepLoaded` |
| New bar widget | `plugins/bar/widgets/qmldir`, `BarWidgetCatalog.qml`, `shell.json` layout |
| New panel tab | `Panel.qml` → `dockModules`, `plugins/panel/modules/qmldir` |
| New layer namespace | `~/.config/hypr/evo-shell.lua` regex |

## IPC

```bash
~/.local/bin/evo-shell-ipc shell toggle <pluginId> [payloadJson]
~/.local/bin/evo-shell-ipc evo.audio stepUp
~/.local/bin/evo-shell-ipc evo.background next
~/.local/bin/evo-shell-ipc evo.lock lock
```

Hypr bindings use full path `~/.local/bin/evo-shell-ipc` (PATH may not include it).

## Bar scripts

- `~/.local/bin/evo-bar-*.sh` source `evo-bar-common.sh`
- `CommandWidget` expects one JSON line: `{ "text", "class", … }`; stores full parse in `lastPayload`
- Poll interval from `shell.json` `interval` (seconds)
- Cursor tooltip reads bar `lastPayload` — no separate poll; `evo-bar-cursor.sh` has no file cache
- Heatmap colours: `~/.themes/current/evo-bar.css`
- Live shell colours: `theme.json` (watched by `Theme.qml`)

## Hover popups

- Use `BarHoverPopup` (`Commons/BarHoverPopup.qml`) — wraps `AttachedOverlay` + shell hover API
- Bar widgets set `onHover` to plugin id (`evo.stats`, `evo.cursor`, …)
- Do not use Qt `ToolTip` on bar items (broke load)

## Pitfalls (already hit)

- `BarWidgetCatalog` root must be `Item`, not `QtObject`
- New bar widgets: `widgets/qmldir` + `BarWidgetCatalog` — not `BarSection.qml`
- `import Quickshell` needed for `Quickshell.execDetached` / env
- Clock `format`: Qt tokens (`%a %d %H:%M`), not strftime
- Streaming bar data (cava): `SplitParser`, not interval polling
- New overlay plugins need full shell **restart**, not just `reloadConfig`
- Panel payload alias: `"calc"` → `"tools"`

## Media library

`evo.library` — Super+M. Index: `~/.local/state/evo-shell/media.db`. Scan: `evo-media.sh scan`.

## User prefs

- Branch `master`, lowercase commit messages
- Don't commit unless asked
- Minimal diffs
