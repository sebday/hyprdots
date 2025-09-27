#!/bin/bash

# Update fuzzel theme
FUZZEL_CONFIG_FILE="$HOME/.config/fuzzel/fuzzel.ini"
FUZZEL_THEME_FILE="$HOME/.themes/current/fuzzel.conf"

if [ -f "$FUZZEL_THEME_FILE" ]; then
    source "$FUZZEL_THEME_FILE"
    sed -i "s|^background=.*|background=$fuzzel_background|" "$FUZZEL_CONFIG_FILE"
    sed -i "s|^text=.*|text=$fuzzel_text|" "$FUZZEL_CONFIG_FILE"
    sed -i "s|^match=.*|match=$fuzzel_match|" "$FUZZEL_CONFIG_FILE"
    sed -i "s|^selection=.*|selection=$fuzzel_selection|" "$FUZZEL_CONFIG_FILE"
    sed -i "s|^selection-match=.*|selection-match=$fuzzel_selection_match|" "$FUZZEL_CONFIG_FILE"
    sed -i "s|^selection-text=.*|selection-text=$fuzzel_selection_text|" "$FUZZEL_CONFIG_FILE"
    sed -i "s|^border=.*|border=$fuzzel_border|" "$FUZZEL_CONFIG_FILE"
fi
