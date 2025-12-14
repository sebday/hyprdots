#!/bin/bash

if [[ "$1" != "on" && "$1" != "off" ]]; then
    echo "Usage: $0 [on|off]"
    exit 1
fi

hyprctl dispatch dpms $1 HDMI-A-1
hyprctl dispatch dpms $1 HDMI-A-2
hyprctl dispatch dpms $1 DP-1
hyprctl dispatch dpms $1 DP-2

if [ "$1" == "on" ]; then
    brightnessctl -r
fi

