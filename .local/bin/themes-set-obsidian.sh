#!/bin/bash

OBSIDIAN_THEME_DIR="$HOME/OneDrive/Notes/.obsidian/themes/Modular"
OBSIDIAN_CONFIG_FILE="$HOME/OneDrive/Notes/.obsidian/appearance.json"
OBSIDIAN_CSS_FILE="$HOME/.themes/current/obsidian.css"
OBSIDIAN_SHARED_CSS_FILE="$HOME/.themes/shared/obsidian.css"

if [ -f "$OBSIDIAN_CSS_FILE" ]; then

    # Ensure the modular theme directory exists
    mkdir -p "$OBSIDIAN_THEME_DIR"

    # Create a manifest.json if it doesn't exist by copying the shared one
    SHARED_MANIFEST_FILE="$THEME_DIR/shared/obsidian.conf"
    if [ ! -f "$OBSIDIAN_THEME_DIR/manifest.json" ] && [ -f "$SHARED_MANIFEST_FILE" ]; then
        cp "$SHARED_MANIFEST_FILE" "$OBSIDIAN_THEME_DIR/manifest.json"
    fi

    # Combine theme-specific and shared CSS into the modular theme's css file
    if [ -f "$OBSIDIAN_SHARED_CSS_FILE" ] && [ -f "$2" ]; then
        cat "$OBSIDIAN_CSS_FILE" "$OBSIDIAN_SHARED_CSS_FILE" > "$OBSIDIAN_THEME_DIR/theme.css"
    fi

    # Ensure config file and directories exist
    OBSIDIAN_CONFIG_DIR=$(dirname "$OBSIDIAN_CONFIG_FILE")
    mkdir -p "$OBSIDIAN_CONFIG_DIR"

    # Read existing config or create a default one
    local updated_json
    if [ -f "$OBSIDIAN_CONFIG_FILE" ]; then
        updated_json=$(cat "$OBSIDIAN_CONFIG_FILE")
    else
        updated_json='{}'
    fi

    # Set the theme to "Modular" and remove snippet settings
    updated_json=$(echo "$updated_json" | jq --arg theme "obsidian" '.theme = $theme' | jq --arg cssTheme "Modular" '.cssTheme = $cssTheme' | jq 'del(.enabledCssSnippets)')

    # Write the updated json to the config file
    echo "$updated_json" > "$OBSIDIAN_CONFIG_FILE"
fi
