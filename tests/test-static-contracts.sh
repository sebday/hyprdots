#!/usr/bin/env bash
set -euo pipefail

root="${EVOSHELL_ROOT:-$HOME/projects/evoshell}"
shell_json="${root}/config/shell.json"
bin="${EVOSHELL_BIN:-${root}/bin}"
evo_bin="${EVOPLAYER_LIB:-${HOME}/.local/lib/evoplayer}"
skip_evoplayer="${EVO_SKIP_EVOPLAYER:-0}"
fail=0

source_paths=(
  "${root}/commons"
  "${root}/evobar"
  "${root}/evopanels"
  "${root}/evoside"
  "${root}/evosys"
  "${root}/shell.qml"
  "${root}/pluginManifest.js"
  "${shell_json}"
  "${root}/config/overrides.example.json"
  "${bin}"/evo-*
)

check_absent() {
  local pattern="$1"
  shift || true
  local -a targets=("$@")
  if ((${#targets[@]} == 0)); then
    targets=("${source_paths[@]}")
  fi
  if rg -q "$pattern" "${targets[@]}" 2>/dev/null; then
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
check_absent 'evopanels/plugins/'
check_absent 'evobar\.'
check_absent 'evopanel\.'
check_absent 'evosys\.'
check_absent 'evoside\.'
check_absent 'evobar-'
check_absent 'evopanel-'
check_absent 'evoside-'
check_absent 'evosys-'
check_absent 'evo\.bar\.media\.evo-player'
check_absent 'evopanel/Evoplayer'
check_absent '\.local/bin/evo-player'
check_absent '\.local/bin/evo-'
check_absent 'evo\.bar\.popups\.'
check_absent 'evo\.panel\.'
check_absent 'BarHoverPopup'
check_absent 'HoverPopupHeader'
check_absent 'setHoverPopup'
check_absent 'isHoverPopupPinned'
check_absent 'evosys/[A-Z][a-zA-Z]+/'
check_absent 'evoside/[A-Z][a-zA-Z]+/'
check_absent 'evopanels/[A-Z][a-zA-Z]+/'
check_absent 'evobar/[A-Z][a-zA-Z]+/'
check_absent 'PlayerModule 1.0'
check_absent 'PlayerSideBrowsePanel'
check_absent 'historyPanelOpen'
check_absent 'browsePanelOpen'
check_absent 'migrate_intermediate_player_paths'
check_absent 'LEGACY_MPV_SOCKET'
if rg -q 'hypr-looks-overrides' \
    "${root}/bin/evo-hyprland" \
    "${root}/hypr/looks.lua" \
    "${root}/commons/Theme.qml" 2>/dev/null; then
  echo "forbidden pattern still present: hypr-looks-overrides.lua in hypr looks consumers" >&2
  fail=1
fi
check_absent 'evoplayerlib|evoplayerartsearch|evoplayerstandardize|evoplayervinyl|testevoplayer|library-sqlite\.sh|history-report\.py'
check_absent 'python3'
check_absent 'EvoPlayer'
check_absent 'sebday'
check_absent 'seb@192\.168'
check_absent 'diy-buildingsupplies'
check_absent 'thegoodsheet-uk'
check_absent 'FieldsetLegendRow'
check_absent 'HistoryRecapStatBox'
check_absent 'HoverPanelStatsGrid'
check_absent 'MenuBarWidget'
check_absent 'ShopifyTrayWidget' "${root}/evobar/widgets/TrayWidget.qml"
check_absent 'evo\.panels\.shopify' "${root}/pluginManifest.js"
check_absent 'evo-panel-shopify' "${bin}"
check_absent 'evo\.bar\.media\.audio'
check_absent '\.local/bin/evoshell/' "${bin}/evo-menu-list"

# Canonical executables must exist
for exe in \
  evo _system _ipc evo-config evo-config-lib \
  evo-bar-weather evo-bar-weather-bar evo-bar-github evo-bar-home-assistant \
  evo-panel-player \
  evo-tasks evo-calculator evo-clipboard evo-wallpaper evo-theme evo-menu-list evo-menu-warm \
  evo-bar-network-bar evo-bar-transmission-bar evo-bar-steam; do
  [[ -x "${bin}/${exe}" ]] || { echo "missing executable: ${exe}" >&2; fail=1; }
done

if [[ "$skip_evoplayer" != "1" ]]; then
  [[ -x "${evo_bin}/evoplayer" ]] || { echo "missing executable: evoplayer (${evo_bin}/evoplayer)" >&2; fail=1; }
  player_lib="${HOME}/.local/lib/evoplayer/evoplayer-lib"
  [[ -x "${player_lib}" ]] || { echo "missing executable: evoplayer-lib (${player_lib})" >&2; fail=1; }
  [[ -e "${root}/vendor/evoplayer/qml/panel/Player.qml" ]] || { echo "missing vendor/evoplayer link (${root}/vendor/evoplayer)" >&2; fail=1; }
fi

check_present 'evo-menu-list' "${root}/evosys/themes/CarouselOverlay.qml"
check_present 'evo-bar-network-bar' "${root}/evobar/widgets/NetworkWidget.qml"
check_present 'evo-bar-transmission-bar' "${root}/evobar/widgets/NetworkWidget.qml"
check_present 'evo\.panels\.notifications' "${root}/pluginManifest.js"
check_present 'NotificationsWidget' "${root}/evobar/widgets/qmldir"
check_present 'NotificationsModule' "${root}/evopanels/notifications/qmldir"
check_present 'NotificationCard' "${root}/evopanels/notifications/qmldir"
check_present 'NotificationsToast' "${root}/evopanels/notifications/qmldir"
check_present 'evo\.panels\.notifications' "${root}/evobar/BarWidgetCatalog.qml"
check_present 'NotificationHistoryEntry' "${root}/evopanels/notifications/qmldir"
check_present 'hiddenIdentities' "${root}/evosys/notifications/Service.qml"
check_present 'web\.telegram\.org' "${root}/evosys/notifications/Service.qml"
check_present 'messages\.google\.com' "${root}/evosys/notifications/Service.qml"
check_present '"notifications":' "${shell_json}"
check_absent 'NotificationArtworkCard' "${root}/evosys/notifications/Service.qml"

# Manifest ids
check_present 'evo\.panels\.weather' "${root}/pluginManifest.js"
check_present 'evo\.panels\.homeassistant' "${root}/pluginManifest.js"
if [[ "$skip_evoplayer" != "1" ]]; then
  check_present 'DashboardModule' "${root}/vendor/evoplayer/qml/panel/qmldir"
  check_present 'FiletreePanel' "${root}/vendor/evoplayer/qml/panel/panels/qmldir"
  check_present 'Controls' "${root}/vendor/evoplayer/qml/panel/panels/qmldir"
  check_present 'toggleFiletreePanel' "${root}/vendor/evoplayer/qml/panel/DashboardModule.qml"
  check_present 'statsPanelOpen' "${root}/vendor/evoplayer/qml/panel/DashboardModule.qml"
fi
check_present 'evo\.panels\.player' "${root}/pluginManifest.js"
check_present 'evo\.sys\.settings' "${root}/pluginManifest.js"
check_present 'userOverridePath' "${root}/shell.qml"
check_present 'deepMerge' "${root}/commons/Util.qml"
check_present 'return requestDashboardOpen\(pluginId\)' "${root}/shell.qml"
check_present 'HomeAssistantWidget' "${root}/evobar/widgets/TrayWidget.qml"
check_present 'extensionTrayWidgets' "${root}/shell.qml"
check_present 'pluginOverlayPath' "${root}/shell.qml"
[[ -f "${root}/config/plugins/manifest.example.json" ]] || { echo "missing plugin overlay example" >&2; fail=1; }
check_present 'Home Assistant' "${root}/evosys/settings/SettingsModule.qml"
check_present 'homeAssistant' "${root}/config/overrides.example.json"
check_present 'HOME_ASSISTANT_URL' "${bin}/evo-bar-home-assistant"
check_present 'HOME_ASSISTANT_TOKEN' "${bin}/evo-bar-home-assistant"
check_present 'BarHoverPanel' "${root}/commons/qmldir"
check_present 'SettingsWidget' "${root}/evobar/widgets/qmldir"
check_present 'evo\.sys\.media\.audio' "${root}/pluginManifest.js"
check_present 'evo\.bar\.volume' "${root}/evobar/BarWidgetCatalog.qml"
check_present 'motionFast' "${root}/commons/Theme.qml"
check_present 'evoCommand' "${root}/commons/Util.qml"
check_absent 'evo-ipc' "${root}/bin"
if [[ -e "${bin}/evo-system" ]]; then
  echo "forbidden executable present: ${bin}/evo-system" >&2
  fail=1
fi
check_present 'maxContentHeight' "${root}/commons/CenteredOverlay.qml"
check_present 'settingsScroll' "${root}/evosys/settings/SettingsModule.qml"
check_present 'SettingsTabBar' "${root}/commons/qmldir"
check_present 'settingsTabs' "${root}/evosys/settings/SettingsModule.qml"
settings_qml="${root}/evosys/settings/SettingsModule.qml"
settings_depth="$(python3 -c "
from pathlib import Path
depth = 0
for ch in Path('${settings_qml}').read_text():
    if ch == '{': depth += 1
    elif ch == '}': depth -= 1
print(depth)
")"
if [[ "$settings_depth" != "0" ]]; then
  echo "SettingsModule.qml brace imbalance: depth=$settings_depth" >&2
  fail=1
fi
if ! rg -Fq 'settingsPanelWidth: systemPanelWidth' "${root}/commons/Theme.qml" 2>/dev/null; then
  echo "expected settingsPanelWidth to match systemPanelWidth in Theme.qml" >&2
  fail=1
fi
check_absent 'settingsPanelWidth: systemPanelWidth * 2'
check_present 'evo-storage-lib' "${root}/bin/evo-config-lib"
check_absent 'evo-system-backup'
if [[ -e "${bin}/evo-shell" ]]; then
  echo "forbidden executable present: ${bin}/evo-shell" >&2
  fail=1
fi

# Design tokens
if rg -q 'opacityEmphasis2' "${root}/commons/Theme.qml"; then
  echo "Theme.opacityEmphasis2 defined"
else
  echo "missing Theme.opacityEmphasis2" >&2
  fail=1
fi

if rg -q 'readonly property real opacityEmphasis: opacityEmphasis2' "${root}/commons/Theme.qml"; then
  echo "Theme.opacityEmphasis alias defined"
else
  echo "missing Theme.opacityEmphasis alias" >&2
  fail=1
fi

# Player state paths
if [[ "$skip_evoplayer" != "1" ]]; then
  lib="${player_lib}"
  # shellcheck source=/dev/null
  source "$lib"
  [[ "$MUSIC_STATE" == *"/panel/player" ]] || { echo "bad MUSIC_STATE: $MUSIC_STATE" >&2; fail=1; }
  [[ "$MUSIC_CACHE" == *"/evoshell/panel/player" ]] || { echo "bad MUSIC_CACHE: $MUSIC_CACHE" >&2; fail=1; }
fi

exit "$fail"
