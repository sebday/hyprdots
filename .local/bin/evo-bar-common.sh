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

    ((${#GITHUB_COLORS[@]} == 5))
}
