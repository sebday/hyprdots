#!/bin/bash
# Set neovim icon colors from current (staging dir)

THEME_ICONS_FILE="$HOME/.themes/current/nvim-icons.lua"
NVIM_CONFIG_DIR="$HOME/.config/nvim/lua"

if [[ ! -f "$THEME_ICONS_FILE" ]]; then
  rm -f "$NVIM_CONFIG_DIR/theme-icons.lua"
  exit 0
fi

cp "$THEME_ICONS_FILE" "$NVIM_CONFIG_DIR/theme-icons.lua"
echo "Set nvim icon colors"
