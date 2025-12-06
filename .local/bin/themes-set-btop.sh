#!/bin/bash

# Update btop theme
BTOP_THEME_FILE="$HOME/.themes/current/btop.theme"
BTOP_CONFIG_DIR="$HOME/.config/btop/themes"

if [ -f "$BTOP_THEME_FILE" ]; then
    mkdir -p "$BTOP_CONFIG_DIR"
    cp "$BTOP_THEME_FILE" "$BTOP_CONFIG_DIR/current.theme"
    sed -i 's|^color_theme =.*|color_theme = "current"|' "$HOME/.config/btop/btop.conf"
fi
