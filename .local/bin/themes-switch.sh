#!/bin/bash

THEME_DIR="$HOME/.themes"
source "$HOME/.local/bin/thumbnails.sh"

generate_theme_list() {
    for theme_dir in "$THEME_DIR"/*; do
        if [ -d "$theme_dir" ] && [ "$(basename "$theme_dir")" != "current" ] && [ "$(basename "$theme_dir")" != "shared" ]; then
            theme_name=$(basename "$theme_dir")
            wallpaper_file=""
            wallpapers_dir="$theme_dir/wallpapers"
            if [ -d "$wallpapers_dir" ]; then
                wallpaper_file=$(find "$wallpapers_dir" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) -print -quit)
            fi
            printf "%s\t%s\n" "$theme_name" "$wallpaper_file"
        fi
    done
}

selected_entry=$(generate_theme_list | generate_fuzzel_entries_with_thumbs "theme" | fuzzel -d -p "Select a theme: ")
if [ -z "$selected_entry" ]; then
    exit 0
fi
selected_theme=$(echo "$selected_entry" | sed 's/^[[:space:]]*//')

gsettings set org.gnome.desktop.interface gtk-theme "$selected_theme"
ln -sfn "$HOME/.themes/$selected_theme" "$THEME_DIR/current"

# Set theme components
"$HOME/.local/bin/wallpaper.sh" "next"
"$HOME/.local/bin/themes-set-icons.sh"
"$HOME/.local/bin/themes-set-btop.sh"
"$HOME/.local/bin/themes-set-mako.sh"
"$HOME/.local/bin/themes-set-cursor.sh"
"$HOME/.local/bin/themes-set-fuzzel.sh"
"$HOME/.local/bin/themes-set-obsidian.sh"
"$HOME/.local/bin/themes-set-hyprland.sh"

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

notify-send "Theme set to $selected_theme"
