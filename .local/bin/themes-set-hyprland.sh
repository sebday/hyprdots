#!/bin/bash

# Update Hyprland theme colors
HYPR_THEME_FILE="$HOME/.themes/current/hyprland.conf"
HYPR_COLORS_FILE="$HOME/.config/hypr/theme-colors.conf"

if [ -f "$HYPR_THEME_FILE" ]; then
    cp "$HYPR_THEME_FILE" "$HYPR_COLORS_FILE"
fi
