# Define menu options with Nerd Font icons
options="󰸘 Change Theme\n󰋪 Change Wallpaper\n󰌌 Show Keybinds\n󰑐 Restart Waybar\n󰖴 Waybar Position\n󰃨 Clear Cache"

selected_option=$(echo -e "$options" | ~/.local/bin/launch-walker --dmenu --width 420 --minheight 1 --maxheight 480 -p "Select an action: ")

case "$selected_option" in
    "󰸘 Change Theme")
        bash ~/.local/bin/themes-apply.sh select
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
    "󰖴 Waybar Position")
        bash ~/.local/bin/waybar-toggle-position.sh
        ;;
    "󰃨 Clear Cache")
        bash ~/.local/bin/cleanup.sh
        ;;
    *)
        # Exit gracefully if nothing was selected
        exit 0
        ;;
esac
