#!/bin/bash
# Volume control via evo-shell Pipewire IPC.

set -euo pipefail

BIN="${HOME}/.local/bin/evo-shell-ipc"

case "${1:-}" in
    up)    exec "$BIN" evo.audio stepUp ;;
    down)  exec "$BIN" evo.audio stepDown ;;
    mute)  exec "$BIN" evo.audio toggleMute ;;
    *)
        echo "Usage: $0 {up|down|mute}" >&2
        exit 1
        ;;
esac
