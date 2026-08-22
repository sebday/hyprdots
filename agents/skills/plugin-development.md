# EvoShell plugin development

Read this before adding or changing plugins, bar widgets, services, hover popups, panels, or dashboards.

EvoShell uses a single `pluginManifest.js` table rather than per-plugin JSON manifests. Registration is spread across several files; missing any one leaves the feature invisible or unloadable.

## Plugin id rules

- Format: `evo.<product>.<segment>` with optional further segments
- Products: `bar`, `panel`, `side`, `sys`
- Examples: `evo.panels.weather`, `evo.panels.player`, `evo.sys.settings`
- Regex enforced by tests: `^evo\.(bar|panel|side|sys)(\.[a-z0-9]+(-[a-z0-9]+)*)*$`

## Plugin kinds

| Kind | Purpose | Lifecycle |
|------|---------|-----------|
| `service` | Background state, IPC, polling | Loaded at startup when listed in manifest |
| `bar` | Layer-shell bar host | Loaded from `shell.json` bar config |
| `menu` | Hover popup or centered overlay | `open(payloadJson)` / `close()`, `opened` property |
| `panel` | Docked side panel (`evo.side`) | `open(payloadJson)` / `close()`, `opened` property |
| `dashboard` | Floating dashboard window | `open()` / `close()`, `opened` property |

Menu hover popups extend `BarHoverPanel` and set `pluginId` plus `layerNamespace`. Centered overlays use `CenteredOverlay` (see `evosys/settings/Settings.qml`).

## Registration checklist

Every new plugin must be wired into every row that applies:

| Step | File | What to add |
|------|------|-------------|
| 1 | `pluginManifest.js` | Entry in `plugins` with `kinds`, `path`, optional `servicePath`, `keepLoaded` |
| 2 | `pluginManifest.js` | Add to `panelPluginIds` when kind is `menu` or `panel` |
| 3 | `shell.qml` | Built-in dashboards use `playerLoader`; extension dashboards load from `$EVOSHELL_CONFIG/plugins/manifest.json` |
| 4 | `evobar/BarWidgetCatalog.qml` | Register `Component` when the plugin has a bar widget |
| 5 | `evobar/widgets/qmldir` | Export new widget type when adding a bar widget QML file |
| 6 | `shell.json` | Add bar layout entry, `onHover`, intervals, or `openOnStart` as needed |
| 7 | `$EVOSHELL_LIB/evo-*` | Add poller/CLI when the bar uses `type: "command"` or `exec` |
| 8 | `tests/test-plugin-manifest.sh` | Add required id when the plugin is core infrastructure |
| 9 | `tests/test-static-contracts.sh` | Add contract checks when introducing new canonical names or paths |

After manifest or loader changes, run `evo system restart`. `shell.json` and overrides also restart the shell (`evo system restart` or `evo ipc shell reloadConfig`).

## pluginManifest.js

Minimal entry:

```javascript
"evo.panels.example": {
    kinds: ["menu"],
    path: "evopanels/example/Example.qml",
    keepLoaded: true
},
```

Service with separate service file:

```javascript
"evo.panels.example": {
    kinds: ["menu", "service"],
    path: "evopanels/example/Example.qml",
    servicePath: "evopanels/example/ExampleService.qml",
    keepLoaded: true
},
```

`keepLoaded: true` keeps the panel loader active even when closed. Use it for popups that must respond quickly to hover.

Add menu/panel ids to `panelPluginIds` or they will not instantiate.

## Config plugin overlay

Machine-local plugins live under `$EVOSHELL_CONFIG/plugins/` and merge at runtime via `$EVOSHELL_CONFIG/plugins/manifest.json`. See [`config/plugins/manifest.example.json`](../../config/plugins/manifest.example.json).

- Set `"root": "plugins"` on manifest entries so QML loads from the config dir
- Symlink `$EVOSHELL_CONFIG/plugins/commons` → `$EVOSHELL_ROOT/commons` for shared imports
- Register optional tray widgets under `trayWidgets` in the overlay manifest
- Register extension dashboards under `dashboardIds`; optional labels for **Settings → Integrations → Startup** under `startupDashboards`
- Register **system menu → Panels** entries under `systemMenuPanels` (name, icon, keywords; command is `toggle <dashboard id>`)
- Extension CLIs can symlink into `$EVOSHELL_BIN/` (e.g. `evo-panel-shopify`)

Built-in manifest ids win on conflict; overlay ids only add new plugins.

## shell.qml

- Services: auto-loaded for every manifest entry with kind `service`
- Panels/menus: `Instantiator` over `panelPluginIds`
- Dashboards: explicit `Loader` blocks with `dashboardLoaderFor()` / `requestDashboardOpen()`

Adding a new extension dashboard today requires:

1. Manifest entry with kind `dashboard` and `dashboardIds` in the overlay manifest
2. `extensionDashboardInstantiator` in `shell.qml` loads it automatically
3. Optional `startupDashboards` label in the overlay manifest for **Settings → Integrations → Startup**
4. Optional `systemMenuPanels` entry in the overlay manifest for **system menu → Panels** (Super+Space)
4. Optional `dashboards.openOnStart` entry in overrides (or toggle in Settings)

## Bar widgets

Bar sections in `shell.json` resolve widgets through `BarWidgetRegistry`:

1. Built-in widgets: registered in `evobar/BarWidgetCatalog.qml`
2. Command widgets: entries with `type: "command"` or `exec` use `CommandWidget` (no catalog entry)

`evobar/widgets/BarSection.qml` passes `settings`, `shell`, `bar`, and `barPanel` into each widget.

### Command bar entries

For pollers, prefer a dedicated `evo-bar-*` script emitting JSON:

```json
{
  "type": "command",
  "exec": "~/.local/lib/evoshell/bin/evo-bar-example-bar",
  "interval": 300,
  "onHover": "evo.panels.example",
  "onClick": "~/.local/lib/evoshell/bin/evo-bar-example open"
}
```

`CommandWidget` parses single-line JSON with `text`/`content`, optional `class`, and tray fields. It writes hover cache via `Util.hoverPanelCacheRead` / `hoverPanelCacheWrite` when `onHover` is set.

### Dedicated bar widgets

1. Create `evobar/widgets/ExampleWidget.qml`
2. Export in `evobar/widgets/qmldir`
3. Register in `BarWidgetCatalog.qml`:

```qml
registry.register("evo.panels.example", exampleComp, { displayName: "Example" })
```

4. Reference by id in `shell.json` layout

## Hover popup plugins

Pattern (see `evopanels/weather/Weather.qml`):

```qml
BarHoverPanel {
    pluginId: "evo.panels.example"
    layerNamespace: "evo-panels-example"
    contentWidth: Theme.hoverPanelWidthStandard

    ExampleModule {}
}
```

`BarHoverPanel` provides `open(payloadJson)`, `close()`, pin/unpin, and reveal timing. Modules receive `shell` and `host` from the popup host.

## Service plugins

Services are plain `Item` roots loaded into the hidden `serviceHost`. They receive `shell` when created.

Expose IPC from the service file:

```qml
IpcHandler {
    target: "evo.bar.example"

    function doThing(arg: string): string { return root.doThing(arg) }
}
```

Call via `evo ipc evo.bar.example doThing "arg"`.

## Dashboard plugins

Dashboards use `FloatingWindow` with `open()`, `close()`, `toggle()`, and `opened` (see `vendor/evoplayer/qml/panel/Player.qml`). The window title should match the plugin id.

`shell.qml` calls `open()` after lazy load when `requestDashboardOpen()` is used.

## Panel plugins

`evo.side` is the docked side panel. Open with a JSON payload:

```bash
evo ipc shell toggle evo.side '{"module":"calc"}'
evo ipc shell toggle evo.side '{"module":"calc","focus":"tasks"}'
```

Only `calc` is a dock module id. Tasks is a focus target inside `AppCalc`, not a separate module.

`evo.side.clipboard` is its own `menu` plugin, not part of the dock host.

Other panel-like UIs (`evo.sys.menu`, `evo.sys.settings`, `evo.sys.themes`, `evo.sys.wallpaper`) are `menu` kind with centered or hover presentation.

## Notifications split

Notification work spans two plugins:

| Plugin | Location | Responsibility |
|--------|----------|----------------|
| `evo.sys.notifications` | `evosys/notifications/Service.qml` | `NotificationServer`, toast overlay, history file, unread count, `showBrief()` |
| `evo.panels.notifications` | `evopanels/notifications/` | Bar hover popup and history UI |

Changing toast placement edits `shell.json` → `notifications` and `evosys/notifications/Service.qml`. Changing history UI edits the Evobar popup files and `NotificationsWidget`.

## Design tokens

Use `Theme.*` for all visual values. Shared layout primitives live in `commons/`.

Do not rewrite widget files wholesale through tools that strip multi-byte Nerd Font glyphs; make targeted edits or insert codepoints via `chr(0xXXXXX)` in a script.

## Tests

```bash
bash tests/test-plugin-manifest.sh
bash tests/test-static-contracts.sh
```

Add the new plugin id to `test-plugin-manifest.sh` when it is required infrastructure. Extend `test-static-contracts.sh` when introducing canonical script names, widget exports, or forbidden legacy prefixes.

## Common mistakes

- Manifest entry without `panelPluginIds` → menu never loads
- Bar widget without `BarWidgetCatalog` registration → blank bar slot
- `onHover` in `shell.json` pointing at an unregistered plugin id → hover does nothing
- Dashboard without `shell.qml` loader → `summon` returns `unknown`
- Editing only QML without restarting after manifest changes → stale plugin table
