import QtQuick
import Quickshell
import Quickshell.Io
import qs.ui
import "Model.js" as Model

PanelHost {
  id: root
  moduleName: "evo.secmon"
  panelUrl: Qt.resolvedUrl("Panel.qml")
  anchor: button

  function openReport() {
    if (panel && panel.openReport)
      panel.openReport("")
  }

  readonly property bool iconError: panel ? panel.iconError === true : false
  readonly property bool iconMuted: panel ? panel.iconMuted === true : true
  readonly property string iconGlyph: panel ? panel.iconGlyph : String.fromCodePoint(0xF0499)
  readonly property string tooltip: panel ? panel.barTooltip : "Security"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  width: implicitWidth
  height: implicitHeight

  IpcHandler {
    enabled: root.ownsIpc
    target: "evo.secmon"

    function refresh(): void { root.broadcast("refresh") }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.iconGlyph
    active: root.iconError
    useActiveColor: root.iconError
    dimmed: root.iconMuted && !root.iconError
    tooltipText: Model.plain(root.tooltip)

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.MiddleButton) root.openReport()
      else if (b === Qt.RightButton) root.refresh()
      else root.togglePanel()
    }
  }
}
