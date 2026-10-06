# Agent guide

Quickshell desktop shell for Hyprland. One long-running instance (`quickshell -n -p ~/projects/hyprdots`), supervised by `evo system start`, controlled via `evo ipc`.

## Paths

```bash
EVOSHELL_ROOT="${EVOSHELL_ROOT:-$HOME/projects/hyprdots}"
EVOSHELL_LIB="${EVOSHELL_LIB:-$HOME/.local/lib/evoshell/bin}"
EVOSHELL_BIN="${EVOSHELL_BIN:-$EVOSHELL_LIB}"
EVOSHELL_CONFIG="${EVOSHELL_CONFIG:-$HOME/.config/evoshell}"
EVOSHELL_STATE="${EVOSHELL_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/evoshell}"
EVOSHELL_CACHE="${EVOSHELL_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/evoshell}"
```

Resolved in [`bin/evo-paths-lib`](bin/evo-paths-lib) and [`commons/Util.qml`](commons/Util.qml). Secrets go through [`bin/evo-secrets-lib`](bin/evo-secrets-lib) (`evoshell/` first, then `omarchy/`). Config layout is in [README.md](README.md). Hyprland loads `hypr/` via `package.path` ([`hypr/README.md`](hypr/README.md)). Keybindings live in [`hypr/bindings.lua`](hypr/bindings.lua).

## Layout

| Path | Role |
|------|------|
| `shell.qml` | Plugin loading, summon/toggle/hide, dashboard loaders |
| `pluginManifest.js` | Built-in ids. Discovered modules come from `modules/*/manifest.json` |
| `modules/<name>/` | Bar widgets, hover panels, services, overlays |
| `commons/` | `Theme`, panels, charts. Colours, type, and spacing go through `Theme.*` |
| `vendor/evoplayer/plugin/panel/` | Evoplayer dashboard |

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
| `config/shell.json` | `evo system restart` or `evo ipc shell reloadConfig` |
| `theme.json`, `ui.json`, `hypr-looks.json` | live |
| `Theme.qml`, `pluginManifest.js`, new widget or dashboard | `evo system restart` |
| `hypr/` | Hypr reload, then usually a shell restart |

Do not start extra Quickshell instances. Do not commit pass secrets or machine-specific monitor names.

## UI check

After a visual change: `evo system restart`, confirm `journalctl --user -t evoshell` has no new QML errors, exercise the changed surface, and screenshot with `grim`.

## Evoplayer

Player source is the separate evoplayer repo (`vendor/evoplayer` symlink). After clone or pull, `bash vendor/evoplayer/scripts/install` (or `bash ~/projects/evoplayer/scripts/install`). Dashboard ids: `evo.panels.player`, `evo.panels.player.monitor`.

## Testing and commits

```bash
bash -n bin/* scripts/*
evo ipc shell ping
```

Commit subjects are imperative sentence case, for example `Replace the docked side panel with a centered calculator`. Default branch is `master`.
