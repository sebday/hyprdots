#!/bin/bash

# Update Hyprland border colors
HYPR_THEME_FILE="$HOME/.themes/current/hypr.conf"
HYPR_CONFIG_FILE="$HOME/.config/hypr/looks.conf"

if [ -f "$HYPR_THEME_FILE" ]; then
    col_active_border=$(grep "^\$col_active_border" "$HYPR_THEME_FILE" | cut -d '=' -f 2- | sed 's/^[[:space:]]*//')
    col_inactive_border=$(grep "^\$col_inactive_border" "$HYPR_THEME_FILE" | cut -d '=' -f 2- | sed 's/^[[:space:]]*//')
    sed -i "s|^[[:space:]]*col\.active_border =.*|    col.active_border = $col_active_border|" "$HYPR_CONFIG_FILE"
    sed -i "s|^[[:space:]]*col\.inactive_border =.*|    col.inactive_border = $col_inactive_border|" "$HYPR_CONFIG_FILE"
fi
