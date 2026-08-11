# Evo shell IPC

The shell exposes a Quickshell `IpcHandler` target named `shell`. Use `evo-shell-ipc` or `quickshell ipc -c evo-shell call ...`.

## Shell target

| Method | Returns | Effect |
|--------|---------|--------|
| `ping` | `ok` | Health check |
| `summon <id> [payloadJson]` | `ok` / `unknown` | Load and open a panel, overlay, or menu |
| `hide <id>` | — | Close a summoned plugin |
| `toggle <id> [payloadJson]` | — | Summon if closed, hide if open |
| `call <id> <method> [arg]` | string | Call a method on a loaded service plugin |
| `reloadConfig` | `ok` | Reload `~/.config/quickshell/evo-shell/shell.json` |
| `listPlugins` | JSON | Static `pluginTable` from `shell.qml` |

Plugin-specific targets are registered by services:

| Target | Methods |
|--------|---------|
| `background` | `refresh`, `set(path)`, `setInstant(path)`, `next`, `prev` |
| `evo.audio` | `stepUp`, `stepDown`, `toggleMute`, `step(up\|down)` |
| `lock` | `lock`, `isLocked`, `status` |
| `idle` | `status` |

`evo.lock` is the plugin id for `shell call`; the direct IPC target is `lock`.

## Examples

```bash
evo-shell-ipc shell ping
evo-shell-ipc shell toggle evo.menu
evo-shell-ipc shell toggle evo.menu '{"mode":"apps"}'
evo-shell-ipc shell toggle evo.panel '{"module":"clipboard"}'
evo-shell-ipc shell call evo.lock lock
evo-shell-ipc lock lock
evo-shell-ipc evo.audio stepUp
evo-shell-ipc background next
evo-shell-ipc shell reloadConfig
```

## shell.json

Canonical user config at `~/.config/quickshell/evo-shell/shell.json`.

- `bar.layout.left|center|right` — widget entries with inline settings
- `idle.screensaver` / `idle.lock` — seconds until DPMS off and session lock
- `notifications.durationMs` — shared popup lifetime
- `panel.side` / `panel.output` — left dock panel placement
- `version: 1` is required

Command widgets accept JSON output: `{ "text": "...", "tooltip": "...", "class": "..." }`.

Shopify and GitHub widgets prefer structured JSON (`label`/`bars`, `cells`) from `evo-bar-*.sh`.
