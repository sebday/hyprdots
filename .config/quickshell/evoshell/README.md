# Evoshell

A Quickshell desktop shell for Hyprland — bar, panel, plugins, IPC, and layer integration.

## What this is

Evoshell is a custom desktop environment layer built on [Quickshell](https://quickshell.org). It renders a configurable status bar, a left dock panel, launcher menu, hover tooltips, and fullscreen overlays. Background services handle audio, wallpaper, lock screen, idle detection, clipboard history, and notifications.

Hyprland keybinds and `evo-ipc` commands talk to a single running Quickshell instance (`quickshell -c evoshell`).

## How it works

The shell loop:

```
shell.json  →  shell.qml  →  bar / panel / menu  →  user input
     ↑              ↓                                    ↓
  reloadConfig   services                          evo-bar-*.sh
     ↑              ↓                                    ↓
theme.json  ←  Theme.qml  ←  ~/.local/state/evoshell  ←  JSON line
```

1. **Config** — `shell.json` defines bar layout (widgets, intervals, hover targets). `theme.json` supplies live colours to `Theme.qml`.
2. **Core** — `shell.qml` owns the plugin table, loads services, routes summon/toggle/hover, and exposes an IPC handler.
3. **Surfaces** — `evo.bar` renders widgets from `BarWidgetCatalog` and `shell.json`. `evo.panel` hosts dock modules. `evo.menu` is the launcher.
4. **Data** — `CommandWidget` runs `evo-bar-*.sh` scripts that print one JSON line. Hover popups read bar `lastPayload` or poll their own modules.
5. **State** — settings, clipboard previews, media index, usage frecency, and font prefs persist under `~/.local/state/evoshell/`.

## Component map

Letters match the diagram.

### The shell core

| | Component | Role |
|---|-----------|------|
| **S** | `shell.qml` | Plugin table, service sync, summon/toggle/hover API, bar loader |
| **I** | `evo-ipc` | CLI wrapper → `quickshell ipc -c evoshell call …` |
| **C** | `shell.json` | Bar layout, idle timeouts, panel side |

### The surfaces

| | Component | Role |
|---|-----------|------|
| **B** | `evo.bar` | Status bar — native widgets + command widgets |
| **P** | `evo.panel` | Left dock — tools, clipboard, settings |
| **M** | `evo.menu` | Application launcher (`evo-menu`) |

### Services

| | Plugin | Role |
|---|--------|------|
| **A** | `evo.audio` | PipeWire volume control |
| **G** | `evo.background` | Wallpaper cycling |
| **L** | `evo.lock` | Lock screen |
| **D** | `evo.idle` | Screensaver + auto-lock |
| **N** | `evo.notifications` | Brief toast notifications |
| **K** | `evo.clipboard` | Clipboard history service |

### Bar data

| | Component | Role |
|---|-----------|------|
| **X** | `evo-bar-*.sh` | Poll scripts → `{ "text", "class", … }` JSON |
| **T** | `theme.json` | Live shell colours (written by `evo-theme-lib.sh`) |
| **H** | `evoshell.lua` | Hyprland layer rules for `evo-*` namespaces |

### Overlays

| | Plugin | Trigger |
|---|--------|---------|
| **W** | `evo.weather`, `evo.stats`, `evo.network`, `evo.cursor` | Bar hover (`onHover` in `shell.json`) |
| **O** | `evo.library`, `evo.theme`, `evo.wallpaper` | Keybind / menu / IPC toggle |
| **R** | `evo.screenshot` | Keybind |

## Directory layout

```
evoshell/
├── shell.qml          # root — plugin table, IPC, loaders
├── shell.json         # user bar layout
├── theme.json         # live colours
├── Commons/           # shared QML (Theme, overlays, popups)
├── plugins/
│   ├── bar/           # Bar.qml + widgets/
│   ├── panel/         # Panel.qml + modules/
│   ├── menu/          # launcher
│   ├── audio/         # service plugins
│   ├── background/
│   ├── …
└── diagram.svg        # architecture diagram
```

## Paths

| What | Where |
|------|--------|
| Shell config | `~/.config/quickshell/evoshell/` |
| Bar/panel scripts | `~/.local/bin/evo-*` |
| IPC | `~/.local/bin/evo-ipc` |
| Hypr integration | `~/.config/hypr/{autostart,bindings,evoshell}.lua` |
| Secrets | `~/.local/share/evoshell/secrets.env` |
| State | `~/.local/state/evoshell/` |
| Bar cache | `~/.cache/evoshell/bar/` |

## Quick commands

```bash
evo-launch                              # start (via autostart)
~/.local/bin/evo-restart             # restart
~/.local/bin/evo-ipc shell ping          # health check
~/.local/bin/evo-ipc shell reloadConfig  # reload shell.json only
~/.local/bin/evo-ipc shell toggle evo.panel '{"module":"settings"}'
journalctl -t evoshell -f
```

## Internals

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

## Plugin kinds

| Kind | Examples | Entry |
|------|----------|-------|
| Service | `evo.audio`, `evo.background`, `evo.idle`, `evo.lock` | `Service.qml` / `Background.qml` |
| Bar | `evo.bar` | `Bar.qml` + `shell.json` layout |
| Hover tooltip | `evo.calendar`, `evo.stats`, `evo.weather`, `evo.cursor` | `BarHoverPopup` + `*Module.qml` |
| Fullscreen overlay | `evo.library`, `evo.theme`, `evo.wallpaper` | `CenteredOverlay` / `PreviewOverlay` |
| Menu | `evo.menu` | Custom `PanelWindow` (`evo-menu`) |
| Panel | `evo.panel` | `Panel.qml` → dock modules `calc`, `clipboard`, `settings` |

## Naming conventions

- **Plugin IDs**: `evo.<feature>` (`evo.calendar`, `evo.panel`)
- **Bar widgets**: `evo.<feature>` in `BarWidgetCatalog` and `shell.json` layout
- **Layer namespaces**: `evo-<kebab>` (`evo-bar`, `evo-calendar`, …) — rules in `evoshell.lua`
- **IPC service targets**: `evo.audio`, `evo.background`, `evo.idle`, `evo.lock` (legacy `background`/`idle`/`lock` still accepted by `evo-ipc`)

## IPC

```bash
~/.local/bin/evo-ipc shell toggle <pluginId> [payloadJson]
~/.local/bin/evo-ipc evo.audio stepUp
~/.local/bin/evo-ipc evo.background next
~/.local/bin/evo-ipc evo.lock lock
```

Hypr bindings use the full path `~/.local/bin/evo-ipc` (PATH may not include it).

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

## Media library

`evo.library` — Super+M. Index: `~/.local/state/evoshell/media.db`. Scan: `evo-media scan`.

## Adding things

| Change | Update |
|--------|--------|
| New overlay/menu plugin | `shell.qml` → `pluginTable` + `panelPluginIds` if `keepLoaded` |
| New bar widget | `plugins/bar/widgets/qmldir`, `BarWidgetCatalog.qml`, `shell.json` |
| New panel tab | `Panel.qml` → `dockModules`, `plugins/panel/modules/qmldir` |
| New layer namespace | `~/.config/hypr/evoshell.lua` regex |

## Pitfalls

- `BarWidgetCatalog` root must be `Item`, not `QtObject`
- New bar widgets: `widgets/qmldir` + `BarWidgetCatalog` — not `BarSection.qml`
- `import Quickshell` needed for `Quickshell.execDetached` / env
- Clock `format`: Qt tokens (`%a %d %H:%M`), not strftime
- Streaming bar data (cava): `SplitParser`, not interval polling
- New overlay plugins need full shell **restart**, not just `reloadConfig`
- Panel payload alias: legacy `"tools"` → `"calc"`


## App layout

Panel mini-apps live under `plugins/<name>/` (`calc/` combines `AppCalc` + `AppTasks` in one dock tab; `clipboard/` also hosts the clipboard service). Backends: `evo-app-calc`, `evo-app-clipboard` colocated with QML. State: `~/.local/state/evoshell/apps/`.
