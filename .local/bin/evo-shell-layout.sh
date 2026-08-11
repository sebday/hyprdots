#!/usr/bin/env bash
# Shared layout helpers for evo-shell bar and panel.

set -euo pipefail

SHELL_JSON="${HOME}/.config/quickshell/evo-shell/shell.json"
SHELL_IPC="${HOME}/.local/bin/evo-shell-ipc"

read_bar_state() {
    python3 - "$SHELL_JSON" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)

bar = data.get("bar", {})
print(json.dumps({"barOnDp1Top": bar.get("output") == "DP-1" and bar.get("position") == "top"}))
PY
}

write_bar_layout() {
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

read_panel_state() {
    python3 - "$SHELL_JSON" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)

panel = data.get("panel", {})
print(json.dumps({"panelOnRight": panel.get("side", "left") == "right"}))
PY
}

write_panel_side() {
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
}

reload_shell_config() {
    "$SHELL_IPC" shell reloadConfig >/dev/null
}

usage() {
    cat >&2 <<'EOF'
usage:
  evo-shell-layout.sh bar get|toggle
  evo-shell-layout.sh panel get|toggle
EOF
    exit 1
}

target="${1:-}"
action="${2:-}"

case "$target" in
bar)
    case "$action" in
    get)
        read_bar_state
        ;;
    toggle)
        current="$(read_bar_state)"
        on="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print('true' if d['barOnDp1Top'] else 'false')" "$current")"
        if [[ "$on" == "true" ]]; then
            write_bar_layout false
        else
            write_bar_layout true
        fi
        reload_shell_config
        read_bar_state
        ;;
    *)
        usage
        ;;
    esac
    ;;
panel)
    case "$action" in
    get)
        read_panel_state
        ;;
    toggle | toggle-side)
        current="$(read_panel_state)"
        on="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print('true' if d['panelOnRight'] else 'false')" "$current")"
        if [[ "$on" == "true" ]]; then
            write_panel_side false
        else
            write_panel_side true
        fi
        reload_shell_config
        read_panel_state
        ;;
    *)
        usage
        ;;
    esac
    ;;
*)
    usage
    ;;
esac
