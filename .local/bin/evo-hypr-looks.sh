#!/usr/bin/env bash
# Toggle Hyprland rounding and gaps for evo-shell panel.

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/evo-shell"
STATE_FILE="${STATE_DIR}/hypr-looks-overrides.lua"

ROUNDING_ON=7
GAPS_IN_ON=10
GAPS_OUT_ON=20

mkdir -p "$STATE_DIR"

read_bools() {
    python3 - "$STATE_FILE" <<'PY'
import json
import re
import subprocess
import sys

path = sys.argv[1]

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

def hypr_gap_out() -> int:
    try:
        raw = subprocess.check_output(["hyprctl", "getoption", "general:gaps_out", "-j"], text=True)
        data = json.loads(raw)
        if "int" in data:
            return int(data["int"])
        css = str(data.get("css", "")).strip()
        if css:
            return int(css.split()[0])
    except (subprocess.CalledProcessError, json.JSONDecodeError, ValueError, TypeError, IndexError):
        pass
    return 0

state = {
    "roundingOn": hypr_int("decoration:rounding") == 7,
    "gapsOn": hypr_int("general:gaps_in") == 10 and hypr_gap_out() == 20,
}
try:
    with open(path, encoding="utf-8") as f:
        text = f.read()
    m_round = re.search(r"roundingOn\s*=\s*(true|false)", text)
    m_gaps = re.search(r"gapsOn\s*=\s*(true|false)", text)
    if m_round:
        state["roundingOn"] = m_round.group(1) == "true"
    if m_gaps:
        state["gapsOn"] = m_gaps.group(1) == "true"
except FileNotFoundError:
    pass

print(json.dumps(state))
PY
}

write_state() {
    local rounding_on="$1"
    local gaps_on="$2"
    cat >"$STATE_FILE" <<EOF
return {
    roundingOn = ${rounding_on},
    gapsOn = ${gaps_on},
}
EOF
}

apply_live() {
    local rounding_on="$1"
    local gaps_on="$2"
    local rounding=0
    local gaps_in=0
    local gaps_out=0
    if [[ "$rounding_on" == "true" ]]; then
        rounding=$ROUNDING_ON
    fi
    if [[ "$gaps_on" == "true" ]]; then
        gaps_in=$GAPS_IN_ON
        gaps_out=$GAPS_OUT_ON
    fi
    hyprctl eval "hl.config({ decoration = { rounding = ${rounding} }, general = { gaps_in = ${gaps_in}, gaps_out = ${gaps_out} } })" >/dev/null
}

bool_to_lua() {
    [[ "$1" == "true" ]] && echo "true" || echo "false"
}

case "${1:-}" in
get)
    read_bools
    ;;
toggle)
    key="${2:-}"
    [[ "$key" =~ ^(rounding|gaps)$ ]] || {
        echo "unknown key: $key" >&2
        exit 1
    }
    current="$(read_bools)"
    rounding_on="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print('true' if d['roundingOn'] else 'false')" "$current")"
    gaps_on="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print('true' if d['gapsOn'] else 'false')" "$current")"
    if [[ "$key" == "rounding" ]]; then
        if [[ "$rounding_on" == "true" ]]; then rounding_on="false"; else rounding_on="true"; fi
    else
        if [[ "$gaps_on" == "true" ]]; then gaps_on="false"; else gaps_on="true"; fi
    fi
    write_state "$(bool_to_lua "$rounding_on")" "$(bool_to_lua "$gaps_on")"
    apply_live "$rounding_on" "$gaps_on"
    read_bools
    ;;
*)
    echo "usage: evo-hypr-looks.sh get|toggle <rounding|gaps>" >&2
    exit 1
    ;;
esac
