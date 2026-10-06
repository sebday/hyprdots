import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import qs.commons
import qs.ui
import "LayoutModel.js" as LayoutModel

Item {
  id: root

  property color foreground: Theme.foreground
  property string fontFamily: Theme.font.family
  property var barPlacements: []
  property var notificationsPlacements: []
  property string selectedMonitor: ""
  property bool enabled: true
  property bool showWorkspaces: true
  property var workspaceByMonitor: ({})

  signal barChosen(string output, string position)
  signal notificationsChosen(string output, string position, string align)
  signal monitorChosen(string output)

  readonly property int canvasHeight: Theme.space(240)
  readonly property int canvasPad: Theme.space(4)
  readonly property int edgeStripHeight: Theme.space(8)
  readonly property int notifMarkerWidth: Theme.space(16)
  readonly property int notifMarkerHeight: Theme.space(8)
  readonly property int markerRadius: Theme.cornerRadius
  readonly property int workspacePillPadH: Theme.space(2)
  readonly property int workspacePillPadV: Theme.space(1)
  readonly property int workspaceFlowSpacing: Theme.space(2)
  readonly property real secondaryOpacity: 0.72

  implicitWidth: Theme.space(380)

  readonly property var layoutBounds: {
    var screens = Quickshell.screens
    if (!screens || screens.length === 0)
      return { minX: 0, minY: 0, width: 1920, height: 1080 }
    var minX = Infinity
    var minY = Infinity
    var maxX = -Infinity
    var maxY = -Infinity
    for (var i = 0; i < screens.length; i++) {
      var s = screens[i]
      if (!s)
        continue
      minX = Math.min(minX, s.x)
      minY = Math.min(minY, s.y)
      maxX = Math.max(maxX, s.x + s.width)
      maxY = Math.max(maxY, s.y + s.height)
    }
    if (!isFinite(minX))
      return { minX: 0, minY: 0, width: 1920, height: 1080 }
    return {
      minX: minX,
      minY: minY,
      width: Math.max(1, maxX - minX),
      height: Math.max(1, maxY - minY)
    }
  }

  readonly property real layoutScale: {
    var availW = Math.max(1, root.width - root.canvasPad * 2)
    var availH = Math.max(1, root.canvasHeight - root.canvasPad * 2)
    var scaleW = availW / layoutBounds.width
    var scaleH = availH / layoutBounds.height
    return Math.min(scaleW, scaleH)
  }

  readonly property real scaledWidth: layoutBounds.width * layoutScale
  readonly property real scaledHeight: layoutBounds.height * layoutScale
  readonly property real layoutOffsetX: (root.width - scaledWidth) / 2
  readonly property real layoutOffsetY: root.canvasPad

  implicitHeight: scaledHeight + root.canvasPad * 2

  function monitorRect(screen) {
    if (!screen)
      return ({ x: 0, y: 0, width: 0, height: 0 })
    return {
      x: layoutOffsetX + (screen.x - layoutBounds.minX) * layoutScale,
      y: layoutOffsetY + (screen.y - layoutBounds.minY) * layoutScale,
      width: screen.width * layoutScale,
      height: screen.height * layoutScale
    }
  }

  function isBarActive(output, position) {
    return LayoutModel.hasBarEdge(barPlacements, output, position)
  }

  function isNotificationsActive(output, edge, align) {
    return LayoutModel.hasNotificationAlign(notificationsPlacements, output, edge, align)
  }

  function parseWorkspaceRules(raw) {
    var map = {}
    try {
      var rules = JSON.parse(String(raw || "[]"))
      for (var i = 0; i < rules.length; i++) {
        var rule = rules[i]
        if (!rule || rule.enabled === false)
          continue
        var monitor = String(rule.monitor || "")
        var ws = String(rule.workspaceString || "")
        if (!monitor || !ws)
          continue
        if (!map[monitor])
          map[monitor] = []
        map[monitor].push(ws)
      }
      var keys = Object.keys(map)
      for (var k = 0; k < keys.length; k++) {
        var key = keys[k]
        map[key].sort(function(a, b) {
          var na = Number(a)
          var nb = Number(b)
          if (isFinite(na) && isFinite(nb))
            return na - nb
          return String(a).localeCompare(String(b))
        })
      }
    } catch (e) {
      map = {}
    }
    return map
  }

  function workspacesForMonitor(monitorName) {
    if (!monitorName)
      return []
    var map = workspaceByMonitor
    return map && map[monitorName] ? map[monitorName] : []
  }

  function workspacePillWidth(wsId) {
    return Math.max(12, String(wsId).length * 7) + workspacePillPadH * 2
  }

  function workspaceFlowRows(monitorName, maxWidth) {
    var ids = workspacesForMonitor(monitorName)
    if (!ids.length || maxWidth <= 0)
      return []
    var gap = workspaceFlowSpacing
    var rows = []
    var row = []
    var rowW = 0
    for (var i = 0; i < ids.length; i++) {
      var w = workspacePillWidth(ids[i])
      var needed = rowW === 0 ? w : rowW + gap + w
      if (rowW > 0 && needed > maxWidth) {
        rows.push(row)
        row = [ids[i]]
        rowW = w
      } else {
        row.push(ids[i])
        rowW = needed
      }
    }
    if (row.length)
      rows.push(row)
    return rows
  }

  function isWorkspaceFocused(wsId) {
    if (!Hyprland.focusedWorkspace)
      return false
    var id = String(wsId)
    return id === String(Hyprland.focusedWorkspace.id)
      || id === String(Hyprland.focusedWorkspace.name || "")
  }

  function refreshWorkspaceRules() {
    if (!showWorkspaces || workspaceRulesProc.running)
      return
    workspaceRulesProc.running = true
  }

  readonly property color barColor: Theme.accent
  readonly property color notificationsColor: Theme.urgent
  readonly property color monitorFill: Theme.normalFillFor(foreground, Theme.accent)
  readonly property color monitorBorder: Theme.normalBorderFor(foreground, Theme.accent)
  readonly property color subtleFill: Theme.hoverFillFor(foreground, Theme.accent)
  readonly property color trackFill: Theme.normalFillFor(foreground, Theme.accent, 0.12)

  Process {
    id: workspaceRulesProc
    onStarted: stdoutBuf = ""
    onExited: function(exitCode) {
      if (exitCode === 0) root.workspaceByMonitor = root.parseWorkspaceRules(stdoutBuf)
    }

    property string stdoutBuf: ""
    command: ["/usr/bin/hyprctl", "workspacerules", "-j"]
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        workspaceRulesProc.stdoutBuf += chunk
        if (workspaceRulesProc.stdoutBuf.length > 262144) {
          workspaceRulesProc.signal(15)
          workspaceRulesProc.stdoutBuf = ""
        }
      }
    }
  }

  // Rules only change with the Hyprland config, so reading them each time the
  // panel opens is enough.
  onEnabledChanged: if (enabled) refreshWorkspaceRules()
  Component.onCompleted: refreshWorkspaceRules()

  Item {
    id: canvas
    width: parent.width
    height: root.implicitHeight

    Repeater {
      model: Quickshell.screens

      delegate: Item {
        id: monitorItem
        required property var modelData

        readonly property string monitorName: modelData ? String(modelData.name || "") : ""
        readonly property var rect: root.monitorRect(modelData)
        readonly property bool selected: monitorItem.monitorName !== ""
          && monitorItem.monitorName === root.selectedMonitor

        x: rect.x
        y: rect.y
        width: rect.width
        height: rect.height

        Rectangle {
          anchors.fill: parent
          radius: Theme.cornerRadius
          color: monitorItem.selected
            ? Theme.selectedFillFor(root.foreground, Theme.accent)
            : root.monitorFill
          border.color: monitorItem.selected ? Theme.accent : root.monitorBorder
          border.width: monitorItem.selected ? 2 : 1
        }

        MouseArea {
          anchors.fill: parent
          anchors.topMargin: root.edgeStripHeight
          anchors.bottomMargin: root.edgeStripHeight
          anchors.leftMargin: root.edgeStripHeight
          anchors.rightMargin: root.edgeStripHeight
          enabled: root.enabled && monitorItem.monitorName !== ""
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.monitorChosen(monitorItem.monitorName)
        }

        Item {
          anchors.left: parent.left
          anchors.leftMargin: root.edgeStripHeight + 1
          anchors.right: parent.right
          anchors.rightMargin: root.edgeStripHeight + 1
          anchors.top: parent.top
          anchors.topMargin: root.edgeStripHeight + 1
          anchors.bottom: parent.bottom
          anchors.bottomMargin: root.edgeStripHeight + 1

          Column {
            anchors.centerIn: parent
            spacing: root.workspaceFlowSpacing
            width: parent.width

            Text {
              textFormat: Text.PlainText
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: monitorItem.monitorName
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Theme.font.caption
              font.bold: true
              elide: Text.ElideRight
              maximumLineCount: 1
              opacity: root.secondaryOpacity
            }

            Column {
              width: parent.width
              spacing: root.workspaceFlowSpacing
              visible: root.showWorkspaces
                && root.workspacesForMonitor(monitorItem.monitorName).length > 0

              Repeater {
                model: root.workspaceFlowRows(
                  monitorItem.monitorName,
                  monitorItem.width - root.workspacePillPadH * 2)

                delegate: Row {
                  required property var modelData
                  anchors.horizontalCenter: parent.horizontalCenter
                  spacing: root.workspaceFlowSpacing

                  Repeater {
                    model: modelData

                    delegate: Rectangle {
                      required property string modelData
                      readonly property string wsId: String(modelData)
                      readonly property bool focused: root.isWorkspaceFocused(wsId)

                      radius: Theme.space(4)
                      color: focused
                        ? Theme.selectedFillFor(root.foreground, Theme.accent)
                        : root.subtleFill
                      border.color: focused ? Theme.accent : "transparent"
                      border.width: focused ? 1 : 0
                      implicitWidth: wsLabel.width + root.workspacePillPadH * 2
                      implicitHeight: wsLabel.height + root.workspacePillPadV * 2

                      Text {
                        textFormat: Text.PlainText
                        id: wsLabel
                        anchors.centerIn: parent
                        text: wsId
                        color: focused ? Theme.accent : root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Theme.font.caption
                        font.bold: focused
                        opacity: root.secondaryOpacity
                      }
                    }
                  }
                }
              }
            }
          }
        }

        Rectangle {
          id: topBarStrip
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: root.edgeStripHeight
          radius: root.markerRadius
          color: root.isBarActive(monitorItem.monitorName, "top")
            ? root.barColor
            : root.subtleFill
          opacity: topBarMouse.containsMouse && root.enabled ? 1 : 0.72

          MouseArea {
            id: topBarMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.enabled && monitorItem.monitorName !== ""
            cursorShape: Qt.PointingHandCursor
            onClicked: root.barChosen(monitorItem.monitorName, "top")
          }
        }

        Rectangle {
          id: leftBarStrip
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: root.edgeStripHeight
          radius: root.markerRadius
          color: root.isBarActive(monitorItem.monitorName, "left")
            ? root.barColor
            : root.subtleFill
          opacity: leftBarMouse.containsMouse && root.enabled ? 1 : 0.72

          MouseArea {
            id: leftBarMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.enabled && monitorItem.monitorName !== ""
            cursorShape: Qt.PointingHandCursor
            onClicked: root.barChosen(monitorItem.monitorName, "left")
          }
        }

        Rectangle {
          id: rightBarStrip
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: root.edgeStripHeight
          radius: root.markerRadius
          color: root.isBarActive(monitorItem.monitorName, "right")
            ? root.barColor
            : root.subtleFill
          opacity: rightBarMouse.containsMouse && root.enabled ? 1 : 0.72

          MouseArea {
            id: rightBarMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.enabled && monitorItem.monitorName !== ""
            cursorShape: Qt.PointingHandCursor
            onClicked: root.barChosen(monitorItem.monitorName, "right")
          }
        }

        Rectangle {
          id: topNotifLeft
          z: 2
          anchors.top: parent.top
          anchors.left: parent.left
          width: root.notifMarkerWidth
          height: root.notifMarkerHeight
          radius: root.markerRadius
          color: root.isNotificationsActive(monitorItem.monitorName, "top", "left")
            ? root.notificationsColor
            : root.trackFill
          opacity: topNotifLeftMouse.containsMouse && root.enabled ? 1 : 0.85

          MouseArea {
            id: topNotifLeftMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.enabled && monitorItem.monitorName !== ""
            cursorShape: Qt.PointingHandCursor
            onClicked: root.notificationsChosen(monitorItem.monitorName, "top", "left")
          }
        }

        Rectangle {
          id: topNotifCenter
          z: 2
          anchors.top: parent.top
          anchors.horizontalCenter: parent.horizontalCenter
          width: root.notifMarkerWidth
          height: root.notifMarkerHeight
          radius: root.markerRadius
          color: root.isNotificationsActive(monitorItem.monitorName, "top", "center")
            ? root.notificationsColor
            : root.trackFill
          opacity: topNotifCenterMouse.containsMouse && root.enabled ? 1 : 0.85

          MouseArea {
            id: topNotifCenterMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.enabled && monitorItem.monitorName !== ""
            cursorShape: Qt.PointingHandCursor
            onClicked: root.notificationsChosen(monitorItem.monitorName, "top", "center")
          }
        }

        Rectangle {
          id: topNotifRight
          z: 2
          anchors.top: parent.top
          anchors.right: parent.right
          width: root.notifMarkerWidth
          height: root.notifMarkerHeight
          radius: root.markerRadius
          color: root.isNotificationsActive(monitorItem.monitorName, "top", "right")
            ? root.notificationsColor
            : root.trackFill
          opacity: topNotifRightMouse.containsMouse && root.enabled ? 1 : 0.85

          MouseArea {
            id: topNotifRightMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.enabled && monitorItem.monitorName !== ""
            cursorShape: Qt.PointingHandCursor
            onClicked: root.notificationsChosen(monitorItem.monitorName, "top", "right")
          }
        }

        Rectangle {
          id: bottomBarStrip
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          height: root.edgeStripHeight
          radius: root.markerRadius
          color: root.isBarActive(monitorItem.monitorName, "bottom")
            ? root.barColor
            : root.subtleFill
          opacity: bottomBarMouse.containsMouse && root.enabled ? 1 : 0.72

          MouseArea {
            id: bottomBarMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.enabled && monitorItem.monitorName !== ""
            cursorShape: Qt.PointingHandCursor
            onClicked: root.barChosen(monitorItem.monitorName, "bottom")
          }
        }

        Rectangle {
          id: bottomNotifLeft
          z: 2
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          width: root.notifMarkerWidth
          height: root.notifMarkerHeight
          radius: root.markerRadius
          color: root.isNotificationsActive(monitorItem.monitorName, "bottom", "left")
            ? root.notificationsColor
            : root.trackFill
          opacity: bottomNotifLeftMouse.containsMouse && root.enabled ? 1 : 0.85

          MouseArea {
            id: bottomNotifLeftMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.enabled && monitorItem.monitorName !== ""
            cursorShape: Qt.PointingHandCursor
            onClicked: root.notificationsChosen(monitorItem.monitorName, "bottom", "left")
          }
        }

        Rectangle {
          id: bottomNotifCenter
          z: 2
          anchors.bottom: parent.bottom
          anchors.horizontalCenter: parent.horizontalCenter
          width: root.notifMarkerWidth
          height: root.notifMarkerHeight
          radius: root.markerRadius
          color: root.isNotificationsActive(monitorItem.monitorName, "bottom", "center")
            ? root.notificationsColor
            : root.trackFill
          opacity: bottomNotifCenterMouse.containsMouse && root.enabled ? 1 : 0.85

          MouseArea {
            id: bottomNotifCenterMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.enabled && monitorItem.monitorName !== ""
            cursorShape: Qt.PointingHandCursor
            onClicked: root.notificationsChosen(monitorItem.monitorName, "bottom", "center")
          }
        }

        Rectangle {
          id: bottomNotifRight
          z: 2
          anchors.bottom: parent.bottom
          anchors.right: parent.right
          width: root.notifMarkerWidth
          height: root.notifMarkerHeight
          radius: root.markerRadius
          color: root.isNotificationsActive(monitorItem.monitorName, "bottom", "right")
            ? root.notificationsColor
            : root.trackFill
          opacity: bottomNotifRightMouse.containsMouse && root.enabled ? 1 : 0.85

          MouseArea {
            id: bottomNotifRightMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.enabled && monitorItem.monitorName !== ""
            cursorShape: Qt.PointingHandCursor
            onClicked: root.notificationsChosen(monitorItem.monitorName, "bottom", "right")
          }
        }
      }
    }
  }
}
