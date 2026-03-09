#!/bin/bash

# Theme switcher for Hyprland
#
# USAGE:
#   themes-switch.sh [select]  - Open menu to select a theme (default)
#   themes-switch.sh refresh  - Regenerate configs for current theme

THEME_DIR="$HOME/.themes"
CURRENT_PATH="$THEME_DIR/current"

get_current_theme() {
    if [ -f "$CURRENT_PATH/.theme-name" ]; then
        cat "$CURRENT_PATH/.theme-name"
    elif [ -L "$CURRENT_PATH" ]; then
        basename "$(readlink -f "$CURRENT_PATH")"
    else
        echo ""
    fi
}

apply_and_reload() {
    local theme_name="$1"
    "$HOME/.local/bin/themes-apply.sh" "$theme_name" || return

    reload_ghostty_windows() {
        local ghostty_addresses=$(hyprctl clients -j | jq -r '.[] | select(.class == "com.mitchellh.ghostty") | .address')
        if [[ -n "$ghostty_addresses" ]]; then
            local current_window=$(hyprctl activewindow -j | jq -r '.address')
            while IFS= read -r address; do
                if [[ -n "$address" ]]; then
                    hyprctl dispatch focuswindow "address:$address"
                    sleep 0.1
                    hyprctl dispatch sendshortcut "CTRL SHIFT, comma, address:$address"
                fi
            done <<< "$ghostty_addresses"
            if [[ -n "$current_window" ]]; then
                hyprctl dispatch focuswindow "address:$current_window"
            fi
        fi
    }

    reload_obsidian() {
        xdg-open "obsidian://command?id=app%3Areload"
    }

    reload_ghostty_windows
    reload_obsidian
    makoctl reload
    hyprctl reload
    pkill -SIGUSR2 waybar
    pkill -SIGUSR2 btop

    notify-send "Theme switched to $theme_name"
}

COMMAND=${1:-select}

case "$COMMAND" in
    select)
        source "$HOME/.local/bin/thumbnails.sh"

        generate_theme_list() {
            for theme_dir in "$THEME_DIR"/*; do
                if [ -d "$theme_dir" ] && [ "$(basename "$theme_dir")" != "current" ] && [ "$(basename "$theme_dir")" != "shared" ]; then
                    theme_name=$(basename "$theme_dir")
                    preview_file="$theme_dir/preview.png"
                    printf "%s\t%s\n" "$theme_name" "$preview_file"
                fi
            done
        }

        selected_entry=$(generate_theme_list | generate_fuzzel_entries_with_thumbs "theme" | fuzzel -d -p "Select a theme: ")
        if [ -z "$selected_entry" ]; then
            exit 0
        fi
        selected_theme=$(echo "$selected_entry" | sed 's/^[[:space:]]*//')

        apply_and_reload "$selected_theme"
        ;;

    refresh)
        current_theme=$(get_current_theme)
        if [ -z "$current_theme" ]; then
            notify-send "Theme Refresh" "No current theme."
            exit 1
        fi
        apply_and_reload "$current_theme"
        ;;

    *)
        echo "Usage: $0 [select|refresh]"
        exit 1
        ;;
esac

exit 0
