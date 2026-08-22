# EvoShell development

Read this before editing the Quickshell desktop under `$EVOSHELL_ROOT` or its companion scripts in `$EVOSHELL_BIN`.

## Runtime model

EvoShell runs as a single long-running Quickshell process. Hyprland autostart launches it through `evo system start`, which supervises:

```bash
quickshell -n -p ~/projects/evoshell
```

Do not start standalone Quickshell instances for individual components. Use `evo system restart` when a full process restart is required.

Check the shell is alive:

```bash
evo ipc shell ping
```

Restart cleanly:

```bash
evo system restart
```

Follow logs:

```bash
journalctl -t evoshell -f
```

## Prerequisites

See [`docs/packages.md`](../../docs/packages.md) for Arch package tiers (required, recommended, optional).

Minimum runtime:

- `quickshell` on PATH (config name: `evoshell`)
- Hyprland session with EvoShell autostart configured in `~/.config/hypr/autostart.lua`
- Feature scripts in `~/.local/lib/evoshell/bin/evo-*` (after `bash scripts/install`)
- `pass` initialized with secrets under `evoshell/`

## Configuration roots

| Area | Location |
|------|----------|
| Shell QML, manifest, layout | `$EVOSHELL_ROOT` (`config/shell.json`) |
| Theme tokens | `$EVOSHELL_STATE/theme.json` → `commons/Theme.qml` |
| Hyprland bindings and window rules | `~/.config/hypr/*.lua` |
| Feature CLIs | `$EVOSHELL_LIB/evo-*` (defaults via `bin/evo-paths-lib`) |
| Durable settings | `$EVOSHELL_CONFIG` (`ui.json`, `weather.json`, `media.json`, `font.json`, `hypr-looks.json`, `overrides.json`) |
| Session restore | `$EVOSHELL_STATE/session.json` |
| Regenerable cache | `$EVOSHELL_CACHE` (`bar/`, `bar-history/`, `menu-cache/`) |
| Secrets | `pass` entries under `evoshell/` |
| Optional overrides | `$EVOSHELL_CONFIG` (e.g. Shopify demo JSON) |

A feature often spans multiple roots: QML in `$EVOSHELL_ROOT`, layout in `config/shell.json`, a poller in `$EVOSHELL_BIN`, optional Hyprland bindings, and state under `$EVOSHELL_STATE` or `$EVOSHELL_CACHE`.

## Reload versus restart

| Change | Action |
|--------|--------|
| `shell.json` / overrides | `evo system restart` or `evo ipc shell reloadConfig` |
| `$EVOSHELL_CONFIG/hypr-looks.json`, `$EVOSHELL_CONFIG/ui.json` | live (Theme bindings) |
| `Theme.qml`, `pluginManifest.js`, new bar widget type, new dashboard loader in `shell.qml` | `evo system restart` |
| `hypr/*.lua` in evoshell repo | `hyprctl reload` |

`reloadConfig` IPC restarts the shell (same as Super+R), not an in-process config reload.

`shell.json` parse failures fall back to the last good config in `shell.qml`; invalid JSON does not crash the shell.

## IPC

`evo ipc` wraps `quickshell ipc -p $EVOSHELL_ROOT`.

Shell lifecycle:

```bash
evo ipc shell ping
evo ipc shell reloadConfig
evo ipc shell summon <pluginId> ""
evo ipc shell hide <pluginId>
evo ipc shell toggle <pluginId> ""
evo ipc shell listPlugins
```

Plugin services expose their own IPC targets. Example:

```bash
evo ipc evo.sys.media.audio stepUp
```

`summon` and `toggle` always accept a `payloadJson` argument; pass `""` when unused.

## Architecture

```
shell.qml
  ├── pluginManifest.js (plugin table, panel ids)
  ├── service host (kinds: service)
  ├── bar loader (evo.bar)
  ├── dashboard loaders (evo.panels.player + config plugin overlays)
  └── panel instantiator (menu/panel plugins from panelPluginIds)
```

`shell.qml` owns summon/hide/toggle, hover popup anchoring, and the `shell` IPC target. Individual services may register their own `IpcHandler` targets (see `evosys/media/audio/Service.qml`).

## Hyprland integration

Evoshell hypr glue lives in `$EVOSHELL_ROOT/hypr/` and loads via `package.path` from `hyprland.lua` (see `hypr/README.md`). Default keybindings ship in `hypr/bindings.lua`; optional personal binds can live in `~/.config/hypr/bindings.lua`.

## Scripts

New scripts belong in `$EVOSHELL_BIN` with the `evo-` prefix.

Conventions for new scripts:

- `#!/usr/bin/env bash`
- `set -euo pipefail`
- 2-space indent
- `[[ ]]` for string/file tests, `(( ))` for numeric tests

Match the surrounding file when editing existing scripts; the tree is not fully normalized yet.

Shared libraries:

- `evoplayer-lib` — player state/cache paths, library jobs
- `evo-bar-common` — bar script helpers
- `evo-theme-lib` — theme and icon env

## Secrets and safety

- Read secrets from `pass` (`evo-secrets-lib` / `pass show evoshell/...`); never commit secrets
- Do not hardcode API tokens in QML or shell scripts
- Prefer `evo system restart` over manual `pkill quickshell`
- `evo system restart` preserves lock state when the session was locked before restart

## When to read other guides

- Adding or changing a plugin, bar widget, service, or dashboard → [`plugin-development.md`](plugin-development.md)
- Any change with a visible UI effect → [`visual-verification.md`](visual-verification.md)
