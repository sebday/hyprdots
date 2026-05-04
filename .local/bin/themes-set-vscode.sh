#!/bin/bash
# Install generated VS Code theme and set workbench.colorTheme (Cursor, Code, Codium)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/themes-common.sh"
themes_sync_vscode_generated_extension "$@"
