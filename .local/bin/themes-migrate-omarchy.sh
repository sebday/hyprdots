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
    local theme_name=$(basename "$target_dir" | tr '[:upper:]' '[:lower:]')
    
    # Catppuccin Mocha palette
    if [[ "$theme_name" =~ catppuccin ]]; then
        cat > "$target_dir/colours.css" << 'EOF'
:root {
    --bg-primary: #1e1e2e;
    --bg-secondary: #181825;
    --text-primary: #cdd6f4;
    --text-accent: #74c7ec;
    --blue: #89b4fa;
    --cyan: #94e2d5;
    --purple: #cba6f7;
    --pink: #f5c2e7;
    --green: #a6e3a1;
    --orange: #fab387;
    --red: #f38ba8;
}
EOF
        echo "Created: colours.css (Catppuccin Mocha palette)"
        return 0
    fi
    
    # For other themes, try to extract colors from waybar.css or mako.ini
    local has_colors=false
    
    if [ -f "$target_dir/waybar.css" ]; then
        local foreground=$(grep -oP '@define-color foreground \K#[0-9a-fA-F]+' "$target_dir/waybar.css" | head -1)
        local background=$(grep -oP '@define-color background \K#[0-9a-fA-F]+' "$target_dir/waybar.css" | head -1)
        
        if [ -n "$foreground" ] && [ -n "$background" ]; then
            cat > "$target_dir/colours.css" << EOF
:root {
    --bg-primary: $background;
    --bg-secondary: $background;
    --text-primary: $foreground;
    --text-accent: $foreground;
}
EOF
            echo "Created: colours.css (extracted from waybar.css)"
            has_colors=true
        fi
    fi
    
    if [ "$has_colors" = false ]; then
        echo "Skipped: colours.css (could not determine color palette)"
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

# Generate colours.css
generate_colours_css "$TARGET_DIR"

echo
echo "✓ Theme migration complete!"
echo "You can now use this theme with themes-switch.sh"
echo
echo "To customize icon theme, edit: $TARGET_DIR/icons.theme"
echo "To customize colors, edit: $TARGET_DIR/colours.css"

