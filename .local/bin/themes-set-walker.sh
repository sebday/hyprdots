#!/bin/bash
# Install Walker theme from ~/.themes/current/walker.css (generated from walker.css.tpl),
# ~/.themes/current/walker/style.css override, or legacy walker-style.css.
# Sets theme name in ~/.config/walker/config.toml.

set -e

CURRENT="${CURRENT_PATH:-$HOME/.themes/current}"
DEST_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/walker/themes"
THEME_NAME="${WALKER_THEME_NAME:-current}"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/walker/config.toml"

SRC=""
if [ -f "$CURRENT/walker/style.css" ]; then
	SRC="$CURRENT/walker/style.css"
elif [ -f "$CURRENT/walker.css" ]; then
	SRC="$CURRENT/walker.css"
elif [ -f "$CURRENT/walker-style.css" ]; then
	SRC="$CURRENT/walker-style.css"
else
	exit 0
fi

[ -f "$CFG" ] || exit 0

mkdir -p "$DEST_ROOT/$THEME_NAME"
cp "$SRC" "$DEST_ROOT/$THEME_NAME/style.css"

if grep -q '^theme = ' "$CFG"; then
	sed -i "s/^theme = .*/theme = \"$THEME_NAME\"/" "$CFG"
fi
