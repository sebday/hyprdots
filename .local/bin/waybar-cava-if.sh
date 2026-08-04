#!/bin/bash
# Exit 0 when PipeWire/Pulse has an active playback stream (waybar exec-if).

pactl list sink-inputs 2>/dev/null | grep -qE '^[[:space:]]+state: RUNNING$'
