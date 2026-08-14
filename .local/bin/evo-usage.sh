#!/usr/bin/env bash
# Persist launch/pick counts for frecency sorting in evoshell menus.

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/evoshell"
STATE_FILE="${STATE_DIR}/usage.json"

usage_load() {
    if [[ -f "$STATE_FILE" ]]; then
        jq -c '.apps // {} | {apps: .}' "$STATE_FILE" 2>/dev/null || echo '{"apps":{}}'
    else
        echo '{"apps":{}}'
    fi
}

usage_bump() {
    local bucket="$1" key="$2"
    local tmp data
    [[ "$bucket" == "apps" && -n "$key" ]] || exit 1
    mkdir -p "$STATE_DIR"
    data="$(usage_load)"
    tmp="$(mktemp)"
    jq -c --arg k "$key" '.apps[$k] = ((.apps[$k] // 0) + 1)' <<<"$data" >"$tmp"
    mv "$tmp" "$STATE_FILE"
}

case "${1:-}" in
bump)
    [[ -n "${2:-}" && -n "${3:-}" ]] || exit 1
    usage_bump "$2" "$3"
    ;;
dump)
    usage_load
    ;;
*)
    echo "usage: evo-usage.sh bump apps <key>|dump" >&2
    exit 1
    ;;
esac
