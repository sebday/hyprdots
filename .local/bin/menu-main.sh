# Define menu options with Nerd Font icons
options="󰸘 Change Theme\n󰋪 Change Wallpaper\n󰌌 Show Keybinds\n󰑐 Restart Waybar\n󰏔 Install Package\n󰃨 Clear Cache"

# Use fuzzel to get the user's choice
selected_option=$(echo -e "$options" | fuzzel -d -p "Select an action: ")

case "$selected_option" in
    "󰸘 Change Theme")
        bash ~/.local/bin/themes-switch.sh
        ;;
    "󰋪 Change Wallpaper")
        bash ~/.local/bin/wallpaper.sh select
        ;;
    "󰌌 Show Keybinds")
        bash ~/.local/bin/keybinds.sh
        ;;
    "󰑐 Restart Waybar")
        pkill waybar 2>/dev/null
        waybar &
        ;;
    "󰏔 Install Package")
        ghostty --class=TUI.float -e /home/seb/.local/bin/install-pkg.sh
        ;;
    "󰃨 Clear Cache")
        rm -rf ~/.cache/thumbnails/* ~/.local/share/Trash/* ~/Projects/stable-diffusion-webui/{cache,outputs}/*
        cliphist wipe
        notify-send "Cache Cleared" "Thumbnails, Trash, Cache and clipboard history cleared"
        ;;
    *)
        # Exit gracefully if nothing was selected
        exit 0
        ;;
esac
