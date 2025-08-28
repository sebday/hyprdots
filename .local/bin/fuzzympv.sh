#!/bin/bash
# A script to find a media file with fuzzel, display Thunar thumbnails, and open it in mpv
# Requires viewing the folders in Thunar's smallest view size to generate the thumbs

export MEDIA_DIR="/mnt/pie/films"
CACHE_FILE="/tmp/fuzzympv_cache"
FUZZEL_HELPERS="$(dirname "$0")/thumbnails.sh"
if [ -f "$FUZZEL_HELPERS" ]; then
    source "$FUZZEL_HELPERS"
fi

# Generate the list of media files for fuzzel
generate_fuzzel_list() {
    find "$MEDIA_DIR" -type f \
        \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" \) \
        | sort \
        | generate_fuzzel_entries_with_thumbs "media_basename_only" "$MEDIA_DIR"
}

# Refresh the cache in the background
refresh_cache_in_background() {
    # Generate a new list and atomically replace the old cache
    local temp_cache_file
    temp_cache_file=$(mktemp)
    generate_fuzzel_list > "$temp_cache_file"
    mv "$temp_cache_file" "$CACHE_FILE"
}

if [ -f "$CACHE_FILE" ]; then
    # If cache exists, use it for an instant menu, then refresh it in the background.
    refresh_cache_in_background &
    disown
    selected_entry=$(cat "$CACHE_FILE" | fuzzel --width=60 -d -p "Search films: ")
else
    # If no cache exists, generate it for the first time.
    echo "Generating cache for the first time... this might take a moment." >&2
    selected_entry=$(generate_fuzzel_list | tee "$CACHE_FILE" | fuzzel --width=60 -d -p "Search films: ")
fi

# If an entry was selected, find the corresponding file and open it in mpv
if [ -n "$selected_entry" ]; then
    # Trim leading spaces added for padding in fuzzel
    trimmed_entry=$(echo "$selected_entry" | sed 's/^[[:space:]]*//')
    
    # Search for the file in the media directory that matches the selected name.
    full_path=$(find "$MEDIA_DIR" -type f -name "$trimmed_entry.*" | head -n 1)

    if [ -n "$full_path" ]; then
        mpv --fullscreen "$full_path" &> /dev/null
    fi
fi 