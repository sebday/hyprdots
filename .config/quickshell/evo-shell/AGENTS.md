# Evo shell — agent notes

Quickshell desktop shell (`quickshell -n -c evo-shell`). Config: `~/.config/quickshell/evo-shell/`. Bar scripts + IPC: `~/.local/bin/evo-*`. Hypr: `~/.config/hypr/{autostart,bindings,evo-shell}.lua`.

```bash
evo-launch-shell                             # supervised start (Hypr autostart)
~/.local/bin/evo-restart-shell.sh            # full restart
~/.local/bin/evo-shell-ipc shell reloadConfig  # re-read shell.json
journalctl -t evo-shell -f
```

Secrets: `~/.local/share/evo-shell/secrets.env` (`chmod 600`). Wallpaper path: `~/.local/state/evo-shell/wallpaper`.

## Where things register

| What | Where |
|------|--------|
| Plugins | `shell.qml` → `pluginTable`, `panelPluginIds` |
| Bar layout | `shell.json` → `bar.layout` |
| Bar widgets | `BarWidgetCatalog.qml` + `widgets/qmldir`; polled scripts use `type: "command"` / `exec` → `CommandWidget` |
| Panel dock tabs | `Panel.qml` → `dockModules` + `plugins/panel/modules/qmldir` |
| Overlay popups | `Calendar.qml`, `Stats.qml`, `Weather.qml`, `Cursor.qml`, `Clipboard.qml`, … + `CenteredOverlay` |

## IPC

`evo-shell-ipc shell toggle <id> [payloadJson]` — pass `""` if no payload.

Hypr bindings use full path `~/.local/bin/evo-shell-ipc` (PATH may not include it). Volume keys call `evo-shell-ipc evo.audio` directly, not `shell call`.

## Monitors

- **Centered popups** (menu, calendar, stats, weather, cursor, clipboard): always `DP-1` via `Util.screenForOverlay()`
- **Left dock** (`evo.panel`): Hyprland focused monitor on each `open()` via `Util.screenForFocused()`

## Bar scripts

`~/.local/bin/evo-bar-*.sh` — source `evo-bar-common.sh`. Cache: `~/.cache/evo-shell/bar/{key}.json` (TTL via `evo_bar_cache_read/write`). Heatmap colours: `~/.themes/current/evo-bar.css`. Theme apply: `~/.local/bin/evo-theme.sh`; live shell colours via `~/.config/quickshell/evo-shell/theme.json` (watched by `Theme.qml`).

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

## Media library

Compact browser at the bottom of the **Info** panel (`LibraryModule`). Super+M and Super+B both open Info.

- **Index**: `~/.local/state/evo-shell/media.db` (scan from `/mnt/external/films` + `/mnt/external/tv`)
- **Posters**: `~/.local/state/evo-shell/media-posters/` — ffmpeg frame grabs (`evo-media-fetch-posters.py`) for films, shows, and episodes

```bash
evo-media.sh scan
evo-media-fetch-posters.py   # optional, extracts posters from video files
```

Re-run `scan` if the external library moves. Select a film or episode → **mpv fullscreen** (Info panel closes).

## User prefs

- Branch `master`, lowercase commit messages, don't commit unless asked, minimal diffs, BEM for Shopify theme CSS (if relevant)
