#!/bin/bash
THEME_DIR="$HOME/.themes"
WALLPAPER_SCRIPT="$HOME/.local/bin/wallpaper.sh"
selected_theme="$1"

if [ -z "$selected_theme" ]; then
    echo "Usage: $0 <theme_name>"
    exit 1
fi

# Update wallpaper using any image from the theme's wallpapers folder (alphabetically sorted)
if [ -f "$WALLPAPER_SCRIPT" ]; then
    wallpapers_dir="$THEME_DIR/$selected_theme/wallpapers"
    if [ -d "$wallpapers_dir" ]; then
        theme_wallpaper=$(find "$wallpapers_dir" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) | sort | head -n 1)
        if [ -n "$theme_wallpaper" ] && [ -f "$theme_wallpaper" ]; then
            "$WALLPAPER_SCRIPT" "$theme_wallpaper"
        fi
    fi
fi
