#!/bin/bash
CURRENT_THEME_LINK="$HOME/.themes/current"
CURSOR_CONFIG_FILE="$HOME/.config/Cursor/User/settings.json"
CURSOR_THEME_JSON="$CURRENT_THEME_LINK/cursor.json"

EXTENSION_ID=$(jq -r '.extension // empty' "$CURSOR_THEME_JSON" 2>/dev/null)
if [ -n "$EXTENSION_ID" ]; then
    if ! cursor --list-extensions | grep -qiw "$EXTENSION_ID"; then
        if ! cursor --install-extension "$EXTENSION_ID"; then
             notify-send "Theme Error" "Failed to install Cursor extension: $EXTENSION_ID"
        fi
    fi
fi

THEME_NAME=$(jq -r '.name // empty' "$CURSOR_THEME_JSON" 2>/dev/null)
if [ -n "$THEME_NAME" ] && [ -f "$CURSOR_CONFIG_FILE" ]; then
    sed -i "s|\"workbench\.colorTheme\".*|    \"workbench.colorTheme\": \"$THEME_NAME\",|" "$CURSOR_CONFIG_FILE"
fi
