# EvoShell development

Read this before editing the Quickshell desktop under `$EVOSHELL_CONFIG` or its companion scripts in `$EVOSHELL_BIN`.

## Runtime model

EvoShell runs as a single long-running Quickshell process. Hyprland autostart launches it through `evo-system start`, which supervises:

```bash
quickshell -n -c evoshell
```

Do not start standalone Quickshell instances for individual components. Use `evo-system restart` when a full process restart is required.

Check the shell is alive:

```bash
evo-ipc shell ping
```

Restart cleanly:

```bash
evo-system restart
```

Follow logs:

```bash
journalctl -t evoshell -f
```

## Prerequisites

- `quickshell` on PATH (config name: `evoshell`)
- Hyprland session with EvoShell autostart configured in `~/.config/hypr/autostart.lua`
- Feature scripts in `~/.local/bin/evo-*`

## Configuration roots

| Area | Location |
|------|----------|
| Shell QML and manifest | `$EVOSHELL_CONFIG` |
| Bar layout, idle, notification placement | `$EVOSHELL_CONFIG/shell.json` |
| Theme tokens | `$EVOSHELL_CONFIG/theme.json` → `Commons/Theme.qml` |
| Hyprland bindings and window rules | `~/.config/hypr/*.lua` |
| Feature CLIs | `$EVOSHELL_BIN/evo-*` |
| Durable state | `$EVOSHELL_STATE` (player, notification history, font, wallpaper) |
| Regenerable cache | `$EVOSHELL_CACHE` |
| Secrets | `$EVOSHELL_DATA/secrets.env` |

A feature often spans multiple roots: QML in `$EVOSHELL_CONFIG`, a poller in `$EVOSHELL_BIN`, optional Hyprland bindings, and state under `$EVOSHELL_STATE` or `$EVOSHELL_CACHE`.

## Reload versus restart

| Change | Action |
|--------|--------|
| `shell.json` | `evo-ipc shell reloadConfig` |
| `theme.json`, `hypr-looks.json`, `ui.json` | live (Theme bindings) |
| `Theme.qml`, `pluginManifest.js`, new bar widget type, new dashboard loader in `shell.qml` | `evo-system restart` |
| `~/.config/hypr/evoshell.lua` | Hypr reload; often shell restart too |

`shell.json` parse failures fall back to the last good config in `shell.qml`; invalid JSON does not crash the shell.

## IPC

`evo-ipc` wraps `quickshell ipc -c evoshell`.

Shell lifecycle:

```bash
evo-ipc shell ping
evo-ipc shell reloadConfig
evo-ipc shell summon <pluginId> ""
evo-ipc shell hide <pluginId>
evo-ipc shell toggle <pluginId> ""
evo-ipc shell listPlugins
```

Plugin services expose their own IPC targets. Example:

```bash
evo-ipc evo.bar.media.audio stepUp
```

Legacy aliases in `evo-ipc` map `background`/`wallpaper` → `evo.sys.wallpaper`, `idle` → `evo.sys.lock-screen.idle`, `lock` → `evo.sys.lock-screen.lock`.

`summon` and `toggle` always accept a `payloadJson` argument; pass `""` when unused.

## Architecture

```
shell.qml
  ├── pluginManifest.js (plugin table, panel ids)
  ├── service host (kinds: service)
  ├── bar loader (evo.bar)
  ├── dashboard loaders (evo.panel.shopify, evo.panel.player)
  └── panel instantiator (menu/panel plugins from panelPluginIds)
```

`shell.qml` owns summon/hide/toggle, hover popup anchoring, and the `shell` IPC target. Individual services may register their own `IpcHandler` targets (see `Evobar/Media/Audio/Service.qml`).

## Hyprland integration

Bindings and window rules for EvoShell live in:

- `~/.config/hypr/bindings.lua`
- `~/.config/hypr/evoshell.lua`
- `~/.config/hypr/windows.lua`

Global shortcuts declared in QML (`shell.qml`) use `appid: "evoshell"`. Keep Hyprland bindings and QML shortcuts aligned when adding new summon/toggle entry points.

## Scripts

New scripts belong in `$EVOSHELL_BIN` with the `evo-` prefix.

Conventions for new scripts:

- `#!/usr/bin/env bash`
- `set -euo pipefail`
- 2-space indent
- `[[ ]]` for string/file tests, `(( ))` for numeric tests

Match the surrounding file when editing existing scripts; the tree is not fully normalized yet.

Shared libraries:

- `evo-player-lib.sh` — player state/cache paths, library jobs
- `evo-bar-common` — bar script helpers
- `evo-theme-lib` — theme and icon env

## Secrets and safety

- Read secrets from `$EVOSHELL_DATA/secrets.env`; never commit that file
- Do not hardcode API tokens in QML or shell scripts
- Prefer `evo-system restart` over manual `pkill quickshell`
- `evo-system restart` preserves lock state when the session was locked before restart

## When to read other guides

- Adding or changing a plugin, bar widget, service, or dashboard → [`plugin-development.md`](plugin-development.md)
- Any change with a visible UI effect → [`visual-verification.md`](visual-verification.md)
