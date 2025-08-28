#!/bin/bash

# A shell-based helper function to generate fuzzel entries with thumbnails.
# It reads input from stdin and formats it for fuzzel's icon support.
#
# Usage: <input_stream> | generate_fuzzel_entries_with_thumbs <mode> [base_dir]
#
# Modes:
#   - wallpaper: Input lines are file paths. Output is relative path with thumbnail.
#   - theme:     Input lines are "theme_name\twallpaper_path". Output is theme name with wallpaper thumbnail.
#   - media:     Input lines are file paths. Output is relative path with thumbnail or generic video icon.

# Percent-encodes a string for use in a file URI path, leaving slashes intact.
urlencode_path() {
    local string="${1}"
    local strlen=${#string}
    local encoded=""
    local pos c o

    for (( pos=0 ; pos<strlen ; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9/] ) o="${c}" ;;
            * )               printf -v o '%%%02x' "'$c"
        esac
        encoded+="${o}"
    done
    echo "${encoded}"
}

generate_fuzzel_entries_with_thumbs() {
    local mode="$1"
    local base_dir="$2"
    local THUNAR_THUMBNAIL_DIR="$HOME/.cache/thumbnails/normal"
    local DEFAULT_ICON="image-x-generic"

    while IFS= read -r line; do
        local file_path=""
        local display_text=""

        if [[ "$mode" == "theme" ]]; then
            # Input is "theme_name\tfile_path"
            theme_name=$(echo -e "$line" | cut -f1)
            file_path=$(echo -e "$line" | cut -f2)
            display_text="$theme_name"
        elif [[ "$mode" == "media_basename_only" ]]; then
            file_path="$line"
            if [ -z "$file_path" ]; then continue; fi
            relative_path=$(realpath --relative-to="$base_dir" "$file_path" 2>/dev/null || basename "$file_path")
            # Show only the filename without path or extension
            display_text=$(basename "$relative_path" | sed 's/\.[^.]*$//')
        else
            # Input is a file path
            file_path="$line"
            if [ -z "$file_path" ]; then continue; fi
            # Get relative path for display text
            relative_path=$(realpath --relative-to="$base_dir" "$file_path" 2>/dev/null || basename "$file_path")
            display_text="$relative_path"
        fi

        local icon_path="$DEFAULT_ICON"
        if [ -n "$file_path" ] && [ -f "$file_path" ]; then
            local abs_path
            abs_path=$(realpath "$file_path")
            
            # Thunar generates thumbnails based on the file URI, which must be percent-encoded.
            local encoded_path
            encoded_path=$(urlencode_path "$abs_path")
            local uri1="file://$encoded_path"
            local uri2="file://localhost$encoded_path"
            
            local md5_hash1
            md5_hash1=$(echo -n "$uri1" | md5sum | awk '{print $1}')
            local md5_hash2
            md5_hash2=$(echo -n "$uri2" | md5sum | awk '{print $1}')

            local thumbnail_path1="$THUNAR_THUMBNAIL_DIR/$md5_hash1.png"
            local thumbnail_path2="$THUNAR_THUMBNAIL_DIR/$md5_hash2.png"

            if [ -f "$thumbnail_path1" ]; then
                icon_path="$thumbnail_path1"
            elif [ -f "$thumbnail_path2" ]; then
                icon_path="$thumbnail_path2"
            elif [[ "$mode" == "wallpaper" ]]; then
                # Fallback to the original file itself for wallpaper previews
                icon_path="$file_path"
            fi
        fi
        
        printf "%s\x00icon\x1f%s\n" "$display_text" "$icon_path"
    done
}
