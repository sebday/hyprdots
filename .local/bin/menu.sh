#!/bin/bash
# A simple fuzzel-based menu script inspired by omarchy-menu.

# Define menu options with Nerd Font icons
options="󰸘 Change Theme\n󰋪 Change Wallpaper\n󰌌 Show Keybinds\n󰝚 Media Player\n󰟹 iPlayer\n󰗃 Channel 4"

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
    "󰝚 Media Player")
        bash ~/.local/bin/fuzzympv.sh
        ;;
    "󰟹 iPlayer")
        brave --app="https://www.bbc.co.uk/iplayer/continue-watching"
        ;;
    "󰗃 Channel 4")
        firefox --new-window https://www.channel4.com/my4/watching --class="Channel4"
        ;;
    *)
        # Exit gracefully if nothing was selected
        exit 0
        ;;
esac
