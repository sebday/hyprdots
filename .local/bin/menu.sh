#!/bin/bash
# A simple fuzzel-based menu script inspired by omarchy-menu.

# Define menu options with Nerd Font icons
options="󰸘 Change Theme\n󰋪 Change Wallpaper\n󰌌 Show Keybinds"

# Use fuzzel to get the user's choice
selected_option=$(echo -e "$options" | fuzzel -d -p "Select an action: ")

# Execute the corresponding script based on the selection
case "$selected_option" in
    "󰸘 Change Theme")
        bash ~/.local/bin/themes.sh
        ;;
    "󰋪 Change Wallpaper")
        bash ~/.local/bin/wallpaper.sh select
        ;;
    "󰌌 Show Keybinds")
        bash ~/.local/bin/keybinds.sh
        ;;
    *)
        # Exit gracefully if nothing was selected
        exit 0
        ;;
esac
