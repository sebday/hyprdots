#!/bin/bash
# A script to find a media file with fuzzel and open it in mpv.

# Find a media file using find, get the relative path, and pipe it to fuzzel.
# Search in /mnt/pie and filter for common media types.
RELATIVE_FILE_PATH=$(find /mnt/pie/ -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.flv" -o -iname "*.wmv" -o -iname "*.mp3" -o -iname "*.flac" -o -iname "*.wav" -o -iname "*.ogg" \) -printf '%P\n' 2>/dev/null | fuzzel -d --width=50 -p "Search media: ")

# If a file was selected, prepend the base path and open it in mpv
if [ -n "$RELATIVE_FILE_PATH" ]; then
    FULL_FILE_PATH="/mnt/pie/$RELATIVE_FILE_PATH"
    mpv "$FULL_FILE_PATH"
fi 