# Evo shell — agent notes

Omarchy Quattro-style consolidated Hyprland desktop shell. One **Quickshell** process (`evo-shell`) replaces Waybar, Walker (launcher/clipboard/emojis), Mako, hyprlock, hyprpaper, and hypridle.

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

**Legacy (do not use for new work):**

- `~/.config/waybar/` — old Waybar config; secrets may still live there

## Naming

- Quickshell config name: `evo-shell` → `quickshell -n -c evo-shell`
- Plugin IDs: `evo.menu`, `evo.bar`, `evo.audio`, … (prefix `evo.`)
- Wayland layer namespaces: `evo-bar`, `evo-menu`, `evo-panel`, `evo-notifications`, `evo-background`
- Scripts: `evo-shell-ipc`, `evo-launch-shell`, `evo-bar-{name}.sh`

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
| `evo.lock` | `lock`, `isLocked`, `status` (via `shell call`) |
| `idle` | `status`, `enable`, `disable`, `toggle` |

Volume keys and `evo-volume.sh` call `evo.audio` directly, not `shell call`.

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

**Services** live in `plugins/*/Service.qml` (or `Background.qml`), registered in `pluginTable`, often `keepLoaded: true`. Clipboard watch remains `evo.clipboard` (service-only); clipboard/emojis UIs live in `evo.panel` modules.

**Bar-only widgets** are **not** in `pluginTable`; mapped in `plugins/bar/Bar.qml` → `widgetComponentFor()`.

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

### Bar widget routing (`Bar.qml`)

| `id` in shell.json | Widget | Data source |
|--------------------|--------|-------------|
| `evo.menu` | `MenuBarWidget` | — |
| `evo.workspaces` | `WorkspacesWidget` | Hyprland |
| `evo.clock` | `ClockWidget` | Qt `format` in settings |
| `evo.audio` | `AudioWidget` | Pipewire via `evo.audio` service |
| `evo.tray` | `TrayWidget` | Quickshell tray |
| `evo.github` | `GithubWidget` | `evo-bar-github.sh` |
| `evo.shopify` | `ShopifyWidget` | `evo-bar-shopify.sh` + `store` setting |
| `evo.cava` | `CavaWidget` | native `cava` + `SplitParser` |
| `type: "command"` or `exec` | `CommandWidget` | polled bash, JSON stdout |

To add a native bar widget:

1. Create `plugins/bar/widgets/MyWidget.qml`
2. Register in `widgets/qmldir`
3. Add `Component` + branch in `widgetComponentFor()`
4. Reference by `id` in `shell.json`

## Bar data scripts (`evo-bar-*.sh`)

Live in `~/.local/bin/`. Shared helpers: `evo-bar-common.sh`.

- **Secrets:** `EVO_SECRETS_FILE` → `~/.local/share/evo-shell/secrets.env` (fallback: waybar path)
- **Heatmap colours:** `~/.themes/current/waybar.css` (`@define-color github-N`) via `evo_bar_load_heatmap_colors`

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
  "label": "D £4,474 | 20 | 9.0%",
  "bars": [{ "level": 5, "colorLevel": 4, "color": "#7fbbb3" }, …]
}
```

Widget draws native `Rectangle` bars; falls back to span parsing if `bars` missing.

**GithubWidget:** still uses span markup in `text`; count parsed from prefix before first `<span`.

**CavaWidget:** runs `cava` natively with `SplitParser`; playback gate via `evo-bar-cava-if.sh`.

## Theme and bar spacing (`Commons/Theme.qml`)

Colours are **hardcoded** in `Theme.qml` today (not live from `colors.toml`). Bar scripts read heatmap colours from theme `waybar.css`.

| Property | Typical use |
|----------|-------------|
| `barHeight` | 32 |
| `barPaddingX` | Widget horizontal padding |
| `barGap` | Gap between bar modules |
| `barSectionGap` | Larger gap (e.g. volume ↔ clock) |
| `sparklineGap` | Gap between label text and chart (Shopify, GitHub) |
| `sparklineBarWidth` / `sparklineBarSpacing` | Native bar charts |
| `fontFamily` | `CaskaydiaMono Nerd Font`, bold |

`themes-apply.sh` calls `evo-shell-ipc shell reloadConfig` after theme switch.

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
-- evo.menu, evo.panel (clipboard/emojis modules), evo.audio, evo-system-lock, evo-wallpaper.sh

-- evo-shell.lua
hl.layer_rule({ match = { namespace = "evo-bar" }, no_anim = true, animation = "none" })
```

Menu power/system entries use `evo-system-lock`, `evo-restart-shell.sh`, `evo-wallpaper.sh`.

## Adding a bar module (checklist)

1. **Native widget** (streaming, Pipewire, rich UI) → QML in `plugins/bar/widgets/`
2. **Simple polled data** → `evo-bar-foo.sh` + `CommandWidget` entry in `shell.json`
3. **Structured chart** → script emits JSON fields + QML renders with `Rectangle` / `Repeater`
4. Register routing in `Bar.qml` if not `type: command`
5. `evo-shell-ipc shell reloadConfig` or restart shell

## User preferences (repo)

- Main branch: `master`
- Commit messages: lowercase
- Do not commit unless asked
- Minimize diff scope; match existing QML/bash style
- Do not edit `.cursor/plans/*.plan.md` unless asked
