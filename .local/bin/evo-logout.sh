#!/bin/bash
# Session exit / reboot / shutdown (evo-shell power menu).

ACTION=$1

if [[ "$ACTION" == "reboot" || "$ACTION" == "shutdown" || "$ACTION" == "relaunch" ]]; then
    # Gracefully close Brave before continuing
    if pgrep -i "brave" &>/dev/null; then
        pkill -TERM -i "brave"
        # Wait for Brave to close
        while pgrep -i "brave" &>/dev/null; do
            sleep 0.1
        done
    fi
fi

# Perform the action
case "$ACTION" in
  reboot)
    systemctl reboot
    ;;
  shutdown)
    bash ~/.local/bin/evo-cleanup.sh
    systemctl poweroff
    ;;
  relaunch)
    hyprctl dispatch exit
    ;;
  *)
    hyprctl dispatch exit
    ;;
esac
