import QtQuick
import Quickshell.Services.SystemTray
import qs.commons
import qs.ui
import "Model.js" as Model

PanelHost {
  id: root
  moduleName: "evo.insync"
  panelUrl: Qt.resolvedUrl("Panel.qml")
  anchor: button

  function showFloating() {
    if (panel && panel.showFloating)
      panel.showFloating()
  }

  // Insync's tray icon changes as soon as sync state changes. The panel only
  // polls while it is open, so the bar follows the tray item instead.
  readonly property var trayItem: {
    var values = SystemTray.items.values || []
    for (var i = 0; i < values.length; i++) {
      var item = values[i]
      if (!item)
        continue
      var id = String(item.id || "").toLowerCase()
      var title = String(item.title || "").toLowerCase()
      if (id === "insync" || title.indexOf("insync") === 0)
        return item
    }
    return null
  }
  readonly property string trayIconName: trayItem ? String(trayItem.icon || "").toLowerCase() : ""
  readonly property bool trayLive: trayIconName !== ""

  readonly property bool iconError: trayLive
    ? (trayIconName.indexOf("alert") >= 0 || trayIconName.indexOf("error") >= 0 || trayItem.status === Status.NeedsAttention)
    : (panel ? panel.iconError === true : false)
  readonly property bool iconBusy: trayLive
    ? trayIconName.indexOf("syncing") >= 0
    : (panel ? panel.iconBusy === true : false)
  readonly property bool iconMuted: trayLive
    ? (trayIconName.indexOf("paused") >= 0 || trayIconName.indexOf("offline") >= 0)
    : (panel ? panel.iconMuted === true : false)
  readonly property string tooltip: {
    if (trayLive) {
      if (trayIconName.indexOf("syncing") >= 0) return "Syncing"
      if (trayIconName.indexOf("paused") >= 0) return "Paused"
      if (trayIconName.indexOf("offline") >= 0) return "Offline"
      if (iconError) return "Sync error"
      if (trayIconName.indexOf("synced") >= 0) return "Synced"
    }
    return panel ? panel.barTooltip : "Insync"
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  width: implicitWidth
  height: implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰋼"
    active: root.iconError
    useActiveColor: root.iconError
    dimmed: root.iconMuted && !root.iconError && !root.iconBusy
    tooltipText: Model.plain(root.tooltip)
    opacity: !hasVisualContent || concealed ? 0 : (root.iconError ? 1 : (root.iconMuted ? 0.45 : (root.iconBusy ? iconPulse.pulseOpacity : 1)))

    BarIconPulse {
      id: iconPulse
      running: root.iconBusy && !root.iconError && !root.iconMuted
    }

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.MiddleButton) {
        root.showFloating()
        return
      }
      if (b === Qt.RightButton) {
        root.refresh()
        return
      }
      root.togglePanel()
    }
  }
}
