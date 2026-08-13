#!/usr/bin/env bash
# Hyprland looks toggles + window/panel opacity for evo-shell settings.

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/evo-shell"
STATE_FILE="${STATE_DIR}/hypr-looks-overrides.lua"
STATE_JSON="${STATE_DIR}/hypr-looks.json"

ROUNDING_ON=7
GAPS_IN_ON=10
GAPS_OUT_ON=20
DEFAULT_ACTIVE_OPACITY=0.97
DEFAULT_INACTIVE_OPACITY=0.88

mkdir -p "$STATE_DIR"

hypr_option() {
    local option="$1" kind="$2" default="$3"
    local raw val
    raw=$(hyprctl getoption "$option" -j 2>/dev/null) || {
        printf '%s' "$default"
        return
    }
    case "$kind" in
    int)
        val=$(jq -r 'if .int != null then .int elif (.css // "") != "" then (.css | split(" ")[0]) else empty end' <<<"$raw" 2>/dev/null)
        ;;
    float)
        val=$(jq -r 'if .float != null then .float elif .int != null then .int elif (.css // "") != "" then (.css | split(" ")[0]) else empty end' <<<"$raw" 2>/dev/null)
        ;;
    bool)
        val=$(jq -r 'if .bool != null then .bool elif .int != null then (.int != 0) else false end' <<<"$raw" 2>/dev/null)
        ;;
    esac
    [[ -n "${val:-}" ]] || val="$default"
    printf '%s' "$val"
}

lua_bool() {
    grep -E "^[[:space:]]*${1}[[:space:]]*=" "$STATE_FILE" 2>/dev/null \
        | head -1 \
        | sed -E 's/.*=[[:space:]]*(true|false).*/\1/' || true
}

lua_float() {
    grep -E "^[[:space:]]*${1}[[:space:]]*=" "$STATE_FILE" 2>/dev/null \
        | head -1 \
        | sed -E 's/.*=[[:space:]]*([0-9.]+).*/\1/' || true
}

read_state() {
    local rounding gaps_in gaps_out rounding_on gaps_on animations_on
    local active_opacity inactive_opacity lua_round lua_gaps lua_anim lua_active lua_inactive

    rounding=$(hypr_option decoration:rounding int 0)
    gaps_in=$(hypr_option general:gaps_in int 0)
    gaps_out=$(hypr_option general:gaps_out int 0)
    rounding_on=$([[ "$rounding" -eq "$ROUNDING_ON" ]] && echo true || echo false)
    gaps_on=$([[ "$gaps_in" -eq "$GAPS_IN_ON" && "$gaps_out" -eq "$GAPS_OUT_ON" ]] && echo true || echo false)
    animations_on=$(hypr_option animations:enabled bool false)
    active_opacity=$(hypr_option decoration:active_opacity float "$DEFAULT_ACTIVE_OPACITY")
    inactive_opacity=$(hypr_option decoration:inactive_opacity float "$DEFAULT_INACTIVE_OPACITY")

    if [[ -f "$STATE_FILE" ]]; then
        lua_round=$(lua_bool roundingOn)
        lua_gaps=$(lua_bool gapsOn)
        lua_anim=$(lua_bool animationsOn)
        lua_active=$(lua_float activeOpacity)
        lua_inactive=$(lua_float inactiveOpacity)
        [[ -n "$lua_round" ]] && rounding_on=$lua_round
        [[ -n "$lua_gaps" ]] && gaps_on=$lua_gaps
        [[ -n "$lua_anim" ]] && animations_on=$lua_anim
        [[ -n "$lua_active" ]] && active_opacity=$lua_active
        [[ -n "$lua_inactive" ]] && inactive_opacity=$lua_inactive
    fi

    jq -n \
        --argjson roundingOn "$([[ "$rounding_on" == true ]] && echo true || echo false)" \
        --argjson gapsOn "$([[ "$gaps_on" == true ]] && echo true || echo false)" \
        --argjson animationsOn "$([[ "$animations_on" == true ]] && echo true || echo false)" \
        --arg activeOpacity "$active_opacity" \
        --arg inactiveOpacity "$inactive_opacity" \
        '{
            roundingOn: $roundingOn,
            gapsOn: $gapsOn,
            animationsOn: $animationsOn,
            activeOpacity: ($activeOpacity | tonumber),
            inactiveOpacity: ($inactiveOpacity | tonumber)
        }'
}

write_state() {
    local rounding_on="$1"
    local gaps_on="$2"
    local animations_on="$3"
    local active_opacity="$4"
    local inactive_opacity="$5"
    cat >"$STATE_FILE" <<EOF
return {
    roundingOn = ${rounding_on},
    gapsOn = ${gaps_on},
    animationsOn = ${animations_on},
    activeOpacity = ${active_opacity},
    inactiveOpacity = ${inactive_opacity},
}
EOF
    jq -n \
        --argjson roundingOn "$([[ "$rounding_on" == true ]] && echo true || echo false)" \
        --argjson gapsOn "$([[ "$gaps_on" == true ]] && echo true || echo false)" \
        --argjson animationsOn "$([[ "$animations_on" == true ]] && echo true || echo false)" \
        --arg activeOpacity "$active_opacity" \
        --arg inactiveOpacity "$inactive_opacity" \
        '{
            roundingOn: $roundingOn,
            gapsOn: $gapsOn,
            animationsOn: $animationsOn,
            activeOpacity: ($activeOpacity | tonumber),
            inactiveOpacity: ($inactiveOpacity | tonumber)
        }' >"$STATE_JSON"
}

apply_live() {
    local rounding_on="$1"
    local gaps_on="$2"
    local animations_on="$3"
    local active_opacity="$4"
    local inactive_opacity="$5"
    local rounding=0
    local gaps_in=0
    local gaps_out=0
    local animations=false
    if [[ "$rounding_on" == "true" ]]; then
        rounding=$ROUNDING_ON
    fi
    if [[ "$gaps_on" == "true" ]]; then
        gaps_in=$GAPS_IN_ON
        gaps_out=$GAPS_OUT_ON
    fi
    if [[ "$animations_on" == "true" ]]; then
        animations=true
    fi
    hyprctl eval "hl.config({ decoration = { rounding = ${rounding}, active_opacity = ${active_opacity}, inactive_opacity = ${inactive_opacity} }, general = { gaps_in = ${gaps_in}, gaps_out = ${gaps_out} }, animations = { enabled = ${animations} } })" >/dev/null
}

bool_to_lua() {
    [[ "$1" == "true" ]] && echo "true" || echo "false"
}

bool_from_json() {
    jq -r --arg k "$1" 'if .[$k] then "true" else "false" end' <<<"$2"
}

percent_to_opacity() {
    awk -v p="$1" 'BEGIN { printf "%.2f", p / 100 }'
}

case "${1:-}" in
get)
    read_state
    ;;
set)
    key="${2:-}"
    value="${3:-}"
    [[ "$key" =~ ^(active|inactive)$ ]] || {
        echo "unknown key: $key" >&2
        exit 1
    }
    [[ "$value" =~ ^[0-9]+$ ]] || {
        echo "value must be an integer percent" >&2
        exit 1
    }
    (( value >= 0 && value <= 100 )) || {
        echo "value must be between 0 and 100" >&2
        exit 1
    }
    current="$(read_state)"
    rounding_on="$(bool_from_json roundingOn "$current")"
    gaps_on="$(bool_from_json gapsOn "$current")"
    animations_on="$(bool_from_json animationsOn "$current")"
    active_opacity="$(jq -r '.activeOpacity' <<<"$current")"
    inactive_opacity="$(jq -r '.inactiveOpacity' <<<"$current")"
    if [[ "$key" == "active" ]]; then
        active_opacity="$(percent_to_opacity "$value")"
    else
        inactive_opacity="$(percent_to_opacity "$value")"
    fi
    write_state "$(bool_to_lua "$rounding_on")" "$(bool_to_lua "$gaps_on")" "$(bool_to_lua "$animations_on")" "$active_opacity" "$inactive_opacity"
    apply_live "$rounding_on" "$gaps_on" "$animations_on" "$active_opacity" "$inactive_opacity"
    read_state
    ;;
toggle)
    key="${2:-}"
    [[ "$key" =~ ^(rounding|gaps|animations)$ ]] || {
        echo "unknown key: $key" >&2
        exit 1
    }
    current="$(read_state)"
    rounding_on="$(bool_from_json roundingOn "$current")"
    gaps_on="$(bool_from_json gapsOn "$current")"
    animations_on="$(bool_from_json animationsOn "$current")"
    active_opacity="$(jq -r '.activeOpacity' <<<"$current")"
    inactive_opacity="$(jq -r '.inactiveOpacity' <<<"$current")"
    case "$key" in
    rounding)
        if [[ "$rounding_on" == "true" ]]; then rounding_on="false"; else rounding_on="true"; fi
        ;;
    gaps)
        if [[ "$gaps_on" == "true" ]]; then gaps_on="false"; else gaps_on="true"; fi
        ;;
    animations)
        if [[ "$animations_on" == "true" ]]; then animations_on="false"; else animations_on="true"; fi
        ;;
    esac
    write_state "$(bool_to_lua "$rounding_on")" "$(bool_to_lua "$gaps_on")" "$(bool_to_lua "$animations_on")" "$active_opacity" "$inactive_opacity"
    apply_live "$rounding_on" "$gaps_on" "$animations_on" "$active_opacity" "$inactive_opacity"
    read_state
    ;;
reset)
    write_state "false" "false" "false" "$DEFAULT_ACTIVE_OPACITY" "$DEFAULT_INACTIVE_OPACITY"
    apply_live "false" "false" "false" "$DEFAULT_ACTIVE_OPACITY" "$DEFAULT_INACTIVE_OPACITY"
    read_state
    ;;
*)
    echo "usage: evo-hypr-looks.sh get|reset|toggle <rounding|gaps|animations>|set <active|inactive> <0-100>" >&2
    exit 1
    ;;
esac
