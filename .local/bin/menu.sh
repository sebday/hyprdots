#!/bin/bash
# A simple fuzzel-based menu script inspired by omarchy-menu.

# Define menu options with Nerd Font icons
options="󰸘 Change Theme\n󰋪 Change Wallpaper\n󰌌 Show Keybinds\n󰝚 Movie Mode"

# Use fuzzel to get the user's choice
selected_option=$(echo -e "$options" | fuzzel -d -p "Select an action: ")

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
    "󰝚 Movie Mode")
        bash ~/.local/bin/fuzzympv.sh
        ;;
    *)
        # Exit gracefully if nothing was selected
        exit 0
        ;;
esac
