#!/bin/bash

# Update mako theme
MAKO_THEME_FILE="$HOME/.themes/current/mako.ini"
MAKO_CONFIG_FILE="$HOME/.config/mako/config"

if [ -f "$MAKO_THEME_FILE" ]; then
    # Copy the mako theme directly as it's in INI format
    cp "$MAKO_THEME_FILE" "$MAKO_CONFIG_FILE"
fi
