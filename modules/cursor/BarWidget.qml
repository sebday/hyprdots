import QtQuick
import Quickshell
import Quickshell.Io
import qs.commons
import qs.ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "evo.cursor"


  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh(true)
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  function openDashboard() {
    if (panelLoader.item && panelLoader.item.openDashboard) {
      panelLoader.item.openDashboard()
      return
    }
    Quickshell.execDetached(["xdg-open", "https://cursor.com/dashboard/spending"])
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
  readonly property bool iconMuted: panelLoader.item ? panelLoader.item.iconMuted === true : false
  readonly property string tooltip: panelLoader.item ? panelLoader.item.barTooltip : "Cursor usage"
  readonly property string valueText: panelLoader.item ? panelLoader.item.barValue : ""
  property color themeGreen: Theme.ansiFallback("green")
  property color themeBlue: Theme.ansiFallback("blue")
  property color themeOrange: Theme.ansiFallback("orange")
  property color themeRed: Theme.ansiFallback("red")
  readonly property real openPanelIndicatorWidth: button.usageWidth

  function loadThemeColors(raw) {
    var green = ""
    var blue = ""
    var orange = ""
    var yellow = ""
    var red = ""
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(/^\s*(green|blue|orange|yellow|red)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
      if (!match) continue
      if (match[1] === "green") green = match[2]
      else if (match[1] === "blue") blue = match[2]
      else if (match[1] === "orange") orange = match[2]
      else if (match[1] === "yellow") yellow = match[2]
      else if (match[1] === "red") red = match[2]
    }
    themeGreen = green || Theme.ansiFallback("green")
    themeBlue = blue || Theme.ansiFallback("blue")
    themeOrange = orange || yellow || Theme.ansiFallback("orange")
    themeRed = red || Theme.ansiFallback("red")
  }

  // evo-theme swaps ~/.themes/current wholesale, so a watch on colors.toml
  // dies after the first switch; Theme.themeData reloads after each switch.
  property FileView themeColorsFile: FileView {
    path: Theme.currentThemePath + "/colors.toml"
    watchChanges: false
    printErrors: false
    onLoaded: root.loadThemeColors(text())
  }

  Connections {
    target: Theme
    function onThemeDataChanged() { root.themeColorsFile.reload() }
    function onForegroundChanged() { root.themeColorsFile.reload() }
    function onAccentChanged() { root.themeColorsFile.reload() }
    function onBackgroundChanged() { root.themeColorsFile.reload() }
  }

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
    onStatusChanged: {
      if (status === Loader.Error)
        console.warn("evo.cursor panel failed:", sourceComponent ? sourceComponent.errorString() : "unknown error")
    }
  }

  IpcHandler {
    target: "evo.cursor"

    function refresh(): void { root.refresh() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.valueText
    labelVisible: false
    hasVisualContent: root.valueText !== ""
    fixedWidth: Theme.bar.iconSlot
    active: root.iconError
    useActiveColor: root.iconError
    dimmed: root.iconMuted && !root.iconError
    tooltipText: Model.plain(root.tooltip)
    opacity: root.iconBusy && !root.iconError ? iconPulse.pulseOpacity : 1
    readonly property real usageWidth: contentRow.implicitWidth

    BarIconPulse {
      id: iconPulse
      running: root.iconBusy && !root.iconError
    }

    UsageCircle {
      id: contentRow
      anchors.centerIn: parent
      fontFamily: button.fontFamily
      color: button.foreground
    }

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.MiddleButton) root.openDashboard()
      else if (b === Qt.RightButton) root.refresh()
      else root.togglePanel()
    }
  }

  component UsageCircle: Item {
    id: circle

    property color color: Theme.foreground
    property string fontFamily: Theme.font.family
    readonly property int glyphBox: Theme.bar.iconCanvas

    width: glyphBox
    height: glyphBox
    implicitWidth: glyphBox
    implicitHeight: glyphBox

    OpticalGlyph {
      anchors.fill: parent
      text: "󱚣"
      fontFamily: circle.fontFamily
      fontSize: Theme.bar.iconFont
      color: circle.color
    }
  }
}
