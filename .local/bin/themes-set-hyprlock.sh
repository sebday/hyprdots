#!/bin/bash

# Update Hyprlock theme colors
HYPRLOCK_THEME_FILE="$HOME/.themes/current/hyprlock.conf"
HYPRLOCK_COLORS_FILE="$HOME/.config/hypr/hyprlock-colors.conf"

if [ -f "$HYPRLOCK_THEME_FILE" ]; then
    cp "$HYPRLOCK_THEME_FILE" "$HYPRLOCK_COLORS_FILE"
fi

