#!/bin/bash
# Write libadwaita palette gtk.css and signal Nautilus to reload.

THEME="${HOME}/.local/state/omarchy/current/theme"
GTK_DIR="${HOME}/.config/gtk-4.0"
PALETTE_SRC="${THEME}/libadwaita-gtk.css"
GTK_CSS="${GTK_DIR}/gtk.css"

[[ -f "$PALETTE_SRC" ]] || exit 0

theme_slug="${1:-}"
if [[ -z $theme_slug ]]; then
	theme_slug=$(cat "${HOME}/.local/state/omarchy/current/theme.name" 2>/dev/null || basename "$THEME")
fi

gtk_css_current=false
if [[ -f $GTK_CSS ]] && head -n 1 "$GTK_CSS" | grep -qF "/* omarchy-theme: ${theme_slug} */"; then
	if (( $(wc -c <"$GTK_CSS") < 10000 )); then
		gtk_css_current=true
	fi
fi

if $gtk_css_current; then
	pkill -USR1 -x nautilus 2>/dev/null || true
	exit 0
fi

# Nautilus reads palette from current/theme; signal before the gtk.css write.
pkill -USR1 -x nautilus 2>/dev/null || true

mkdir -p "$GTK_DIR"

{
	printf '/* omarchy-theme: %s */\n' "$theme_slug"
	cat "$PALETTE_SRC"
} >"${GTK_CSS}.new"

mv -f "${GTK_CSS}.new" "$GTK_CSS"
chmod 644 "$GTK_CSS"
