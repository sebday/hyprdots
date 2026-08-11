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
| `listPlugins` | JSON | Discovered plugins and enabled state |

Plugin-specific targets are registered by services:

| Target | Methods |
|--------|---------|
| `background` | `refresh`, `set(path)`, `setInstant(path)`, `next`, `prev` |
| `evo.audio` | `stepUp`, `stepDown`, `toggleMute`, `step(up\|down)` |
| `evo.lock` | `lock`, `isLocked`, `status` |
| `idle` | `status`, `enable`, `disable`, `toggle` |

## Examples

```bash
evo-shell-ipc shell ping
evo-shell-ipc shell toggle evo.menu
evo-shell-ipc shell toggle evo.menu '{"mode":"apps"}'
evo-shell-ipc shell toggle evo.panel '{"module":"clipboard"}'
evo-shell-ipc shell call evo.lock lock
evo-shell-ipc evo.audio stepUp
evo-shell-ipc background next
evo-shell-ipc shell reloadConfig
```

## shell.json

Canonical user config at `~/.config/quickshell/evo-shell/shell.json`.

- `bar.layout.left|center|right` — widget entries with inline settings
- `idle.screensaver` / `idle.lock` — seconds until DPMS off and session lock
- `version: 1` is required

Command widgets accept Waybar-style JSON output: `{ "text": "...", "tooltip": "...", "class": "..." }`.
