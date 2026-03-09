#!/bin/bash
# Install generated VS Code theme and set workbench.colorTheme
# Uses ~/.themes/current/vscode-theme/ (generated from colors.toml)

CURSOR_CONFIG_FILE="$HOME/.config/Cursor/User/settings.json"
CURSOR_EXTENSIONS_DIR="$HOME/.cursor/extensions"
VSCODE_THEME_DIR="$HOME/.themes/current/vscode-theme"

[ ! -d "$VSCODE_THEME_DIR" ] && exit 0
[ ! -f "$VSCODE_THEME_DIR/package.json" ] && exit 0

# Read extension id and theme label from generated package.json
publisher=$(jq -r '.publisher // "sebday"' "$VSCODE_THEME_DIR/package.json" 2>/dev/null)
name=$(jq -r '.name // empty' "$VSCODE_THEME_DIR/package.json" 2>/dev/null)
version=$(jq -r '.version // "1.0.0"' "$VSCODE_THEME_DIR/package.json" 2>/dev/null)
theme_label=$(jq -r '.contributes.themes[0].label // empty' "$VSCODE_THEME_DIR/package.json" 2>/dev/null)

[ -z "$name" ] || [ -z "$theme_label" ] && exit 0

ext_id="${publisher}.${name}"
ext_dir="$CURSOR_EXTENSIONS_DIR/${ext_id}-${version}"

# Install: copy only if extension missing or content changed
mkdir -p "$CURSOR_EXTENSIONS_DIR"
if [ -d "$ext_dir" ]; then
    if diff -q "$VSCODE_THEME_DIR/themes/color-theme.json" "$ext_dir/themes/color-theme.json" 2>/dev/null && \
       diff -q "$VSCODE_THEME_DIR/package.json" "$ext_dir/package.json" 2>/dev/null; then
        # Content identical, skip copy
        :
    else
        rm -rf "$ext_dir"
        cp -r "$VSCODE_THEME_DIR" "$ext_dir"
    fi
else
    cp -r "$VSCODE_THEME_DIR" "$ext_dir"
fi

# Update workbench.colorTheme in settings
mkdir -p "$(dirname "$CURSOR_CONFIG_FILE")"
[ -f "$CURSOR_CONFIG_FILE" ] || printf '{\n}\n' > "$CURSOR_CONFIG_FILE"

grep -q '"workbench.colorTheme"' "$CURSOR_CONFIG_FILE" || \
    sed -i --follow-symlinks -E '0,/\{/{s/\{/{\n    "workbench.colorTheme": "",/}' "$CURSOR_CONFIG_FILE"

safe_name=$(printf '%s' "$theme_label" | sed 's/[&\]/\\&/g')
sed -i --follow-symlinks -E \
    "s/(\"workbench\.colorTheme\"[[:space:]]*:[[:space:]]*\")[^\"]*(\")/\1${safe_name}\2/" \
    "$CURSOR_CONFIG_FILE"
