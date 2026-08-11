# Evo shell — agent notes

Omarchy Quattro-style consolidated Hyprland desktop shell. One **Quickshell** process (`evo-shell`) replaces Waybar, Walker (launcher/clipboard), Mako, hyprlock, hyprpaper, and hypridle.

Read this before editing bar widgets, shell IPC, Hypr bindings, or `evo-bar-*` scripts.

## Directory layout

| Path | Purpose |
|------|---------|
| `~/.config/quickshell/evo-shell/` | QML shell, plugins, `shell.json`, `theme.json` |
| `~/.local/share/evo-shell/secrets.env` | API tokens (not in git) |
| `~/.local/bin/evo-*` | Launch, IPC, bar data scripts |
| `~/.config/hypr/autostart.lua` | Starts `evo-launch-shell` |
| `~/.config/hypr/bindings.lua` | Keybinds → `evo-shell-ipc` |
| `~/.config/hypr/evo-shell.lua` | Layer rules for `evo-*` namespaces |
| `~/.local/state/evo-shell/wallpaper` | Current wallpaper path |
| `~/.cache/evo-shell/bar/` | TTL JSON cache for `evo-bar-*.sh` output |

**Legacy (do not use for new work):**

- `~/.config/waybar/` — removed; do not add new fallbacks

## Naming

- Quickshell config name: `evo-shell` → `quickshell -n -c evo-shell`
- Plugin IDs: `evo.menu`, `evo.bar`, `evo.audio`, … (prefix `evo.`)
- Wayland layer namespaces: `evo-bar`, `evo-menu`, `evo-panel`, `evo-notifications`, `evo-background`
- Scripts: `evo-shell-ipc`, `evo-launch-shell`, `evo-shell-layout.sh`, `evo-bar-{name}.sh`

## Run, reload, debug

```bash
# Supervisor (autostart)
~/.local/bin/evo-launch-shell

# Restart shell (relaunches evo-shell)
~/.local/bin/evo-restart-shell.sh

# Reload bar layout without full restart
~/.local/bin/evo-shell-ipc shell reloadConfig

# Logs
journalctl -t evo-shell -f

# Hypr reload (bindings/autostart)
hyprctl reload
```

`evo-launch-shell` runs `systemd-cat -t evo-shell -- quickshell -n -c evo-shell` with crash relaunch logic.

## IPC

Wrapper: `~/.local/bin/evo-shell-ipc` → `quickshell ipc -c evo-shell call …`

### Shell target (`evo-shell-ipc shell …`)

| Method | Notes |
|--------|--------|
| `ping` | Returns `ok` |
| `toggle <id> [payloadJson]` | **Always pass payload** for toggle/summon (use `""` if empty) |
| `summon <id> [payloadJson]` | Open menu/panel |
| `hide <id>` | Close panel |
| `call <pluginId> <method> [arg]` | Invoke service method |
| `reloadConfig` | Re-read `shell.json` |
| `listPlugins` | JSON plugin table |

Examples:

```bash
evo-shell-ipc shell toggle evo.menu
evo-shell-ipc shell toggle evo.menu '{"mode":"apps"}'
evo-shell-ipc shell call evo.lock lock
evo-shell-ipc evo.audio stepUp          # direct plugin IPC
evo-shell-ipc background next
```

Hypr `bindings.lua` uses `$HOME/.local/bin/evo-shell-ipc` (PATH may not include `~/.local/bin`).

### Plugin IPC targets

| Target | Methods |
|--------|---------|
| `background` | `refresh`, `set(path)`, `setInstant(path)`, `next`, `prev` |
| `evo.audio` | `stepUp`, `stepDown`, `toggleMute`, `step(up\|down)` |
| `evo.lock` | `lock`, `isLocked`, `status` via `shell call`; direct target is `lock` |
| `idle` | `status` |

Hypr volume keys call `evo-shell-ipc evo.audio` directly, not `shell call`.

## `shell.json` (version 1)

Canonical path: `~/.config/quickshell/evo-shell/shell.json`.

```json
{
  "version": 1,
  "idle": { "screensaver": 1800, "lock": 900 },
  "notifications": { "durationMs": 3000 },
  "bar": {
    "id": "evo.bar",
    "position": "bottom",
    "output": "HDMI-A-1",
    "layout": {
      "left": [ /* widget entries */ ],
      "center": [ /* … */ ],
      "right": [ /* … */ ]
    }
  }
}
```

Widget entry fields depend on type (see below). `FileView` watches this file; `reloadConfig` or save triggers `applyShellConfig()` → `reloadBar()`.

| Key | Purpose |
|-----|---------|
| `idle.screensaver` / `idle.lock` | Seconds before screensaver / lock |
| `notifications.durationMs` | How long all popups stay visible (volume OSD, calc copy, dbus notifications) |

Use `theme.json` for colours and notification sizing only — not timing.

| `theme.json` key | Purpose |
|------------------|---------|
| `surfaceOpacity` | Panel/dock background alpha; default `0.97` (match hypr `decoration.active_opacity`) |
| `surfaceOpacityInactive` | Reserved for unfocused surfaces; default `0.88` (match hypr `inactive_opacity`) |

## Architecture

```
shell.qml
├── pluginTable → services (background, audio, idle, lock, notifications)
├── Loader → plugins/bar/Bar.qml (from barConfig)
├── Instantiator → menu, panel
└── IpcHandler target "shell"
```

**Services** live in `plugins/*/Service.qml` (or `Background.qml`), registered in `pluginTable`, often `keepLoaded: true`. Clipboard watch remains `evo.clipboard` (service-only); clipboard UI lives in an `evo.panel` module.

**Bar-only widgets** are **not** in `pluginTable`; mapped in `plugins/bar/widgets/BarSection.qml`.

**Shared Commons helpers:** `Util.screenForOutput`, `Format`, `JsonPollRunner`, `SparklineChart`.

### Left dock panels

Fixed left-side panels that reserve screen width via `exclusiveZone` (windows shift right instead of being covered). Reuse `Commons/LeftDockPanel.qml`:

```qml
LeftDockPanel {
    id: dock
    layerNamespace: "evo-mytool"   // add to hypr/evo-shell.lua layer rules
    title: "My tool"                // optional header

    // children go into the panel body; use Layout.* attached properties
    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 48 /* … */ }
    Item { Layout.fillWidth: true; Layout.fillHeight: true /* … */ }
}
```

Plugin root should call `dock.reveal()` / `dock.conceal()` from `open()` / `close()`, and register in `shell.qml` `panelPluginIds`. The unified left dock is `plugins/panel/Panel.qml` with a `DockModuleBar` and per-module QML under `plugins/panel/modules/`.

### Bar widget routing (`BarSection.qml`)

| `id` in shell.json | Widget | Data source |
|--------------------|--------|-------------|
| `evo.menu` | `MenuBarWidget` | — |
| `evo.workspaces` | `WorkspacesWidget` | Hyprland |
| `evo.clock` | `ClockWidget` | Qt `format` in settings |
| `evo.audio` | `AudioWidget` | Pipewire via `evo.audio` service |
| `evo.tray` | `TrayWidget` | Quickshell tray |
| `evo.github` | `GithubWidget` | `evo-bar-github.sh` |
| `evo.shopify` | `ShopifyWidget` | `evo-bar-shopify.sh` + `store` setting |
| `evo.cava` | `CavaWidget` | Pipewire peak monitor |
| `type: "command"` or `exec` | `CommandWidget` | polled bash, JSON stdout |

To add a native bar widget:

1. Create `plugins/bar/widgets/MyWidget.qml`
2. Register in `widgets/qmldir`
3. Add branch in `BarSection.qml` → `widgetComponentFor()`
4. Reference by `id` in `shell.json`

## Bar data scripts (`evo-bar-*.sh`)

Live in `~/.local/bin/`. Shared helpers: `evo-bar-common.sh`, `evo-weather-lib.sh`.

- **Secrets:** `EVO_SECRETS_FILE` → `~/.local/share/evo-shell/secrets.env`
- **Heatmap colours:** `~/.themes/current/evo-bar.css` via `evo_bar_load_heatmap_colors`
- **TTL cache:** `evo_bar_cache_read` / `evo_bar_cache_write` in `~/.cache/evo-shell/bar/`
- **Weather env:** `EVO_WEATHER_LAT` / `EVO_WEATHER_LON`

### Output conventions

**CommandWidget** (btc, spcx, weather, recording): one-shot JSON per poll:

```json
{ "text": "…", "tooltip": "…", "class": "…" }
```

Pango `<span foreground='…'>` in `text` is converted to RichText in `CommandWidget`.

**ShopifyWidget:** structured JSON (preferred):

```json
{
  "text": "legacy full string with spans",
  "label": "D £4,474 | 8.8%",
  "bars": [{ "level": 5, "colorLevel": 4, "color": "#7fbbb3" }, …],
  "orders": 20
}
```

Widget draws native `Rectangle` bars from `bars`.

**GithubWidget:** structured JSON with `today` and `cells`.

**CavaWidget:** Pipewire `PwNodePeakMonitor` audio visualizer.

**Layout scripts:** `evo-shell-layout.sh bar|panel get|toggle` (wrappers: `evo-bar-layout.sh`, `evo-panel-layout.sh`).

## Theme and bar spacing (`Commons/Theme.qml`)

Colours are read live from `theme.json` via `FileView`. Bar scripts read heatmap colours from `evo-bar.css`.

| Property | Typical use |
|----------|-------------|
| `barHeight` | 32 |
| `barPaddingX` | Widget horizontal padding |
| `barGap` | Gap between bar modules |
| `barSectionGap` | Larger gap (e.g. volume ↔ clock) |
| `sparklineGap` | Gap between label text and chart (Shopify, GitHub) |
| `sparklineBarWidth` / `sparklineBarSpacing` | Native bar charts |
| `fontFamily` | `CaskaydiaMono Nerd Font`, bold |

`themes-apply.sh` updates live consumers without `reloadConfig`: `Theme.qml` watches `theme.json`, wallpaper changes go through `evo.background` IPC, and `~/.cache/evo-shell/bar/` is cleared so heatmap JSON cannot retain stale colours.

### Theme switcher (`themes-apply.sh`)

Pipeline: **build** (staging under `~/.themes/next`) → **promote** (atomic swap to `current`) → **activate** (Hypr `theme.lua`, `theme.json`, GTK, wallpaper, icons, editor theme) → **notify** (Ghostty reload, `hyprctl reload`, preview warm, btop, post-switch hook).

| Output | Notes |
|--------|--------|
| `theme.json` | Written from `colors.toml`; `Theme.qml` reloads live |
| `~/.themes/current/evo-bar.css` | Bar heatmap colours |
| `~/.config/hypr/theme.lua` | Hypr border colours |
| GTK / Ghostty / btop / vscode-theme / Obsidian / browser CSS | Generated in staging, activated after promote |

Browser CSS (`colors.css`, `shoelace-hex.css`) is served from `~/.themes/current/` via darkhttpd on port 8008 for the Violentmonkey userscript in `~/.themes/shared/violentmonkey.js`. Site-specific CSS lives in `~/.themes/shared/css/`.
| Wallpaper | First lexicographically sorted image in `backgrounds/` (`1-` prefix promotes default) |

**Manual setters:** `themes-set-obsidian.sh`, `themes-set-gtk.sh`, `themes-set-vscode.sh`, `themes-set-icons.sh`, `themes-hook-post-switch` (Obsidian also syncs automatically on theme switch).

**Menu previews:** `evo-menu-list-previews.sh` (fast TSV listing), `evo-menu-preview-warm.sh` (thumbnail writer on startup and after switch; prunes orphan cache). Preview tiles use `cache: false` so regenerated thumbs appear without shell restart.

## Quickshell patterns

### Imports

Bar widgets: `import Quickshell`, `import Quickshell.Io`, `import "../../../Commons"`.

Audio: `import Quickshell.Services.Pipewire` — use `Pipewire.defaultAudioSink`, `PwObjectTracker`.

### Process I/O

- **One-shot:** `Process` + `StdioCollector { onStreamFinished: … }`
- **Streaming:** `stdout: SplitParser { onRead: function(data) { … } }` (cava)
- **Do not** poll streaming data with `interval` + `timeout` — use `SplitParser` or `StdioCollector` with `waitForEnd: false`

### Bar widget lifecycle

Widgets receive `settings` from shell.json entry via Loader `onLoaded`. Implement `restartPolling()` and `onSettingsChanged` for interval-based widgets.

### Common QML pitfalls (already hit)

- `import Quickshell` required for singletons / `Quickshell.execDetached`
- `widgets/qmldir` must list every bar widget
- `toggle` IPC needs two args when payload omitted — handled in `evo-shell-ipc`
- `ToolTip` on bar items broke load — avoid unless tested
- Clock: use Qt date format (`%a %d %H:%M`), not `strftime`
- `errorString()` on Loader/Component for load failures

## Hypr integration

```lua
-- autostart.lua
hl.exec_cmd(HOME .. "/.local/bin/evo-launch-shell")

-- bindings.lua
local shell_ipc = bin .. "/evo-shell-ipc"
-- evo.menu, evo.panel (clipboard/stats modules), evo.audio, evo-system-lock, evo-wallpaper.sh

-- evo-shell.lua
hl.layer_rule({ match = { namespace = "evo-bar" }, no_anim = true, animation = "none" })
```

Menu power/system entries use `evo-system-lock`, `evo-restart-shell.sh`, `evo-wallpaper.sh`.

## Adding a bar module (checklist)

1. **Native widget** (streaming, Pipewire, rich UI) → QML in `plugins/bar/widgets/`
2. **Simple polled data** → `evo-bar-foo.sh` + `CommandWidget` entry in `shell.json`
3. **Structured chart** → script emits JSON fields + QML renders with `Rectangle` / `Repeater`
4. Register routing in `BarSection.qml` if not `type: command`
5. `evo-shell-ipc shell reloadConfig` or restart shell

## User preferences (repo)

- Main branch: `master`
- Commit messages: lowercase
- Do not commit unless asked
- Minimize diff scope; match existing QML/bash style
- Do not edit `.cursor/plans/*.plan.md` unless asked
