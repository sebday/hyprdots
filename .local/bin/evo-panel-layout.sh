#!/usr/bin/env bash
# Panel layout helpers: side (left/right) and pin (exclusive zone).

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

panel = data.get("panel", {})
print(json.dumps({
    "panelOnRight": panel.get("side", "left") == "right",
    "panelPinned": panel.get("pinned", False) is True,
}))
PY
}

write_panel() {
    local on_right="$1"
    local pinned="$2"
    local reload="${3:-false}"
    python3 - "$SHELL_JSON" "$on_right" "$pinned" <<'PY'
import json
import sys

path, on_right, pinned = sys.argv[1], sys.argv[2] == "true", sys.argv[3] == "true"
with open(path, encoding="utf-8") as f:
    data = json.load(f)

panel = data.setdefault("panel", {})
panel["side"] = "right" if on_right else "left"
panel["pinned"] = pinned

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
    if [[ "$reload" == "true" ]]; then
        "$SHELL_IPC" shell reloadConfig >/dev/null
    fi
}

case "${1:-}" in
get)
    read_state
    ;;
toggle | toggle-side)
    current="$(read_state)"
    on="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print('true' if d['panelOnRight'] else 'false')" "$current")"
    pinned="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print('true' if d['panelPinned'] else 'false')" "$current")"
    if [[ "$on" == "true" ]]; then
        write_panel false "$pinned" true
    else
        write_panel true "$pinned" true
    fi
    read_state
    ;;
toggle-pin)
    current="$(read_state)"
    on="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print('true' if d['panelOnRight'] else 'false')" "$current")"
    pinned="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print('true' if d['panelPinned'] else 'false')" "$current")"
    if [[ "$pinned" == "true" ]]; then
        write_panel "$on" false false
    else
        write_panel "$on" true false
    fi
    read_state
    ;;
*)
    echo "usage: evo-panel-layout.sh get|toggle|toggle-pin" >&2
    exit 1
    ;;
esac
