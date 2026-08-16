# Evoshell

A Quickshell desktop shell for Hyprland — bar, panel, plugins, IPC, and layer integration.

## What this is

Evoshell is a custom desktop environment layer built on [Quickshell](https://quickshell.org). It renders a configurable status bar, a left dock panel, launcher menu, hover popups, and fullscreen overlays. Background services handle audio, wallpaper, lock screen, idle detection, clipboard history, and notifications.

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
| **G** | `evo.wallpaper` | Wallpaper display + cycling |
| **L** | `evo.lock` | Lock screen |
| **D** | `evo.idle` | Screensaver + auto-lock |
| **N** | `evo.notifications` | Brief toast notifications |
| **K** | `evo.clipboard` | Clipboard history service |

### Bar data

| | Component | Role |
|---|-----------|------|
| **X** | `evo-bar-*.sh`, `evo-bar-system` | Poll scripts → JSON line for bar widgets |
| **T** | `theme.json` | Live shell colours (written by `evo-theme-lib.sh`) |
| **H** | `evoshell.lua` | Hyprland layer rules for `evo-*` namespaces |

### Overlays

| | Plugin | Trigger |
|---|--------|---------|
| **W** | `evo.calendar`, `evo.weather`, `evo.stats_diy`, `evo.stats_tgs`, `evo.github`, `evo.stocks`, `evo.sound`, `evo.network`, `evo.cursor` | Bar hover (`onHover` in `shell.json`) |
| **C** | `evo.system` | Bar click → `evo-bar-btop` toggle (Hyprland window rule) |
| **O** | `evo.library`, `evo.theme`, `evo.wallpaper` | Keybind / menu / IPC toggle |
| **R** | `hyprshot` + `satty` (`evo-screenshot edit`) | Keybind (`bindings.lua`) |

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
│   ├── wallpaper/
│   ├── …
└── diagram.svg        # architecture diagram
```

## Paths

| What | Where |
|------|--------|
| Shell config | `~/.config/quickshell/evoshell/` |
| Bar/panel scripts | `~/.local/bin/evo-*` |
| Screenshots | `hyprshot` → `/tmp/hyprshot.png`, annotate via `~/.local/bin/evo-screenshot edit` (`satty`) |
| IPC | `~/.local/bin/evo-ipc` |
| Hypr integration | `~/.config/hypr/{autostart,bindings,evoshell,windows}.lua` |
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
└── syncServices → wallpaper, audio, idle, lock, notifications, clipboard

shell.json → bar.layout (widgets, intervals, onHover)
BarWidgetCatalog → native widgets (evo.clock, evo.system, evo.github, …)
CommandWidget → exec scripts (evo-bar-*.sh) → JSON line
```

## Plugin kinds

| Kind | Examples | Entry |
|------|----------|-------|
| Service | `evo.audio`, `evo.wallpaper`, `evo.idle`, `evo.lock` | `Service.qml` |
| Bar | `evo.bar` | `Bar.qml` + `shell.json` layout |
| Click action | `evo.system` | `SystemWidget` → `evo-bar-btop` (btop in ghostty; geometry in `windows.lua`) |
| Hover popup | `evo.calendar`, `evo.weather`, `evo.stats_diy`, `evo.stats_tgs`, `evo.github`, `evo.stocks`, `evo.sound`, `evo.network`, `evo.cursor` | `BarHoverPopup` + `*Module.qml` |
| Fullscreen overlay | `evo.library`, `evo.theme`, `evo.wallpaper` | `CenteredOverlay` / `CarouselOverlay` |
| Menu | `evo.menu` | Custom `PanelWindow` (`evo-menu`) |
| Panel | `evo.panel` | `Panel.qml` → dock modules `calc`, `clipboard`, `settings` |

## Naming conventions

- **Plugin IDs**: `evo.<feature>` (`evo.calendar`, `evo.panel`)
- **Bar widgets**: `evo.<feature>` in `BarWidgetCatalog` and `shell.json` layout
- **Layer namespaces**: `evo-<kebab>` (`evo-bar`, `evo-calendar`, …) — rules in `evoshell.lua`
- **IPC service targets**: `evo.audio`, `evo.wallpaper`, `evo.idle`, `evo.lock` (legacy `background`/`wallpaper`/`idle`/`lock` still accepted by `evo-ipc`)

## IPC

```bash
~/.local/bin/evo-ipc shell toggle <pluginId> [payloadJson]
~/.local/bin/evo-ipc evo.audio stepUp
~/.local/bin/evo-ipc evo.wallpaper next
~/.local/bin/evo-ipc evo.lock lock
```

Hypr bindings use the full path `~/.local/bin/evo-ipc` (PATH may not include it).

## Bar scripts

- `~/.local/bin/evo-bar-*.sh` source `evo-bar-common.sh`
- `evo-bar-system` — CPU %, uptime, OS age (`Xd / Yd`) for `evo.system`
- `evo-bar-weather` — weather label + hover popup payload for `evo.weather`
- `evo-bar-btop` — show/hide/toggle ghostty btop (`131×31` cells); size/position via Hyprland `btop-float` rule in `windows.lua`
- `CommandWidget` expects one JSON line: `{ "text", "class", … }`; stores full parse in `lastPayload`
- Poll interval from `shell.json` `interval` (seconds)
- Cursor hover popup reads bar `lastPayload` — no separate poll; `evo-bar-cursor.sh` has no file cache
- Heatmap colours: `~/.themes/current/evo-bar.css`
- Live shell colours: `theme.json` (watched by `Theme.qml`)

## Hover popups

- Use `BarHoverPopup` (`Commons/BarHoverPopup.qml`) — plugin root; wraps `BarHoverOverlay` + shell hover API
- Content modules use `SectionPanel` fieldsets and `Theme.hoverPopup*` typography tokens
- Bar widgets set `onHover` to plugin id (`evo.weather`, `evo.stats_diy`, `evo.github`, …)
- `CommandWidget` publishes bar JSON to `shell.setHoverPopupData` for instant `bootstrapFromCache` on open
- Qt `ToolTip` on bar items is only used when `onHover` is unset (not the general pattern)

## Media library

`evo.library` — Super+M. Index: `~/.local/state/evoshell/media.db`. Scan: `evo-media scan`.

## Wallpapers

Wallpapers live in `~/.themes/<theme>/wallpapers/`. The picker lists the active theme's set; cycle (`evo-wallpaper next|prev`) and theme apply default read from `~/.themes/current/wallpapers/`.

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
