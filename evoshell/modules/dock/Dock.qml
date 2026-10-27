import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.commons
import qs.ui

// Pinned-app dock. Super+D toggles it through `evo ipc shell toggle evo.dock`.
// The bar lives on the focused monitor and slides up from below the screen.
// `opened` drops as soon as close starts, so a second Super+D is not swallowed
// by the slide-down.
Item {
  id: root

  property var shell: null
  property bool opened: false
  property var pins: []
  property var entries: []
  property int selectedIndex: 0
  property var hostScreen: null
  property bool focusPrimed: false
  // 1 is parked below the screen, 0 is the resting dock.
  property real slide: 1

  readonly property int iconSize: Theme.space(72)
  readonly property int cellWidth: Theme.space(104)
  readonly property int cellHeight: iconSize + Theme.space(6) + Theme.fontSizeS + Theme.space(8)
  readonly property int barPad: Theme.space(12)
  // Hyprland general:border_size. Drawn on the top and sides only.
  readonly property int windowBorder: 2
  readonly property int slideDistance: Theme.space(220)
  readonly property string pinsPath: {
    var dir = shell && shell.shellDir ? String(shell.shellDir) : String(Quickshell.shellDir)
    return dir + "/modules/dock/pins.json"
  }

  Behavior on slide {
    NumberAnimation { duration: Theme.duration(180); easing.type: Easing.OutCubic }
  }

  function pinKey(id) {
    var key = String(id || "").trim()
    if (key.toLowerCase().endsWith(".desktop"))
      key = key.slice(0, -8)
    return key
  }

  function lookupEntry(pin) {
    var key = pinKey(pin)
    if (!key)
      return null
    var direct = DesktopEntries.byId(key)
    if (direct)
      return direct
    var withSuffix = DesktopEntries.byId(key + ".desktop")
    if (withSuffix)
      return withSuffix
    var guessed = DesktopEntries.heuristicLookup(key)
    if (guessed)
      return guessed
    var values = DesktopEntries.applications.values || []
    var want = key.toLowerCase()
    for (var i = 0; i < values.length; i++) {
      var entry = values[i]
      if (entry && pinKey(entry.id).toLowerCase() === want)
        return entry
    }
    return null
  }

  function applyPins(raw) {
    var next = []
    try {
      var data = JSON.parse(String(raw || "").trim() || "[]")
      if (Array.isArray(data))
        next = data
    } catch (e) {
      next = []
    }
    pins = next
    if (opened)
      rebuildEntries()
  }

  function rebuildEntries() {
    var next = []
    for (var i = 0; i < pins.length; i++) {
      var entry = lookupEntry(pins[i])
      if (!entry)
        continue
      next.push({
        id: String(entry.id || pins[i]),
        name: String(entry.name || pins[i]),
        iconSource: Util.iconSourceForName(String(entry.icon || "")) || ""
      })
    }
    entries = next
    if (entries.length === 0)
      selectedIndex = 0
    else if (selectedIndex < 0 || selectedIndex >= entries.length)
      selectedIndex = 0
  }

  function focusedScreen() {
    var screens = Quickshell.screens
    var monitor = Hyprland.focusedMonitor
    if (!monitor)
      return screens.length > 0 ? screens[0] : null
    var name = String(monitor.name || "")
    for (var i = 0; i < screens.length; i++) {
      if (screens[i] && String(screens[i].name || "") === name)
        return screens[i]
    }
    for (var j = 0; j < screens.length; j++) {
      var screen = screens[j]
      if (screen && screen.x === monitor.x && screen.y === monitor.y)
        return screen
    }
    return screens.length > 0 ? screens[0] : null
  }

  function open(payloadJson) {
    if (shell)
      shell.hide("evo.sys.menu")
    rebuildEntries()
    hostScreen = focusedScreen()
    var wasOpen = opened
    opened = true
    focusPrimed = false
    focusPrimeTimer.restart()
    if (!wasOpen && slide > 0.98)
      slide = 1
    Qt.callLater(function() {
      if (root.opened)
        root.slide = 0
    })
  }

  function close() {
    if (!opened)
      return
    opened = false
    slide = 1
    focusPrimeTimer.stop()
    focusPrimed = false
  }

  function dismiss() {
    if (shell)
      shell.hide("evo.dock")
    else
      close()
  }

  function moveSelection(dx) {
    if (entries.length === 0 || dx === 0)
      return
    var next = selectedIndex + dx
    if (next < 0)
      next = entries.length - 1
    else if (next >= entries.length)
      next = 0
    selectedIndex = next
  }

  function launchIndex(index) {
    if (index < 0 || index >= entries.length)
      return
    var item = entries[index]
    var entry = lookupEntry(item.id)
    if (entry && entry.runInTerminal)
      Quickshell.execDetached(["gtk-launch", String(entry.id)])
    else if (entry && typeof entry.execute === "function")
      entry.execute()
    else
      Quickshell.execDetached(["gtk-launch", String(item.id)])
    dismiss()
  }

  function activateSelection() {
    launchIndex(selectedIndex)
  }

  Timer {
    id: focusPrimeTimer
    interval: 75
    onTriggered: if (root.opened) root.focusPrimed = true
  }

  FileView {
    id: pinsFile
    path: root.pinsPath
    watchChanges: true
    printErrors: false
    onLoaded: root.applyPins(text())
    onLoadFailed: root.applyPins("[]")
  }

  Connections {
    target: DesktopEntries
    function onApplicationsChanged() {
      if (root.opened)
        root.rebuildEntries()
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      readonly property bool showHere: {
        if (!root.hostScreen || !modelData)
          return false
        if (modelData === root.hostScreen)
          return true
        return modelData.x === root.hostScreen.x && modelData.y === root.hostScreen.y
      }

      function focusKeys() {
        if (showHere && root.opened)
          keys.forceActiveFocus()
      }

      screen: modelData
      visible: showHere && (root.opened || root.slide < 0.98)
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "evo-panels-dock"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: showHere && root.opened
        ? (root.focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
        : WlrKeyboardFocus.None
      anchors { top: true; bottom: true; left: true; right: true }
      // Drop the input region as soon as the dock closes so the slide-down
      // does not eat clicks meant for the windows underneath.
      mask: Region {
        width: root.opened && panel.showHere ? panel.width : 0
        height: root.opened && panel.showHere ? panel.height : 0
      }

      onVisibleChanged: if (visible) focusKeys()
      onBackingWindowVisibleChanged: if (backingWindowVisible) focusKeys()

      Connections {
        target: root
        function onOpenedChanged() { panel.focusKeys() }
      }

      MouseArea {
        anchors.fill: parent
        enabled: root.opened
        onClicked: root.dismiss()
      }

      Item {
        id: dockBar
        z: 1
        clip: true
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: iconRow.implicitWidth + root.barPad * 2
        height: Math.max(iconRow.implicitHeight, root.cellHeight) + root.barPad * 2
        transform: Translate {
          y: root.slide * Math.max(dockBar.height, root.slideDistance)
        }

        // The fill is taller than the dock so the clip cuts off the bottom
        // border and the bottom corner radius. What remains matches a Hyprland
        // window border on the top and sides, with a square bottom edge.
        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          height: parent.height + Theme.cornerRadius + root.windowBorder
          radius: Theme.cornerRadius
          color: Theme.background
          border.width: root.windowBorder
          border.color: Theme.accent
        }

        MouseArea {
          anchors.fill: parent
          onClicked: {}
        }

        Row {
          id: iconRow
          x: root.barPad
          y: root.barPad
          spacing: Theme.space(8)

          Repeater {
            model: root.entries

            Rectangle {
              id: cell
              required property var modelData
              required property int index

              implicitWidth: root.cellWidth
              implicitHeight: root.cellHeight
              radius: Theme.cornerRadius
              color: index === root.selectedIndex || iconMouse.containsMouse
                ? Theme.panelMantle
                : "transparent"

              MouseArea {
                id: iconMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selectedIndex = index
                onClicked: root.launchIndex(index)
              }

              Column {
                anchors.centerIn: parent
                spacing: Theme.space(6)
                width: root.cellWidth - Theme.space(8)

                Item {
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: root.iconSize
                  height: root.iconSize

                  Image {
                    id: iconImage
                    anchors.fill: parent
                    visible: source !== "" && status !== Image.Error
                    source: cell.modelData ? Util.normalizeIconSource(cell.modelData.iconSource) : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    smooth: true
                    sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
                  }

                  Text {
                    anchors.centerIn: parent
                    visible: !iconImage.visible
                    text: {
                      var name = cell.modelData ? String(cell.modelData.name || "") : ""
                      return name.length > 0 ? name.charAt(0).toUpperCase() : ""
                    }
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.space(28)
                    font.bold: Theme.fontBold
                  }
                }

                Text {
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  elide: Text.ElideRight
                  maximumLineCount: 1
                  text: cell.modelData ? cell.modelData.name : ""
                  color: Theme.foreground
                  opacity: index === root.selectedIndex || iconMouse.containsMouse ? 1 : Theme.opacitySecondary
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSizeS
                  font.bold: Theme.fontBold
                }
              }
            }
          }
        }
      }

      PanelKeyCatcher {
        id: keys
        width: 1
        height: 1
        enabled: panel.showHere && root.opened
        onMoveRequested: function(dx, dy) { root.moveSelection(dx) }
        onActivateRequested: root.activateSelection()
        onCloseRequested: root.dismiss()
      }
    }
  }
}
