#!/usr/bin/env bash
# Toggle evo panel dock side between left and right.

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
on = panel.get("side", "left") == "right"
print(json.dumps({"panelOnRight": on}))
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
    on="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print('true' if d['panelOnRight'] else 'false')" "$current")"
    if [[ "$on" == "true" ]]; then
        write_side false
    else
        write_side true
    fi
    "$SHELL_IPC" shell reloadConfig >/dev/null
    read_state
    ;;
*)
    echo "usage: evo-panel-layout.sh get|toggle" >&2
    exit 1
    ;;
esac
