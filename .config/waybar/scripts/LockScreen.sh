#!/bin/bash
IDLE_TIMEOUT=900000  # 15 minutes in milliseconds
while true; do
    IDLE_TIME=$(hyprctl -j activewindow | jq '.at[0] | .idle')
    if [ "$IDLE_TIME" -ge "$IDLE_TIMEOUT" ]; then
        gtklock --monitor-priority DP-2
    fi
    sleep 60
done
