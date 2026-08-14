#!/usr/bin/env bash
# Evo bar: ethernet network indicator.

set -euo pipefail

source "${HOME}/.local/bin/evo-bar-common.sh"
source "${HOME}/.local/bin/evo-network-lib.sh"

SCRIPT="${HOME}/.local/bin/evo-network.sh"
SAMPLE_SECS=1

line=$("$SCRIPT" status 2>/dev/null || printf 'disconnected\t\t\n')
kind="${line%%$'\t'*}"
rest="${line#*$'\t'}"
iface="${rest%%$'\t'*}"
speed="${rest#*$'\t'}"

icon=$(connection_icon "$kind")
tooltip="No connection"
label="off"
connected=false
download_bps=0
upload_bps=0

if [[ "$kind" == "ethernet" && -n "$iface" ]]; then
    connected=true
    label="net"
    ip=$(ip -j route get "${INTERNET_PROBE:-1.1.1.1}" 2>/dev/null | jq -r '.[0].prefsrc // ""' 2>/dev/null || true)
    tooltip="$iface"
    [[ -n "$ip" ]] && tooltip+=$'\n'"$ip"
    if [[ -n "$speed" && "$speed" =~ ^[0-9]+$ && "$speed" -gt 0 ]]; then
        link=$(format_link_speed "$speed" || true)
        [[ -n "$link" ]] && tooltip+=$'\n'"$link"
    fi
    IFS=$'\t' read -r download_bps upload_bps <<<"$(sample_iface_rates "$iface" "$SAMPLE_SECS")"
fi

out=$(jq -cn \
    --arg icon "$icon" \
    --arg label "$label" \
    --arg tooltip "$tooltip" \
    --argjson connected "$connected" \
    --argjson download_bps "${download_bps:-0}" \
    --argjson upload_bps "${upload_bps:-0}" \
    '{
        icon: $icon,
        label: $label,
        tooltip: $tooltip,
        connected: $connected,
        download_bps: $download_bps,
        upload_bps: $upload_bps
    }')
printf '%s\n' "$out"
