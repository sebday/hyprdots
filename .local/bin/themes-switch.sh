#!/bin/bash

# A unified script for managing themes in Hyprland
#
# USAGE:
#   themes-switch.sh select   - Open a menu to select a theme
#   themes-switch.sh next     - Cycle to the next theme
#   themes-switch.sh prev     - Cycle to the previous theme

THEME_DIR="$HOME/.themes"
CURRENT_LINK="$THEME_DIR/current"

# Function to apply a theme
apply_theme() {
    local theme_name="$1"
    
    # Update symlink
    ln -sfn "$HOME/.themes/$theme_name" "$CURRENT_LINK"
    
    # Set GTK theme
    gsettings set org.gnome.desktop.interface gtk-theme "$theme_name"
    
    # Set theme components
    "$HOME/.local/bin/wallpaper.sh" "next"
    "$HOME/.local/bin/themes-set-icons.sh"
    "$HOME/.local/bin/themes-set-btop.sh"
    "$HOME/.local/bin/themes-set-mako.sh"
    "$HOME/.local/bin/themes-set-cursor.sh"
    "$HOME/.local/bin/themes-set-fuzzel.sh"
    "$HOME/.local/bin/themes-set-obsidian.sh"
    
    # Reload applications
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
        # Interactive theme selection with fuzzel
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
        
        apply_theme "$selected_theme"
        ;;
    
    next|prev)
        # Cycle through themes
        mapfile -t themes < <(
            for theme_dir in "$THEME_DIR"/*; do
                if [ -d "$theme_dir" ]; then
                    theme_name=$(basename "$theme_dir")
                    if [[ "$theme_name" != "current" && "$theme_name" != "shared" ]]; then
                        echo "$theme_name"
                    fi
                fi
            done | sort
        )
        
        if [ ${#themes[@]} -eq 0 ]; then
            notify-send "Theme Cycler" "No themes found."
            exit 0
        fi
        
        # Get current theme
        current_theme=""
        if [ -L "$CURRENT_LINK" ]; then
            current_theme=$(basename "$(readlink -f "$CURRENT_LINK")")
        fi
        
        # Find current theme index
        current_idx=-1
        if [ -n "$current_theme" ]; then
            for i in "${!themes[@]}"; do
                if [[ "${themes[$i]}" == "$current_theme" ]]; then
                    current_idx=$i
                    break
                fi
            done
        fi
        
        # Determine target theme
        target_idx=0
        if [ "$current_idx" -ne -1 ]; then
            if [[ "$COMMAND" == "next" ]]; then
                target_idx=$(( (current_idx + 1) % ${#themes[@]} ))
            elif [[ "$COMMAND" == "prev" ]]; then
                target_idx=$(( (current_idx - 1 + ${#themes[@]}) % ${#themes[@]} ))
            fi
        else
            # If current not found, start from beginning or end
            [[ "$COMMAND" == "prev" ]] && target_idx=$(( ${#themes[@]} - 1 ))
        fi
        
        apply_theme "${themes[$target_idx]}"
        ;;
    
    *)
        echo "Usage: $0 [select|next|prev]"
        exit 1
        ;;
esac

exit 0
