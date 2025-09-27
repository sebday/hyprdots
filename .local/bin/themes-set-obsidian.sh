#!/bin/bash

# Update Obsidian theme
OBSIDIAN_VAULT_DIR="$HOME/OneDrive/Notes"
OBSIDIAN_CONFIG_FILE="$OBSIDIAN_VAULT_DIR/.obsidian/appearance.json"
THEME_CSS_FILE="$HOME/.themes/current/obsidian.css"

if [ -f "$THEME_CSS_FILE" ]; then
    
    MODULAR_THEME_DIR="$OBSIDIAN_VAULT_DIR/.obsidian/themes/Modular"
    SHARED_CSS_FILE="$HOME/.themes/shared/obsidian.css"

    mkdir -p "$MODULAR_THEME_DIR"
    
    SHARED_MANIFEST_FILE="$HOME/.themes/shared/obsidian.conf"
    if [ ! -f "$MODULAR_THEME_DIR/manifest.json" ] && [ -f "$SHARED_MANIFEST_FILE" ]; then
        cp "$SHARED_MANIFEST_FILE" "$MODULAR_THEME_DIR/manifest.json"
    fi
    
    if [ -f "$SHARED_CSS_FILE" ] && [ -f "$THEME_CSS_FILE" ]; then
        cat "$THEME_CSS_FILE" "$SHARED_CSS_FILE" > "$MODULAR_THEME_DIR/theme.css"
    fi

    OBSIDIAN_CONFIG_DIR=$(dirname "$OBSIDIAN_CONFIG_FILE")
    mkdir -p "$OBSIDIAN_CONFIG_DIR"

    if [ -f "$OBSIDIAN_CONFIG_FILE" ]; then
        updated_json=$(cat "$OBSIDIAN_CONFIG_FILE")
    else
        updated_json='{}'
    fi

    updated_json=$(echo "$updated_json" | jq --arg theme "obsidian" '.theme = $theme' | jq --arg cssTheme "Modular" '.cssTheme = $cssTheme' | jq 'del(.enabledCssSnippets)')

    echo "$updated_json" > "$OBSIDIAN_CONFIG_FILE"
fi
