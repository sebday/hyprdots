import QtQuick
import qs.ui
import "Model.js" as Model

PanelHost {
  id: root
  moduleName: "evo.webtheme"
  panelUrl: Qt.resolvedUrl("Panel.qml")
  anchor: button

  readonly property bool iconError: panel ? panel.iconError === true : false
  readonly property bool iconBusy: panel ? panel.iconBusy === true : false
  readonly property bool iconMuted: panel ? panel.iconMuted === true : false
  readonly property string tooltip: panel ? panel.barTooltip : "Webtheme"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  width: implicitWidth
  height: implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰸌"
    active: root.iconError
    useActiveColor: root.iconError
    dimmed: root.iconMuted && !root.iconError
    tooltipText: Model.plain(root.tooltip)

    onPressed: function() {
      if (!root.bar) return
      root.togglePanel()
    }
  }
}
