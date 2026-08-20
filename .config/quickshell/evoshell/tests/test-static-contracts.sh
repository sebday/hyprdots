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
check_absent 'Evoplayer'
check_absent 'evo\.bar\.media\.evo-player'
check_absent 'Evopanel/Evoplayer'
check_absent 'PlayerModule 1.0'
check_absent 'PlayerSideBrowsePanel'
check_absent 'historyPanelOpen'
check_absent 'browsePanelOpen'
check_absent 'migrate_intermediate_player_paths'
check_absent 'LEGACY_MPV_SOCKET'
check_absent 'evo-music\.sock'

# Canonical executables must exist
for exe in \
  evo-ipc evo-system evo-player evo-player-lib.sh \
  evo-bar-weather evo-bar-weather-bar evo-bar-github evo-bar-home-assistant evo-panel-player evo-panel-shopify \
  evo-tasks evo-calculator evo-clipboard evo-wallpaper evo-theme evo-menu-list evo-menu-warm \
  evo-bar-network-bar evo-bar-transmission-bar; do
  [[ -x "${bin}/${exe}" ]] || { echo "missing executable: ${exe}" >&2; fail=1; }
done

check_present 'evo-menu-list' "${root}/Evosys/Themes/CarouselOverlay.qml"
check_present 'evo-bar-network-bar' "${root}/Evobar/widgets/NetworkWidget.qml"
check_present 'evo-bar-transmission-bar' "${root}/Evobar/widgets/NetworkWidget.qml"
check_present 'evo\.bar\.popups\.notifications' "${root}/pluginManifest.js"
check_present 'NotificationsWidget' "${root}/Evobar/widgets/qmldir"
check_present 'NotificationsModule' "${root}/Evobar/Popups/Notifications/qmldir"
check_present 'NotificationCard' "${root}/Evobar/Popups/Notifications/qmldir"
check_present 'NotificationsToast' "${root}/Evobar/Popups/Notifications/qmldir"
check_present 'evo\.bar\.popups\.notifications' "${root}/Evobar/BarWidgetCatalog.qml"
check_present 'NotificationHistoryEntry' "${root}/Evobar/Popups/Notifications/qmldir"
check_present 'hiddenIdentities' "${root}/Evosys/Notifications/Service.qml"
check_present 'web\.telegram\.org' "${root}/Evosys/Notifications/Service.qml"
check_present 'messages\.google\.com' "${root}/Evosys/Notifications/Service.qml"
check_present '"notifications":' "${root}/shell.json"
check_present 'evo\.bar\.popups\.notifications' "${root}/shell.json"
check_absent 'NotificationArtworkCard' "${root}/Evosys/Notifications/Service.qml"

# Manifest ids
check_present 'evo\.bar\.popups\.weather' "${root}/pluginManifest.js"
check_present 'evo\.bar\.popups\.home-assistant' "${root}/pluginManifest.js"
check_present 'evo\.bar\.media\.player' "${root}/pluginManifest.js"
check_present 'EvoPlayerDashboardModule' "${root}/Evopanel/EvoPlayer/qmldir"
check_present 'EvoPlayerFiletreePanel' "${root}/Evopanel/EvoPlayer/panels/qmldir"
check_present 'EvoPlayerControls' "${root}/Evopanel/EvoPlayer/panels/qmldir"
check_present 'toggleFiletreePanel' "${root}/Evopanel/EvoPlayer/EvoPlayerDashboardModule.qml"
check_present 'statsPanelOpen' "${root}/Evopanel/EvoPlayer/EvoPlayerDashboardModule.qml"
check_present 'evo\.panel\.player' "${root}/pluginManifest.js"
check_present 'evo\.sys\.settings' "${root}/pluginManifest.js"
check_present '"exec": "~/.local/bin/evo-bar-weather-bar"' "${root}/shell.json"
check_present 'return requestDashboardOpen\(pluginId\)' "${root}/shell.qml"
check_present 'HomeAssistantWidget' "${root}/Evobar/widgets/TrayWidget.qml"
check_present 'homeAssistant' "${root}/shell.json"
check_present 'HOME_ASSISTANT_URL' "${bin}/evo-bar-home-assistant"
check_present 'HOME_ASSISTANT_TOKEN' "${bin}/evo-bar-home-assistant"

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

if rg -q 'HistoryRecapStatBox' "${root}/Commons/qmldir"; then
  echo "HistoryRecapStatBox exported"
else
  echo "HistoryRecapStatBox not exported" >&2
  fail=1
fi

# Player state paths
lib="${bin}/evo-player-lib.sh"
# shellcheck source=/dev/null
source "$lib"
[[ "$MUSIC_STATE" == *"/panel/player" ]] || { echo "bad MUSIC_STATE: $MUSIC_STATE" >&2; fail=1; }
[[ "$MUSIC_CACHE" == *"/evoshell/panel/player" ]] || { echo "bad MUSIC_CACHE: $MUSIC_CACHE" >&2; fail=1; }

exit "$fail"
