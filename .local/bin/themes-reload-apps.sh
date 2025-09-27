#!/bin/bash

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

# Function to reload obsidian gracefully
reload_obsidian() {
    xdg-open "obsidian://command?id=app%3Areload"
}

# Reload all applications
pkill -SIGUSR2 waybar
reload_ghostty_windows
reload_obsidian
makoctl reload
hyprctl reload
pkill -SIGUSR2 btop
