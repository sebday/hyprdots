#!/bin/bash

# Migrate omarchy theme to local theme format
# Usage: themes-migrate-omarchy.sh <source-theme-path> [target-theme-name]

if [ -z "$1" ]; then
    echo "Usage: $0 <source-theme-path> [target-theme-name]"
    echo "Example: $0 ~/Projects/omarchy/themes/catppuccin"
    echo "Example: $0 ~/Projects/omarchy/themes/catppuccin my-catppuccin"
    exit 1
fi

SOURCE_THEME="$1"
THEME_NAME="${2:-$(basename "$SOURCE_THEME")}"
TARGET_DIR="$HOME/.themes/$THEME_NAME"

generate_colours_css() {
    local target_dir="$1"
    
    # Collect colors from all available sources
    declare -A colors
    local sources_found=()
    
    # Extract from walker.css
    if [ -f "$target_dir/walker.css" ]; then
        colors[walker_text]=$(grep -oP '@define-color text \K#[0-9a-fA-F]+' "$target_dir/walker.css" | head -1)
        colors[walker_foreground]=$(grep -oP '@define-color foreground \K#[0-9a-fA-F]+' "$target_dir/walker.css" | head -1)
        colors[walker_background]=$(grep -oP '@define-color background \K#[0-9a-fA-F]+' "$target_dir/walker.css" | head -1)
        colors[walker_base]=$(grep -oP '@define-color base \K#[0-9a-fA-F]+' "$target_dir/walker.css" | head -1)
        colors[walker_selected]=$(grep -oP '@define-color selected-text \K#[0-9a-fA-F]+' "$target_dir/walker.css" | head -1)
        colors[walker_border]=$(grep -oP '@define-color border \K#[0-9a-fA-F]+' "$target_dir/walker.css" | head -1)
        [ -n "${colors[walker_background]}" ] && sources_found+=("walker.css")
    fi
    
    # Extract from waybar.css
    if [ -f "$target_dir/waybar.css" ]; then
        colors[waybar_foreground]=$(grep -oP '@define-color foreground \K#[0-9a-fA-F]+' "$target_dir/waybar.css" | head -1)
        colors[waybar_background]=$(grep -oP '@define-color background \K#[0-9a-fA-F]+' "$target_dir/waybar.css" | head -1)
        [ -n "${colors[waybar_background]}" ] && sources_found+=("waybar.css")
    fi
    
    # Extract from mako.ini
    if [ -f "$target_dir/mako.ini" ]; then
        colors[mako_text]=$(grep -oP '^text-color=\K#[0-9a-fA-F]+' "$target_dir/mako.ini" | head -1)
        colors[mako_border]=$(grep -oP '^border-color=\K#[0-9a-fA-F]+' "$target_dir/mako.ini" | head -1)
        colors[mako_background]=$(grep -oP '^background-color=\K#[0-9a-fA-F]+' "$target_dir/mako.ini" | head -1)
        [ -n "${colors[mako_background]}" ] && sources_found+=("mako.ini")
    fi
    
    # If we have at least one source with colors, generate colours.css
    if [ ${#sources_found[@]} -gt 0 ]; then
        # Build CSS with preference: specific > general
        local bg_primary="${colors[walker_base]:-${colors[walker_background]:-${colors[waybar_background]:-${colors[mako_background]}}}}"
        local bg_secondary="${colors[walker_background]:-${colors[waybar_background]:-${colors[mako_background]}}}"
        local text_primary="${colors[walker_text]:-${colors[walker_foreground]:-${colors[waybar_foreground]:-${colors[mako_text]}}}}"
        local text_accent="${colors[walker_selected]:-${colors[walker_foreground]:-${colors[waybar_foreground]:-${colors[mako_text]}}}}"
        local border="${colors[walker_border]:-${colors[mako_border]:-${colors[walker_foreground]:-${colors[waybar_foreground]}}}}"
        
        cat > "$target_dir/colours.css" << EOF
:root {
    --bg-primary: $bg_primary;
    --bg-secondary: $bg_secondary;
    --text-primary: $text_primary;
    --text-accent: $text_accent;
    --border: $border;
}
EOF
        echo "Created: colours.css (extracted from ${sources_found[*]})"
    else
        echo "Skipped: colours.css (could not extract colors from theme)"
    fi
}

if [ ! -d "$SOURCE_THEME" ]; then
    echo "Error: Source theme directory does not exist: $SOURCE_THEME"
    exit 1
fi

if [ -d "$TARGET_DIR" ]; then
    read -p "Theme '$THEME_NAME' already exists. Overwrite? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    rm -rf "$TARGET_DIR"
fi

echo "Migrating theme: $THEME_NAME"
echo "Source: $SOURCE_THEME"
echo "Target: $TARGET_DIR"
echo

# Copy the theme
cp -r "$SOURCE_THEME" "$TARGET_DIR"

# Generate colours.css BEFORE removing walker.css (needs it for color extraction)
generate_colours_css "$TARGET_DIR"

# Remove unused config files
FILES_TO_REMOVE=(
    "alacritty.toml"
    "chromium.theme"
    "kitty.conf"
    "swayosd.css"
    "walker.css"
)

for file in "${FILES_TO_REMOVE[@]}"; do
    if [ -f "$TARGET_DIR/$file" ]; then
        rm "$TARGET_DIR/$file"
        echo "Removed: $file"
    fi
done

# Add icons.theme if missing
if [ ! -f "$TARGET_DIR/icons.theme" ]; then
    echo "Catppuccin-Mocha" > "$TARGET_DIR/icons.theme"
    echo "Created: icons.theme (default: Catppuccin-Mocha)"
fi

echo
echo "✓ Theme migration complete!"
echo "You can now use this theme with themes-switch.sh"
echo
echo "To customize icon theme, edit: $TARGET_DIR/icons.theme"
echo "To customize colors, edit: $TARGET_DIR/colours.css"

