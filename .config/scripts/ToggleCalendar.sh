#!/bin/bash

CALENDAR_APP_ID="current-cal"

LAUNCH_SPEC="[floating; silent; size 880 275] foot --app-id=\"$CALENDAR_APP_ID\" --font=\"monospace:size=14\" -e bash /home/seb/.config/waybar/scripts/ShowCalendar.sh"

if hyprctl -j clients | jq -e '.[] | select(.class == "'"$CALENDAR_APP_ID"'")' > /dev/null; then
    hyprctl dispatch closewindow class:"^(${CALENDAR_APP_ID})$"
else
    hyprctl dispatch exec "$LAUNCH_SPEC"
fi