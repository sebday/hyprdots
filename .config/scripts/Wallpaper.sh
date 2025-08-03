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
HYPRPAPER_CONFIG="$HOME/.config/hypr/hyprpaper.conf"
THUMBNAILS_SCRIPT="$HOME/.config/scripts/Thumbnails.sh"

# Source the shared thumbnail utilities
source "$THUMBNAILS_SCRIPT"

# --- FUNCTION: UPDATE HYPRPAPER CONFIG ---
update_hyprpaper_config() {
    local wallpaper_path="$1"
    if [ -z "$wallpaper_path" ]; then
        echo "Error: No wallpaper path provided to update_hyprpaper_config." >&2
        return 1
    fi
    
    if [ ! -f "$HYPRPAPER_CONFIG" ]; then
        echo "Warning: hyprpaper.conf not found at $HYPRPAPER_CONFIG" >&2
        return 1
    fi
    
    # Create a temporary file for the updated config
    local temp_config
    temp_config=$(mktemp) || {
        echo "Error: Failed to create temporary file for hyprpaper config update." >&2
        return 1
    }
    
    # Read the existing config and update the preload and wallpaper lines
    while IFS= read -r line; do
        if [[ "$line" =~ ^preload[[:space:]]*= ]]; then
            echo "preload = $wallpaper_path"
        elif [[ "$line" =~ ^wallpaper[[:space:]]*= ]]; then
            echo "wallpaper = ,$wallpaper_path"
        else
            echo "$line"
        fi
    done < "$HYPRPAPER_CONFIG" > "$temp_config"
    
    # Replace the original config with the updated one
    if mv "$temp_config" "$HYPRPAPER_CONFIG"; then
        echo "Updated hyprpaper.conf with new wallpaper: $wallpaper_path"
    else
        echo "Error: Failed to update hyprpaper.conf" >&2
        rm -f "$temp_config"
        return 1
    fi
}

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
    
    # Update hyprpaper.conf with the new wallpaper for persistence across reboots
    update_hyprpaper_config "$target_wallpaper"
}

# --- TUI FUNCTION: SELECT WALLPAPER ---
select_wallpaper_tui() {
    # Get current theme wallpapers folder
    CURRENT_THEME_LINK="$HOME/.themes/current"
    CURRENT_THEME_WALLPAPERS=""
    if [ -L "$CURRENT_THEME_LINK" ] && [ -d "$CURRENT_THEME_LINK/wallpapers" ]; then
        CURRENT_THEME_WALLPAPERS="$CURRENT_THEME_LINK/wallpapers"
    fi
    
    # Find wallpaper files from both directories, put current theme first, sorted alphabetically
    selected_entry=$(
        (
            # Current theme wallpapers first (if available) - sorted
            if [ -n "$CURRENT_THEME_WALLPAPERS" ]; then
                find "$CURRENT_THEME_WALLPAPERS" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) | sort
            fi
            
            # Main wallpaper directory - sorted
            find "$WALLPAPER_DIR_PRIMARY" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) | sort
        ) | generate_fuzzel_thumbnails "wallpaper" "$WALLPAPER_DIR_PRIMARY" | fuzzel -d -p "Select Wallpaper: "
    )

    # If an entry was selected, reconstruct the full path and set the wallpaper
    if [ -n "$selected_entry" ]; then
        # Strip leading space that was added for fuzzel padding
        selected_entry=$(echo "$selected_entry" | sed 's/^ //')
        
        # Try main directory first, then theme directory
        full_path="$WALLPAPER_DIR_PRIMARY/$selected_entry"
        if [ ! -f "$full_path" ] && [ -n "$CURRENT_THEME_WALLPAPERS" ]; then
            full_path="$CURRENT_THEME_WALLPAPERS/$selected_entry"
        fi
        
        if [ -f "$full_path" ]; then
            set_wallpaper "$full_path"
        else
            notify-send "Wallpaper Error" "Selected wallpaper file not found: $selected_entry"
        fi
    fi
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