import QtQuick
import Quickshell
import Quickshell.Hyprland
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
  property int selectedIndex: 0
  property var hostScreen: null
  property bool focusPrimed: false
  // 1 is parked below the screen, 0 is the resting dock.
  property real slide: 1

  readonly property int iconSize: Theme.space(48)
  readonly property int cellWidth: Theme.space(84)
  readonly property int cellHeight: iconSize + Theme.space(6) + Theme.fontSizeS + Theme.space(8)
  readonly property int barPad: Theme.space(12)
  // Hyprland general:border_size. Drawn on the top and sides only.
  readonly property int windowBorder: 2
  readonly property int slideDistance: Theme.space(220)
  readonly property int cellSpacing: Theme.space(8)
  readonly property real dragThreshold: Theme.space(4)

  // Index into `entries` of the icon being dragged, -1 when idle.
  property int dragIndex: -1
  property int dropIndex: -1
  property bool dropAfter: false
  property real dragX: 0
  property real dragY: 0

  readonly property var entries: {
    var ids = DockPins.resolvedIds
    var next = []
    for (var i = 0; i < ids.length; i++) {
      if (!ids[i])
        continue
      var entry = DockPins.lookupEntry(ids[i])
      if (!entry)
        continue
      next.push({
        id: String(entry.id || ids[i]),
        name: String(entry.name || ids[i]),
        iconSource: Util.iconSourceForName(String(entry.icon || "")) || "",
        pinIndex: i
      })
    }
    return next
  }

  Behavior on slide {
    NumberAnimation { duration: Theme.duration(180); easing.type: Easing.OutCubic }
  }

  onEntriesChanged: {
    if (selectedIndex < 0 || selectedIndex >= entries.length)
      selectedIndex = 0
  }

  // Slot under a point in iconRow coordinates. Cells share one width, so the
  // slot falls out of the x position.
  function dropAt(rowX) {
    if (entries.length === 0)
      return null
    var stride = cellWidth + cellSpacing
    var slot = Math.floor(rowX / stride)
    slot = Math.max(0, Math.min(entries.length - 1, slot))
    var within = rowX - slot * stride
    return { index: slot, after: within > cellWidth / 2 }
  }

  function clearDrag() {
    dragIndex = -1
    dropIndex = -1
    dropAfter = false
  }

  function finishDrag() {
    var from = dragIndex
    var target = dropIndex
    var after = dropAfter
    clearDrag()
    if (from < 0 || target < 0 || from >= entries.length || target >= entries.length)
      return
    var movedId = entries[from].id
    DockPins.movePin(entries[from].pinIndex, entries[target].pinIndex, after)
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].id === movedId) {
        selectedIndex = i
        break
      }
    }
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
      shell.hide("evo.power")
    }
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
    clearDrag()
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
    var entry = DockPins.lookupEntry(item.id)
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
          spacing: root.cellSpacing

          Repeater {
            model: root.entries

            Rectangle {
              id: cell
              required property var modelData
              required property int index
              readonly property bool dragSource: root.dragIndex === index

              implicitWidth: root.cellWidth
              implicitHeight: root.cellHeight
              radius: Theme.cornerRadius
              color: root.dragIndex < 0 && (index === root.selectedIndex || iconMouse.containsMouse)
                ? Theme.panelMantle
                : "transparent"

              Rectangle {
                visible: root.dropIndex === cell.index && root.dragIndex >= 0
                width: 2
                height: parent.height
                x: root.dropAfter
                  ? parent.width + root.cellSpacing / 2 - width / 2
                  : -root.cellSpacing / 2 - width / 2
                color: Theme.accent
                z: 3
              }

              MouseArea {
                id: iconMouse

                property bool dragging: false
                property bool suppressClick: false
                property real pressedX: 0
                property real pressedY: 0

                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: dragging ? Qt.SizeHorCursor : Qt.PointingHandCursor
                onEntered: if (root.dragIndex < 0) root.selectedIndex = index

                onPressed: function(mouse) {
                  dragging = false
                  suppressClick = false
                  pressedX = mouse.x
                  pressedY = mouse.y
                  root.clearDrag()
                }

                onPositionChanged: function(mouse) {
                  if (!(mouse.buttons & Qt.LeftButton) || root.entries.length < 2)
                    return
                  var distance = Math.abs(mouse.x - pressedX) + Math.abs(mouse.y - pressedY)
                  if (distance >= root.dragThreshold && !dragging) {
                    dragging = true
                    suppressClick = true
                    root.dragIndex = index
                  }
                  if (!dragging)
                    return
                  var scenePoint = cell.mapToItem(null, mouse.x, mouse.y)
                  root.dragX = scenePoint.x
                  root.dragY = scenePoint.y
                  var rowPoint = cell.mapToItem(iconRow, mouse.x, mouse.y)
                  var drop = root.dropAt(rowPoint.x)
                  root.dropIndex = drop ? drop.index : -1
                  root.dropAfter = drop ? drop.after : false
                }

                onReleased: function(mouse) {
                  var wasDragging = dragging
                  dragging = false
                  if (wasDragging)
                    root.finishDrag()
                  else
                    root.clearDrag()
                }

                onCanceled: {
                  dragging = false
                  suppressClick = false
                  root.clearDrag()
                }

                onClicked: {
                  if (suppressClick) {
                    suppressClick = false
                    return
                  }
                  root.launchIndex(index)
                }
              }

              Column {
                opacity: cell.dragSource ? 0.22 : 1
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
                    font.pixelSize: Theme.space(20)
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

      Image {
        readonly property var dragged: root.dragIndex >= 0 && root.dragIndex < root.entries.length
          ? root.entries[root.dragIndex]
          : null
        z: 2
        visible: dragged !== null && panel.showHere && source !== ""
        x: Math.round(root.dragX - width / 2)
        y: Math.round(root.dragY - height / 2)
        width: root.iconSize
        height: root.iconSize
        source: dragged ? Util.normalizeIconSource(dragged.iconSource) : ""
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
        smooth: true
        opacity: 0.9
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
