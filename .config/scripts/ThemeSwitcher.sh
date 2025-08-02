#!/bin/bash

# Define directories
THEME_DIR="$HOME/.config/themes"
BTOP_CONFIG_FILE="$HOME/.config/btop/btop.conf"
GHOSTTY_CONFIG_FILE="$HOME/.config/ghostty/config"

# Function to read theme config
read_theme_config() {
    local theme_name="$1"
    local config_file="$THEME_DIR/$theme_name/config"
    
    if [ ! -f "$config_file" ]; then
        echo "Error: Config file not found for theme $theme_name" >&2
        return 1
    fi
    
    # Source the config file to get theme variables
    source "$config_file"
}

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

# Get theme options from the theme directory
themes=()
for theme_dir in "$THEME_DIR"/*; do
    if [ -d "$theme_dir" ] && [ -f "$theme_dir/config" ]; then
        themes+=("$(basename "$theme_dir")")
    fi
done

# Use fuzzel to select a theme
selected_theme=$(printf "%s\n" "${themes[@]}" | fuzzel -d -p "Select a theme: ")

# Exit if no theme is selected
if [ -z "$selected_theme" ]; then
    exit 0
fi

# Read the theme configuration
if ! read_theme_config "$selected_theme"; then
    notify-send "Theme Switcher" "Error: Could not read config for $selected_theme"
    exit 1
fi

# Set the theme for btop
if [ -n "$btop_theme" ]; then
    # Check if it's a file path or theme name
    if [[ "$btop_theme" == /* ]] || [ -f "$THEME_DIR/$selected_theme/$btop_theme" ]; then
        # It's a file path
        if [ -f "$THEME_DIR/$selected_theme/$btop_theme" ]; then
            btop_theme_file="$THEME_DIR/$selected_theme/$btop_theme"
        else
            btop_theme_file="$btop_theme"
        fi
        sed -i "s|^color_theme =.*|color_theme = \"$btop_theme_file\"|" "$BTOP_CONFIG_FILE"
    else
        # It's a built-in theme name
        sed -i "s|^color_theme =.*|color_theme = \"$btop_theme\"|" "$BTOP_CONFIG_FILE"
    fi
    notify-send "Theme Switcher" "Switched btop to $btop_theme."
else
    notify-send "Theme Switcher" "No btop theme configured for $selected_theme."
fi

# Set the theme for ghostty
if [ -n "$ghostty_theme" ]; then
    # Update the theme line in the config file
    sed -i "s|^theme =.*|theme = $ghostty_theme|" "$GHOSTTY_CONFIG_FILE"
    
    # If no theme line exists, add it
    if ! grep -q "^theme =" "$GHOSTTY_CONFIG_FILE"; then
        echo "theme = $ghostty_theme" >> "$GHOSTTY_CONFIG_FILE"
    fi
    
    # Reload ghostty windows using keyboard shortcut instead of signal
    reload_ghostty_windows
    
    notify-send "Theme Switcher" "Switched ghostty to $ghostty_theme."
else
    notify-send "Theme Switcher" "No ghostty theme configured for $selected_theme."
fi

notify-send "Theme Switcher" "Switched to $selected_theme theme."