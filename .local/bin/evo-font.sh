#!/usr/bin/env bash
# Global font family + unified text size for evo-shell settings.
# Applies to GTK (incl. Firefox UI), evo-shell, Ghostty, Cursor, and Obsidian.

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/evo-shell"
STATE_FILE="${STATE_DIR}/font.json"
THEME_JSON="${HOME}/.config/quickshell/evo-shell/theme.json"
GHOSTTY_CONF="${HOME}/.config/ghostty/config"
GKEY_SCHEMA="org.gnome.desktop.interface"
GKEY_SCALING="text-scaling-factor"

DEFAULT_FAMILY="CaskaydiaMono Nerd Font"
DEFAULT_SCALE_PERCENT=100
DEFAULT_BASE_FONT_SIZE=13
SMALL_FONT_OFFSET=-2
LARGE_FONT_OFFSET=3
XLARGE_FONT_OFFSET=5
MIN_SCALE_PERCENT=50
MAX_SCALE_PERCENT=150
SCALE_STEP=10
MIN_TEXT_SIZE=9
MAX_TEXT_SIZE=28
OBSIDIAN_CONFIG="${HOME}/.config/obsidian/obsidian.json"

mkdir -p "$STATE_DIR"

font_tiers() {
    python3 - "$1" "$SMALL_FONT_OFFSET" "$LARGE_FONT_OFFSET" <<'PY'
import sys

base = int(sys.argv[1])
print(base + int(sys.argv[2]))
print(base + int(sys.argv[3]))
PY
}

compute_sizes() {
    local scale_percent="$1"
    local base_font_size="${2:-$DEFAULT_BASE_FONT_SIZE}"
    python3 - "$scale_percent" "$base_font_size" "$MIN_SCALE_PERCENT" "$MAX_SCALE_PERCENT" "$MIN_TEXT_SIZE" "$MAX_TEXT_SIZE" "$SMALL_FONT_OFFSET" "$LARGE_FONT_OFFSET" <<'PY'
import sys

percent = int(sys.argv[1])
base = int(sys.argv[2])
lo_pct = int(sys.argv[3])
hi_pct = int(sys.argv[4])
lo = int(sys.argv[5])
hi = int(sys.argv[6])
small_off = int(sys.argv[7])
large_off = int(sys.argv[8])

small_base = base + small_off
large_base = base + large_off
percent = max(lo_pct, min(hi_pct, percent))
offset = (percent - 100) // 10
small_size = max(lo, min(hi, small_base + offset))
base_size = max(lo, min(hi, base + offset))
obsidian_size = max(lo, min(hi, large_base + offset))
print(small_size)
print(base_size)
print(obsidian_size)
PY
}

read_state() {
    python3 - "$STATE_FILE" "$DEFAULT_FAMILY" "$DEFAULT_SCALE_PERCENT" "$DEFAULT_BASE_FONT_SIZE" "$MIN_SCALE_PERCENT" "$MAX_SCALE_PERCENT" "$MIN_TEXT_SIZE" "$MAX_TEXT_SIZE" "$SMALL_FONT_OFFSET" "$LARGE_FONT_OFFSET" "$XLARGE_FONT_OFFSET" <<'PY'
import json
import os
import sys

path = sys.argv[1]
default_family = sys.argv[2]
default_scale = int(sys.argv[3])
default_base = int(sys.argv[4])
lo_pct = int(sys.argv[5])
hi_pct = int(sys.argv[6])
lo = int(sys.argv[7])
hi = int(sys.argv[8])
small_off = int(sys.argv[9])
large_off = int(sys.argv[10])
xlarge_off = int(sys.argv[11])

state = {
    "family": default_family,
    "scalePercent": default_scale,
    "baseFontSize": default_base,
    "lastAppliedScalePercent": default_scale,
}
had_last_applied = False

if os.path.isfile(path):
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict):
            if isinstance(data.get("family"), str) and data["family"].strip():
                state["family"] = data["family"].strip()
            if isinstance(data.get("scalePercent"), (int, float)):
                state["scalePercent"] = int(data["scalePercent"])
            if isinstance(data.get("baseFontSize"), (int, float)):
                state["baseFontSize"] = int(data["baseFontSize"])
            if isinstance(data.get("lastAppliedScalePercent"), (int, float)):
                state["lastAppliedScalePercent"] = int(data["lastAppliedScalePercent"])
                had_last_applied = True
            elif isinstance(data.get("textSize"), (int, float)):
                state["scalePercent"] = 100 + (int(data["textSize"]) - (state["baseFontSize"] + small_off)) * 10
    except (OSError, json.JSONDecodeError, TypeError, ValueError):
        pass

base_font_size = max(lo, min(hi, state["baseFontSize"]))
small_base = base_font_size + small_off
large_base = base_font_size + large_off
percent = max(lo_pct, min(hi_pct, state["scalePercent"]))
offset = (percent - 100) // 10
small_size = max(lo, min(hi, small_base + offset))
base_size = max(lo, min(hi, base_font_size + offset))
cursor_size = max(lo, min(hi, base_font_size + xlarge_off))
obsidian_size = max(lo, min(hi, large_base + offset))
state["baseFontSize"] = base_font_size
state["scalePercent"] = percent
if not had_last_applied:
    state["lastAppliedScalePercent"] = percent
else:
    state["lastAppliedScalePercent"] = max(lo_pct, min(hi_pct, state["lastAppliedScalePercent"]))
state["smallFontSize"] = small_base
state["largeFontSize"] = large_base
state["textSize"] = small_size
state["evoSize"] = base_size
state["cursorSize"] = cursor_size
state["obsidianSize"] = obsidian_size
print(json.dumps(state))
PY
}

write_state() {
    local family="$1"
    local scale_percent="$2"
    local base_font_size="$3"
    python3 - "$STATE_FILE" "$family" "$scale_percent" "$base_font_size" "$MIN_SCALE_PERCENT" "$MAX_SCALE_PERCENT" "$MIN_TEXT_SIZE" "$MAX_TEXT_SIZE" "$SMALL_FONT_OFFSET" "$LARGE_FONT_OFFSET" "$XLARGE_FONT_OFFSET" <<'PY'
import json
import sys

path, family = sys.argv[1], sys.argv[2]
percent = int(sys.argv[3])
base_font_size = int(sys.argv[4])
lo_pct = int(sys.argv[5])
hi_pct = int(sys.argv[6])
lo = int(sys.argv[7])
hi = int(sys.argv[8])
small_off = int(sys.argv[9])
large_off = int(sys.argv[10])
xlarge_off = int(sys.argv[11])

base_font_size = max(lo, min(hi, base_font_size))
small_base = base_font_size + small_off
large_base = base_font_size + large_off
percent = max(lo_pct, min(hi_pct, percent))
offset = (percent - 100) // 10
small_size = max(lo, min(hi, small_base + offset))
base_size = max(lo, min(hi, base_font_size + offset))
cursor_size = max(lo, min(hi, base_font_size + xlarge_off))
obsidian_size = max(lo, min(hi, large_base + offset))

data = {
    "family": family,
    "scalePercent": percent,
    "baseFontSize": base_font_size,
    "lastAppliedScalePercent": percent,
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print(json.dumps({
    "family": family,
    "scalePercent": percent,
    "baseFontSize": base_font_size,
    "lastAppliedScalePercent": percent,
    "smallFontSize": small_base,
    "largeFontSize": large_base,
    "textSize": small_size,
    "evoSize": base_size,
    "cursorSize": cursor_size,
    "obsidianSize": obsidian_size,
}))
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

mono_font_family() {
    local family="$1"
    if fc-list "$family Mono" family 2>/dev/null | grep -q .; then
        printf '%s Mono' "$family"
    elif [[ "$family" == *Mono ]]; then
        printf '%s' "$family"
    elif fc-list "${family} Mono" family 2>/dev/null | grep -q .; then
        printf '%s Mono' "$family"
    else
        printf '%s' "$family"
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

    gsettings set "$GKEY_SCHEMA" font-name "$font_name" 2>/dev/null || true
    gsettings set "$GKEY_SCHEMA" "$GKEY_SCALING" 1.0 2>/dev/null || true
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
    pkill -SIGUSR2 ghostty 2>/dev/null || true
}

ui_zoom_level() {
    python3 - "$1" "$2" <<'PY'
import sys

base_size, base_font_size = int(sys.argv[1]), int(sys.argv[2])
print(round((base_size - base_font_size) * 0.4, 2))
PY
}

obsidian_zoom_level() {
    python3 - "$1" "$2" <<'PY'
import sys

small_size, small_base = int(sys.argv[1]), int(sys.argv[2])
offset = small_size - small_base
zoom = round(offset * 0.5, 1)
zoom = max(-2.5, min(3.0, zoom))
print(int(zoom) if zoom == int(zoom) else zoom)
PY
}

obsidian_running() {
    pgrep -f '/usr/lib/obsidian/app.asar' >/dev/null 2>&1
}

obsidian_cli_available() {
    command -v obsidian >/dev/null 2>&1 && obsidian help >/dev/null 2>&1
}

obsidian_apply_zoom_delta() {
    local delta="$1"
    local i cmd

    ((delta == 0)) && return 0
    obsidian_running || return 0
    obsidian_cli_available || return 0

    if ((delta > 0)); then
        cmd="window:zoom-in"
        for ((i = 0; i < delta; i++)); do
            obsidian command "id=$cmd" >/dev/null 2>&1 || return 0
        done
    else
        cmd="window:zoom-out"
        for ((i = 0; i < -delta; i++)); do
            obsidian command "id=$cmd" >/dev/null 2>&1 || return 0
        done
    fi
}

apply_cursor() {
    local family="$1"
    local base_size="$2"
    local base_font_size="$3"
    local cursor_editor_size zoom_level
    cursor_editor_size="$(clamp_px $((base_font_size + XLARGE_FONT_OFFSET)))"
    zoom_level="$(ui_zoom_level "$base_size" "$base_font_size")"
    python3 - "$family" "$cursor_editor_size" "$zoom_level" <<'PY'
import json
import os
import sys

family = sys.argv[1]
editor_size = int(sys.argv[2])
zoom_level = float(sys.argv[3])
font_family = f"'{family}', 'monospace', monospace"
path = os.path.expanduser("~/.config/Cursor/User/settings.json")
parent = os.path.dirname(path)
if not os.path.isdir(parent):
    raise SystemExit

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
data["editor.inlayHints.fontFamily"] = font_family
data["editor.fontSize"] = editor_size
data["window.zoomLevel"] = zoom_level
data.pop("chat.editor.fontSize", None)
data.pop("cursor.composer.textSizeScale", None)
for key in [k for k in data if k.startswith("custom-ui-style.")]:
    del data[key]

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=4)
    f.write("\n")
PY
}

apply_obsidian() {
    local family="$1"
    local small_size="$2"
    local large_baseline="$3"
    local small_baseline="$4"
    local zoom_delta="${5:-0}"
    local mono_family zoom_level
    mono_family="$(mono_font_family "$family")"
    zoom_level="$(obsidian_zoom_level "$small_size" "$small_baseline")"

    if ((zoom_delta != 0)); then
        obsidian_apply_zoom_delta "$zoom_delta"
    fi

    python3 - "$OBSIDIAN_CONFIG" "$family" "$mono_family" "$large_baseline" "$zoom_level" <<'PY'
import json
import os
import sys

config_path, family, mono_family, base_font_size = sys.argv[1:5]
zoom_level = float(sys.argv[5])
config_dir = os.path.dirname(config_path)
vaults = []
vault_ids = []
if os.path.isfile(config_path):
    try:
        with open(config_path, encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict):
            for vault_id, entry in data.get("vaults", {}).items():
                if isinstance(entry, dict) and isinstance(entry.get("path"), str):
                    vault_ids.append(vault_id)
                    vaults.append(entry["path"])
    except (OSError, json.JSONDecodeError, TypeError, ValueError):
        pass

seen = set()
for vault in vaults:
    appearance = os.path.join(vault, ".obsidian", "appearance.json")
    if appearance in seen or not os.path.isdir(os.path.dirname(appearance)):
        continue
    seen.add(appearance)
    data = {}
    if os.path.isfile(appearance):
        try:
            with open(appearance, encoding="utf-8") as f:
                loaded = json.load(f)
            if isinstance(loaded, dict):
                data = loaded
        except (OSError, json.JSONDecodeError):
            data = {}

    data["interfaceFontFamily"] = family
    data["textFontFamily"] = family
    data["monospaceFontFamily"] = mono_family
    data["baseFontSize"] = int(base_font_size)

    os.makedirs(os.path.dirname(appearance), exist_ok=True)
    with open(appearance, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")

for vault_id in vault_ids:
    state_path = os.path.join(config_dir, f"{vault_id}.json")
    state = {}
    if os.path.isfile(state_path):
        try:
            with open(state_path, encoding="utf-8") as f:
                loaded = json.load(f)
            if isinstance(loaded, dict):
                state = loaded
        except (OSError, json.JSONDecodeError):
            state = {}
    state["zoom"] = int(zoom_level) if zoom_level == int(zoom_level) else zoom_level
    with open(state_path, "w", encoding="utf-8") as f:
        json.dump(state, f, separators=(",", ":"))
        f.write("\n")
PY
}

apply_all() {
    local family="$1"
    local scale_percent="$2"
    local base_font_size="$3"
    local last_applied_scale="${4:-$scale_percent}"
    local sizes small_size base_size tiers small_baseline large_baseline zoom_delta
    sizes="$(compute_sizes "$scale_percent" "$base_font_size")"
    small_size="$(sed -n '1p' <<<"$sizes")"
    base_size="$(sed -n '2p' <<<"$sizes")"
    tiers="$(font_tiers "$base_font_size")"
    small_baseline="$(sed -n '1p' <<<"$tiers")"
    large_baseline="$(sed -n '2p' <<<"$tiers")"
    zoom_delta=$(( (scale_percent - last_applied_scale) / 10 ))
    apply_gtk "$family" "$small_size"
    apply_evo_shell "$family" "$base_size"
    apply_ghostty "$family" "$base_size"
    apply_cursor "$family" "$base_size" "$base_font_size"
    apply_obsidian "$family" "$small_size" "$large_baseline" "$small_baseline" "$zoom_delta"
}

clamp_px() {
    local n="$1"
    if ((n < MIN_TEXT_SIZE)); then
        echo "$MIN_TEXT_SIZE"
    elif ((n > MAX_TEXT_SIZE)); then
        echo "$MAX_TEXT_SIZE"
    else
        echo "$n"
    fi
}

clamp_base() {
    clamp_px "$1"
}

clamp_scale() {
    local scale="$1"
    if ((scale < MIN_SCALE_PERCENT)); then
        echo "$MIN_SCALE_PERCENT"
    elif ((scale > MAX_SCALE_PERCENT)); then
        echo "$MAX_SCALE_PERCENT"
    else
        echo "$scale"
    fi
}

state_field() {
    python3 -c "import json,sys; print(json.loads(sys.argv[1])[sys.argv[2]])" "$1" "$2"
}

load_state() {
    local _state
    _state="$(read_state)"
    family="$(state_field "$_state" family)"
    scale_percent="$(state_field "$_state" scalePercent)"
    base_font_size="$(state_field "$_state" baseFontSize)"
    last_applied_scale="$(state_field "$_state" lastAppliedScalePercent)"
}

case "${1:-}" in
get)
    read_state
    ;;
list)
    list_families
    ;;
apply)
    load_state
    apply_all "$family" "$scale_percent" "$base_font_size" "$last_applied_scale"
    write_state "$family" "$scale_percent" "$base_font_size" >/dev/null
    read_state
    ;;
apply-gtk)
    load_state
    sizes="$(compute_sizes "$scale_percent" "$base_font_size")"
    apply_gtk "$family" "$(sed -n '1p' <<<"$sizes")"
    ;;
set)
    key="${2:-}"
    value="${3:-}"
    load_state
    case "$key" in
    family)
        [[ -n "$value" ]] || { echo "missing family" >&2; exit 1; }
        family="$value"
        ;;
    scale | scalePercent | zoom | zoomLevel | text-size | textSize)
        [[ "$value" =~ ^[0-9]+$ ]] || { echo "scale must be int percent" >&2; exit 1; }
        scale_percent="$(clamp_scale "$value")"
        ;;
    base | baseSize | baseFontSize | base-font-size)
        [[ "$value" =~ ^[0-9]+$ ]] || { echo "base size must be int px" >&2; exit 1; }
        base_font_size="$(clamp_base "$value")"
        ;;
    *)
        echo "unknown key: $key" >&2
        exit 1
        ;;
    esac
    apply_all "$family" "$scale_percent" "$base_font_size" "$last_applied_scale"
    write_state "$family" "$scale_percent" "$base_font_size" >/dev/null
    read_state
    ;;
cycle-family)
    direction="${2:-next}"
    load_state
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
    write_state "$next" "$scale_percent" "$base_font_size" >/dev/null
    apply_all "$next" "$scale_percent" "$base_font_size" "$last_applied_scale"
    read_state
    ;;
step-zoom)
    direction="${2:-up}"
    load_state
    if [[ "$direction" == "down" ]]; then
        scale_percent=$((scale_percent - SCALE_STEP))
    else
        scale_percent=$((scale_percent + SCALE_STEP))
    fi
    scale_percent="$(clamp_scale "$scale_percent")"
    apply_all "$family" "$scale_percent" "$base_font_size" "$last_applied_scale"
    write_state "$family" "$scale_percent" "$base_font_size" >/dev/null
    read_state
    ;;
*)
    echo "usage: evo-font.sh get|list|apply|apply-gtk|set <family|zoom|base> <value>|cycle-family [next|prev]|step-zoom [up|down]" >&2
    exit 1
    ;;
esac
