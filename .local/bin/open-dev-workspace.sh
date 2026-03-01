#!/usr/bin/env bash
# Open 3 Ghostty terminals on the current workspace (tiled with dwindle layout)
# Use SUPER+J to toggle split direction if needed

hyprctl dispatch exec "ghostty --working-directory=$HOME/Projects/shopify-theme"
sleep 0.2
hyprctl dispatch exec "ghostty --working-directory=$HOME/Projects/shopify-theme"
sleep 0.2
hyprctl dispatch exec "ghostty --working-directory=$HOME/Projects/shopify-theme"
