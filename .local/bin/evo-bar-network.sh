#!/usr/bin/env bash
# Evo bar: ethernet network indicator.

set -euo pipefail

source "${HOME}/.local/bin/evo-bar-common.sh"
source "${HOME}/.local/bin/evo-network-lib.sh"

SCRIPT="${HOME}/.local/bin/evo-network.sh"

if cached=$(evo_bar_cache_read "network-bar-v4" 5 2>/dev/null); then
    printf '%s\n' "$cached"
    exit 0
fi

line=$("$SCRIPT" status 2>/dev/null || printf 'disconnected\t\t\n')
kind="${line%%$'\t'*}"
rest="${line#*$'\t'}"
iface="${rest%%$'\t'*}"
speed="${rest#*$'\t'}"

icon=$(connection_icon "$kind")
tooltip="No connection"
text="$icon off"

if [[ "$kind" == "ethernet" && -n "$iface" ]]; then
    text="$icon net"
    ip=$(ip -j route get "${INTERNET_PROBE:-1.1.1.1}" 2>/dev/null | jq -r '.[0].prefsrc // ""' 2>/dev/null || true)
    tooltip="$iface"
    [[ -n "$ip" ]] && tooltip+=$'\n'"$ip"
    if [[ -n "$speed" && "$speed" =~ ^[0-9]+$ && "$speed" -gt 0 ]]; then
        link=$(format_link_speed "$speed" || true)
        [[ -n "$link" ]] && tooltip+=$'\n'"$link"
    fi
fi

out=$(jq -cn --arg text "$text" --arg tooltip "$tooltip" '{text: $text, tooltip: $tooltip}')
evo_bar_cache_write "network-bar-v4" "$out" 2>/dev/null || true
printf '%s\n' "$out"
