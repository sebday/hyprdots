#!/bin/bash
# Copy theme files to config per manifest (replaces trivial themes-set-* copy scripts)

THEME_DIR="${THEME_DIR:-$HOME/.themes}"
CURRENT="${CURRENT_PATH:-$THEME_DIR/current}"
CONFIG="$HOME/.config"

copy_if() {
    local src="$1" dest="$2"
    [ -f "$CURRENT/$src" ] || return 0
    mkdir -p "$(dirname "$dest")"
    cp "$CURRENT/$src" "$dest"
}

copy_if mako.ini "$CONFIG/mako/config"
copy_if hyprland.conf "$CONFIG/hypr/theme.conf"

# btop: copy theme + update btop.conf
if [ -f "$CURRENT/btop.theme" ]; then
    mkdir -p "$CONFIG/btop/themes"
    cp "$CURRENT/btop.theme" "$CONFIG/btop/themes/current.theme"
    [ -f "$CONFIG/btop/btop.conf" ] && sed -i 's|^color_theme =.*|color_theme = "current"|' "$CONFIG/btop/btop.conf"
fi
