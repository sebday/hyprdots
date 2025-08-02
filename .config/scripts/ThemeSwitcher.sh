#!/bin/bash

# Define directories
THEME_DIR="$HOME/.config/themes"
CURRENT_THEME_LINK="$THEME_DIR/current"

# Get theme options from the theme directory
themes=()
for theme_dir in "$THEME_DIR"/*; do
    if [ -d "$theme_dir" ] && [[ "$(basename "$theme_dir")" != "current" ]]; then
        themes+=("$(basename "$theme_dir")")
    fi
done

# Use fuzzel to select a theme
selected_theme=$(printf "%s\n" "${themes[@]}" | fuzzel -d -p "Select a theme: ")

# Exit if no theme is selected
if [ -z "$selected_theme" ]; then
    exit 0
fi

# Update the symbolic link
ln -sfn "$THEME_DIR/$selected_theme" "$CURRENT_THEME_LINK"

# --- Update btop theme ---
BTHEME_CONFIG_FILE="$CURRENT_THEME_LINK/btop.conf"
if [ -f "$BTHEME_CONFIG_FILE" ]; then
    # Source the config file to get the btop_theme variable
    source "$BTHEME_CONFIG_FILE"
    
    if [ -n "$btop_theme" ]; then
        # Update the color_theme line in btop config
        sed -i "s|^color_theme =.*|color_theme = \"$btop_theme\"|" "$HOME/.config/btop/btop.conf"
        notify-send "Theme Switcher" "Switched btop to $(basename "$btop_theme" .theme)."
    else
        notify-send "Theme Switcher" "No btop theme configured for $selected_theme."
    fi
else
    notify-send "Theme Switcher" "No btop.conf file found for $selected_theme."
fi


# Function to reload ghostty windows
reload_ghostty_windows() {
    # Get all ghostty window addresses
    local ghostty_addresses=$(hyprctl clients -j | jq -r '.[] | select(.class == "com.mitchellh.ghostty") | .address')
    
    if [[ -n "$ghostty_addresses" ]]; then
        # Save current active window
        local current_window=$(hyprctl activewindow -j | jq -r '.address')
        
        # Send reload keybind to each ghostty window
        while IFS= read -r address; do
            if [[ -n "$address" ]]; then
                hyprctl dispatch focuswindow "address:$address"
                sleep 0.1
                # Send Ctrl+Shift+, (reload config shortcut)
                hyprctl dispatch sendshortcut "CTRL SHIFT, comma, address:$address"
            fi
        done <<< "$ghostty_addresses"
        
        # Return focus to original window
        if [[ -n "$current_window" ]]; then
            hyprctl dispatch focuswindow "address:$current_window"
        fi
    fi
}

# Reload ghostty to apply the new theme
reload_ghostty_windows

notify-send "Theme Switcher" "Switched to $selected_theme theme."
