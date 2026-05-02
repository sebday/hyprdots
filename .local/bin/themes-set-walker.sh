#!/bin/bash
# Install Walker theme CSS as a symlink: ~/.config/walker/themes/<name>/style.css → source file.
# Prefers ~/.themes/current/walker/style.css, then walker.css, then walker-style.css.

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
# Single source of truth in ~/.themes/current — Walker only reads style.css in this folder.
ln -sfn "$(realpath "$SRC")" "$DEST_ROOT/$THEME_NAME/style.css"

if grep -q '^theme = ' "$CFG"; then
	sed -i "s/^theme = .*/theme = \"$THEME_NAME\"/" "$CFG"
fi
