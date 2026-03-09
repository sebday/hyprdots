#!/usr/bin/env bash

HYPRPAPER_CONFIG="$HOME/.config/hypr/hyprpaper.conf"

update_hyprpaper_config() {
    local wallpaper_path="$1"
    sed -i "s|^\s*path = .*|    path = $wallpaper_path|" "$HYPRPAPER_CONFIG"
}

set_wallpaper() {
    local target_wallpaper="$1"

    hyprctl hyprpaper wallpaper ", $target_wallpaper" >/dev/null
    update_hyprpaper_config "$target_wallpaper"
}

select_wallpaper_menu() {
    # Get current theme backgrounds folder
    CURRENT_THEME_LINK="$HOME/.themes/current"
    CURRENT_THEME_WALLPAPERS=""
    if [ -d "$CURRENT_THEME_LINK/backgrounds" ]; then
        CURRENT_THEME_WALLPAPERS="$CURRENT_THEME_LINK/backgrounds"
    else
        notify-send "Wallpaper Error" "No backgrounds directory found for the current theme."
        exit 1
    fi

    # Find wallpaper files from the theme directory, sorted alphabetically
    selected_entry=$(
        find "$CURRENT_THEME_WALLPAPERS" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) | sort | while read -r file; do
            relative=$(realpath --relative-to="$CURRENT_THEME_WALLPAPERS" "$file")
            printf "%s\x00icon\x1f%s\n" "$relative" "$file"
        done | fuzzel -d -p "Select Wallpaper: "
    )

    # If an entry was selected, reconstruct the full path and set the wallpaper
    if [ -n "$selected_entry" ]; then
        full_path="$CURRENT_THEME_WALLPAPERS/$selected_entry"

        if [ -f "$full_path" ]; then
            set_wallpaper "$full_path"
        else
            notify-send "Wallpaper Error" "Selected wallpaper file not found: $selected_entry"
        fi
    fi
}

# If we have an argument, process it
if [ -n "$1" ]; then
    # Handle direct file path argument
    if [ -f "$1" ]; then
        set_wallpaper "$1"
        exit $?
    fi
    # Otherwise continue to command processing below
else
    # Only check stdin if no arguments provided
    if [ ! -t 0 ]; then
        read -r wallpaper_path
        [ -n "$wallpaper_path" ] && [ -f "$wallpaper_path" ] && set_wallpaper "$wallpaper_path"
        exit $?
    fi
fi

COMMAND=${1:-next} # Default to 'next' if no argument is provided

case "$COMMAND" in
    select)
        select_wallpaper_menu
        ;;

    next|prev)
        # Get current theme backgrounds folder
        CURRENT_THEME_LINK="$HOME/.themes/current"
        WALLPAPER_DIR=""
        if [ -d "$CURRENT_THEME_LINK/backgrounds" ]; then
            WALLPAPER_DIR="$CURRENT_THEME_LINK/backgrounds"
        else
            notify-send "Wallpaper Cycler Error" "No backgrounds directory found for the current theme."
            exit 1
        fi

        DIRECTION=$COMMAND

        mapfile -d $'\0' wallpapers < <(find "$WALLPAPER_DIR" -type f -print0 | sort -z)
        if [ ${#wallpapers[@]} -eq 0 ]; then
            notify-send "Wallpaper Cycler" "No wallpapers found."
            exit 0
        fi

        current_wallpaper_path=$(grep -oP '^\s*path = \K.*' "$HYPRPAPER_CONFIG" | head -1)

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
        if [ "$current_idx" -ne -1 ]; then
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
        echo "Usage: $0 [next|prev|select|<path_to_wallpaper>]"
        exit 1
        ;;
esac

exit 0 