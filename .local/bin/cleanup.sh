#!/bin/bash
# Clear various caches and temporary files.

# Entire ~/.cache (XDG_CACHE_HOME)
if [ -d "$HOME/.cache" ]; then
  find "$HOME/.cache" -mindepth 1 -delete
fi

# Clear Trash
rm -rf ~/.local/share/Trash/*

# Clear clipboard
cliphist wipe

# Unmount FUSE
fusermount -u /mnt/secure

# Send notification
notify-send "Cache Cleared" "Full ~/.cache, Trash, clipboard, FUSE unmount."
notify-send "Regenerating thumbnails..."
