#!/usr/bin/env bash
# Background warm-up for menu preview thumbnails.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
thumb="$SCRIPT_DIR/evo-menu-preview-thumb.sh"
theme_dir="${HOME}/.themes"

thumb_one() {
    local src="$1"
    local key="$2"
    [[ -f "$src" ]] || return 0
    "$thumb" "$src" "$key" >/dev/null 2>&1 || true
}

while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    thumb_one "$theme_dir/$name/preview.png" "themes/${name}.png"
done < <(find "$theme_dir" -mindepth 1 -maxdepth 1 -type d ! -name current ! -name shared ! -name next -printf '%f\n' 2>/dev/null | sort)

current="$theme_dir/current"
theme_name=""
[[ -f "$current/.theme-name" ]] && theme_name=$(tr -d '\n' < "$current/.theme-name")
bg_dir="$current/backgrounds"

if [[ -n "$theme_name" && -d "$bg_dir" ]]; then
    while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        bn="${file##*/}"
        thumb_one "$file" "wallpapers/${theme_name}/${bn}"
    done < <(find "$bg_dir" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) 2>/dev/null | sort)
fi
