#!/bin/bash
CURRENT_THEME_LINK="$HOME/.themes/current"

# Update icon theme from index.theme file
INDEX_THEME_FILE="$CURRENT_THEME_LINK/index.theme"
if [ -f "$INDEX_THEME_FILE" ]; then
    # Parse the icon theme name from the index.theme file
    icon_theme=$(grep -i '^IconTheme=' "$INDEX_THEME_FILE" | cut -d'=' -f2)
    
    if [ -n "$icon_theme" ]; then
        # Apply via gsettings and update config files for all GTK versions
        gsettings set org.gnome.desktop.interface icon-theme "$icon_theme"
    fi
fi
