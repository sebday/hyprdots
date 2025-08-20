#!/bin/bash

# Shared thumbnail utility for Wallpaper.sh and ThemeSwitcher.sh
# This provides a common Python script for generating fuzzel entries with thumbnails

FUZZEL_THUMBNAIL_GENERATOR='
import sys, os, hashlib, pathlib

THUNAR_THUMBNAIL_DIR = os.path.expanduser("~/.cache/thumbnails/normal")
DEFAULT_ICON = "image-x-generic"

def get_thumbnail_for_file(file_path):
    if not os.path.exists(file_path):
        return DEFAULT_ICON
    
    uri = pathlib.Path(file_path).resolve().as_uri()
    uris_to_try = [
        uri,
        uri.replace("file:///", "file://localhost/", 1)
    ]
    
    for u in uris_to_try:
        md5_hash = hashlib.md5(u.encode("utf-8")).hexdigest()
        thumbnail_path = os.path.join(THUNAR_THUMBNAIL_DIR, f"{md5_hash}.png")
        if os.path.exists(thumbnail_path):
            return thumbnail_path
    
    return file_path  # Fallback to original file if no thumbnail

# Process input based on mode
mode = os.environ.get("THUMBNAIL_MODE", "wallpaper")

if mode == "wallpaper":
    # Wallpaper mode: input is file paths, output relative paths with thumbnails
    WALLPAPER_DIR = os.environ.get("WALLPAPER_DIR", ".")
    
    for line in sys.stdin:
        file_path = line.strip()
        if not file_path:
            continue
        
        # Try to get a clean relative path from the main wallpaper directory
        try:
            relative_path = os.path.relpath(file_path, WALLPAPER_DIR)
            # If the relative path goes up directories (starts with ../), just use the filename
            if relative_path.startswith("../"):
                relative_path = os.path.basename(file_path)
        except ValueError:
            # Different drives on Windows or other path issues, just use filename
            relative_path = os.path.basename(file_path)
        
        icon_path = get_thumbnail_for_file(file_path)
        print(f" {relative_path}\x00icon\x1f{icon_path}")
        
elif mode == "theme":
    # Theme mode: input is theme_name\tfile_path, output theme entries with thumbnails
    DEFAULT_ICON = "preferences-desktop-theme"
    
    for line in sys.stdin:
        parts = line.strip().split("\t")
        if len(parts) != 2:
            continue
        theme_name, wallpaper_path = parts
        
        entry_text = f"  {theme_name}"
        if wallpaper_path and os.path.exists(wallpaper_path):
            icon_path = get_thumbnail_for_file(wallpaper_path)
        else:
            icon_path = DEFAULT_ICON
        
        print(f"{entry_text}\x00icon\x1f{icon_path}")

elif mode == "media":
    # Media mode: for video/audio, with a generic fallback icon
    MEDIA_DIR = os.environ.get("MEDIA_DIR", ".")
    DEFAULT_ICON = "video-x-generic"

    for line in sys.stdin:
        file_path = line.strip()
        if not file_path:
            continue
        
        try:
            relative_path = os.path.relpath(file_path, MEDIA_DIR)
            if relative_path.startswith("../"):
                relative_path = os.path.basename(file_path)
        except ValueError:
            relative_path = os.path.basename(file_path)

        icon_path = get_thumbnail_for_file(file_path)
        if icon_path == file_path: # Check if fallback to file_path occurred
            icon_path = DEFAULT_ICON
        
        # Add two spaces for padding, consistent with the original FuzzyMpv.sh
        print(f"  {relative_path}\x00icon\x1f{icon_path}")
'

# Function to generate fuzzel entries with thumbnails
# Usage: generate_fuzzel_thumbnails <mode> [base_dir]
# Mode: "wallpaper", "theme", or "media"
generate_fuzzel_thumbnails() {
    local mode="$1"
    local base_dir="$2"
    
    export THUMBNAIL_MODE="$mode"
    if [ -n "$base_dir" ]; then
        if [ "$mode" == "wallpaper" ]; then
            export WALLPAPER_DIR="$base_dir"
        elif [ "$mode" == "media" ]; then
            export MEDIA_DIR="$base_dir"
        fi
    fi
    
    python3 -c "$FUZZEL_THUMBNAIL_GENERATOR"
}