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

read_state() {
    python3 - "$STATE_FILE" "$DEFAULT_ACTIVE_OPACITY" "$DEFAULT_INACTIVE_OPACITY" <<'PY'
import json
import re
import subprocess
import sys

path, default_active, default_inactive = sys.argv[1:4]
default_active = float(default_active)
default_inactive = float(default_inactive)

def hypr_int(option: str, default: int = 0) -> int:
    try:
        raw = subprocess.check_output(["hyprctl", "getoption", option, "-j"], text=True)
        data = json.loads(raw)
        if "int" in data:
            return int(data["int"])
        css = str(data.get("css", "")).strip()
        if css:
            return int(css.split()[0])
    except (subprocess.CalledProcessError, json.JSONDecodeError, ValueError, TypeError, IndexError):
        pass
    return default

def hypr_bool(option: str, default: bool = False) -> bool:
    try:
        raw = subprocess.check_output(["hyprctl", "getoption", option, "-j"], text=True)
        data = json.loads(raw)
        if "bool" in data:
            return bool(data["bool"])
        if "int" in data:
            return int(data["int"]) != 0
    except (subprocess.CalledProcessError, json.JSONDecodeError, ValueError, TypeError):
        pass
    return default

def hypr_float(option: str, default: float) -> float:
    try:
        raw = subprocess.check_output(["hyprctl", "getoption", option, "-j"], text=True)
        data = json.loads(raw)
        if "float" in data:
            return float(data["float"])
        if "int" in data:
            return float(data["int"])
        css = str(data.get("css", "")).strip()
        if css:
            return float(css.split()[0])
    except (subprocess.CalledProcessError, json.JSONDecodeError, ValueError, TypeError, IndexError):
        pass
    return default

def hypr_gap_out() -> int:
    return hypr_int("general:gaps_out", 0)

state = {
    "roundingOn": hypr_int("decoration:rounding") == 7,
    "gapsOn": hypr_int("general:gaps_in") == 10 and hypr_gap_out() == 20,
    "animationsOn": hypr_bool("animations:enabled", False),
    "activeOpacity": round(hypr_float("decoration:active_opacity", default_active), 2),
    "inactiveOpacity": round(hypr_float("decoration:inactive_opacity", default_inactive), 2),
}
try:
    with open(path, encoding="utf-8") as f:
        text = f.read()
    m_round = re.search(r"roundingOn\s*=\s*(true|false)", text)
    m_gaps = re.search(r"gapsOn\s*=\s*(true|false)", text)
    m_anim = re.search(r"animationsOn\s*=\s*(true|false)", text)
    m_active = re.search(r"activeOpacity\s*=\s*([0-9.]+)", text)
    m_inactive = re.search(r"inactiveOpacity\s*=\s*([0-9.]+)", text)
    if m_round:
        state["roundingOn"] = m_round.group(1) == "true"
    if m_gaps:
        state["gapsOn"] = m_gaps.group(1) == "true"
    if m_anim:
        state["animationsOn"] = m_anim.group(1) == "true"
    if m_active:
        state["activeOpacity"] = round(float(m_active.group(1)), 2)
    if m_inactive:
        state["inactiveOpacity"] = round(float(m_inactive.group(1)), 2)
except FileNotFoundError:
    pass

print(json.dumps(state))
PY
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
    python3 - "$STATE_JSON" "$rounding_on" "$gaps_on" "$animations_on" "$active_opacity" "$inactive_opacity" <<'PY'
import json
import sys

path, rounding_on, gaps_on, animations_on, active_opacity, inactive_opacity = sys.argv[1:]
data = {
    "roundingOn": rounding_on == "true",
    "gapsOn": gaps_on == "true",
    "animationsOn": animations_on == "true",
    "activeOpacity": round(float(active_opacity), 2),
    "inactiveOpacity": round(float(inactive_opacity), 2),
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f)
    f.write("\n")
PY
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
    rounding_on="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print('true' if d['roundingOn'] else 'false')" "$current")"
    gaps_on="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print('true' if d['gapsOn'] else 'false')" "$current")"
    animations_on="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print('true' if d.get('animationsOn') else 'false')" "$current")"
    active_opacity="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d['activeOpacity'])" "$current")"
    inactive_opacity="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d['inactiveOpacity'])" "$current")"
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
    rounding_on="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print('true' if d['roundingOn'] else 'false')" "$current")"
    gaps_on="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print('true' if d['gapsOn'] else 'false')" "$current")"
    animations_on="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print('true' if d.get('animationsOn') else 'false')" "$current")"
    active_opacity="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d['activeOpacity'])" "$current")"
    inactive_opacity="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d['inactiveOpacity'])" "$current")"
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
