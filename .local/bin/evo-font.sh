#!/usr/bin/env bash
# Global UI/editor font for evo panel settings.
# Applies to GTK, evo-shell theme.json, Ghostty (editor size), and Cursor/VS Code.

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/evo-shell"
STATE_FILE="${STATE_DIR}/font.json"
THEME_JSON="${HOME}/.config/quickshell/evo-shell/theme.json"
GHOSTTY_CONF="${HOME}/.config/ghostty/config"

DEFAULT_FAMILY="CaskaydiaMono Nerd Font"
DEFAULT_UI_SIZE=13
DEFAULT_EDITOR_SIZE=18

mkdir -p "$STATE_DIR"

read_state() {
    python3 - "$STATE_FILE" <<'PY'
import json
import os
import re
import subprocess
import sys

path = sys.argv[1]
defaults = {
    "family": "CaskaydiaMono Nerd Font",
    "uiSize": 13,
    "editorSize": 18,
}

state = dict(defaults)
if os.path.isfile(path):
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict):
            if isinstance(data.get("family"), str) and data["family"].strip():
                state["family"] = data["family"].strip()
            if isinstance(data.get("uiSize"), (int, float)):
                state["uiSize"] = int(data["uiSize"])
            if isinstance(data.get("editorSize"), (int, float)):
                state["editorSize"] = int(data["editorSize"])
    except (OSError, json.JSONDecodeError, TypeError, ValueError):
        pass
else:
    # Bootstrap from live GTK / Cursor when no state yet.
    try:
        raw = subprocess.check_output(
            ["gsettings", "get", "org.gnome.desktop.interface", "font-name"],
            text=True,
        ).strip().strip("'\"")
        m = re.match(r"(.+)\s+(\d+)\s*$", raw)
        if m:
            state["family"] = m.group(1).replace(" Mono", "").strip() or state["family"]
            # Keep Mono variant name if that's what's set
            fam = m.group(1).strip()
            if fam:
                state["family"] = fam
            state["uiSize"] = int(m.group(2))
    except (subprocess.CalledProcessError, FileNotFoundError, ValueError):
        pass

    for settings in (
        os.path.expanduser("~/.config/Cursor/User/settings.json"),
        os.path.expanduser("~/.config/Code/User/settings.json"),
    ):
        if not os.path.isfile(settings):
            continue
        try:
            with open(settings, encoding="utf-8") as f:
                data = json.load(f)
            size = data.get("editor.fontSize")
            if isinstance(size, (int, float)):
                state["editorSize"] = int(size)
            break
        except (OSError, json.JSONDecodeError, TypeError, ValueError):
            pass

print(json.dumps(state))
PY
}

write_state() {
    local family="$1"
    local ui_size="$2"
    local editor_size="$3"
    python3 - "$STATE_FILE" "$family" "$ui_size" "$editor_size" <<'PY'
import json
import sys

path, family, ui_size, editor_size = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
data = {"family": family, "uiSize": ui_size, "editorSize": editor_size}
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print(json.dumps(data))
PY
}

list_families() {
    python3 <<'PY'
import json
import subprocess

out = []
seen = set()
try:
    raw = subprocess.check_output(["fc-list", ":mono", "family"], text=True, stderr=subprocess.DEVNULL)
except (subprocess.CalledProcessError, FileNotFoundError):
    raw = ""

for line in raw.splitlines():
    family = line.split(",", 1)[0].strip()
    if not family or family in seen:
        continue
    # Skip emoji / symbol-only faces that break UI monospace use.
    lower = family.lower()
    if "emoji" in lower or "signwriting" in lower:
        continue
    seen.add(family)
    out.append(family)

out.sort(key=str.casefold)
print(json.dumps({"families": out}))
PY
}

gtk_font_name() {
    local family="$1"
    local size="$2"
    # Prefer Mono face for GTK/terminal if installed.
    if fc-list "$family Mono" family 2>/dev/null | grep -q .; then
        printf '%s Mono %s' "$family" "$size"
    elif [[ "$family" == *Mono ]]; then
        printf '%s %s' "$family" "$size"
    elif fc-list "${family} Mono" family 2>/dev/null | grep -q .; then
        printf '%s Mono %s' "$family" "$size"
    else
        printf '%s %s' "$family" "$size"
    fi
}

apply_gtk() {
    local family="$1"
    local size="$2"
    local font_name
    font_name=$(gtk_font_name "$family" "$size")

    for ini in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
        mkdir -p "$(dirname "$ini")"
        if [[ -f "$ini" ]]; then
            if grep -q '^gtk-font-name=' "$ini"; then
                sed -i "s/^gtk-font-name=.*/gtk-font-name=${font_name}/" "$ini"
            else
                printf '\ngtk-font-name=%s\n' "$font_name" >>"$ini"
            fi
        else
            printf '[Settings]\ngtk-font-name=%s\n' "$font_name" >"$ini"
        fi
    done

    gsettings set org.gnome.desktop.interface font-name "$font_name" 2>/dev/null || true
}

apply_evo_shell() {
    local family="$1"
    local size="$2"
    python3 - "$THEME_JSON" "$family" "$size" <<'PY'
import json
import os
import sys

path, family, size = sys.argv[1], sys.argv[2], int(sys.argv[3])
data = {}
if os.path.isfile(path):
    try:
        with open(path, encoding="utf-8") as f:
            loaded = json.load(f)
        if isinstance(loaded, dict):
            data = loaded
    except (OSError, json.JSONDecodeError):
        data = {}

data["fontFamily"] = family
data["fontPixelSize"] = size

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
}

apply_ghostty() {
    local family="$1"
    local size="$2"
    mkdir -p "$(dirname "$GHOSTTY_CONF")"
    python3 - "$GHOSTTY_CONF" "$family" "$size" <<'PY'
import os
import re
import sys

path, family, size = sys.argv[1], sys.argv[2], sys.argv[3]
lines = []
if os.path.isfile(path):
    with open(path, encoding="utf-8") as f:
        lines = f.read().splitlines()

kept = []
for line in lines:
    if re.match(r"^\s*font-family\s*=", line):
        continue
    if re.match(r"^\s*font-size\s*=", line):
        continue
    kept.append(line)

# Drop trailing blank lines, then append font block.
while kept and not kept[-1].strip():
    kept.pop()

if kept and kept[-1].strip():
    kept.append("")
kept.append(f"font-family = {family}")
kept.append(f"font-size = {size}")
kept.append("")

os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
with open(path, "w", encoding="utf-8") as f:
    f.write("\n".join(kept))
PY
}

apply_editors() {
    local family="$1"
    local size="$2"
    python3 - "$family" "$size" <<'PY'
import json
import os
import sys

family, size = sys.argv[1], int(sys.argv[2])
font_family = f"'{family}', 'monospace', monospace"
paths = [
    os.path.expanduser("~/.config/Cursor/User/settings.json"),
    os.path.expanduser("~/.config/Code/User/settings.json"),
    os.path.expanduser("~/.config/VSCodium/User/settings.json"),
]

for path in paths:
    parent = os.path.dirname(path)
    if not os.path.isdir(parent):
        continue
    data = {}
    if os.path.isfile(path):
        try:
            with open(path, encoding="utf-8") as f:
                loaded = json.load(f)
            if isinstance(loaded, dict):
                data = loaded
        except (OSError, json.JSONDecodeError):
            data = {}

    data["editor.fontFamily"] = font_family
    data["editor.fontSize"] = size
    data["editor.inlayHints.fontFamily"] = font_family
    # Keep chat editor slightly smaller than main editor when possible.
    chat = max(10, size - 2)
    data["chat.editor.fontSize"] = chat

    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4)
        f.write("\n")
PY
}

apply_all() {
    local family="$1"
    local ui_size="$2"
    local editor_size="$3"
    apply_gtk "$family" "$ui_size"
    apply_evo_shell "$family" "$ui_size"
    apply_ghostty "$family" "$editor_size"
    apply_editors "$family" "$editor_size"
}

current_or_default() {
    read_state
}

case "${1:-}" in
get)
    current_or_default
    ;;
list)
    list_families
    ;;
apply)
    state="$(read_state)"
    family="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['family'])" "$state")"
    ui_size="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['uiSize'])" "$state")"
    editor_size="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['editorSize'])" "$state")"
    apply_all "$family" "$ui_size" "$editor_size"
    write_state "$family" "$ui_size" "$editor_size" >/dev/null
    read_state
    ;;
set)
    key="${2:-}"
    value="${3:-}"
    state="$(read_state)"
    family="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['family'])" "$state")"
    ui_size="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['uiSize'])" "$state")"
    editor_size="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['editorSize'])" "$state")"
    case "$key" in
    family)
        [[ -n "$value" ]] || { echo "missing family" >&2; exit 1; }
        family="$value"
        ;;
    ui-size | uiSize)
        [[ "$value" =~ ^[0-9]+$ ]] || { echo "ui-size must be int" >&2; exit 1; }
        ui_size="$value"
        ;;
    editor-size | editorSize)
        [[ "$value" =~ ^[0-9]+$ ]] || { echo "editor-size must be int" >&2; exit 1; }
        editor_size="$value"
        ;;
    *)
        echo "unknown key: $key" >&2
        exit 1
        ;;
    esac
    write_state "$family" "$ui_size" "$editor_size" >/dev/null
    apply_all "$family" "$ui_size" "$editor_size"
    read_state
    ;;
cycle-family)
    direction="${2:-next}"
    state="$(read_state)"
    family="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['family'])" "$state")"
    ui_size="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['uiSize'])" "$state")"
    editor_size="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['editorSize'])" "$state")"
    families_json="$(list_families)"
    next="$(python3 - "$families_json" "$family" "$direction" <<'PY'
import json
import sys

families = json.loads(sys.argv[1]).get("families", [])
current = sys.argv[2]
direction = sys.argv[3]
if not families:
    print(current)
    raise SystemExit
try:
    idx = families.index(current)
except ValueError:
    # Prefer closest match (strip trailing Mono).
    base = current.removesuffix(" Mono")
    idx = -1
    for i, name in enumerate(families):
        if name == base or name == current or name.removesuffix(" Mono") == base:
            idx = i
            break
    if idx < 0:
        idx = 0 if direction == "next" else -1
if direction == "prev":
    idx = (idx - 1) % len(families)
else:
    idx = (idx + 1) % len(families)
print(families[idx])
PY
)"
    write_state "$next" "$ui_size" "$editor_size" >/dev/null
    apply_all "$next" "$ui_size" "$editor_size"
    read_state
    ;;
*)
    echo "usage: evo-font.sh get|list|apply|set <family|ui-size|editor-size> <value>|cycle-family [next|prev]" >&2
    exit 1
    ;;
esac
