#!/usr/bin/env bash
# Back-compat wrapper for evo-shell-layout.sh panel.

set -euo pipefail
exec "${HOME}/.local/bin/evo-shell-layout.sh" panel "$@"
