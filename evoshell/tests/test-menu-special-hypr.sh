#!/usr/bin/env bash
# menu-special hyprctl integration (eval dispatch required on current Hyprland).

set -euo pipefail

root="${EVOSHELL_ROOT:-$HOME/projects/evoshell}"
script="${root}/bin/evo-hyprland"

grep -q 'hl.dsp.workspace.toggle_special("evomenu")' "$script" || {
  echo "evo-hyprland missing menu special eval dispatch" >&2
  exit 1
}

grep -q 'menu-special' "$script" || {
  echo "evo-hyprland missing menu-special subcommand" >&2
  exit 1
}

echo "menu-special hyprctl ok"
