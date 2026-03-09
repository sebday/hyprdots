#!/bin/bash
set -e
# Process templates from colors.toml into a theme dir
# Usage: themes-process-templates.sh <theme_dir>

THEME_DIR="${THEME_DIR:-$HOME/.themes}"
TEMPLATES_DIR="${TEMPLATES_DIR:-$THEME_DIR/shared/templates}"

theme_dir="$1"
[ -z "$theme_dir" ] && exit 1

toml="$theme_dir/colors.toml"
[ ! -f "$toml" ] && exit 0

sed_script=$(mktemp)
trap 'rm -f "$sed_script"' EXIT

while IFS='=' read -r key value; do
    key="${key//[\"\' ]/}"
    [[ $key && $key != \#* ]] || continue
    value="${value#*[\"\']}"
    value="${value%%[\"\']*}"
    printf 's|{{ %s }}|%s|g\n' "$key" "$value" >> "$sed_script"
    printf 's|{{ %s_strip }}|%s|g\n' "$key" "${value#\#}" >> "$sed_script"
    if [[ $value =~ ^# ]]; then
        hex="${value#\#}"
        printf 's|{{ %s_rgb }}|%d,%d,%d|g\n' "$key" "$(( 0x${hex:0:2} ))" "$(( 0x${hex:2:2} ))" "$(( 0x${hex:4:2} ))" >> "$sed_script"
    fi
done < "$toml"

# Add icon_path from icons.theme for mako.ini
icon_path="/home/seb/.local/share/icons/Adwaita"
if [ -f "$theme_dir/icons.theme" ]; then
    icon_name=$(tr -d '\n' < "$theme_dir/icons.theme" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -n "$icon_name" ] && icon_path="/home/seb/.local/share/icons/$icon_name"
fi
printf 's|{{ icon_path }}|%s|g\n' "$icon_path" >> "$sed_script"

for tpl in "$TEMPLATES_DIR"/*.tpl; do
    [ -f "$tpl" ] || continue
    filename=$(basename "$tpl" .tpl)
    output="$theme_dir/$filename"
    [ -f "$output" ] && continue
    sed -f "$sed_script" "$tpl" > "$output"
done
