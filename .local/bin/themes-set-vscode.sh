#!/bin/bash
# Install generated VS Code theme and set workbench.colorTheme (Cursor, Code, Codium)
# Uses ~/.themes/current/vscode-theme/ from themes-generate-vscode.sh

SRC="$HOME/.themes/current/vscode-theme"
[ ! -f "$SRC/package.json" ] && exit 0

publisher=$(jq -r '.publisher // "sebday"' "$SRC/package.json")
name=$(jq -r '.name // empty' "$SRC/package.json")
version=$(jq -r '.version // "1.0.0"' "$SRC/package.json")
theme_label=$(jq -r '.contributes.themes[0].label // empty' "$SRC/package.json")
[ -z "$name" ] || [ -z "$theme_label" ] && exit 0

ext_id="${publisher}.${name}-${version}"

set_theme() {
  local ext_dir="$1"
  local settings="$2"
  [ -z "$ext_dir" ] || [ -z "$settings" ] && return 0
  [ -d "$(dirname "$settings")" ] || return 0

  mkdir -p "$ext_dir"
  rm -rf "$ext_dir/$ext_id"
  cp -r "$SRC" "$ext_dir/$ext_id"

  [ -f "$settings" ] || echo '{}' > "$settings"
  safe_label=$(printf '%s' "$theme_label" | sed 's/[&\]/\\&/g')
  if grep -q '"workbench.colorTheme"' "$settings"; then
    sed -i --follow-symlinks -E "s/(\"workbench\\.colorTheme\"[[:space:]]*:[[:space:]]*\")[^\"]*(\")/\\1${safe_label}\\2/" "$settings"
  else
    sed -i --follow-symlinks -E '0,/\{/{s/\{/{\n    "workbench.colorTheme": "'"$safe_label"'",/}' "$settings"
  fi
}

set_theme "$HOME/.cursor/extensions" "$HOME/.config/Cursor/User/settings.json"
set_theme "$HOME/.vscode/extensions" "$HOME/.config/Code/User/settings.json"
set_theme "$HOME/.vscode-oss/extensions" "$HOME/.config/VSCodium/User/settings.json"
