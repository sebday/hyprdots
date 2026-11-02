import QtQuick
import qs.commons
import qs.ui

PanelHost {
  id: root
  moduleName: "evo.bluetooth"
  panelUrl: Qt.resolvedUrl("Panel.qml")
  anchor: button

  readonly property bool iconError: false
  readonly property bool iconBusy: panel ? panel.iconBusy === true : false
  readonly property bool iconMuted: panel ? panel.iconMuted === true : true
  readonly property string iconGlyph: panel ? panel.iconGlyph : "󰂲"
  readonly property string tooltip: panel ? panel.barTooltip : "Bluetooth"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  width: implicitWidth
  height: implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.iconGlyph
    active: root.iconError
    useActiveColor: root.iconError
    dimmed: root.iconMuted
    tooltipText: root.tooltip
    opacity: root.iconBusy && !root.iconMuted ? iconPulse.pulseOpacity : 1

    BarIconPulse {
      id: iconPulse
      running: root.iconBusy && !root.iconMuted
    }

    onPressed: function() {
      if (!root.bar) return
      root.togglePanel()
    }
  }
}
