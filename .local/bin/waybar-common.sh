#!/bin/bash
# Shared helpers for waybar JSON modules.
# Heatmap colours come from ~/.themes/current/waybar.css (generated from colors.toml).

WAYBAR_THEME_CSS="${WAYBAR_THEME_CSS:-$HOME/.themes/current/waybar.css}"

# Fill global GITHUB_COLORS[0..4] from @define-color github-N in theme waybar.css.
waybar_load_heatmap_colors() {
    declare -gA GITHUB_COLORS=()

    [[ -f "$WAYBAR_THEME_CSS" ]] || return 1

    local i color
    for i in {0..4}; do
        color=$(grep "@define-color github-$i" "$WAYBAR_THEME_CSS" | awk '{print $3}' | tr -d ';' || true)
        [[ -n "$color" ]] && GITHUB_COLORS[$i]="$color"
    done

    ((${#GITHUB_COLORS[@]} == 5))
}
