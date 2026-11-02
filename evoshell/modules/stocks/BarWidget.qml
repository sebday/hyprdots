import QtQuick
import qs.ui
import "Model.js" as Model

PanelHost {
  id: root
  moduleName: "evo.stocks"
  panelUrl: Qt.resolvedUrl("Panel.qml")
  anchor: button

  readonly property bool iconError: panel ? panel.iconError === true : false
  readonly property bool iconBusy: panel ? panel.iconBusy === true : false
  readonly property bool iconMuted: panel ? panel.iconMuted === true : false
  readonly property string tooltip: panel ? panel.barTooltip : "Stocks"
  readonly property string valueText: panel ? panel.barValue : ""
  readonly property string iconText: panel ? (panel.barIcon || "") : ""
  readonly property real openPanelIndicatorWidth: button.labelWidth

  visible: valueText !== ""
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  width: implicitWidth
  height: implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.valueText
    leadingIcon: root.iconText
    hasVisualContent: root.valueText !== ""
    horizontalMargin: 8.75
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
