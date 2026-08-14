#!/usr/bin/env bash
# Reset evoshell settings panel values to defaults.

set -euo pipefail

BIN="${HOME}/.local/bin"

"$BIN/evo-font.sh" reset >/dev/null
"$BIN/evo-hypr-looks.sh" reset >/dev/null
"$BIN/evoshell-layout.sh" bar reset >/dev/null

echo '{"ok":true}'
