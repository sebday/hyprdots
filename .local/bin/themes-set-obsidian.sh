#!/bin/bash
THEME_DIR="$HOME/.themes"
CURRENT_THEME_LINK="$HOME/.themes/current"
OBSIDIAN_VAULT_DIR="$HOME/OneDrive/Notes"

# Update Obsidian theme
OBSIDIAN_CONFIG_FILE="$OBSIDIAN_VAULT_DIR/.obsidian/appearance.json"
OBSIDIAN_VAULT_THEMES_DIR="$OBSIDIAN_VAULT_DIR/.obsidian/themes"
THEME_CSS_FILE="$CURRENT_THEME_LINK/obsidian.css"

if [ -f "$THEME_CSS_FILE" ]; then
    # --- New Modular Theme Logic ---
    MODULAR_THEME_NAME="Modular"
    MODULAR_THEME_DIR="$OBSIDIAN_VAULT_THEMES_DIR/$MODULAR_THEME_NAME"
    SHARED_CSS_FILE="$THEME_DIR/shared/obsidian.css"

    # Ensure the modular theme directory exists
    mkdir -p "$MODULAR_THEME_DIR"

    # Create a manifest.json if it doesn't exist, by copying the shared one
    SHARED_MANIFEST_FILE="$THEME_DIR/shared/obsidian.conf"
    if [ ! -f "$MODULAR_THEME_DIR/manifest.json" ] && [ -f "$SHARED_MANIFEST_FILE" ]; then
        cp "$SHARED_MANIFEST_FILE" "$MODULAR_THEME_DIR/manifest.json"
    fi

    # Combine theme-specific and shared CSS into the modular theme's css file
    if [ -f "$SHARED_CSS_FILE" ] && [ -f "$THEME_CSS_FILE" ]; then
        cat "$THEME_CSS_FILE" "$SHARED_CSS_FILE" > "$MODULAR_THEME_DIR/theme.css"
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
    updated_json=$(echo "$updated_json" | jq --arg theme "obsidian" '.theme = $theme' | jq --arg cssTheme "$MODULAR_THEME_NAME" '.cssTheme = $cssTheme' | jq 'del(.enabledCssSnippets)')

    # Write the updated json to the config file
    echo "$updated_json" > "$OBSIDIAN_CONFIG_FILE"
fi
