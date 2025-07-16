#!/bin/bash

# Power menu for Hyprland using fuzzel
# Provides power off, restart, and sleep options

# Function to show power menu.
show_power_menu() {
  local menu_options=" Lock\n󰤄 Suspend\n Relaunch\n󰜉 Restart\n󰐥 Shutdown"
  local selection=$(echo -e "$menu_options" | fuzzel --dmenu --prompt "" --lines=5 --width=12)

  case "$selection" in
  " Lock") hyprlock ;;
  " Relaunch") hyprctl dispatch exit ;;
  "󰜉 Restart") ~/.config/hypr/scripts/logout.sh reboot ;;
  "󰐥 Shutdown") ~/.config/hypr/scripts/logout.sh shutdown ;;
  esac
}

# Main execution
show_power_menu 