#!/bin/bash

# Update mako theme - just copy the theme file with include
MAKO_THEME_FILE="$HOME/.themes/current/mako.ini"
MAKO_CONFIG_FILE="$HOME/.config/mako/config"

if [ -f "$MAKO_THEME_FILE" ]; then
    # Copy the mako theme file (which includes shared config)
    cp "$MAKO_THEME_FILE" "$MAKO_CONFIG_FILE"
fi
