#!/bin/bash

# Update mako theme
MAKO_THEME_FILE="$HOME/.themes/current/mako.conf"
MAKO_CONFIG_FILE="$HOME/.config/mako/config"

if [ -f "$MAKO_THEME_FILE" ]; then
    source "$MAKO_THEME_FILE"
    sed -i "s|^background-color=.*|background-color=$background_color|" "$MAKO_CONFIG_FILE"
    sed -i "s|^text-color=.*|text-color=$text_color|" "$MAKO_CONFIG_FILE"
    sed -i "s|^border-color=.*|border-color=$border_color|" "$MAKO_CONFIG_FILE"
    sed -i "s|^progress-color=.*|progress-color=$progress_color|" "$MAKO_CONFIG_FILE"
fi
