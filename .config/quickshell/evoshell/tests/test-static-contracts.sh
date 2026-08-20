#!/usr/bin/env bash
set -euo pipefail

root="${HOME}/.config/quickshell/evoshell"
bin="${HOME}/.local/bin"
hypr="${HOME}/.config/hypr"
fail=0

check_absent() {
  local pattern="$1"
  if rg -q "$pattern" "$root" "$hypr" "$bin"/evo-* 2>/dev/null; then
    echo "forbidden pattern still present: $pattern" >&2
    fail=1
  fi
}

check_present() {
  local pattern="$1"
  if ! rg -q "$pattern" "$2" 2>/dev/null; then
    echo "expected pattern missing: $pattern in $2" >&2
    fail=1
  fi
}

# Intermediate naming must not remain in contracts
check_absent 'plugins/'
check_absent 'evobar\.'
check_absent 'evopanel\.'
check_absent 'evosys\.'
check_absent 'evoside\.'
check_absent 'evobar-'
check_absent 'evopanel-'
check_absent 'evoside-'
check_absent 'evosys-'
check_absent 'evoshell-'
check_absent 'evo-sys-menu'

# Canonical executables must exist
for exe in \
  evo-ipc evo-system evo-player evo-player-lib.sh \
  evo-bar-weather evo-bar-weather-bar evo-bar-github evo-panel-player evo-panel-shopify \
  evo-tasks evo-calculator evo-clipboard evo-wallpaper evo-theme evo-menu-list evo-menu-warm; do
  [[ -x "${bin}/${exe}" ]] || { echo "missing executable: ${exe}" >&2; fail=1; }
done

check_present 'evo-menu-list' "${root}/Evosys/Themes/CarouselOverlay.qml"
check_present 'evo-bar-network-bar' "${root}/Evobar/widgets/NetworkWidget.qml"

# Manifest ids
check_present 'evo\.bar\.popups\.weather' "${root}/pluginManifest.js"
check_present 'evo\.panel\.player' "${root}/pluginManifest.js"
check_present 'evo\.sys\.settings' "${root}/pluginManifest.js"
check_present '"exec": "~/.local/bin/evo-bar-weather-bar"' "${root}/shell.json"
check_present 'return requestDashboardOpen\(pluginId\)' "${root}/shell.qml"

# Design tokens
if rg -q 'opacityEmphasis2' "${root}/Commons/Theme.qml"; then
  echo "Theme.opacityEmphasis2 defined"
else
  echo "missing Theme.opacityEmphasis2" >&2
  fail=1
fi

if rg -q 'FieldsetLegendRow' "${root}/Commons/qmldir"; then
  echo "FieldsetLegendRow exported"
else
  echo "FieldsetLegendRow not exported" >&2
  fail=1
fi

# Player state paths
lib="${bin}/evo-player-lib.sh"
# shellcheck source=/dev/null
source "$lib"
[[ "$MUSIC_STATE" == *"/panel/player" ]] || { echo "bad MUSIC_STATE: $MUSIC_STATE" >&2; fail=1; }
[[ "$MUSIC_CACHE" == *"/evoshell/panel/player" ]] || { echo "bad MUSIC_CACHE: $MUSIC_CACHE" >&2; fail=1; }

exit "$fail"
