import QtQuick
import qs.commons
import qs.ui
import "Model.js" as Model

PanelHost {
  id: root
  moduleName: "evo.github"
  panelUrl: Qt.resolvedUrl("Panel.qml")
  anchor: button

  readonly property bool iconError: panel ? panel.iconError === true : false
  readonly property bool iconBusy: panel ? panel.iconBusy === true : false
  readonly property bool iconMuted: panel ? panel.iconMuted === true : false
  readonly property string tooltip: panel ? panel.barTooltip : "GitHub contributions"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  width: implicitWidth
  height: implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    active: root.iconError
    useActiveColor: root.iconError
    dimmed: root.iconMuted && !root.iconError && !root.iconBusy
    tooltipText: Model.plain(root.tooltip)
    opacity: root.iconBusy && !root.iconError && !root.iconMuted ? iconPulse.pulseOpacity : 1

    BarIconPulse {
      id: iconPulse
      running: root.iconBusy && !root.iconError && !root.iconMuted
    }

    onPressed: function() {
      if (!root.bar) return
      root.togglePanel()
    }
  }
}
