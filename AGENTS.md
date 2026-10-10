# Agent guide

Quickshell desktop shell for Hyprland. One long-running instance (`quickshell -n -p ~/projects/hyprdots/evoshell`), supervised by `evo system start`, controlled via `evo ipc`.

## Paths

```bash
EVOSHELL_ROOT="${EVOSHELL_ROOT:-$HOME/projects/hyprdots/evoshell}"
EVOSHELL_LIB="${EVOSHELL_LIB:-$HOME/.local/lib/evoshell/bin}"
EVOSHELL_BIN="${EVOSHELL_BIN:-$EVOSHELL_LIB}"
EVOSHELL_CONFIG="${EVOSHELL_CONFIG:-$HOME/.config/evoshell}"
EVOSHELL_STATE="${EVOSHELL_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/evoshell}"
EVOSHELL_CACHE="${EVOSHELL_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/evoshell}"
```

Resolved in [`evoshell/bin/evo-paths-lib`](evoshell/bin/evo-paths-lib) and [`evoshell/commons/Util.qml`](evoshell/commons/Util.qml). Secrets go through [`evoshell/bin/evo-secrets-lib`](evoshell/bin/evo-secrets-lib) (`pass` prefix `evoshell/`). Config layout is in [README.md](README.md). Hyprland config is [`.config/hypr`](.config/hypr). Keybindings live in [`.config/hypr/bindings.lua`](.config/hypr/bindings.lua).

## Layout

| Path | Role |
|------|------|
| `evoshell/shell.qml` | Plugin loading, summon/toggle/hide, dashboard loaders |
| `evoshell/pluginManifest.js` | Built-in ids. Discovered modules come from `evoshell/modules/*/manifest.json` |
| `evoshell/modules/<name>/` | Bar widgets, hover panels, services, overlays |
| `evoshell/commons/` | `Theme`, panels, charts. Colours, type, and spacing go through `Theme.*` |
| `evoshell/vendor/evoplayer/plugin/panel/` | Evoplayer dashboard |

Plugin ids use `evo.bar.*`, `evo.panels.*`, `evo.side.*`, and `evo.sys.*`. Settings opens inside the system menu: IPC for `evo.sys.settings` is redirected to `evo.sys.menu`.

| Kind | Examples |
|------|----------|
| `service` | `evo.sys.media.audio`, `evo.sys.notifications` |
| `bar` | `evo.bar` |
| `menu` | `evo.sys.menu`, `evo.calculator` |
| `panel` | `evo.osd` |
| `dashboard` | `evo.panels.player` |

## IPC and reload

```bash
evo ipc shell ping|reloadConfig|summon|hide|toggle <pluginId> [payloadJson]
evo ipc evo.sys.media.audio stepUp
evo system restart
journalctl --user -t evoshell -f
```

`reloadConfig` restarts the shell (same as Super+F5).

| Change | Action |
|--------|--------|
| `evoshell/shell.json` | `evo system restart` or `evo ipc shell reloadConfig` |
| `theme.json`, `ui.json`, `hypr-looks.json` | live |
| `Theme.qml`, `pluginManifest.js`, new widget or dashboard | `evo system restart` |
| `.config/hypr/` | Hypr reload, then usually a shell restart |

Do not start extra Quickshell instances. Do not commit pass secrets or machine-specific monitor names.

## UI check

After a visual change: `evo system restart`, confirm `journalctl --user -t evoshell` has no new QML errors, exercise the changed surface, and screenshot with `omasnap`.

## Evoplayer

Player source is the separate evoplayer repo (`evoshell/vendor/evoplayer` symlink). After clone or pull, `bash evoshell/vendor/evoplayer/scripts/install` (or `bash ~/projects/evoplayer/scripts/install`). Dashboard ids: `evo.panels.player`, `evo.panels.player.monitor`.

## Testing and commits

```bash
bash -n evoshell/bin/* scripts/*
evo ipc shell ping
```

Commit subjects are imperative sentence case, for example `Replace the docked side panel with a centered calculator`. Default branch is `master`.
