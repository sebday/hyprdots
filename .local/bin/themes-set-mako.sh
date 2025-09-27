#!/bin/bash
CURRENT_THEME_LINK="$HOME/.themes/current"
MAKO_CONFIG_FILE="$HOME/.config/mako/config"

# Update mako theme
MAKO_THEME_FILE="$CURRENT_THEME_LINK/mako.conf"
if [ -f "$MAKO_THEME_FILE" ]; then
    # Source the mako theme file to get color variables
    source "$MAKO_THEME_FILE"
    
    # Update mako config with theme colors
    sed -i "s|^background-color=.*|background-color=$background_color|" "$MAKO_CONFIG_FILE"
    sed -i "s|^text-color=.*|text-color=$text_color|" "$MAKO_CONFIG_FILE"
    sed -i "s|^border-color=.*|border-color=$border_color|" "$MAKO_CONFIG_FILE"
    sed -i "s|^progress-color=.*|progress-color=$progress_color|" "$MAKO_CONFIG_FILE"
fi
