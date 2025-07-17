#!/usr/bin/env bash

# A unified script for managing wallpapers in Hyprland.
#
# USAGE:
#   Wallpaper.sh next|prev|random    - Cycle to the next, previous, or a random wallpaper.
#   Wallpaper.sh select [directory]  - Open a TUI to select a wallpaper from a directory.
#                                      Defaults to standard wallpaper locations if none is given.
#   Wallpaper.sh /path/to/image.jpg  - Set a specific image as the wallpaper.
#   cat /path/to/image.jpg | Wallpaper.sh - Set wallpaper from stdin.

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
}

# --- TUI FUNCTION: SELECT WALLPAPER ---
select_wallpaper_tui() {
    # Check for dependencies
    if ! command -v fzf &> /dev/null || ! command -v viu &> /dev/null; then
        notify-send "Wallpaper Selector Error" "fzf and/or viu is not installed."
        exit 1
    fi

    # Use provided directory or default to standard wallpaper directories
    local search_dirs
    if [ -n "$1" ] && [ -d "$1" ]; then
        search_dirs=("$1")
    else
        search_dirs=(
            "$HOME/OneDrive/Pictures/Widescreen"
            "$HOME/OneDrive/Pictures/Wallpapers"
        )
    fi

    local files=()
    for dir in "${search_dirs[@]}"; do
        if [ -d "$dir" ]; then
            while IFS= read -r -d $'\0' file; do files+=("$file"); done < <(
                find "$dir" -type f \( \
                -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o \
                -iname "*.gif" -o -iname "*.bmp" -o -iname "*.webp" \
                \) -print0 | sort -z
            )
        fi
    done

    if [ ${#files[@]} -eq 0 ]; then
        notify-send "Wallpaper Selector" "No wallpapers found."
        exit 0
    fi

    printf "%s\n" "${files[@]}" | \
        fzf --multi --height=80% --layout=reverse \
            --preview='viu -w 200 {}' \
            --preview-window=right:40%:wrap |
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
        # The second argument can be the directory
        select_wallpaper_tui "$2"
        ;;

    next|prev|random)
        WALLPAPER_DIR="$HOME/OneDrive/Pictures/Wallpapers"
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

        current_wallpaper_path=$(hyprctl hyprpaper listactive | head -n 1 | sed -n 's/^Wallpaper \(.*\) is active on monitor.*$/\1/p')

        current_idx=-1
        if [[ "$DIRECTION" != "random" ]]; then
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
        echo "       $0 select [directory]"
        exit 1
        ;;
esac

exit 0 