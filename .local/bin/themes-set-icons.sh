#!/bin/bash

# Update icon theme from index.theme file
INDEX_THEME_FILE="$HOME/.themes/current/index.theme"
if [ -f "$INDEX_THEME_FILE" ]; then
    icon_theme=$(grep -i '^IconTheme=' "$INDEX_THEME_FILE" | cut -d'=' -f2)    
    if [ -n "$icon_theme" ]; then
        gsettings set org.gnome.desktop.interface icon-theme "$icon_theme"
    fi
fi
