#!/usr/bin/env bash
# Restart the evo-shell Quickshell process.

set -euo pipefail

BIN="${HOME}/.local/bin"

pkill -f "quickshell.*evo-shell" 2>/dev/null || true
pkill -f "systemd-cat -t evo-shell" 2>/dev/null || true
pkill -f "evo-launch-shell" 2>/dev/null || true
sleep 0.5
nohup "${BIN}/evo-launch-shell" >/dev/null 2>&1 &
disown 2>/dev/null || true
