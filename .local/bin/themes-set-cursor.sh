#!/bin/bash

# Configuration
CURSOR_CONFIG_FILE="$HOME/.config/Cursor/User/settings.json"
CURSOR_THEME_JSON="$HOME/.themes/current/vscode.json"
CURSOR_EXTENSIONS_DIR="$HOME/.cursor/extensions"

# Check if theme definition exists
[ ! -f "$CURSOR_THEME_JSON" ] && exit 0

# 1. Handle Extension Installation
EXTENSION_ID=$(jq -r '.extension // empty' "$CURSOR_THEME_JSON" 2>/dev/null)
if [ -n "$EXTENSION_ID" ]; then
    # Try marketplace first (handles "already installed" case gracefully)
    if ! cursor --install-extension "$EXTENSION_ID" >/dev/null 2>&1; then
        # Fallback to GitHub for specific extensions
        case "$EXTENSION_ID" in
            sebday.*)
                THEME_SLUG=${EXTENSION_ID#sebday.}
                GITHUB_URL="https://github.com/sebday/vscode-$THEME_SLUG"
                TEMP_DIR=$(mktemp -d)
                
                if git clone --depth 1 "$GITHUB_URL" "$TEMP_DIR" 2>/dev/null; then
                    rm -rf "$TEMP_DIR/.git"
                    EXTENSION_VERSION=$(jq -r '.version // "1.0.0"' "$TEMP_DIR/package.json" 2>/dev/null)
                    EXTENSION_DIR="$CURSOR_EXTENSIONS_DIR/${EXTENSION_ID}-${EXTENSION_VERSION}"
                    
                    mkdir -p "$CURSOR_EXTENSIONS_DIR"
                    rm -rf "$EXTENSION_DIR"
                    cp -r "$TEMP_DIR" "$EXTENSION_DIR"
                    echo "✓ Installed from GitHub: $EXTENSION_ID"
                fi
                rm -rf "$TEMP_DIR"
                ;;
        esac
    fi
fi

# 2. Update Settings
THEME_NAME=$(jq -r '.name // empty' "$CURSOR_THEME_JSON" 2>/dev/null)

if [ -n "$THEME_NAME" ]; then
    # Ensure settings file exists
    mkdir -p "$(dirname "$CURSOR_CONFIG_FILE")"
    [ -f "$CURSOR_CONFIG_FILE" ] || printf '{\n}\n' >"$CURSOR_CONFIG_FILE"

    # Add key if missing
    grep -q '"workbench.colorTheme"' "$CURSOR_CONFIG_FILE" || \
        sed -i --follow-symlinks -E '0,/\{/{s/\{/{\n    "workbench.colorTheme": "",/}' "$CURSOR_CONFIG_FILE"

    # Update value
    sed -i --follow-symlinks -E \
        "s/(\"workbench\.colorTheme\"[[:space:]]*:[[:space:]]*\")[^\"]*(\")/\1$THEME_NAME\2/" \
        "$CURSOR_CONFIG_FILE"
fi
