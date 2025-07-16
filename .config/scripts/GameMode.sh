#!/bin/bash

# Get all workspace IDs except special:magic
workspaces=$(hyprctl workspaces -j | jq -r '.[] | select(.id != "special:magic") | .id')

# Iterate through workspaces and move to special:magic
for workspace in $workspaces; do
    hyprctl dispatch workspace "$workspace"
    hyprctl dispatch movetoworkspacesilent special:magic
done
