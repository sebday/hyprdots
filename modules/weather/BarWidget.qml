import QtQuick
import qs.commons
import qs.ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "evo.weather"

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
  readonly property bool iconBusy: panelLoader.item ? panelLoader.item.iconBusy === true : false
  readonly property bool iconMuted: false
  readonly property string tooltip: panelLoader.item ? panelLoader.item.barTooltip : "Weather"
  readonly property string valueText: panelLoader.item ? panelLoader.item.barValue : ""
  readonly property real openPanelIndicatorWidth: button.labelWidth

  visible: valueText !== ""
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
