#!/usr/bin/env bash
# Fast TSV listing for Evo menu theme/wallpaper previews (no ImageMagick).
set -euo pipefail

mode="${1:-}"
cache_root="${XDG_STATE_HOME:-$HOME/.local/state}/evoshell/menu-cache"
home="${HOME:?}"

preview_path() {
    local src="$1" key="$2"
    local cached="$cache_root/$key"
    if [[ -f "$cached" ]]; then
        printf '%s' "$cached"
    else
        printf '%s' "$src"
    fi
}

case "$mode" in
themes)
    find "$home/.themes" -mindepth 1 -maxdepth 1 -type d \
        ! -name current ! -name shared ! -name next -printf '%f\n' 2>/dev/null | sort |
        while IFS= read -r name; do
            [[ -n "$name" ]] || continue
            src="$home/.themes/$name/preview.png"
            [[ -f "$src" ]] || continue
            p=$(preview_path "$src" "themes/${name}.png")
            printf '%s\t%s/.local/bin/evo-theme.sh %s\t%s\n' "$name" "$home" "$name" "$p"
        done
    ;;
wallpapers)
  {
    dir="$home/.themes/current/backgrounds"
    theme=$(tr -d '\n' < "$home/.themes/current/.theme-name" 2>/dev/null || true)
    [[ -n "$theme" && -d "$dir" ]] || exit 0
    find "$dir" -type f \
        \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
        2>/dev/null | sort |
        while IFS= read -r file; do
            [[ -n "$file" ]] || continue
            bn="${file##*/}"
            p=$(preview_path "$file" "wallpapers/${theme}/${bn}")
            printf '%s\t%s/.local/bin/evo-wallpaper.sh set %s\t%s\n' "$bn" "$home" "$file" "$p"
        done
  }
    ;;
*)
    echo "usage: $0 themes|wallpapers" >&2
    exit 1
    ;;
esac
