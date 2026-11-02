import QtQuick
import qs.commons
import qs.ui
import "Model.js" as Model

PanelHost {
  id: root
  moduleName: "evo.weather"
  panelUrl: Qt.resolvedUrl("Panel.qml")
  anchor: button

  readonly property bool iconError: panel ? panel.iconError === true : false
  readonly property bool iconBusy: panel ? panel.iconBusy === true : false
  readonly property bool iconMuted: false
  readonly property string tooltip: panel ? panel.barTooltip : "Weather"
  readonly property string valueText: panel ? panel.barValue : ""
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
    hasVisualContent: root.valueText !== ""
    horizontalMargin: 8.75
    active: root.iconError
    useActiveColor: root.iconError
    dimmed: root.iconMuted && !root.iconError && !root.iconBusy
    tooltipText: Model.plain(root.tooltip)
    opacity: root.iconBusy && !root.iconError ? iconPulse.pulseOpacity : 1

    BarIconPulse {
      id: iconPulse
      running: root.iconBusy && !root.iconError
    }

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }
  }
}
