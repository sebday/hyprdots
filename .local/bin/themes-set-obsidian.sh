#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/themes-common.sh"
process_theme_template "$THEME_DIR/current" "obsidian.css"
themes_sync_obsidian_modular
