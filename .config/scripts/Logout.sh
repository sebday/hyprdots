#!/bin/bash

# This script is called by power-menu.sh
# It exits Hyprland and then performs the requested action.

ACTION=$1

# Exit Hyprland
hyprctl dispatch exit

# Wait for Hyprland to exit completely
while pgrep -x Hyprland > /dev/null; do
    sleep 0.1
done

# Perform the action
case "$ACTION" in
  reboot)
    systemctl reboot
    ;;
  shutdown)
    systemctl poweroff
    ;;
  *)
    # Default to logout (do nothing more)
    ;;
esac 