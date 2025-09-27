#!/bin/bash

# Update btop theme
BTHEME_CONFIG_FILE="$$HOME/.themes/current/btop.conf"

if [ -f "$BTHEME_CONFIG_FILE" ]; then
    source "$BTHEME_CONFIG_FILE"
    if [ -n "$btop_theme" ]; then
        sed -i "s|^color_theme =.*|color_theme = \"$btop_theme\"|" "$HOME/.config/btop/btop.conf"
    fi
fi
