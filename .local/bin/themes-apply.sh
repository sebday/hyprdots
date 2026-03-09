#!/bin/bash
# Apply a theme: rebuild current/, process templates, run setters
# Usage: themes-apply.sh <theme_name>

THEME_DIR="${THEME_DIR:-$HOME/.themes}"
CURRENT_PATH="${CURRENT_PATH:-$THEME_DIR/current}"

theme_name="$1"
[ -z "$theme_name" ] && exit 1

source_path="$THEME_DIR/$theme_name"
[ ! -d "$source_path" ] && exit 1

# Rebuild current dir: copy source, then generate templates (omarchy-style staging)
rm -rf "$CURRENT_PATH"
mkdir -p "$CURRENT_PATH"
cp -a "$source_path/." "$CURRENT_PATH/"
echo "$theme_name" > "$CURRENT_PATH/.theme-name"

# Generate configs from templates into current/
"$HOME/.local/bin/themes-process-templates.sh" "$CURRENT_PATH"

# Set theme components
"$HOME/.local/bin/themes-set-gtk.sh"
"$HOME/.local/bin/wallpaper.sh" "next"
"$HOME/.local/bin/themes-set-icons.sh"
"$HOME/.local/bin/themes-set-btop.sh"
"$HOME/.local/bin/themes-set-yazi.sh"
"$HOME/.local/bin/themes-set-neovim-icons.sh"
"$HOME/.local/bin/themes-set-mako.sh"
"$HOME/.local/bin/themes-set-cursor.sh"
"$HOME/.local/bin/themes-set-fuzzel.sh"
"$HOME/.local/bin/themes-set-obsidian.sh"
