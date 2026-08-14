#!/bin/bash
# Shared helpers for evo bar JSON modules.
# Heatmap colours come from ~/.themes/current/evo-bar.css (generated from colors.toml).

EVO_BAR_THEME_CSS="${EVO_BAR_THEME_CSS:-$HOME/.themes/current/evo-bar.css}"
EVO_SECRETS_FILE="${EVO_SECRETS_FILE:-${XDG_DATA_HOME:-$HOME/.local/share}/evoshell/secrets.env}"
EVO_BAR_CACHE_DIR="${EVO_BAR_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/evoshell/bar}"

# Fill global GITHUB_COLORS[0..4] from @define-color github-N in theme evo-bar.css.
evo_bar_load_heatmap_colors() {
    declare -gA GITHUB_COLORS=()

    [[ -f "$EVO_BAR_THEME_CSS" ]] || return 1

    local i color
    for i in {0..4}; do
        color=$(grep "@define-color github-$i" "$EVO_BAR_THEME_CSS" | awk '{print $3}' | tr -d ';' || true)
        [[ -n "$color" ]] && GITHUB_COLORS[$i]="$color"
    done

    # Fallbacks if theme CSS missing colors.
    : "${GITHUB_COLORS[0]:=#45475a}"
    : "${GITHUB_COLORS[1]:=#89b4fa}"
    : "${GITHUB_COLORS[2]:=#74c7ec}"
    : "${GITHUB_COLORS[3]:=#89dceb}"
    : "${GITHUB_COLORS[4]:=#cba6f7}"

    ((${#GITHUB_COLORS[@]} >= 5))
}

# Build sparkline JSON from "date|value" rows. Prints a JSON array.
evo_bar_build_bars_json() {
    local -a rows=("$@")
    local max_sale row day_iso sale bar_level color_level color

    if ((${#rows[@]} == 0)); then
        printf '[]'
        return
    fi

    max_sale=$(printf '%s\n' "${rows[@]}" | awk -F'|' '
        { v = ($2 == "" ? 0 : $2 + 0); if (v < 0) v = 0; if (v > max) max = v }
        END { print max + 0 }
    ')

    if awk -v m="$max_sale" 'BEGIN { exit (m == 0) ? 0 : 1 }'; then
        printf '[]'
        return
    fi

    local lines=""
    for row in "${rows[@]}"; do
        IFS='|' read -r day_iso sale <<< "$row"
        read -r bar_level color_level <<< "$(awk -v sale="$sale" -v max="$max_sale" 'BEGIN {
            s = (sale == "" ? 0 : sale + 0)
            if (s < 0) s = 0

            bar_level = 0
            if (s > 0) {
                bar_level = int((s / max) * 7)
                if (bar_level == 0) bar_level = 1
            }
            if (bar_level > 7) bar_level = 7

            color_level = 0
            if (s > 0) {
                pct = s / max
                if (pct > 0.75) color_level = 4
                else if (pct > 0.5) color_level = 3
                else if (pct > 0.25) color_level = 2
                else color_level = 1
            }

            print bar_level, color_level
        }')"
        color="${GITHUB_COLORS[$color_level]:-#89b4fa}"
        lines+="$(jq -cn --arg date "$day_iso" --argjson value "${sale:-0}" \
            --argjson level "$bar_level" --argjson colorLevel "$color_level" --arg color "$color" \
            '{date: $date, value: $value, level: $level, colorLevel: $colorLevel, color: $color}')"
        lines+=$'\n'
    done

    printf '%s' "$lines" | jq -s '.'
}

evo_bar_cache_path() {
    printf '%s/%s.json' "$EVO_BAR_CACHE_DIR" "$1"
}

# Return cached JSON when younger than ttl seconds.
evo_bar_cache_read() {
    local key="$1" ttl="${2:-60}"
    local path now mtime age
    path="$(evo_bar_cache_path "$key")"
    [[ -f "$path" ]] || return 1
    now=$(date +%s)
    mtime=$(stat -c %Y "$path" 2>/dev/null || echo 0)
    age=$((now - mtime))
    (( age < ttl )) || return 1
    cat "$path"
}

# Write JSON cache atomically from stdin.
evo_bar_cache_write() {
    local key="$1" path tmp
    mkdir -p "$EVO_BAR_CACHE_DIR"
    path="$(evo_bar_cache_path "$key")"
    tmp="$(mktemp "${path}.XXXXXX")"
    cat >"$tmp"
    mv "$tmp" "$path"
}

# Merge date|value rows from stdin into a JSON history file.
# Prints date|value lines for the last $keep days.
# Usage: { echo '2026-01-01|100'; ...; } | evo_bar_merge_history <path> [keep]
evo_bar_merge_history() {
    local path="$1"
    local keep="${2:-30}"
    local stdin_data existing merged tmp line d v
    mkdir -p "$(dirname "$path")"
    stdin_data="$(cat)"

    if [[ -f "$path" ]]; then
        existing=$(jq -c 'if type == "array" then map(select(type == "object" and (.date // "") != "")) else [] end' "$path" 2>/dev/null || echo '[]')
    else
        existing='[]'
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line//$'\r'/}"
        [[ "$line" == *"|"* ]] || continue
        d="${line%%|*}"
        v="${line#*|}"
        d="${d//[[:space:]]/}"
        [[ -n "$d" ]] || continue
        existing=$(jq -c --arg d "$d" --arg v "$v" '
            (map(select(.date != $d)) + [{date: $d, value: ($v | tonumber)}])
        ' <<<"$existing" 2>/dev/null || echo "$existing")
    done <<<"$stdin_data"

    merged=$(jq -c --argjson keep "$keep" 'sort_by(.date) | .[-$keep:]' <<<"$existing")
    tmp="$(mktemp)"
    printf '%s\n' "$merged" | jq '.' >"$tmp"
    mv "$tmp" "$path"
    jq -r '.[] | "\(.date)|\(.value)"' <<<"$merged"
}
