#!/usr/bin/env bash
# Restart the evoshell Quickshell process, preserving lock state when possible.

set -euo pipefail

BIN="${HOME}/.local/bin"
IPC="${BIN}/evoshell-ipc"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/evoshell"
SUPERVISOR_PID_FILE="${STATE_DIR}/launch-shell.pid"

was_locked="false"
if status="$("$IPC" evo.lock status 2>/dev/null || true)"; then
    was_locked="$(printf '%s' "$status" | jq -r '.locked // false' 2>/dev/null || echo false)"
fi

stop_pid() {
    local pid="$1"
    [[ -n "$pid" ]] || return 0
    kill -TERM "$pid" 2>/dev/null || true
    for _ in {1..30}; do
        kill -0 "$pid" 2>/dev/null || return 0
        sleep 0.1
    done
    kill -KILL "$pid" 2>/dev/null || true
}

if [[ -f "$SUPERVISOR_PID_FILE" ]]; then
    stop_pid "$(cat "$SUPERVISOR_PID_FILE" 2>/dev/null || true)"
fi

pkill -f "systemd-cat -t evoshell" 2>/dev/null || true
pkill -f "quickshell.*evoshell" 2>/dev/null || true
sleep 0.3

nohup "${BIN}/evo-launch-shell" >/dev/null 2>&1 &
disown 2>/dev/null || true

if [[ "$was_locked" == "true" ]]; then
    for _ in {1..20}; do
        if "$IPC" shell ping >/dev/null 2>&1; then
            "$IPC" evo.lock lock >/dev/null 2>&1 || true
            break
        fi
        sleep 0.2
    done
fi
