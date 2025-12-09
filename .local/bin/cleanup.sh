#!/bin/bash

# Clear various caches and temporary files
rm -rf ~/.cache/thumbnails/* ~/.local/share/Trash/* ~/Projects/stable-diffusion-webui/{cache,outputs}/*
cliphist wipe

# Regenerate thumbnails for .themes folder and subfolders
if [ -d ~/.themes ]; then
    {
        # Build arrays for URIs and mime types
        uris=""
        mimes=""
        while IFS= read -r file; do
            uri="file://$(readlink -f "$file")"
            mime=$(file -b --mime-type "$file")
            uris="${uris}'${uri}',"
            mimes="${mimes}'${mime}',"
        done < <(find ~/.themes -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \))
        
        # Remove trailing commas and queue thumbnails
        if [ -n "$uris" ]; then
            uris="[${uris%,}]"
            mimes="[${mimes%,}]"
            gdbus call --session --dest org.freedesktop.thumbnails.Thumbnailer1 \
                --object-path /org/freedesktop/thumbnails/Thumbnailer1 \
                --method org.freedesktop.thumbnails.Thumbnailer1.Queue \
                "$uris" "$mimes" 'normal' 'default' 0 2>/dev/null
        fi
    } &
fi

# Send notification
notify-send "Cache Cleared" "Thumbnails, Trash, Cache and clipboard history cleared."
notify-send "Regenerating .themes thumbnails..."

