#!/bin/bash
# Activate GTK theme (run after swap so current/ has new theme)
# Updates settings.ini, GTK4 symlinks, and triggers gsettings reload for Thunar etc.

THEME_DIR="${THEME_DIR:-$HOME/.themes}"
gtk_theme="current"

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

# Toggle gsettings to force GTK hot-reload (Thunar etc)
gsettings set org.gnome.desktop.interface gtk-theme "" 2>/dev/null || true
sleep 0.5
gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" 2>/dev/null || true
