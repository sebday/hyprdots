#!/bin/bash
CURRENT_THEME_LINK="$HOME/.themes/current"

# Update btop theme
BTHEME_CONFIG_FILE="$CURRENT_THEME_LINK/btop.conf"
if [ -f "$BTHEME_CONFIG_FILE" ]; then
    # Source the config file to get the btop_theme variable
    source "$BTHEME_CONFIG_FILE"
    
    if [ -n "$btop_theme" ]; then
        # Update the color_theme line in btop config
        sed -i "s|^color_theme =.*|color_theme = \"$btop_theme\"|" "$HOME/.config/btop/btop.conf"
    fi
fi
