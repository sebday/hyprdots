import QtQuick
import Quickshell
import Quickshell.Io
import qs.commons
import qs.ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "evo.secmon"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  function openReport() {
    if (panelLoader.item && panelLoader.item.openReport) panelLoader.item.openReport("")
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  readonly property bool iconError: panelLoader.item ? panelLoader.item.iconError === true : false
  readonly property bool iconMuted: panelLoader.item ? panelLoader.item.iconMuted === true : true
  readonly property string iconGlyph: panelLoader.item ? panelLoader.item.iconGlyph : String.fromCodePoint(0xF0499)
  readonly property string tooltip: panelLoader.item ? panelLoader.item.barTooltip : "Security"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  width: implicitWidth
  height: implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
    onStatusChanged: {
      if (status === Loader.Error)
        console.warn("evo.secmon panel failed to load")
    }
  }

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
