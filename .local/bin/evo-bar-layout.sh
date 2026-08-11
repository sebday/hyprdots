#!/usr/bin/env bash
# Toggle evo bar between HDMI-A-1 bottom and DP-1 top.

set -euo pipefail

SHELL_JSON="${HOME}/.config/quickshell/evo-shell/shell.json"
SHELL_IPC="${HOME}/.local/bin/evo-shell-ipc"

read_state() {
    python3 - "$SHELL_JSON" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)

bar = data.get("bar", {})
on = bar.get("output") == "DP-1" and bar.get("position") == "top"
print(json.dumps({"barOnDp1Top": on}))
PY
}

write_layout() {
    local on_dp1_top="$1"
    python3 - "$SHELL_JSON" "$on_dp1_top" <<'PY'
import json
import sys

path, on_dp1_top = sys.argv[1], sys.argv[2] == "true"
with open(path, encoding="utf-8") as f:
    data = json.load(f)

bar = data.setdefault("bar", {})
if on_dp1_top:
    bar["output"] = "DP-1"
    bar["position"] = "top"
else:
    bar["output"] = "HDMI-A-1"
    bar["position"] = "bottom"

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
}

case "${1:-}" in
get)
    read_state
    ;;
toggle)
    current="$(read_state)"
    on="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print('true' if d['barOnDp1Top'] else 'false')" "$current")"
    if [[ "$on" == "true" ]]; then
        write_layout false
    else
        write_layout true
    fi
    "$SHELL_IPC" shell reloadConfig >/dev/null
    read_state
    ;;
*)
    echo "usage: evo-bar-layout.sh get|toggle" >&2
    exit 1
    ;;
esac
