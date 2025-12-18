#!/bin/bash

# Clear various caches and temporary files
rm -rf ~/.cache/thumbnails/* ~/.local/share/Trash/* ~/Projects/stable-diffusion-webui/{cache,outputs}/*
cliphist wipe

# Function to regenerate thumbnails
regen_thumbs() {
    local dir="$1"
    shift
    local exts=("$@")
    
    if [ -d "$dir" ]; then
        {
            # Build find command args
            local find_args=("$dir" "-type" "f" "(")
            local first=true
            for ext in "${exts[@]}"; do
                if [ "$first" = true ]; then
                    find_args+=("-iname" "*.$ext")
                    first=false
                else
                    find_args+=("-o" "-iname" "*.$ext")
                fi
            done
            find_args+=(")")

            # Build arrays for URIs and mime types
            uris=""
            mimes=""
            while IFS= read -r file; do
                uri="file://$(readlink -f "$file")"
                mime=$(file -b --mime-type "$file")
                uris="${uris}'${uri}',"
                mimes="${mimes}'${mime}',"
            done < <(find "${find_args[@]}")
            
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
}

# Regenerate thumbnails for .themes folder
regen_thumbs ~/.themes "jpg" "jpeg" "png" "gif" "webp"

# Regenerate thumbnails for films
regen_thumbs /mnt/pie/films "mkv" "mp4" "avi"

# Send notification
notify-send "Cache Cleared" "Thumbnails, Trash, Cache and clipboard history cleared."
notify-send "Regenerating thumbnails..."
