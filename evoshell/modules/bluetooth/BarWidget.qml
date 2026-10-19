import QtQuick
import qs.commons
import qs.ui

BarWidget {
  id: root
  moduleName: "evo.bluetooth"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  readonly property var panelItem: panelLoader.item
  readonly property bool opened: panelItem ? panelItem.opened === true : false

  function open() {
    if (panelItem && panelItem.openFromHotkey) panelItem.openFromHotkey()
  }

  function close() {
    if (panelItem && panelItem.close) panelItem.close()
  }

  readonly property bool popoutSwitchClosing: panelItem ? panelItem.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelItem) panelItem.closeForPopoutSwitch()
  }

  readonly property bool iconError: false
  readonly property bool iconBusy: panelItem ? panelItem.iconBusy === true : false
  readonly property bool iconMuted: panelItem ? panelItem.iconMuted === true : true
  readonly property string iconGlyph: panelItem ? panelItem.iconGlyph : "󰂲"
  readonly property string tooltip: panelItem ? panelItem.barTooltip : "Bluetooth"

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
  }

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
