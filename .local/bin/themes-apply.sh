#!/bin/bash
set -e
# Apply a theme: build into staging dir, atomically swap, run setters
# Usage: themes-apply.sh <theme_name>

THEME_DIR="${THEME_DIR:-$HOME/.themes}"
CURRENT_PATH="${CURRENT_PATH:-$THEME_DIR/current}"
NEXT_PATH="${NEXT_PATH:-$THEME_DIR/next}"

theme_name="$1"
[ -z "$theme_name" ] && exit 1

source_path="$THEME_DIR/$theme_name"
[ ! -d "$source_path" ] && exit 1

# Build into staging dir (atomic: only swap on success)
rm -rf "$NEXT_PATH"
mkdir -p "$NEXT_PATH"
cp -a "$source_path/." "$NEXT_PATH/"
echo "$theme_name" > "$NEXT_PATH/.theme-name"

# Generate configs from templates into staging
"$HOME/.local/bin/themes-process-templates.sh" "$NEXT_PATH"

# Generate GTK theme into staging (THEME_PATH=next for build; symlinks point to current)
THEME_PATH="$NEXT_PATH" "$HOME/.local/bin/themes-set-gtk.sh"

# Atomic swap
rm -rf "$CURRENT_PATH"
mv "$NEXT_PATH" "$CURRENT_PATH"

# Set theme components (read from current/)
"$HOME/.local/bin/themes-install-manifest.sh"
"$HOME/.local/bin/wallpaper.sh" "next"
"$HOME/.local/bin/themes-set-icons.sh"
"$HOME/.local/bin/themes-set-cursor.sh"
"$HOME/.local/bin/themes-set-fuzzel.sh"
"$HOME/.local/bin/themes-set-obsidian.sh"
