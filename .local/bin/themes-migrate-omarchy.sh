#!/bin/bash

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

# Parse key from colors.toml
toml_val() {
    grep "^$1 " "$2" 2>/dev/null | sed 's/.*= *"//;s/".*//' | tr -d '\n'
}

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

    echo "Migrating: $theme_name"
    mkdir -p "$target_dir"

    # Copy theme files, exclude omarchy-specific
    rsync -a \
        --exclude='chromium.theme' \
        --exclude='kitty.conf' \
        --exclude='swayosd.css' \
        --exclude='walker.css' \
        --exclude='alacritty.toml' \
        "$source_theme/" "$target_dir/"

    # Copy GTK themes from shared and replace colors
    if [ -d "$THEME_DIR/shared/gtk-3.0" ] && [ -f "$target_dir/colors.toml" ]; then
        cp -r "$THEME_DIR/shared/gtk-3.0" "$target_dir/"
        cp -r "$THEME_DIR/shared/gtk-4.0" "$target_dir/"

        local toml="$target_dir/colors.toml"
        local new_bg_primary new_bg_secondary new_text new_accent
        local new_blue new_cyan new_purple new_pink new_green new_orange new_red

        new_bg_primary=$(toml_val background "$toml")
        new_bg_secondary=$(toml_val color0 "$toml")
        new_text=$(toml_val foreground "$toml")
        new_accent=$(toml_val accent "$toml")
        new_blue=$(toml_val color4 "$toml")
        new_cyan=$(toml_val color6 "$toml")
        new_purple=$(toml_val color5 "$toml")
        new_pink=$(toml_val color13 "$toml")
        new_green=$(toml_val color2 "$toml")
        new_orange=$(toml_val color3 "$toml")
        new_red=$(toml_val color1 "$toml")

        for gtk_css in "$target_dir/gtk-3.0/gtk.css" "$target_dir/gtk-3.0/gtk-dark.css" "$target_dir/gtk-4.0/gtk.css" "$target_dir/gtk-4.0/gtk-dark.css"; do
            [ -f "$gtk_css" ] || continue
            sed -i "s/#313244/$new_bg_secondary/gi" "$gtk_css"
            sed -i "s/#292c3c/$new_bg_secondary/gi" "$gtk_css"
            sed -i "s/#4a4b5a/$new_bg_secondary/gi" "$gtk_css"
            sed -i "s/#232634/$new_bg_secondary/gi" "$gtk_css"
            sed -i "s/#2b2b3a/$new_bg_secondary/gi" "$gtk_css"
            sed -i "s/#1e1e2e/$new_bg_primary/gi" "$gtk_css"
            sed -i "s/#181825/$new_bg_secondary/gi" "$gtk_css"
            sed -i "s/#cdd6f4/$new_text/gi" "$gtk_css"
            sed -i "s/#74c7ec/$new_accent/gi" "$gtk_css"
            sed -i "s/#89b4fa/$new_blue/gi" "$gtk_css"
            sed -i "s/#94e2d5/$new_cyan/gi" "$gtk_css"
            sed -i "s/#cba6f7/$new_purple/gi" "$gtk_css"
            sed -i "s/#f5c2e7/$new_pink/gi" "$gtk_css"
            sed -i "s/#a6e3a1/$new_green/gi" "$gtk_css"
            sed -i "s/#fab387/$new_orange/gi" "$gtk_css"
            sed -i "s/#f38ba8/$new_red/gi" "$gtk_css"
        done
        echo "  Updated GTK theme colors"
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
echo "Migration complete. Use themes-switch.sh to apply."
