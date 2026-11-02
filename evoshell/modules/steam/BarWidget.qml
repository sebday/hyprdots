import QtQuick
import qs.commons
import qs.ui
import "Model.js" as Model

PanelHost {
  id: root
  moduleName: "evo.steam"
  panelUrl: Qt.resolvedUrl("Panel.qml")
  anchor: button

  function openSteam() {
    if (panel && panel.openSteam)
      panel.openSteam()
  }

  readonly property bool iconError: panel ? panel.iconError === true : false
  readonly property bool iconBusy: panel ? panel.iconBusy === true : false
  readonly property bool iconMuted: panel ? panel.iconMuted === true : false
  readonly property string tooltip: panel ? panel.barTooltip : "Steam"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  width: implicitWidth
  height: implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰓓"
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
        root.openSteam()
        return
      }
      root.togglePanel()
    }
  }
}
