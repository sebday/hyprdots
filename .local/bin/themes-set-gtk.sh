#!/bin/bash
# Generate GTK theme from shared base + colors.toml, then apply
# Uses THEME_PATH for build dir (default: current). Symlinks always point to current/.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/themes-common.sh"

THEME_DIR="${THEME_DIR:-$HOME/.themes}"
THEME_PATH="${THEME_PATH:-$THEME_DIR/current}"
SHARED_GTK="$THEME_DIR/shared"

[ ! -d "$THEME_PATH" ] && exit 0
[ ! -f "$THEME_PATH/colors.toml" ] && exit 0
[ ! -d "$SHARED_GTK/gtk-3.0" ] && exit 0

toml="$THEME_PATH/colors.toml"

# Copy shared GTK base into theme dir
cp -r "$SHARED_GTK/gtk-3.0" "$THEME_PATH/"
cp -r "$SHARED_GTK/gtk-4.0" "$THEME_PATH/"

new_bg_primary=$(toml_val background "$toml")
new_bg_secondary=$(toml_val color0 "$toml")
new_text=$(toml_val foreground "$toml")
new_accent=$(toml_val accent "$toml")
new_blue=$(toml_val color4 "$toml")
new_cyan=$(toml_val color6 "$toml")
new_purple=$(toml_val color5 "$toml")
new_pink=$(toml_val color13 "$toml")
new_green=$(toml_val color2 "$toml")
new_orange=$(toml_val color3 "$toml")
new_red=$(toml_val color1 "$toml")

for gtk_css in "$THEME_PATH/gtk-3.0/gtk.css" "$THEME_PATH/gtk-3.0/gtk-dark.css" "$THEME_PATH/gtk-4.0/gtk.css" "$THEME_PATH/gtk-4.0/gtk-dark.css"; do
    [ -f "$gtk_css" ] || continue
    sed -i "s/#313244/$new_bg_secondary/gi" "$gtk_css"
    sed -i "s/#292c3c/$new_bg_secondary/gi" "$gtk_css"
    sed -i "s/#4a4b5a/$new_bg_secondary/gi" "$gtk_css"
    sed -i "s/#232634/$new_bg_secondary/gi" "$gtk_css"
    sed -i "s/#2b2b3a/$new_bg_secondary/gi" "$gtk_css"
    sed -i "s/#1e1e2e/$new_bg_primary/gi" "$gtk_css"
    sed -i "s/#181825/$new_bg_secondary/gi" "$gtk_css"
    sed -i "s/#cdd6f4/$new_text/gi" "$gtk_css"
    sed -i "s/#74c7ec/$new_accent/gi" "$gtk_css"
    sed -i "s/#89b4fa/$new_blue/gi" "$gtk_css"
    sed -i "s/#94e2d5/$new_cyan/gi" "$gtk_css"
    sed -i "s/#cba6f7/$new_purple/gi" "$gtk_css"
    sed -i "s/#f5c2e7/$new_pink/gi" "$gtk_css"
    sed -i "s/#a6e3a1/$new_green/gi" "$gtk_css"
    sed -i "s/#fab387/$new_orange/gi" "$gtk_css"
    sed -i "s/#f38ba8/$new_red/gi" "$gtk_css"
done

# Set gtk-theme-name to "current" so GTK loads from ~/.themes/current/gtk-*
# Toggle away and back to force GTK hot-reload (Thunar etc) when value would otherwise stay "current"
gtk_theme="current"
gsettings set org.gnome.desktop.interface gtk-theme ""
gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme"

# Update settings.ini
if [ -f "$HOME/.config/gtk-3.0/settings.ini" ]; then
    sed -i "s/^gtk-theme-name=.*/gtk-theme-name=$gtk_theme/" "$HOME/.config/gtk-3.0/settings.ini"
fi
if [ -f "$HOME/.config/gtk-4.0/settings.ini" ]; then
    sed -i "s/^gtk-theme-name=.*/gtk-theme-name=$gtk_theme/" "$HOME/.config/gtk-4.0/settings.ini"
fi

# Link GTK 4 CSS and assets (always point to current/ for live path)
current_gtk="$THEME_DIR/current/gtk-4.0"
if [ -d "$current_gtk" ]; then
    mkdir -p "$HOME/.config/gtk-4.0"
    ln -sf "$current_gtk/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
    [ -f "$current_gtk/gtk-dark.css" ] && ln -sf "$current_gtk/gtk-dark.css" "$HOME/.config/gtk-4.0/gtk-dark.css"
    [ -d "$current_gtk/assets" ] && ln -sf "$current_gtk/assets" "$HOME/.config/gtk-4.0/assets"
fi
