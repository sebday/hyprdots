import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.commons
import qs.ui

// Session actions in a dock-style bar floating in the middle of the focused
// monitor. Super+Escape toggles it through `evo ipc shell toggle evo.power`.
Item {
  id: root

  property var shell: null
  property bool opened: false
  property int selectedIndex: 0
  property var hostScreen: null
  property bool focusPrimed: false
  // 0 is hidden, 1 is fully shown.
  property real reveal: 0

  readonly property string evo: Quickshell.env("HOME") + "/.local/bin/evo"
  readonly property int iconSize: Theme.space(48)
  readonly property int cellWidth: Theme.space(84)
  readonly property int cellHeight: iconSize + Theme.space(6) + Theme.fontSizeS + Theme.space(8)
  readonly property int cellSpacing: Theme.space(8)
  readonly property int barPad: Theme.space(12)
  // Hyprland general:border_size.
  readonly property int windowBorder: 2

  readonly property var actions: [
    { name: "Lock", icon: "󰌾", command: [evo, "system", "lock"] },
    { name: "Reboot", icon: "󰜉", command: [evo, "system", "reboot"] },
    { name: "Shutdown", icon: "󰐥", command: [evo, "system", "shutdown"] }
  ]

  Behavior on reveal {
    NumberAnimation { duration: Theme.duration(160); easing.type: Easing.OutCubic }
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
    if (shell) {
      shell.hide("evo.sys.menu")
      shell.hide("evo.dock")
    }
    hostScreen = focusedScreen()
    selectedIndex = 0
    opened = true
    focusPrimed = false
    focusPrimeTimer.restart()
    Qt.callLater(function() {
      if (root.opened)
        root.reveal = 1
    })
  }

  function close() {
    if (!opened)
      return
    opened = false
    reveal = 0
    focusPrimeTimer.stop()
    focusPrimed = false
  }

  function dismiss() {
    if (shell)
      shell.hide("evo.power")
    else
      close()
  }

  function moveSelection(dx) {
    if (dx === 0)
      return
    selectedIndex = (selectedIndex + dx + actions.length) % actions.length
  }

  function runIndex(index) {
    if (index < 0 || index >= actions.length)
      return
    var command = actions[index].command
    dismiss()
    Quickshell.execDetached(command)
  }

  Timer {
    id: focusPrimeTimer
    interval: 75
    onTriggered: if (root.opened) root.focusPrimed = true
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
      visible: showHere && (root.opened || root.reveal > 0.02)
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "evo-panels-power"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: showHere && root.opened
        ? (root.focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
        : WlrKeyboardFocus.None
      anchors { top: true; bottom: true; left: true; right: true }
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

      Rectangle {
        id: powerBar
        z: 1
        anchors.centerIn: parent
        width: actionRow.implicitWidth + root.barPad * 2
        height: root.cellHeight + root.barPad * 2
        radius: Theme.cornerRadius
        color: Theme.background
        border.width: root.windowBorder
        border.color: Theme.accent
        opacity: root.reveal
        scale: 0.94 + 0.06 * root.reveal

        MouseArea {
          anchors.fill: parent
          onClicked: {}
        }

        Row {
          id: actionRow
          x: root.barPad
          y: root.barPad
          spacing: root.cellSpacing

          Repeater {
            model: root.actions

            Rectangle {
              id: cell
              required property var modelData
              required property int index
              readonly property bool hot: index === root.selectedIndex || actionMouse.containsMouse

              implicitWidth: root.cellWidth
              implicitHeight: root.cellHeight
              radius: Theme.cornerRadius
              color: hot ? Theme.panelMantle : "transparent"

              MouseArea {
                id: actionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selectedIndex = index
                onClicked: root.runIndex(index)
              }

              Column {
                anchors.centerIn: parent
                spacing: Theme.space(6)
                width: root.cellWidth - Theme.space(8)

                Item {
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: root.iconSize
                  height: root.iconSize

                  Text {
                    anchors.centerIn: parent
                    text: cell.modelData.icon
                    color: cell.hot ? Theme.accent : Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.space(36)
                  }
                }

                Text {
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  elide: Text.ElideRight
                  maximumLineCount: 1
                  text: cell.modelData.name
                  color: Theme.foreground
                  opacity: cell.hot ? 1 : Theme.opacitySecondary
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
        onActivateRequested: root.runIndex(root.selectedIndex)
        onCloseRequested: root.dismiss()
      }
    }
  }
}
