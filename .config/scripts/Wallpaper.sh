#!/usr/bin/env bash

# A unified script for managing wallpapers in Hyprland.
#
# USAGE:
#   Wallpaper.sh next|prev|random    - Cycle to the next, previous, or a random wallpaper.
#   Wallpaper.sh select              - Open a TUI to select a wallpaper.
#   Wallpaper.sh /path/to/image.jpg  - Set a specific image as the wallpaper.
#   cat /path/to/image.jpg | Wallpaper.sh - Set wallpaper from stdin.

# --- CONFIGURATION ---
WALLPAPER_DIR_PRIMARY="$HOME/OneDrive/Pictures/Wallpapers"
WALLPAPER_DIR_WIDE="$HOME/OneDrive/Pictures/Widescreen"
STATE_FILE="/tmp/current_wallpaper"

# --- CORE FUNCTION: SET WALLPAPER ---
set_wallpaper() {
    local target_wallpaper="$1"
    if [ -z "$target_wallpaper" ]; then
        echo "Error: No wallpaper path provided to set_wallpaper." >&2
        return 1
    fi

    if ! hyprctl hyprpaper preload "$target_wallpaper"; then
        notify-send "Wallpaper Error" "Failed to preload: $target_wallpaper"
        return 1
    fi

    mapfile -t monitors < <(hyprctl monitors | grep "Monitor " | awk '{print $2}')
    if [ ${#monitors[@]} -eq 0 ]; then
        hyprctl hyprpaper wallpaper ",$target_wallpaper"
    else
        for monitor in "${monitors[@]}"; do
            hyprctl hyprpaper wallpaper "$monitor,$target_wallpaper"
        done
    fi

    hyprctl hyprpaper unload unused

    # Save the path of the successfully set wallpaper
    mkdir -p "$(dirname "$STATE_FILE")"
    echo "$target_wallpaper" > "$STATE_FILE"
}

# --- TUI FUNCTION: SELECT WALLPAPER ---
select_wallpaper_tui() {
    # Check for dependencies
    if ! command -v fzf &> /dev/null || ! command -v viu &> /dev/null; then
        notify-send "Wallpaper Selector Error" "fzf and/or viu is not installed."
        exit 1
    fi

    # Set the search directory for the TUI
    local search_dir="$WALLPAPER_DIR_PRIMARY"

    local files=()
    if [ -d "$search_dir" ]; then
        while IFS= read -r -d $'\0' file; do files+=("$file"); done < <(
            find "$search_dir" -type f \( \
            -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o \
            -iname "*.gif" -o -iname "*.bmp" -o -iname "*.webp" \
            \) -print0 | sort -z
        )
    fi

    if [ ${#files[@]} -eq 0 ]; then
        notify-send "Wallpaper Selector" "No wallpapers found."
        exit 0
    fi

    # Prepare file list for fzf (basename + full path)
    # This allows displaying only the basename while retaining the full path for selection.
    (
        for file in "${files[@]}"; do
            printf "%s\t%s\n" "$(basename "$file")" "$file"
        done
    ) | fzf --multi --height=100% --layout=reverse \
            --delimiter='\t' --with-nth=1 \
            --preview-window="right:70%" \
            --preview='viu -w 163 {2}' |
    # Get the full path (second column) from the selected line
    awk -F'\t' '{print $2}' |
    while read -r selected_wallpaper; do
        [ -n "$selected_wallpaper" ] && set_wallpaper "$selected_wallpaper"
    done
}


# --- MAIN LOGIC ---

# Handle stdin for piping from other commands (e.g., imv)
if [ ! -t 0 ]; then
    read -r wallpaper_path
    [ -n "$wallpaper_path" ] && [ -f "$wallpaper_path" ] && set_wallpaper "$wallpaper_path"
    exit $?
fi

# Handle direct file path argument
if [ -f "$1" ]; then
    set_wallpaper "$1"
    exit $?
fi

COMMAND=${1:-next} # Default to 'next' if no argument is provided

case "$COMMAND" in
    select)
        select_wallpaper_tui
        ;;

    next|prev|random)
        WALLPAPER_DIR="$WALLPAPER_DIR_PRIMARY"
        DIRECTION=$COMMAND

        if [ ! -d "$WALLPAPER_DIR" ]; then
            notify-send "Wallpaper Cycler Error" "Directory '$WALLPAPER_DIR' not found."
            exit 1
        fi

        mapfile -d $'\0' wallpapers < <(find "$WALLPAPER_DIR" -type f -print0 | sort -z)
        if [ ${#wallpapers[@]} -eq 0 ]; then
            notify-send "Wallpaper Cycler" "No wallpapers found."
            exit 0
        fi

        current_wallpaper_path=""
        if [[ "$DIRECTION" != "random" ]] && [ -f "$STATE_FILE" ]; then
            current_wallpaper_path=$(<"$STATE_FILE")
        fi

        current_idx=-1
        if [ -n "$current_wallpaper_path" ]; then
            for i in "${!wallpapers[@]}"; do
                if [[ "${wallpapers[$i]}" == "$current_wallpaper_path" ]]; then
                    current_idx=$i
                    break
                fi
            done
        fi

        target_idx=0
        if [[ "$DIRECTION" == "random" ]]; then
            target_idx=$(( RANDOM % ${#wallpapers[@]} ))
        elif [ "$current_idx" -ne -1 ]; then
            if [[ "$DIRECTION" == "next" ]]; then
                target_idx=$(( (current_idx + 1) % ${#wallpapers[@]} ))
            elif [[ "$DIRECTION" == "prev" ]]; then
                target_idx=$(( (current_idx - 1 + ${#wallpapers[@]}) % ${#wallpapers[@]} ))
            fi
        else # If current not found, start from beginning/end
            [[ "$DIRECTION" == "prev" ]] && target_idx=$(( ${#wallpapers[@]} - 1 ))
        fi

        set_wallpaper "${wallpapers[$target_idx]}"
        ;;

    *)
        echo "Usage: $0 [next|prev|random|select|<path_to_wallpaper>]"
        exit 1
        ;;
esac

exit 0 