#!/bin/bash
# A script to find a media file with fuzzel, display Thunar thumbnails, and open it in mpv
# Requires viewing the folders in Thunar to generate the thumbs

# Configuration
export MEDIA_DIR="/mnt/pie/"

# Use a Python script to correctly generate thumbnail paths and feed fuzzel.
# This is more efficient than a bash loop and handles URI encoding correctly.
FUZZEL_INPUT_GENERATOR='
import sys, os, hashlib, pathlib

THUNAR_THUMBNAIL_DIR = os.path.expanduser("~/.cache/thumbnails/normal")
DEFAULT_ICON = "video-x-generic"
MEDIA_DIR = os.environ.get("MEDIA_DIR", ".")

for line in sys.stdin:
    file_path = line.strip()
    if not file_path:
        continue

    # Use pathlib for robust URI generation, resolving symlinks to get the canonical path.
    uri = pathlib.Path(file_path).resolve().as_uri()
    relative_path = os.path.relpath(file_path, MEDIA_DIR)

    # List of URIs to try for thumbnail lookup
    uris_to_try = [
        uri,
        uri.replace("file:///", "file://localhost/", 1)
    ]

    found_path = None
    for u in uris_to_try:
        md5_hash = hashlib.md5(u.encode("utf-8")).hexdigest()
        thumbnail_path = os.path.join(THUNAR_THUMBNAIL_DIR, f"{md5_hash}.png")
        if os.path.exists(thumbnail_path):
            found_path = thumbnail_path
            break
            
    if found_path:
        # Add two spaces for padding between icon and text
        print(f"  {relative_path}\x00icon\x1f{found_path}")
    else:
        print(f"  {relative_path}\x00icon\x1f{DEFAULT_ICON}")
'

# Find media files, sort them, process with Python, and pipe to fuzzel
selected_entry=$(find "$MEDIA_DIR" -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.flv" -o -iname "*.wmv" -o -iname "*.mp3" -o -iname "*.flac" -o -iname "*.wav" -o -iname "*.ogg" \) | sort | python3 -c "$FUZZEL_INPUT_GENERATOR" | fuzzel --width=60 -d -p "Search media: ")

# If an entry was selected, reconstruct the full path and open it in mpv
if [ -n "$selected_entry" ]; then
    # Trim leading spaces added for padding in fuzzel
    trimmed_entry=$(echo "$selected_entry" | sed 's/^[[:space:]]*//')
    full_path="$MEDIA_DIR$trimmed_entry"
    mpv "$full_path" &> /dev/null
fi 