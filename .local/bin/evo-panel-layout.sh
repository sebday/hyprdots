#!/usr/bin/env bash
# Panel layout helpers: side (left/right).

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
}))
PY
}

write_side() {
    local on_right="$1"
    python3 - "$SHELL_JSON" "$on_right" <<'PY'
import json
import sys

path, on_right = sys.argv[1], sys.argv[2] == "true"
with open(path, encoding="utf-8") as f:
    data = json.load(f)

panel = data.setdefault("panel", {})
panel["side"] = "right" if on_right else "left"
panel.pop("pinned", None)

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
    "$SHELL_IPC" shell reloadConfig >/dev/null
}

case "${1:-}" in
get)
    read_state
    ;;
toggle | toggle-side)
    current="$(read_state)"
    on="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print('true' if d['panelOnRight'] else 'false')" "$current")"
    if [[ "$on" == "true" ]]; then
        write_side false
    else
        write_side true
    fi
    read_state
    ;;
*)
    echo "usage: evo-panel-layout.sh get|toggle" >&2
    exit 1
    ;;
esac
