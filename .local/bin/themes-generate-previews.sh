#!/usr/bin/env bash
# Convert the first image (1-*) in each theme's backgrounds/ to PNG (same basename).
# Requires: imagemagick

THEME_DIR="${THEME_DIR:-$HOME/.themes}"

for theme_dir in "$THEME_DIR"/*; do
    [ ! -d "$theme_dir" ] && continue
    [[ "$(basename "$theme_dir")" == "current" || "$(basename "$theme_dir")" == "shared" ]] && continue

    bg_dir="$theme_dir/backgrounds"
    [ ! -d "$bg_dir" ] && continue

    first=$(find "$bg_dir" -maxdepth 1 -type f -iname "1-*" 2>/dev/null | sort | head -1)
    [ -z "$first" ] && continue

    ext="${first##*.}"
    [[ "${ext,,}" == "png" ]] && continue

    base="${first%.*}"
    png="${base}.png"
    convert "$first" "$png" && rm "$first" && echo "Converted $(basename "$first") -> $(basename "$png")"
done
