#!/bin/bash
CURRENT_THEME_LINK="$HOME/.themes/current"
FUZZEL_CONFIG_FILE="$HOME/.config/fuzzel/fuzzel.ini"

# Update fuzzel theme
FUZZEL_THEME_FILE="$CURRENT_THEME_LINK/fuzzel.conf"
if [ -f "$FUZZEL_THEME_FILE" ]; then
    # Source the fuzzel theme file to get color variables
    source "$FUZZEL_THEME_FILE"
    
    # Update fuzzel config with theme colors
    sed -i "s|^background=.*|background=$fuzzel_background|" "$FUZZEL_CONFIG_FILE"
    sed -i "s|^text=.*|text=$fuzzel_text|" "$FUZZEL_CONFIG_FILE"
    sed -i "s|^match=.*|match=$fuzzel_match|" "$FUZZEL_CONFIG_FILE"
    sed -i "s|^selection=.*|selection=$fuzzel_selection|" "$FUZZEL_CONFIG_FILE"
    sed -i "s|^selection-match=.*|selection-match=$fuzzel_selection_match|" "$FUZZEL_CONFIG_FILE"
    sed -i "s|^selection-text=.*|selection-text=$fuzzel_selection_text|" "$FUZZEL_CONFIG_FILE"
    sed -i "s|^border=.*|border=$fuzzel_border|" "$FUZZEL_CONFIG_FILE"
fi
