import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.commons
import qs.ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "evo.steam"
  ipcTarget: "evo.steam"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: Theme.foreground
  readonly property color urgent: bar ? bar.urgent : Theme.urgent
  readonly property color accent: Theme.accent
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property color surface: Theme.popups.background
  readonly property string fontFamily: bar ? bar.fontFamily : Theme.font.family

  readonly property int tileArtWidth: 96
  readonly property int tileArtHeight: 88
  readonly property int tileArtSourceSize: 192
  readonly property int tileHeight: tileArtHeight + 20
  readonly property int maxPlayedGames: 3
  readonly property int pollMs: 2000

  property bool loading: true
  property var data: Model.emptyData()

  readonly property var displayedGames: {
    var games = data && Array.isArray(data.playedGames) ? data.playedGames : []
    return games.slice(0, maxPlayedGames)
  }
  readonly property string statusScript: Qt.resolvedUrl("bin/steam-status").toString().replace("file://", "")
  readonly property bool iconActive: Model.iconActive(data)
  readonly property bool iconError: !loading && !!(data && data.error)
  readonly property bool iconBusy: iconActive
  readonly property bool iconMuted: !!(data && data.ok && !data.running)
  readonly property string barTooltip: Model.barTooltip(data)
  readonly property string statusPillText: Model.statusPillText(data, loading)
  readonly property color statusPillColor: Model.statusPillColor(data, loading, accent, urgent, foreground)

  function applyPayload(raw) {
    loading = false
    data = Model.parsePayload(raw)
  }

  function refresh() {
    if (!statusScript || statusProc.running) return
    if (!data.ok) loading = true
    statusProc.command = [statusScript, "popup"]
    statusProc.running = true
  }

  function launchGame(appid) {
    var id = String(appid || "").trim()
    if (!id || actionProc.running) return
    actionProc.command = [statusScript, "launch", id]
    actionProc.running = true
  }

  function openSteam() {
    if (actionProc.running) return
    actionProc.command = [statusScript, "open"]
    actionProc.running = true
  }

  function openFromHotkey() {
    root.controller.show()
    root.refresh()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  Component.onCompleted: refresh()

  onOpenedChanged: {
    if (opened) {
      refresh()
      pollTimer.start()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    } else {
      pollTimer.stop()
    }
  }

  Process {
    id: statusProc
    onStarted: { stdoutBuf = ""; stderrBuf = "" }

    property string stdoutBuf: ""
    property string stderrBuf: ""
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        statusProc.stdoutBuf += chunk
        if (statusProc.stdoutBuf.length > 262144) {
          statusProc.signal(15)
          statusProc.stdoutBuf = ""
        }
      }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        statusProc.stderrBuf += chunk
        if (statusProc.stderrBuf.length > 4096) {
          statusProc.signal(15)
          statusProc.stderrBuf = ""
        }
      }
    }
    onExited: function(exitCode) {
      var raw = String(stdoutBuf || "").trim()
        if (!raw) {
          root.loading = false
          return
        }
        root.applyPayload(raw)
      root.loading = false
    }
  }

  Process {
    id: actionProc
  }

  Timer {
    id: pollTimer
    interval: root.pollMs
    repeat: true
    onTriggered: root.refresh()
  }



  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function show(): void { root.openFromHotkey() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Theme.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Theme.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
          root.bar.switchPanelFrom(root.barIdentity, direction)
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Theme.space(12)

          PanelHero {
            width: parent.width
            title: "Steam"
            meta: root.data.running ? "Library" : "Not running"
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: root.data.running ? 1 : 0.55

            iconComponent: Component {
              Text {
                textFormat: Text.PlainText
                text: "󰓓"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Theme.font.display
                opacity: 0.92
              }
            }
          }

          Row {
            width: parent.width
            spacing: Theme.space(16)

            StatTile {
              width: (parent.width - parent.spacing * 2) / 3
              value: root.loading ? "…" : (root.data.installedCount <= 0 ? "—" : String(root.data.installedCount))
              label: "installed"
            }

            StatTile {
              width: (parent.width - parent.spacing * 2) / 3
              value: root.loading ? "…" : (root.data.ownedCount <= 0 ? "—" : String(root.data.ownedCount))
              label: "games"
            }

            StatTile {
              width: (parent.width - parent.spacing * 2) / 3
              value: Model.formatTotalPlayed(root.data.totalPlaytimeMin, root.loading)
              label: "total time"
            }
          }

          StatusPill {
            width: parent.width
            visible: root.statusPillText !== ""
            text: root.statusPillText
            textColor: root.statusPillColor
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Item {
            id: recentBox
            visible: root.displayedGames.length > 0
            width: parent.width
            implicitHeight: recentFrame.height + (legendChip.visible ? legendChip.height / 2 : 0)

            Rectangle {
              id: recentFrame
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.topMargin: legendChip.visible ? legendChip.height / 2 : 0
              height: recentColumn.implicitHeight + Theme.space(12)
              color: "transparent"
              radius: Theme.space(8)
              border.width: 1
              border.color: Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.9)
              antialiasing: true
            }

            Item {
              id: legendChip
              x: Theme.space(14)
              y: 0
              width: legendTextItem.implicitWidth + Theme.space(8)
              height: Math.max(1, legendTextItem.implicitHeight)
              visible: recentBox.visible

              Rectangle {
                anchors.fill: parent
                color: Theme.popups.background
              }

              Text {
                id: legendTextItem
                x: Theme.space(4)
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: "recent"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Theme.font.caption
                font.bold: true
              }
            }

            Column {
              id: recentColumn
              anchors.left: recentFrame.left
              anchors.right: recentFrame.right
              anchors.top: recentFrame.top
              anchors.topMargin: Theme.space(6)
              anchors.leftMargin: Theme.space(4)
              anchors.rightMargin: Theme.space(4)

              Repeater {
                model: root.displayedGames

                GameRow {
                  required property var modelData
                  required property int index
                  width: recentColumn.width
                  game: modelData
                  showDivider: index < root.displayedGames.length - 1
                }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: !root.loading && !!(root.data && root.data.error)
            text: String((root.data && root.data.error) || "")
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Theme.font.body
            wrapMode: Text.WordWrap
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: !root.loading && root.displayedGames.length === 0 && !(root.data && root.data.error)
            text: (root.data && root.data.running) ? "No recent play history" : "Steam not running"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Theme.font.bodySmall
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }

  component StatusPill: Rectangle {
    property string text: ""
    property color textColor: foreground
    property color foreground: Theme.foreground
    property string fontFamily: Theme.font.family

    implicitWidth: pillText.implicitWidth + Theme.spacing.lg * 2
    implicitHeight: pillText.implicitHeight + Theme.spacing.sm * 2
    radius: implicitHeight / 2
    color: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.14)

    Text {
      textFormat: Text.PlainText
      id: pillText
      anchors.centerIn: parent
      text: parent.text
      color: parent.textColor
      font.family: parent.fontFamily
      font.pixelSize: Theme.font.caption
      font.bold: true
    }
  }

  component GameRow: Item {
    id: gameRow
    property var game: null
    property bool showDivider: false

    implicitHeight: root.tileHeight + (showDivider ? 1 : 0)

    Rectangle {
      anchors.bottom: parent.bottom
      width: parent.width
      height: 1
      visible: gameRow.showDivider
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
    }

    Item {
      anchors.top: parent.top
      width: parent.width
      height: root.tileHeight

      scale: tileMouse.pressed ? 0.97 : 1
      opacity: tileMouse.pressed ? 0.88 : 1

      Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
      Behavior on opacity { NumberAnimation { duration: 90 } }

      Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: tileMouse.pressed
          ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12)
          : (tileMouse.containsMouse
            ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07)
            : "transparent")
      }

      Row {
        anchors.fill: parent
        anchors.margins: Theme.space(10)
        spacing: Theme.space(12)

        Item {
          width: root.tileArtWidth
          height: root.tileArtHeight
          clip: true

          Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            visible: gameIcon.source === "" || gameIcon.status === Image.Error
            text: "󰓓"
            color: root.foreground
            opacity: 0.35
            font.family: root.fontFamily
            font.pixelSize: Theme.font.title
          }

          Image {
            id: gameIcon
            anchors.fill: parent
            visible: source !== "" && status !== Image.Error
            source: Model.gameArtUrl(gameRow.game ? gameRow.game.icon_path : "")
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            sourceSize: Qt.size(
              root.tileArtSourceSize,
              Math.round(root.tileArtSourceSize * root.tileArtHeight / root.tileArtWidth))
          }
        }

        Column {
          width: parent.width - root.tileArtWidth - Theme.space(12) - playHint.implicitWidth - Theme.space(8)
          spacing: Theme.spacing.labelGap
          anchors.verticalCenter: parent.verticalCenter

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: String(gameRow.game ? gameRow.game.name : "Game")
            color: tileMouse.containsMouse ? root.accent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Theme.font.title
            font.bold: true
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
          }

          Row {
            spacing: Theme.spacing.sm

            StatusPill {
              visible: Model.formatLastPlayed(gameRow.game ? gameRow.game.last_played : 0) !== "—"
              text: Model.formatLastPlayed(gameRow.game ? gameRow.game.last_played : 0)
              textColor: root.foreground
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            StatusPill {
              visible: Model.formatPlaytime(gameRow.game ? gameRow.game.playtime_min : 0) !== ""
              text: Model.formatPlaytime(gameRow.game ? gameRow.game.playtime_min : 0)
              textColor: root.foreground
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          id: playHint
          visible: tileMouse.containsMouse && !tileMouse.pressed
          anchors.verticalCenter: parent.verticalCenter
          text: "󰐊"
          color: root.accent
          opacity: 0.85
          font.family: root.fontFamily
          font.pixelSize: Theme.font.title
        }
      }

      MouseArea {
        id: tileMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.launchGame(gameRow.game ? gameRow.game.appid : "")
      }
    }
  }

  component StatTile: Item {
    id: tile
    property string value: ""
    property string label: ""
    property color valueColor: root.accent

    implicitWidth: Theme.space(108)
    implicitHeight: Theme.font.heading + Theme.space(56)

    Rectangle {
      id: frame
      anchors.fill: parent
      anchors.topMargin: legendChip.visible ? legendChip.height / 2 : 0
      color: "transparent"
      radius: Theme.space(8)
      border.width: 1
      border.color: Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.9)
      antialiasing: true
    }

    Item {
      id: legendChip
      x: Theme.space(14)
      y: 0
      width: legendTextItem.implicitWidth + Theme.space(8)
      height: Math.max(1, legendTextItem.implicitHeight)
      visible: tile.label !== ""

      Rectangle {
        anchors.fill: parent
        color: Theme.popups.background
      }

      Text {
        id: legendTextItem
        x: Theme.space(4)
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: tile.label
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Theme.font.caption
        font.bold: true
      }
    }

    Text {
      anchors.fill: frame
      anchors.leftMargin: Theme.space(8)
      anchors.rightMargin: Theme.space(8)
      textFormat: Text.PlainText
      text: tile.value
      color: tile.valueColor
      font.family: root.fontFamily
      font.pixelSize: Theme.font.display
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
      fontSizeMode: Text.HorizontalFit
      minimumPixelSize: Theme.font.body
    }
  }
}
