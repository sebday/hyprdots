# EvoShell plugin development

Read this before adding or changing plugins, bar widgets, services, hover popups, panels, or dashboards.

EvoShell uses a single `pluginManifest.js` table rather than per-plugin JSON manifests. Registration is spread across several files; missing any one leaves the feature invisible or unloadable.

## Plugin id rules

- Format: `evo.<product>.<segment>` with optional further segments
- Products: `bar`, `panel`, `side`, `sys`
- Examples: `evo.bar.popups.weather`, `evo.panel.player`, `evo.sys.settings`
- Regex enforced by tests: `^evo\.(bar|panel|side|sys)(\.[a-z0-9]+(-[a-z0-9]+)*)*$`

## Plugin kinds

| Kind | Purpose | Lifecycle |
|------|---------|-----------|
| `service` | Background state, IPC, polling | Loaded at startup when listed in manifest |
| `bar` | Layer-shell bar host | Loaded from `shell.json` bar config |
| `menu` | Hover popup or centered overlay | `open(payloadJson)` / `close()`, `opened` property |
| `panel` | Docked side panel (`evo.side`) | `open(payloadJson)` / `close()`, `opened` property |
| `dashboard` | Floating dashboard window | `open()` / `close()`, `opened` property |

Menu hover popups extend `BarHoverPopup` and set `pluginId` plus `layerNamespace`. Centered overlays use `CenteredOverlay` (see `Evosys/Settings/Settings.qml`).

## Registration checklist

Every new plugin must be wired into every row that applies:

| Step | File | What to add |
|------|------|-------------|
| 1 | `pluginManifest.js` | Entry in `plugins` with `kinds`, `path`, optional `servicePath`, `keepLoaded` |
| 2 | `pluginManifest.js` | Add to `panelPluginIds` when kind is `menu` or `panel` |
| 3 | `shell.qml` | Add dedicated `Loader` when kind is `dashboard` (currently hard-coded for shopify/player) |
| 4 | `Evobar/BarWidgetCatalog.qml` | Register `Component` when the plugin has a bar widget |
| 5 | `Evobar/widgets/qmldir` | Export new widget type when adding a bar widget QML file |
| 6 | `shell.json` | Add bar layout entry, `onHover`, intervals, or `openOnStart` as needed |
| 7 | `$EVOSHELL_BIN/evo-*` | Add poller/CLI when the bar uses `type: "command"` or `exec` |
| 8 | `tests/test-plugin-manifest.sh` | Add required id when the plugin is core infrastructure |
| 9 | `tests/test-static-contracts.sh` | Add contract checks when introducing new canonical names or paths |

After manifest or loader changes, run `evo-system restart`. After `shell.json` only, `evo-ipc shell reloadConfig` is enough.

## pluginManifest.js

Minimal entry:

```javascript
"evo.bar.popups.example": {
    kinds: ["menu"],
    path: "Evobar/Popups/Example/Example.qml",
    keepLoaded: true
},
```

Service with separate service file:

```javascript
"evo.bar.popups.example": {
    kinds: ["menu", "service"],
    path: "Evobar/Popups/Example/Example.qml",
    servicePath: "Evobar/Popups/Example/ExampleService.qml",
    keepLoaded: true
},
```

`keepLoaded: true` keeps the panel loader active even when closed. Use it for popups that must respond quickly to hover.

Add menu/panel ids to `panelPluginIds` or they will not instantiate.

## shell.qml

- Services: auto-loaded for every manifest entry with kind `service`
- Panels/menus: `Instantiator` over `panelPluginIds`
- Dashboards: explicit `Loader` blocks with `dashboardLoaderFor()` / `requestDashboardOpen()`

Adding a new dashboard today requires:

1. Manifest entry with kind `dashboard`
2. New `Loader` in `shell.qml` (or extending `dashboardLoaderFor()`)
3. Optional `dashboards.openOnStart` entry in `shell.json`

## Bar widgets

Bar sections in `shell.json` resolve widgets through `BarWidgetRegistry`:

1. Built-in widgets: registered in `Evobar/BarWidgetCatalog.qml`
2. Command widgets: entries with `type: "command"` or `exec` use `CommandWidget` (no catalog entry)

`Evobar/widgets/BarSection.qml` passes `settings`, `shell`, `bar`, and `barPanel` into each widget.

### Command bar entries

For pollers, prefer a dedicated `evo-bar-*` script emitting JSON:

```json
{
  "type": "command",
  "exec": "~/.local/bin/evo-bar-example-bar",
  "interval": 300,
  "onHover": "evo.bar.popups.example",
  "onClick": "~/.local/bin/evo-bar-example open"
}
```

`CommandWidget` parses single-line JSON with `text`/`content`, optional `class`, and tray fields. It writes hover cache via `Util.hoverPopupCacheRead` / `hoverPopupCacheWrite` when `onHover` is set.

### Dedicated bar widgets

1. Create `Evobar/widgets/ExampleWidget.qml`
2. Export in `Evobar/widgets/qmldir`
3. Register in `BarWidgetCatalog.qml`:

```qml
registry.register("evo.bar.popups.example", exampleComp, { displayName: "Example" })
```

4. Reference by id in `shell.json` layout

## Hover popup plugins

Pattern (see `Evobar/Popups/Weather/Weather.qml`):

```qml
BarHoverPopup {
    pluginId: "evo.bar.popups.example"
    layerNamespace: "evo-bar-popups-example"
    contentWidth: Theme.hoverPopupWidthStandard

    ExampleModule {}
}
```

`BarHoverPopup` provides `open(payloadJson)`, `close()`, pin/unpin, and reveal timing. Modules receive `shell` and `host` from the popup host.

## Service plugins

Services are plain `Item` roots loaded into the hidden `serviceHost`. They receive `shell` when created.

Expose IPC from the service file:

```qml
IpcHandler {
    target: "evo.bar.example"

    function doThing(arg: string): string { return root.doThing(arg) }
}
```

Call via `evo-ipc evo.bar.example doThing "arg"`.

## Dashboard plugins

Dashboards use `FloatingWindow` with `open()`, `close()`, `toggle()`, and `opened` (see `Evopanel/Evoplayer/Player.qml`). The window title should match the plugin id.

`shell.qml` calls `open()` after lazy load when `requestDashboardOpen()` is used.

## Panel plugins

`evo.side` is the docked side panel. Open with a JSON payload:

```bash
evo-ipc shell toggle evo.side '{"module":"calc"}'
evo-ipc shell toggle evo.side '{"module":"calc","focus":"tasks"}'
```

Only `calc` is a dock module id. Tasks is a focus target inside `AppCalc`, not a separate module.

`evo.side.clipboard` is its own `menu` plugin, not part of the dock host.

Other panel-like UIs (`evo.sys.menu`, `evo.sys.settings`, `evo.sys.themes`, `evo.sys.wallpaper`) are `menu` kind with centered or hover presentation.

## Notifications split

Notification work spans two plugins:

| Plugin | Location | Responsibility |
|--------|----------|----------------|
| `evo.sys.notifications` | `Evosys/Notifications/Service.qml` | `NotificationServer`, toast overlay, history file, unread count, `showBrief()` |
| `evo.bar.popups.notifications` | `Evobar/Popups/Notifications/` | Bar hover popup and history UI |

Changing toast placement edits `shell.json` → `notifications` and `Evosys/Notifications/Service.qml`. Changing history UI edits the Evobar popup files and `NotificationsWidget`.

## Design tokens

Use `Theme.*` for all visual values. Shared layout primitives live in `Commons/`.

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
