#!/usr/bin/env bash
# Clipboard history via cliphist + wl-clipboard.

set -euo pipefail

LIMIT_DEFAULT=30
STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/evo-shell"
PREVIEW_DIR="${STATE_DIR}/clipboard-previews"
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

list_entries() {
    local limit="${1:-$LIMIT_DEFAULT}"
    cliphist list 2>/dev/null | head -n "$limit"
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

case "${1:-}" in
watch) watch ;;
list) list_entries "${2:-$LIMIT_DEFAULT}" ;;
copy) copy_id "${2:-}" ;;
preview) preview_file "${2:-}" ;;
cache-previews) cache_previews "${2:-$LIMIT_DEFAULT}" ;;
*)
    echo "usage: evo-clipboard.sh watch|list [n]|copy <id>|preview <id>|cache-previews [n]" >&2
    exit 1
    ;;
esac
