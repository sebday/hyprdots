#!/bin/bash
# A script to find a media file with fuzzel, display Thunar thumbnails, and open it in mpv
# Requires viewing the folders in Thunar's smallest view size to generate the thumbs

# Configuration
export MEDIA_DIR="/mnt/pie/films"

# Source the shared fuzzel utility
FUZZEL_HELPERS="$(dirname "$0")/thumbnails.sh"
if [ -f "$FUZZEL_HELPERS" ]; then
    source "$FUZZEL_HELPERS"
fi

# Find media files, sort them, process with the thumbnail generator, and pipe to fuzzel
selected_entry=$(find "$MEDIA_DIR" -type f \
    \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.flv" -o -iname "*.wmv" -o -iname "*.mp3" -o -iname "*.flac" -o -iname "*.wav" -o -iname "*.ogg" \) \
    | sort \
    | generate_fuzzel_entries_with_thumbs "media" "$MEDIA_DIR" \
    | fuzzel --width=60 -d -p "Search films: ")

# If an entry was selected, reconstruct the full path and open it in mpv
if [ -n "$selected_entry" ]; then
    # Trim leading spaces added for padding in fuzzel
    trimmed_entry=$(echo "$selected_entry" | sed 's/^[[:space:]]*//')
    full_path="$MEDIA_DIR/$trimmed_entry"
    mpv "$full_path" &> /dev/null
fi 