#!/bin/bash
# Shared helpers for evo bar JSON modules.
# Heatmap colours come from ~/.themes/current/evo-bar.css (generated from colors.toml).

EVO_BAR_THEME_CSS="${EVO_BAR_THEME_CSS:-$HOME/.themes/current/evo-bar.css}"
if [[ ! -f "$EVO_BAR_THEME_CSS" ]]; then
    EVO_BAR_THEME_CSS="$HOME/.themes/current/waybar.css"
fi
EVO_SECRETS_FILE="${EVO_SECRETS_FILE:-${XDG_DATA_HOME:-$HOME/.local/share}/evo-shell/secrets.env}"
if [[ ! -f "$EVO_SECRETS_FILE" ]]; then
    EVO_SECRETS_FILE="$HOME/.config/waybar/secrets.env"
fi

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

# Merge date|value rows from stdin into a JSON history file.
# Prints date|value lines for the last $keep days.
# Usage: { echo '2026-01-01|100'; ...; } | evo_bar_merge_history <path> [keep]
evo_bar_merge_history() {
    local path="$1"
    local keep="${2:-30}"
    mkdir -p "$(dirname "$path")"

    python3 -c '
import json, os, sys

path, keep = sys.argv[1], int(sys.argv[2])
by_day = {}

if os.path.isfile(path):
    try:
        with open(path, encoding="utf-8") as f:
            loaded = json.load(f)
        if isinstance(loaded, list):
            for row in loaded:
                if not isinstance(row, dict):
                    continue
                d = str(row.get("date") or "")
                if not d:
                    continue
                try:
                    by_day[d] = float(row.get("value") or 0)
                except (TypeError, ValueError):
                    pass
    except (OSError, json.JSONDecodeError):
        pass

for line in sys.stdin:
    line = line.strip()
    if not line or "|" not in line:
        continue
    d, _, v = line.partition("|")
    d = d.strip()
    if not d:
        continue
    try:
        by_day[d] = float(v)
    except ValueError:
        continue

ordered = sorted(by_day.items())[-keep:]
out = [{"date": d, "value": v} for d, v in ordered]
with open(path, "w", encoding="utf-8") as f:
    json.dump(out, f, indent=2)
    f.write("\n")

for d, v in ordered:
    print(f"{d}|{v}")
' "$path" "$keep"
}
