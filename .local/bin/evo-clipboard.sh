#!/usr/bin/env bash
# Clipboard history via cliphist + wl-clipboard.

set -euo pipefail

LIMIT_DEFAULT=30
STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/evo-shell"
PREVIEW_DIR="${STATE_DIR}/clipboard-previews"
PINS_FILE="${STATE_DIR}/clipboard-pins.json"
PINS_DATA_DIR="${STATE_DIR}/clipboard-pins-data"
PID_FILE="${STATE_DIR}/clipboard-watch.pid"
STORE_SCRIPT="${STATE_DIR}/clipboard-store.sh"

stop_watch() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(<"$PID_FILE")
        kill "$pid" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
}

watch() {
    mkdir -p "$STATE_DIR"

    cat >"$STORE_SCRIPT" <<'EOF'
#!/usr/bin/env bash
cliphist store
EOF
    chmod +x "$STORE_SCRIPT"

    stop_watch
    pkill -f 'wl-paste --watch cliphist store' 2>/dev/null || true
    pkill -f 'wl-paste --watch bash -c cliphist store' 2>/dev/null || true

    wl-paste --watch "$STORE_SCRIPT" &
    echo "$!" >"$PID_FILE"
}

pins_py() {
    python3 - "$@" <<'PY'
import json
import os
import subprocess
import sys
import uuid

pins_path = sys.argv[2]
data_dir = sys.argv[3]
cmd = sys.argv[1]


def cliphist_list():
    try:
        raw = subprocess.check_output(["cliphist", "list"], text=True, stderr=subprocess.DEVNULL)
    except (subprocess.CalledProcessError, FileNotFoundError):
        raw = ""
    by_id = {}
    order = []
    for line in raw.splitlines():
        if "\t" not in line:
            continue
        entry_id, text = line.split("\t", 1)
        if not entry_id.isdigit():
            continue
        by_id[entry_id] = text
        order.append(entry_id)
    return by_id, order


def save_pins(pins):
    os.makedirs(os.path.dirname(pins_path) or ".", exist_ok=True)
    os.makedirs(data_dir, exist_ok=True)
    with open(pins_path, "w", encoding="utf-8") as f:
        json.dump({"version": 2, "pins": pins}, f, indent=2)
        f.write("\n")


def read_pin_blob(pin):
    with open(os.path.join(data_dir, pin["file"]), "rb") as f:
        return f.read()


def write_pin_blob(pin_id, blob):
    fname = f"{pin_id}.bin"
    path = os.path.join(data_dir, fname)
    os.makedirs(data_dir, exist_ok=True)
    with open(path, "wb") as f:
        f.write(blob)
    return fname


def store_blob(blob):
    subprocess.run(
        ["cliphist", "store"],
        input=blob,
        check=False,
        stderr=subprocess.DEVNULL,
    )


def load_pins():
    if not os.path.isfile(pins_path):
        return []

    try:
        with open(pins_path, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError, TypeError, ValueError):
        return []

    if isinstance(data, list):
        by_id, _ = cliphist_list()
        pins = []
        for entry_id in [str(x) for x in data if str(x).isdigit()]:
            if entry_id not in by_id:
                continue
            try:
                blob = subprocess.check_output(
                    ["cliphist", "decode", entry_id], stderr=subprocess.DEVNULL
                )
            except subprocess.CalledProcessError:
                continue
            pin_id = uuid.uuid4().hex[:12]
            fname = write_pin_blob(pin_id, blob)
            pins.append(
                {
                    "pinId": pin_id,
                    "cliphistId": entry_id,
                    "label": by_id[entry_id],
                    "file": fname,
                }
            )
        save_pins(pins)
        return pins

    if isinstance(data, dict) and isinstance(data.get("pins"), list):
        return data["pins"]

    return []


def sync_pins_into_cliphist(pins):
    by_id, _ = cliphist_list()
    changed = False
    for pin in pins:
        entry_id = str(pin.get("cliphistId", ""))
        label = pin.get("label", "")
        if entry_id in by_id and by_id[entry_id] == label:
            continue
        try:
            blob = read_pin_blob(pin)
        except OSError:
            continue
        store_blob(blob)
        changed = True

    if not changed:
        return pins

    by_id, _ = cliphist_list()
    labels_to_id = {}
    for entry_id, text in by_id.items():
        labels_to_id[text] = entry_id

    for pin in pins:
        label = pin.get("label", "")
        if label in labels_to_id:
            pin["cliphistId"] = labels_to_id[label]

    save_pins(pins)
    return pins


if cmd == "list":
    limit = int(sys.argv[4])
    pins = sync_pins_into_cliphist(load_pins())
    by_id, order = cliphist_list()
    pinned_ids = set()
    out = []

    for pin in pins:
        entry_id = str(pin.get("cliphistId", ""))
        if entry_id not in by_id:
            continue
        pinned_ids.add(entry_id)
        out.append(f"{entry_id}\t{by_id[entry_id]}\t1")

    unpinned = 0
    for entry_id in order:
        if entry_id in pinned_ids:
            continue
        out.append(f"{entry_id}\t{by_id[entry_id]}\t0")
        unpinned += 1
        if unpinned >= limit:
            break

    print("\n".join(out))
    raise SystemExit

if cmd == "read":
    pins = load_pins()
    print(json.dumps([str(p.get("cliphistId")) for p in pins if str(p.get("cliphistId", "")).isdigit()]))
    raise SystemExit

if cmd == "toggle":
    entry_id = sys.argv[4]
    if not entry_id.isdigit():
        print(json.dumps({"ok": False, "error": "invalid id"}))
        raise SystemExit

    pins = load_pins()
    by_id, _ = cliphist_list()

    for index, pin in enumerate(pins):
        if str(pin.get("cliphistId")) == entry_id:
            try:
                os.remove(os.path.join(data_dir, pin["file"]))
            except OSError:
                pass
            pins.pop(index)
            save_pins(pins)
            print(json.dumps({"ok": True, "pinned": False, "id": entry_id}))
            raise SystemExit

    if entry_id not in by_id:
        print(json.dumps({"ok": False, "error": "not found"}))
        raise SystemExit

    try:
        blob = subprocess.check_output(["cliphist", "decode", entry_id], stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        print(json.dumps({"ok": False, "error": "decode failed"}))
        raise SystemExit

    pin_id = uuid.uuid4().hex[:12]
    fname = write_pin_blob(pin_id, blob)
    pins.insert(
        0,
        {
            "pinId": pin_id,
            "cliphistId": entry_id,
            "label": by_id[entry_id],
            "file": fname,
        },
    )
    save_pins(pins)
    print(json.dumps({"ok": True, "pinned": True, "id": entry_id}))
    raise SystemExit

if cmd == "clear":
    preview_dir = sys.argv[4]
    pins = load_pins()
    snapshots = []
    for pin in pins:
        try:
            snapshots.append({"pin": pin, "data": read_pin_blob(pin)})
        except OSError:
            pass

    subprocess.run(["cliphist", "wipe"], check=False, stderr=subprocess.DEVNULL)

    for item in reversed(snapshots):
        store_blob(item["data"])

    kept_pins = []
    if snapshots:
        by_id, _ = cliphist_list()
        labels_to_id = {}
        for entry_id, text in by_id.items():
            labels_to_id[text] = entry_id

        for item in snapshots:
            pin = item["pin"]
            label = pin.get("label", "")
            if label in labels_to_id:
                pin["cliphistId"] = labels_to_id[label]
                kept_pins.append(pin)

    save_pins(kept_pins)

    valid_ids = {str(p.get("cliphistId")) for p in kept_pins}
    if os.path.isdir(preview_dir):
        for name in os.listdir(preview_dir):
            path = os.path.join(preview_dir, name)
            entry_id = name.split(".", 1)[0]
            if entry_id not in valid_ids:
                try:
                    os.remove(path)
                except OSError:
                    pass
    else:
        os.makedirs(preview_dir, exist_ok=True)
    raise SystemExit

print(json.dumps({"ok": False, "error": "unknown command"}), file=sys.stderr)
raise SystemExit(1)
PY
}

list_entries() {
    local limit="${1:-$LIMIT_DEFAULT}"
    pins_py list "$PINS_FILE" "$PINS_DATA_DIR" "$limit"
}

read_pins() {
    pins_py read "$PINS_FILE" "$PINS_DATA_DIR"
}

toggle_pin() {
    local id="${1:-}"
    [[ "$id" =~ ^[0-9]+$ ]] || return 1
    pins_py toggle "$PINS_FILE" "$PINS_DATA_DIR" "$id"
}

copy_id() {
    local id="${1:-}"
    [[ "$id" =~ ^[0-9]+$ ]] || return 1
    cliphist decode "$id" | wl-copy
}

image_format_from_text() {
    local text="$1"
    if [[ "$text" =~ binary[[:space:]]data.*[[:space:]](png|jpe?g)[[:space:]]([0-9]+)x([0-9]+) ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
    fi
    return 1
}

preview_extension() {
    local format="$1"
    case "$format" in
    jpg | jpeg) printf 'jpg' ;;
    png) printf 'png' ;;
    *) return 1 ;;
    esac
}

write_preview() {
    local id="$1" format="$2"
    local ext
    ext=$(preview_extension "$format") || return 1
    mkdir -p "$PREVIEW_DIR"
    local out="${PREVIEW_DIR}/${id}.${ext}"
  if [[ -s "$out" ]]; then
        printf '%s\n' "$out"
        return 0
    fi
    local tmp="${out}.tmp"
    if ! cliphist decode "$id" >"$tmp" 2>/dev/null; then
        rm -f "$tmp"
        return 1
    fi
    if [[ ! -s "$tmp" ]]; then
        rm -f "$tmp"
        return 1
    fi
    mv "$tmp" "$out"
    printf '%s\n' "$out"
}

preview_file() {
    local id="${1:-}"
    [[ "$id" =~ ^[0-9]+$ ]] || return 1
    local line text format
    line=$(cliphist list 2>/dev/null | awk -F '\t' -v id="$id" '$1 == id { print; exit }')
    [[ -n "$line" ]] || return 1
    text="${line#*$'\t'}"
    format=$(image_format_from_text "$text") || return 1
    write_preview "$id" "$format"
}

cache_previews() {
    local limit="${1:-$LIMIT_DEFAULT}"
    mkdir -p "$PREVIEW_DIR"
    while IFS=$'\t' read -r id text; do
        [[ "$id" =~ ^[0-9]+$ ]] || continue
        format=$(image_format_from_text "$text") || continue
        write_preview "$id" "$format" >/dev/null || true
    done < <(cliphist list 2>/dev/null | head -n "$limit")
}

clear_history() {
    pins_py clear "$PINS_FILE" "$PINS_DATA_DIR" "$PREVIEW_DIR"
}

case "${1:-}" in
watch) watch ;;
list) list_entries "${2:-$LIMIT_DEFAULT}" ;;
copy) copy_id "${2:-}" ;;
preview) preview_file "${2:-}" ;;
cache-previews) cache_previews "${2:-$LIMIT_DEFAULT}" ;;
toggle-pin) toggle_pin "${2:-}" ;;
pins) read_pins ;;
clear) clear_history ;;
*)
    echo "usage: evo-clipboard.sh watch|list [n]|copy <id>|preview <id>|cache-previews [n]|toggle-pin <id>|pins|clear" >&2
    exit 1
    ;;
esac
