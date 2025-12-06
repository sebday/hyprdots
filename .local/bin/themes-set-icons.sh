#!/bin/bash

# Update icon theme from icons.theme file
ICONS_THEME_FILE="$HOME/.themes/current/icons.theme"
if [ -f "$ICONS_THEME_FILE" ]; then
    icon_theme=$(cat "$ICONS_THEME_FILE" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -n "$icon_theme" ]; then
        gsettings set org.gnome.desktop.interface icon-theme "$icon_theme"
    fi
fi
