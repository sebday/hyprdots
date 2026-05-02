#!/bin/bash

# Power menu for Hyprland using Walker --dmenu
# Provides power off, restart, and sleep options

# Function to show power menu.
show_power_menu() {
  local menu_options=" Lock\n Relaunch\n󰜉 Restart\n󰐥 Shutdown"
  local selection=$(echo -e "$menu_options" | "$HOME/.local/bin/launch-walker" --dmenu --width 360 --minheight 1 --maxheight 280 -p "Power: ")

  case "$selection" in
  " Lock") hyprlock ;;
  " Relaunch") ~/.local/bin/logout.sh relaunch ;;
  "󰜉 Restart") ~/.local/bin/logout.sh reboot ;;
  "󰐥 Shutdown") ~/.local/bin/logout.sh shutdown ;;
  esac
}

# Main execution
show_power_menu 