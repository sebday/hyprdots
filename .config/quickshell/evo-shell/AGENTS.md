# Evo shell — agent notes

Quickshell desktop shell (`quickshell -n -c evo-shell`). Config: `~/.config/quickshell/evo-shell/`. Bar scripts + IPC: `~/.local/bin/evo-*`. Hypr: `~/.config/hypr/{autostart,bindings,evo-shell}.lua`.

```bash
~/.local/bin/evo-restart-shell.sh          # full restart
~/.local/bin/evo-shell-ipc shell reloadConfig  # re-read shell.json
journalctl -t evo-shell -f
```

## Where things register

| What | Where |
|------|--------|
| Plugins | `shell.qml` → `pluginTable`, `panelPluginIds` |
| Bar layout | `shell.json` → `bar.layout` |
| Bar widgets | `BarWidgetCatalog.qml` + `widgets/qmldir`; polled scripts use `type: "command"` / `exec` → `CommandWidget` |
| Panel dock tabs | `Panel.qml` → `dockModules` + `plugins/panel/modules/qmldir` |
| Overlay popups | Own plugin (`Weather.qml`, `Stats.qml`, …) + `CenteredOverlay` |

## IPC

`evo-shell-ipc shell toggle <id> [payloadJson]` — pass `""` if no payload.

Hypr bindings use full path `~/.local/bin/evo-shell-ipc` (PATH may not include it). Volume keys call `evo-shell-ipc evo.audio` directly, not `shell call`.

## Monitors

- **Popups** (weather, stats, cursor, clipboard): `CenteredOverlay.preferredOutput` → `shell.overlayOutput` from `shell.json` `panel.output` (default `DP-1`)
- **Left dock** (`evo.panel`): Hyprland focused monitor on each `open()`
- **Menu / calendar**: focused monitor (no `preferredOutput`)

## Bar scripts

`~/.local/bin/evo-bar-*.sh` — source `evo-bar-common.sh`. Cache: `~/.cache/evo-shell/bar/{key}.json` (TTL via `evo_bar_cache_read/write`). Heatmap colours: `~/.themes/current/evo-bar.css`.

`CommandWidget` expects one JSON line: `{ "text": "…", "class": "…" }`. Native widgets parse their own JSON from scripts.

## Pitfalls (already hit)

- `BarWidgetCatalog` root must be `Item`, not `QtObject`
- New bar widgets: `widgets/qmldir` + `BarWidgetCatalog` — not `BarSection.qml`
- `import Quickshell` needed for `Quickshell.execDetached` / env
- No `ToolTip` on bar items (broke load)
- Clock `format`: Qt tokens (`%a %d %H:%M`), not strftime
- Streaming bar data (cava): `SplitParser`, not interval polling
- New overlay plugins need `shell.qml` entry + `panelPluginIds` if `keepLoaded`; restart shell to pick up new plugins (not just `reloadConfig`)
- Layer namespaces (`evo-bar`, `evo-panel`, …) → `~/.config/hypr/evo-shell.lua`

## User prefs

- Branch `master`, lowercase commit messages, don't commit unless asked, minimal diffs, BEM for Shopify theme CSS (if relevant)
