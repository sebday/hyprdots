#!/bin/bash

# Power menu for Hyprland using fuzzel
# Provides power off, restart, and sleep options

# Function to show power menu.
show_power_menu() {
  local menu_options=" Lock\n Relaunch\n󰜉 Restart\n󰐥 Shutdown"
  local selection=$(echo -e "$menu_options" | fuzzel --dmenu --lines=4 --width=12)

  case "$selection" in
  " Lock") hyprlock ;;
  " Relaunch") ~/.local/bin/logout.sh relaunch ;;
  "󰜉 Restart") ~/.local/bin/logout.sh reboot ;;
  "󰐥 Shutdown") ~/.local/bin/logout.sh shutdown ;;
  esac
}

# Main execution
show_power_menu 