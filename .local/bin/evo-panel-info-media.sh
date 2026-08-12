#!/bin/bash
# Evo panel: MPRIS now-playing info (no playerctl dependency).
#
# Usage:
#   evo-panel-info-media.sh          — JSON metadata
#   evo-panel-info-media.sh toggle    — play/pause active player

set -euo pipefail

MPRIS_IFACE="org.mpris.MediaPlayer2"
PLAYER_IFACE="org.mpris.MediaPlayer2.Player"
OBJ_PATH="/org/mpris/MediaPlayer2"

json_out() {
    jq -cn \
        --argjson ok "${1:-false}" \
        --argjson playing "${2:-false}" \
        --arg status "${3:-}" \
        --arg title "${4:-}" \
        --arg artist "${5:-}" \
        --arg album "${6:-}" \
        --arg artUrl "${7:-}" \
        --argjson position "${8:-0}" \
        --argjson length "${9:-0}" \
        --arg player "${10:-}" \
        '{
            ok: $ok,
            playing: $playing,
            status: $status,
            title: $title,
            artist: $artist,
            album: $album,
            artUrl: $artUrl,
            position: $position,
            length: $length,
            player: $player
        }'
}

list_players() {
    busctl --user list --no-legend 2>/dev/null \
        | awk '/^org\.mpris\.MediaPlayer2\./ { print $1 }'
}

player_status() {
    local svc="$1"
    busctl --user --json=short call "$svc" "$OBJ_PATH" org.freedesktop.DBus.Properties Get ss \
        "$PLAYER_IFACE" PlaybackStatus 2>/dev/null \
        | jq -r '.data[0].data // ""' 2>/dev/null || true
}

pick_player() {
    local svc status
    local fallback=""

    while IFS= read -r svc; do
        [[ -z "$svc" ]] && continue
        status="$(player_status "$svc")"
        if [[ "$status" == "Playing" ]]; then
            printf '%s\n' "$svc"
            return 0
        fi
        [[ -z "$fallback" ]] && fallback="$svc"
    done < <(list_players)

    [[ -n "$fallback" ]] && printf '%s\n' "$fallback"
}

get_prop() {
    local svc="$1" prop="$2"
    busctl --user --json=short call "$svc" "$OBJ_PATH" org.freedesktop.DBus.Properties Get ss \
        "$PLAYER_IFACE" "$prop" 2>/dev/null || true
}

toggle_player() {
    local svc
    svc="$(pick_player || true)"
    if [[ -z "$svc" ]]; then
        exit 1
    fi
    busctl --user call "$svc" "$OBJ_PATH" "$PLAYER_IFACE" PlayPause >/dev/null 2>&1 || exit 1
}

read_metadata() {
    local svc="$1"
    local meta status pos_raw length_raw title artist album artUrl position length playing

    meta="$(get_prop "$svc" Metadata)"
    status="$(player_status "$svc")"
    pos_raw="$(get_prop "$svc" Position)"
    position="$(echo "$pos_raw" | jq -r '.data[0].data // 0' 2>/dev/null || echo 0)"

    title="$(echo "$meta" | jq -r '.data[0].data["xesam:title"].data // ""' 2>/dev/null || true)"
    artist="$(echo "$meta" | jq -r '.data[0].data["xesam:artist"].data[0] // ""' 2>/dev/null || true)"
    album="$(echo "$meta" | jq -r '.data[0].data["xesam:album"].data // ""' 2>/dev/null || true)"
    artUrl="$(echo "$meta" | jq -r '.data[0].data["mpris:artUrl"].data // .data[0].data["xesam:artUrl"].data // ""' 2>/dev/null || true)"
    length_raw="$(echo "$meta" | jq -r '.data[0].data["mpris:length"].data // 0' 2>/dev/null || echo 0)"

    length="${length_raw:-0}"
    position="${position:-0}"
    playing="false"
    [[ "$status" == "Playing" ]] && playing="true"

    json_out true "$playing" "$status" "$title" "$artist" "$album" "$artUrl" "$position" "$length" "$svc"
}

if [[ "${1:-}" == "toggle" ]]; then
    toggle_player
    exit 0
fi

svc="$(pick_player || true)"
if [[ -z "$svc" ]]; then
    json_out false false "" "" "" "" "" 0 0 ""
    exit 0
fi

read_metadata "$svc"
