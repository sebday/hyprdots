#!/bin/bash
# Clear various caches, clipboard history, and old logs.

set -euo pipefail

cleared=()

# Clipboard history (evo-shell clipboard + cliphist)
if command -v cliphist >/dev/null 2>&1; then
  cliphist wipe 2>/dev/null || true
  cleared+=("cliphist")
fi

# Entire ~/.cache (XDG_CACHE_HOME)
if [ -d "$HOME/.cache" ]; then
  find "$HOME/.cache" -mindepth 1 -delete
  cleared+=("~/.cache")
fi

# Clear Trash
if [ -d "$HOME/.local/share/Trash" ]; then
  rm -rf "$HOME/.local/share/Trash"/*
  cleared+=("trash")
fi

# Unmount FUSE secure volume if mounted
if mountpoint -q /mnt/secure 2>/dev/null; then
  fusermount3 -u /mnt/secure
  cleared+=("/mnt/secure unmounted")
fi

# User journal — safe to trim without root
if command -v journalctl >/dev/null 2>&1; then
  journalctl --user --vacuum-time=30d --quiet 2>/dev/null || true
  journalctl --user --vacuum-size=200M --quiet 2>/dev/null || true
  cleared+=("user journal")
fi

# System journal — only when passwordless sudo is available
if command -v journalctl >/dev/null 2>&1 && \
  sudo -n journalctl --vacuum-time=30d --vacuum-size=500M --quiet 2>/dev/null; then
  cleared+=("system journal")
fi

summary=$(printf '%s, ' "${cleared[@]}")
summary=${summary%, }

notify-send "Cache Cleared" "${summary:-nothing to clear}."
