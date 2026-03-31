#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/themes-common.sh"

# Migrate omarchy themes to local theme format
# Usage: themes-migrate-omarchy.sh <source-path>
#   source-path: single theme dir (has colors.toml) or directory of themes (children have colors.toml)
#
# Example:
#   themes-migrate-omarchy.sh ~/downloads/omarchy-dev/themes/         # all themes
#   themes-migrate-omarchy.sh ~/downloads/omarchy-dev/themes/ethereal  # single theme

if [ -z "$1" ]; then
    echo "Usage: $0 <source-path>"
    echo "  source-path: theme directory or directory containing theme subdirs"
    echo "Example: $0 ~/downloads/omarchy-dev/themes/"
    exit 1
fi

SOURCE="$1"
THEME_DIR="$HOME/.themes"

# Migrate a single theme
migrate_theme() {
    local source_theme="$1"
    local theme_name
    theme_name=$(basename "$source_theme")
    local target_dir="$THEME_DIR/$theme_name"

    if [ ! -f "$source_theme/colors.toml" ]; then
        echo "Skipping $theme_name: no colors.toml"
        return
    fi

    if [ -d "$target_dir" ]; then
        echo "Skipping $theme_name: already exists"
        return
    fi

    echo "Migrating: $theme_name"
    mkdir -p "$target_dir"

    # Copy theme files, exclude omarchy-specific and files we generate at apply
    # (themes-process-templates.sh writes hyprland.conf / waybar.css from shared *.tpl)
    rsync -a \
        --exclude='chromium.theme' \
        --exclude='keyboard.rgb' \
        --exclude='kitty.conf' \
        --exclude='swayosd.css' \
        --exclude='walker.css' \
        --exclude='alacritty.toml' \
        --exclude='hyprland.conf' \
        --exclude='waybar.css' \
        "$source_theme/" "$target_dir/"

    # Add mantle (required for VS Code editor/chrome split): 20% darker than background
    if ! grep -q '^mantle ' "$target_dir/colors.toml" 2>/dev/null; then
        bg=$(grep '^background ' "$target_dir/colors.toml" 2>/dev/null | sed 's/.*= *"//;s/".*//' | tr -d '\n')
        [ -z "$bg" ] && bg="#000000"
        mantle_hex=$(darken_hex "$bg")
        awk -v m="mantle = \"$mantle_hex\"" '/^background /{print; print m; next}1' "$target_dir/colors.toml" > "$target_dir/colors.toml.tmp" && mv "$target_dir/colors.toml.tmp" "$target_dir/colors.toml"
    fi

    echo "  Done: $theme_name"
}

# Main
if [ ! -d "$SOURCE" ]; then
    echo "Error: Source does not exist: $SOURCE"
    exit 1
fi

# Detect: single theme (has colors.toml) vs directory of themes (children have colors.toml)
if [ -f "$SOURCE/colors.toml" ]; then
    migrate_theme "$SOURCE"
else
    for theme_path in "$SOURCE"/*; do
        [ -d "$theme_path" ] || continue
        migrate_theme "$theme_path"
    done
fi

echo
echo "Migration complete. Use themes-apply.sh select or themes-apply.sh to apply."
