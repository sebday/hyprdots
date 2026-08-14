#!/usr/bin/env bash
# Global font family + unified text size for evoshell settings.
# Applies to GTK (incl. Firefox UI), evoshell, Ghostty, Cursor, and Obsidian.

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/evoshell"
STATE_FILE="${STATE_DIR}/font.json"
THEME_JSON="${HOME}/.config/quickshell/evoshell/theme.json"
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

font_tiers() {
    local base="$1"
    echo "$((base + SMALL_FONT_OFFSET))"
    echo "$((base + LARGE_FONT_OFFSET))"
}

compute_sizes() {
    local scale_percent="$1"
    local base_font_size="${2:-$DEFAULT_BASE_FONT_SIZE}"
    local small_base=$((base_font_size + SMALL_FONT_OFFSET))
    local large_base=$((base_font_size + LARGE_FONT_OFFSET))
    scale_percent="$(clamp_scale "$scale_percent")"
    local offset=$(( (scale_percent - 100) / 10 ))
    local small_size
    local base_size
    local obsidian_size
    small_size="$(clamp_px $((small_base + offset)))"
    base_size="$(clamp_px $((base_font_size + offset)))"
    obsidian_size="$(clamp_px $((large_base + offset)))"
    echo "$small_size"
    echo "$base_size"
    echo "$obsidian_size"
}

read_state() {
    local family="$DEFAULT_FAMILY"
    local scale_percent="$DEFAULT_SCALE_PERCENT"
    local base_font_size="$DEFAULT_BASE_FONT_SIZE"
    local last_applied_scale="$DEFAULT_SCALE_PERCENT"
    local had_last_applied=false

    if [[ -f "$STATE_FILE" ]] && jq -e 'type == "object"' "$STATE_FILE" >/dev/null 2>&1; then
        local read_family
        read_family="$(jq -r 'if (.family | type) == "string" and (.family | length) > 0 then .family else empty end' "$STATE_FILE")"
        if [[ -n "$read_family" ]]; then
            family="$read_family"
        fi

        if jq -e '.scalePercent | type == "number"' "$STATE_FILE" >/dev/null 2>&1; then
            scale_percent="$(jq '.scalePercent | floor' "$STATE_FILE")"
        fi

        if jq -e '.baseFontSize | type == "number"' "$STATE_FILE" >/dev/null 2>&1; then
            base_font_size="$(jq '.baseFontSize | floor' "$STATE_FILE")"
        fi

        if jq -e '.lastAppliedScalePercent | type == "number"' "$STATE_FILE" >/dev/null 2>&1; then
            last_applied_scale="$(jq '.lastAppliedScalePercent | floor' "$STATE_FILE")"
            had_last_applied=true
        elif jq -e '.textSize | type == "number"' "$STATE_FILE" >/dev/null 2>&1; then
            local text_size
            text_size="$(jq '.textSize | floor' "$STATE_FILE")"
            scale_percent=$((100 + (text_size - (base_font_size + SMALL_FONT_OFFSET)) * 10))
        fi
    fi

    base_font_size="$(clamp_px "$base_font_size")"
    local small_base=$((base_font_size + SMALL_FONT_OFFSET))
    local large_base=$((base_font_size + LARGE_FONT_OFFSET))
    scale_percent="$(clamp_scale "$scale_percent")"
    local offset=$(( (scale_percent - 100) / 10 ))
    local small_size
    local base_size
    local cursor_size
    local obsidian_size
    small_size="$(clamp_px $((small_base + offset)))"
    base_size="$(clamp_px $((base_font_size + offset)))"
    cursor_size="$(clamp_px $((base_font_size + XLARGE_FONT_OFFSET)))"
    obsidian_size="$(clamp_px $((large_base + offset)))"

    if ! $had_last_applied; then
        last_applied_scale="$scale_percent"
    else
        last_applied_scale="$(clamp_scale "$last_applied_scale")"
    fi

    jq -n \
        --arg family "$family" \
        --argjson scalePercent "$scale_percent" \
        --argjson baseFontSize "$base_font_size" \
        --argjson lastAppliedScalePercent "$last_applied_scale" \
        --argjson smallFontSize "$small_base" \
        --argjson largeFontSize "$large_base" \
        --argjson textSize "$small_size" \
        --argjson evoSize "$base_size" \
        --argjson cursorSize "$cursor_size" \
        --argjson obsidianSize "$obsidian_size" \
        '{
            family: $family,
            scalePercent: $scalePercent,
            baseFontSize: $baseFontSize,
            lastAppliedScalePercent: $lastAppliedScalePercent,
            smallFontSize: $smallFontSize,
            largeFontSize: $largeFontSize,
            textSize: $textSize,
            evoSize: $evoSize,
            cursorSize: $cursorSize,
            obsidianSize: $obsidianSize
        }'
}

write_state() {
    local family="$1"
    local scale_percent="$2"
    local base_font_size="$3"

    base_font_size="$(clamp_px "$base_font_size")"
    local small_base=$((base_font_size + SMALL_FONT_OFFSET))
    local large_base=$((base_font_size + LARGE_FONT_OFFSET))
    scale_percent="$(clamp_scale "$scale_percent")"
    local offset=$(( (scale_percent - 100) / 10 ))
    local small_size
    local base_size
    local cursor_size
    local obsidian_size
    small_size="$(clamp_px $((small_base + offset)))"
    base_size="$(clamp_px $((base_font_size + offset)))"
    cursor_size="$(clamp_px $((base_font_size + XLARGE_FONT_OFFSET)))"
    obsidian_size="$(clamp_px $((large_base + offset)))"

    jq -n \
        --arg family "$family" \
        --argjson scalePercent "$scale_percent" \
        --argjson baseFontSize "$base_font_size" \
        --argjson lastAppliedScalePercent "$scale_percent" \
        '{
            family: $family,
            scalePercent: $scalePercent,
            baseFontSize: $baseFontSize,
            lastAppliedScalePercent: $lastAppliedScalePercent
        }' >"$STATE_FILE"

    jq -n \
        --arg family "$family" \
        --argjson scalePercent "$scale_percent" \
        --argjson baseFontSize "$base_font_size" \
        --argjson lastAppliedScalePercent "$scale_percent" \
        --argjson smallFontSize "$small_base" \
        --argjson largeFontSize "$large_base" \
        --argjson textSize "$small_size" \
        --argjson evoSize "$base_size" \
        --argjson cursorSize "$cursor_size" \
        --argjson obsidianSize "$obsidian_size" \
        '{
            family: $family,
            scalePercent: $scalePercent,
            baseFontSize: $baseFontSize,
            lastAppliedScalePercent: $lastAppliedScalePercent,
            smallFontSize: $smallFontSize,
            largeFontSize: $largeFontSize,
            textSize: $textSize,
            evoSize: $evoSize,
            cursorSize: $cursorSize,
            obsidianSize: $obsidianSize
        }'
}

list_families() {
    local raw="" family lower
    local -a families=()
    local -A seen=()

    if command -v fc-list >/dev/null 2>&1; then
        raw="$(fc-list ':mono' family 2>/dev/null || true)"
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        family="${line%%,*}"
        family="${family#"${family%%[![:space:]]*}"}"
        family="${family%"${family##*[![:space:]]}"}"
        if [[ -z "$family" ]] || [[ -n "${seen[$family]:-}" ]]; then
            continue
        fi
        lower="${family,,}"
        if [[ "$lower" == *emoji* ]] || [[ "$lower" == *signwriting* ]]; then
            continue
        fi
        seen[$family]=1
        families+=("$family")
    done <<<"$raw"

    if ((${#families[@]} > 0)); then
        mapfile -t families < <(printf '%s\n' "${families[@]}" | LC_ALL=C sort -f)
    fi

    local json_array="[]"
    local f
    for f in "${families[@]}"; do
        json_array="$(jq --arg name "$f" '. + [$name]' <<<"$json_array")"
    done

    jq -n --argjson families "$json_array" '{families: $families}'
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
    local data="{}"

    mkdir -p "$(dirname "$THEME_JSON")"
    if [[ -f "$THEME_JSON" ]] && jq -e 'type == "object"' "$THEME_JSON" >/dev/null 2>&1; then
        data="$(jq -c . "$THEME_JSON")"
    fi

    jq \
        --arg family "$family" \
        --argjson fontPixelSize "$size" \
        '. + {fontFamily: $family, fontPixelSize: $fontPixelSize}' <<<"$data" \
        | jq --indent 2 . >"$THEME_JSON"
}

apply_ghostty() {
    local family="$1"
    local size="$2"
    local -a kept=()
    local line

    mkdir -p "$(dirname "$GHOSTTY_CONF")"
    if [[ -f "$GHOSTTY_CONF" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" =~ ^[[:space:]]*font-family[[:space:]]*= ]] \
                || [[ "$line" =~ ^[[:space:]]*font-size[[:space:]]*= ]]; then
                continue
            fi
            kept+=("$line")
        done <"$GHOSTTY_CONF"
    fi

    while ((${#kept[@]} > 0)) && [[ -z "${kept[-1]//[[:space:]]/}" ]]; do
        unset 'kept[-1]'
    done

    if ((${#kept[@]} > 0)) && [[ -n "${kept[-1]//[[:space:]]/}" ]]; then
        kept+=("")
    fi
    kept+=("font-family = ${family}")
    kept+=("font-size = ${size}")
    kept+=("")

    printf '%s\n' "${kept[@]}" >"$GHOSTTY_CONF"
    pkill -SIGUSR2 ghostty 2>/dev/null || true
}

ui_zoom_level() {
    awk -v base_size="$1" -v base_font_size="$2" \
        'BEGIN { printf "%.2f\n", (base_size - base_font_size) * 0.4 }'
}

obsidian_zoom_level() {
    awk -v small_size="$1" -v small_base="$2" \
        'BEGIN {
            offset = small_size - small_base
            zoom = offset * 0.5
            if (zoom < -2.5) zoom = -2.5
            if (zoom > 3.0) zoom = 3.0
            rounded = sprintf("%.1f", zoom)
            zoom_num = rounded + 0
            if (zoom_num == int(zoom_num)) print int(zoom_num)
            else print rounded
        }'
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
    local cursor_editor_size zoom_level font_family path parent data
    cursor_editor_size="$(clamp_px $((base_font_size + XLARGE_FONT_OFFSET)))"
    zoom_level="$(ui_zoom_level "$base_size" "$base_font_size")"
    font_family="'${family}', 'monospace', monospace"
    path="${HOME}/.config/Cursor/User/settings.json"
    parent="$(dirname "$path")"

    if [[ ! -d "$parent" ]]; then
        return 0
    fi

    data="{}"
    if [[ -f "$path" ]] && jq -e 'type == "object"' "$path" >/dev/null 2>&1; then
        data="$(jq -c . "$path")"
    fi

    jq \
        --arg font_family "$font_family" \
        --argjson editor_size "$cursor_editor_size" \
        --argjson zoom_level "$zoom_level" \
        'del(.["chat.editor.fontSize"], .["cursor.composer.textSizeScale"]) |
         with_entries(select(.key | startswith("custom-ui-style.") | not)) |
         . + {
             "editor.fontFamily": $font_family,
             "editor.inlayHints.fontFamily": $font_family,
             "editor.fontSize": $editor_size,
             "window.zoomLevel": $zoom_level
         }' <<<"$data" \
        | jq --indent 4 . >"$path"
}

apply_obsidian() {
    local family="$1"
    local small_size="$2"
    local large_baseline="$3"
    local small_baseline="$4"
    local zoom_delta="${5:-0}"
    local mono_family zoom_level appearance data state_path state zoom_json
    local -A seen_appearances=()
    local vault_id vault_path

    mono_family="$(mono_font_family "$family")"
    zoom_level="$(obsidian_zoom_level "$small_size" "$small_baseline")"

    if ((zoom_delta != 0)); then
        obsidian_apply_zoom_delta "$zoom_delta"
    fi

    if [[ -f "$OBSIDIAN_CONFIG" ]] && jq -e 'type == "object"' "$OBSIDIAN_CONFIG" >/dev/null 2>&1; then
        while IFS=$'\t' read -r vault_id vault_path; do
            [[ -n "$vault_id" && -n "$vault_path" ]] || continue

            appearance="${vault_path}/.obsidian/appearance.json"
            if [[ -n "${seen_appearances[$appearance]:-}" ]]; then
                continue
            fi
            if [[ ! -d "$(dirname "$appearance")" ]]; then
                continue
            fi
            seen_appearances[$appearance]=1

            data="{}"
            if [[ -f "$appearance" ]] && jq -e 'type == "object"' "$appearance" >/dev/null 2>&1; then
                data="$(jq -c . "$appearance")"
            fi

            jq \
                --arg interfaceFontFamily "$family" \
                --arg textFontFamily "$family" \
                --arg monospaceFontFamily "$mono_family" \
                --argjson baseFontSize "$large_baseline" \
                '. + {
                    interfaceFontFamily: $interfaceFontFamily,
                    textFontFamily: $textFontFamily,
                    monospaceFontFamily: $monospaceFontFamily,
                    baseFontSize: $baseFontSize
                }' <<<"$data" \
                | jq --indent 2 . >"$appearance"

            state_path="${HOME}/.config/obsidian/${vault_id}.json"
            state="{}"
            if [[ -f "$state_path" ]] && jq -e 'type == "object"' "$state_path" >/dev/null 2>&1; then
                state="$(jq -c . "$state_path")"
            fi

            zoom_json="$(jq -n --argjson z "$zoom_level" '$z')"

            jq --argjson zoom "$zoom_json" '. + {zoom: $zoom}' <<<"$state" \
                | jq -c . >"$state_path"
            printf '\n' >>"$state_path"
        done < <(jq -r '.vaults // {} | to_entries[] | select((.value.path | type) == "string") | [.key, .value.path] | @tsv' "$OBSIDIAN_CONFIG")
    fi
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

state_field() {
    jq -r --arg key "$2" '.[$key]' <<<"$1"
}

load_state() {
    local _state
    _state="$(read_state)"
    family="$(state_field "$_state" family)"
    scale_percent="$(state_field "$_state" scalePercent)"
    base_font_size="$(state_field "$_state" baseFontSize)"
    last_applied_scale="$(state_field "$_state" lastAppliedScalePercent)"
}

family_stem() {
    local name="$1"
    if [[ "$name" == *" Mono" ]]; then
        printf '%s' "${name% Mono}"
    else
        printf '%s' "$name"
    fi
}

cycle_family() {
    local families_json="$1"
    local current="$2"
    local direction="$3"
    local count idx=0 i=0 name name_stem current_stem
    local -a families=()

    count="$(jq '.families | length' <<<"$families_json")"
    if ((count == 0)); then
        printf '%s' "$current"
        return 0
    fi

    mapfile -t families < <(jq -r '.families[]' <<<"$families_json")
    current_stem="$(family_stem "$current")"

    if jq -e --arg current "$current" '.families | index($current) != null' <<<"$families_json" >/dev/null 2>&1; then
        idx="$(jq --arg current "$current" '.families | index($current)' <<<"$families_json")"
    else
        idx=-1
        for name in "${families[@]}"; do
            name_stem="$(family_stem "$name")"
            if [[ "$name" == "$current_stem" || "$name" == "$current" || "$name_stem" == "$current_stem" ]]; then
                idx=$i
                break
            fi
            ((i++))
        done
        if ((idx < 0)); then
            if [[ "$direction" == "prev" ]]; then
                idx=-1
            else
                idx=0
            fi
        fi
    fi

    if [[ "$direction" == "prev" ]]; then
        idx=$((idx - 1))
        idx=$((idx % count))
        if ((idx < 0)); then
            idx=$((idx + count))
        fi
    else
        idx=$(( (idx + 1) % count ))
    fi

    printf '%s' "${families[$idx]}"
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
    next="$(cycle_family "$families_json" "$family" "$direction")"
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
reset)
    apply_all "$DEFAULT_FAMILY" "$DEFAULT_SCALE_PERCENT" "$DEFAULT_BASE_FONT_SIZE" "$DEFAULT_SCALE_PERCENT"
    write_state "$DEFAULT_FAMILY" "$DEFAULT_SCALE_PERCENT" "$DEFAULT_BASE_FONT_SIZE" >/dev/null
    read_state
    ;;
*)
    echo "usage: evo-font.sh get|list|apply|apply-gtk|reset|set <family|zoom|base> <value>|cycle-family [next|prev]|step-zoom [up|down]" >&2
    exit 1
    ;;
esac
