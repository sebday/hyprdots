#!/bin/bash
# Toggle waybar between HDMI-A-1 bottom and DP-1 top

CONFIG="$HOME/.config/waybar/config.jsonc"

output=$(jq -r '.output' "$CONFIG")
position=$(jq -r '.position' "$CONFIG")

if [[ "$output" == "HDMI-A-1" && "$position" == "bottom" ]]; then
    jq '.output = "DP-1" | .position = "top"' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
    notify-send "Waybar" "Moved to DP-1 (top)"
else
    jq '.output = "HDMI-A-1" | .position = "bottom"' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
    notify-send "Waybar" "Moved to HDMI-A-1 (bottom)"
fi

pkill waybar 2>/dev/null
waybar &
