#!/bin/bash

# Update Cursor theme
CURSOR_CONFIG_FILE="$HOME/.config/Cursor/User/settings.json"
CURSOR_THEME_FILE="$HOME/.themes/current/cursor.conf"

if [ -f "$CURSOR_THEME_FILE" ] && [ -f "$CURSOR_CONFIG_FILE" ]; then
    source "$CURSOR_THEME_FILE"
    if [ -n "$cursor_theme" ]; then
        sed -i "s|\"workbench.colorTheme\":.*|\"workbench.colorTheme\": \"$cursor_theme\",|" "$CURSOR_CONFIG_FILE"
    fi
fi
