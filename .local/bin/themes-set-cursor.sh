#!/bin/bash
CURRENT_THEME_LINK="$HOME/.themes/current"
CURSOR_CONFIG_FILE="$HOME/.config/Cursor/User/settings.json"

# Update Cursor theme
CURSOR_THEME_FILE="$CURRENT_THEME_LINK/cursor.conf"
if [ -f "$CURSOR_THEME_FILE" ] && [ -f "$CURSOR_CONFIG_FILE" ]; then
    # Source the cursor theme file to get the theme name
    source "$CURSOR_THEME_FILE"
    
    if [ -n "$cursor_theme" ]; then
        # Update the workbench.colorTheme line in Cursor settings
        sed -i "s|\"workbench.colorTheme\":.*|\"workbench.colorTheme\": \"$cursor_theme\",|" "$CURSOR_CONFIG_FILE"
    fi
fi
