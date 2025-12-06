#!/bin/bash
CURRENT_THEME_LINK="$HOME/.themes/current"
CURSOR_CONFIG_FILE="$HOME/.config/Cursor/User/settings.json"
CURSOR_THEME_JSON="$CURRENT_THEME_LINK/vscode.json"
CURSOR_EXTENSIONS_DIR="$HOME/.cursor/extensions"

if [ ! -f "$CURSOR_THEME_JSON" ]; then
    echo "Warning: No vscode.json found in current theme"
    exit 0
fi

EXTENSION_ID=$(jq -r '.extension // empty' "$CURSOR_THEME_JSON" 2>/dev/null)
if [ -n "$EXTENSION_ID" ]; then
    # Convert extension ID to folder format (publisher.name -> publisher.name-*)
    EXTENSION_FOLDER_PATTERN="${EXTENSION_ID}-*"
    
    # Check if extension folder exists
    if ! ls -d "$CURSOR_EXTENSIONS_DIR"/$EXTENSION_FOLDER_PATTERN 2>/dev/null | grep -q .; then
        echo "Extension not found in $CURSOR_EXTENSIONS_DIR"
        THEME_NAME=$(basename "$(readlink -f "$CURRENT_THEME_LINK")" | sed 's/-omarchy$//')
        
        # 1. Try installing from marketplace first
        echo "Trying marketplace: $EXTENSION_ID"
        INSTALL_OUTPUT=$(cursor --install-extension "$EXTENSION_ID" 2>&1 | grep -v "Warning:")
        
        if ls -d "$CURSOR_EXTENSIONS_DIR"/$EXTENSION_FOLDER_PATTERN 2>/dev/null | grep -q .; then
            echo "✓ Installed from marketplace: $EXTENSION_ID"
            notify-send "Theme Extension Installed" "$EXTENSION_ID"
        else
            # 2. Try installing from GitHub
            GITHUB_URL=""
            case "$EXTENSION_ID" in
                sebday.*)
                    THEME_SLUG=$(echo "$EXTENSION_ID" | sed 's/sebday\.//')
                    GITHUB_URL="https://github.com/sebday/vscode-$THEME_SLUG"
                    ;;
            esac
            
            if [ -n "$GITHUB_URL" ]; then
                echo "Marketplace failed, trying GitHub: $GITHUB_URL"
                TEMP_DIR=$(mktemp -d)
                
                if git clone --depth 1 "$GITHUB_URL" "$TEMP_DIR" 2>/dev/null; then
                    echo "Cloned successfully, installing to extensions directory..."
                    
                    # Remove .git folder and copy to extensions
                    rm -rf "$TEMP_DIR/.git"
                    
                    # Create extension directory name (publisher.name-version)
                    EXTENSION_VERSION=$(jq -r '.version // "1.0.0"' "$TEMP_DIR/package.json" 2>/dev/null)
                    EXTENSION_DIR="$CURSOR_EXTENSIONS_DIR/${EXTENSION_ID}-${EXTENSION_VERSION}"
                    
                    # Copy the extension
                    mkdir -p "$CURSOR_EXTENSIONS_DIR"
                    rm -rf "$EXTENSION_DIR"
                    cp -r "$TEMP_DIR" "$EXTENSION_DIR"
                    rm -rf "$TEMP_DIR"
                    
                    if [ -d "$EXTENSION_DIR" ]; then
                        echo "✓ Installed from GitHub: $EXTENSION_ID at $EXTENSION_DIR"
                        notify-send "Theme Extension Installed" "$EXTENSION_ID (from GitHub)"
                    else
                        echo "⚠ Failed to copy extension to $EXTENSION_DIR"
                    fi
                else
                    rm -rf "$TEMP_DIR"
                    echo "⚠ Failed to clone from GitHub: $GITHUB_URL"
                fi
            fi
            
        fi
    else
        echo "✓ Extension already installed: $EXTENSION_ID"
    fi
fi

THEME_NAME=$(jq -r '.name // empty' "$CURSOR_THEME_JSON" 2>/dev/null)
if [ -n "$THEME_NAME" ] && [ -f "$CURSOR_CONFIG_FILE" ]; then
    sed -i "s|\"workbench\.colorTheme\".*|    \"workbench.colorTheme\": \"$THEME_NAME\",|" "$CURSOR_CONFIG_FILE"
    echo "✓ Set Cursor theme to: $THEME_NAME"
fi
