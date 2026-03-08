#!/bin/bash
# Set neovim icon colors based on current theme

THEME_DIR="$HOME/.themes"
CURRENT_LINK="$THEME_DIR/current"
NVIM_CONFIG_DIR="$HOME/.config/nvim/lua"

# Get current theme name
if [[ -L "$CURRENT_LINK" ]]; then
  CURRENT_THEME=$(basename "$(readlink -f "$CURRENT_LINK")")
else
  echo "Error: No current theme symlink found"
  exit 1
fi

# Check if nvim icons file exists for this theme
THEME_ICONS_FILE="$THEME_DIR/$CURRENT_THEME/nvim-icons.lua"
if [[ ! -f "$THEME_ICONS_FILE" ]]; then
  echo "Warning: No nvim icons config found for: $CURRENT_THEME"
  # Remove existing theme-icons.lua if theme doesn't have one
  rm -f "$NVIM_CONFIG_DIR/theme-icons.lua"
  exit 0
fi

# Copy theme's icon config to nvim
cp "$THEME_ICONS_FILE" "$NVIM_CONFIG_DIR/theme-icons.lua"
echo "Set nvim icon colors to: $CURRENT_THEME"
