import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.commons
import qs.ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "evo.now-playing"
  ipcTarget: "evo.now-playing"
  manageIpc: false

  function evoplayerBin() {
    var env = Quickshell.env("EVOPLAYER_BIN")
    if (env && String(env).trim() !== "")
      return String(env).trim()
    return (Quickshell.env("HOME") || "") + "/.local/lib/evoplayer/evoplayer"
  }

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: Theme.foreground
  readonly property color urgent: bar ? bar.urgent : Theme.urgent
  readonly property color accent: Theme.accent
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Theme.font.family
  readonly property color background: Theme.background

  readonly property var mediaService: bar && bar.shell ? bar.shell.serviceFor("evo.now-playing") : null
  readonly property var activePlayer: mediaService ? mediaService.activePlayer : null
  readonly property bool hasMedia: activePlayer !== null && !!(activePlayer.trackTitle || activePlayer.trackArtist)
  readonly property bool playerPlaying: !!(activePlayer && activePlayer.isPlaying)
  readonly property string trackTitle: activePlayer ? String(activePlayer.trackTitle || "") : ""
  readonly property string trackArtist: activePlayer ? String(activePlayer.trackArtist || "") : ""
  readonly property string trackAlbum: activePlayer && activePlayer.trackAlbum ? String(activePlayer.trackAlbum) : ""
  readonly property string trackArtUrl: activePlayer && activePlayer.trackArtUrl ? String(activePlayer.trackArtUrl) : ""
  readonly property string playerIdentity: activePlayer ? String(activePlayer.identity || activePlayer.desktopEntry || "") : ""

  readonly property var playingActions: ["previous", "playPause", "next"]

  property var recentRows: []
  readonly property string playingPath: filePathFromUrl(activePlayer && activePlayer.metadata ? activePlayer.metadata["xesam:url"] : "")
  readonly property var history: rowsExceptPlaying(recentRows, hasMedia, trackTitle, trackArtist, playingPath)
  property bool historyLoading: false
  property bool dashReady: false
  property string artDir: ""
  property var dash: ({})
  property real positionTick: 0
  readonly property real trackDuration: {
    if (!Model.isEvoplayer(activePlayer) || !mediaService || !mediaService.player)
      return 0
    var d = Number(mediaService.player.duration) || 0
    return d > 0 && d < 86400 ? d : 0
  }

  property bool cursorActive: false
  property string focusSection: "history"
  property int selectedIndex: 0
  property int playingIndex: 1

  readonly property int panelContentHeight: panelColumn.implicitHeight
  readonly property int historyThumb: Theme.space(40)
  readonly property int historyRowHeight: root.historyThumb + Theme.space(8)
  readonly property var dashCells: [
    { label: "SCROBBLES", key: "scrobbles" },
    { label: "ARTISTS", key: "artists" },
    { label: "ALBUMS", key: "albums" },
    { label: "TRACKS", key: "tracks" }
  ]
  readonly property bool iconActive: Model.iconActive(playerPlaying)
  readonly property bool iconError: false
  readonly property bool iconBusy: iconActive
  readonly property bool iconMuted: !iconActive
  readonly property string barTooltip: Model.barTooltip(playerPlaying, trackTitle)
  readonly property real playProgress: {
    var _ = root.positionTick
    var __ = root.trackDuration
    if (!activePlayer) return 0
    var len = 0
    if (activePlayer.lengthSupported && Number(activePlayer.length) > 0)
      len = Number(activePlayer.length)
    else
      len = trackDuration
    if (len <= 0) return 0
    var pos = Number(activePlayer.position) || 0
    return Math.max(0, Math.min(1, pos / len))
  }
  readonly property string heroTitle: hasMedia ? (trackTitle || "Unknown track") : "Media"
  readonly property string heroMeta: hasMedia
    ? Model.heroMeta(trackArtist, trackAlbum, playerIdentity)
    : (historyLoading ? "Loading scrobbles…" : "Scrobble history")
  readonly property string heroDetail: hasMedia ? Model.playbackLabel(activePlayer) : ""
  readonly property int nowPlayingArtSize: 96

  onHistoryChanged: {
    if (selectedIndex >= history.length)
      selectedIndex = Math.max(0, history.length - 1)
  }

  function filePathFromUrl(url) {
    var value = String(url || "").trim()
    if (value.indexOf("file://") !== 0)
      return ""
    var path = value.slice("file://".length)
    if (path.indexOf("%") >= 0) {
      try { path = decodeURIComponent(path) } catch (e) {}
    }
    if (!path || path.charAt(0) !== "/" || path.indexOf("\n") >= 0 || path.indexOf("\r") >= 0)
      return ""
    return path
  }

  function samePlaying(row, title, artist, path) {
    if (!row)
      return false
    var rowPath = String(row.path || "")
    if (path && rowPath === path)
      return true
    var rowTitle = String(row.title || "").trim().toLowerCase()
    var rowArtist = String(row.artist || "").trim().toLowerCase()
    var wantTitle = String(title || "").trim().toLowerCase()
    var wantArtist = String(artist || "").trim().toLowerCase()
    return rowTitle !== "" && rowArtist !== "" && rowTitle === wantTitle && rowArtist === wantArtist
  }

  function rowsExceptPlaying(rows, playing, title, artist, path) {
    var list = Array.isArray(rows) ? rows : []
    var out = []
    for (var i = 0; i < list.length && out.length < 3; i++) {
      var row = list[i]
      if (!row)
        continue
      if (playing && samePlaying(row, title, artist, path))
        continue
      out.push(row)
    }
    return out
  }

  function historyTitle(row) {
    if (!row)
      return ""
    var artist = String(row.artist || "")
    var title = String(row.title || "")
    if (artist && title)
      return artist + " — " + title
    return title || artist || "Unknown"
  }

  function historyWhen(row) {
    var at = row ? String(row.at || "") : ""
    if (at.length >= 16)
      return at.slice(11, 16)
    return ""
  }

  function pluginFile(rel) {
    var u = Qt.resolvedUrl(rel).toString()
    if (u.indexOf("file://") !== 0)
      return ""
    var path = decodeURIComponent(u.slice("file://".length))
    if (!path || path.charAt(0) !== "/" || path.indexOf("\n") >= 0 || path.indexOf("\r") >= 0)
      return ""
    return path
  }

  function historyEnv() {
    var env = {
      HOME: Quickshell.env("HOME") || "",
      PATH: "/usr/bin:/bin",
      LANG: "C.UTF-8"
    }
    var keys = ["XDG_STATE_HOME", "XDG_CACHE_HOME", "XDG_CONFIG_HOME"]
    for (var i = 0; i < keys.length; i++) {
      var value = Quickshell.env(keys[i]) || ""
      if (value && value.charAt(0) === "/" && value.indexOf("\n") < 0 && value.indexOf("\r") < 0)
        env[keys[i]] = value
    }
    return env
  }

  function dashValue(key) {
    if (!dashReady)
      return historyLoading ? "…" : "-"
    var n = dash ? dash[key] : undefined
    if (typeof n !== "number" || !isFinite(n) || n < 0 || n > 9999999)
      return "-"
    var text = String(Math.floor(n))
    return text.replace(/\B(?=(\d{3})+(?!\d))/g, ",")
  }

  function historyArtSource(row) {
    return Model.historyArtUrl(row && row.art, artDir)
  }

  function loadHistory() {
    if (historyProc.running)
      return
    var script = pluginFile("bin/history-dash")
    if (!script)
      return
    historyLoading = true
    historyProc.stdoutBuf = ""
    historyProc.overflow = false
    historyProc.environment = historyEnv()
    historyProc.command = ["/usr/bin/timeout", "-k", "2", "8", "/usr/bin/python3", "-I", script]
    historyProc.running = true
  }

  function playHistory(index) {
    if (index < 0 || index >= history.length)
      return
    var row = history[index]
    var path = row && row.path ? String(row.path) : ""
    if (!path || path.charAt(0) !== "/" || path.indexOf("\n") >= 0 || path.indexOf("\r") >= 0)
      return
    Quickshell.execDetached([evoplayerBin(), "queue", "play", path, path])
  }

  function ensureCursor() {
    if (focusSection === "playing" && !hasMedia)
      focusSection = "history"
    if (playingIndex < 0) playingIndex = 0
    if (playingIndex > 2) playingIndex = 2
    if (selectedIndex >= history.length)
      selectedIndex = Math.max(0, history.length - 1)
  }

  function moveCursor(dx, dy) {
    cursorActive = true
    ensureCursor()
    if (dy !== 0) {
      if (focusSection === "playing") {
        if (dy > 0 && history.length > 0) {
          focusSection = "history"
          selectedIndex = 0
        }
      } else if (focusSection === "history") {
        if (dy < 0 && selectedIndex <= 0) {
          if (hasMedia)
            focusSection = "playing"
        } else {
          selectedIndex = Math.max(0, Math.min(history.length - 1, selectedIndex + dy))
        }
      }
    }
    if (dx !== 0 && focusSection === "playing")
      playingIndex = Math.max(0, Math.min(playingActions.length - 1, playingIndex + dx))
  }

  function activateCursor() {
    ensureCursor()
    if (focusSection === "playing")
      runTransport(playingActions[playingIndex])
    else if (focusSection === "history")
      playHistory(selectedIndex)
  }

  function runTransport(action) {
    if (!mediaService || typeof mediaService.runAction !== "function") return
    mediaService.runAction(action, false)
  }

  function raisePlayer() {
    if (activePlayer && activePlayer.canRaise) {
      activePlayer.raise()
      return
    }
    if (Model.isEvoplayer(activePlayer))
      Quickshell.execDetached(["xdg-terminal-exec", "--", evoplayerBin()])
  }

  function refresh() {
    loadHistory()
  }

  function openFromHotkey() {
    root.controller.show()
    refresh()
  }

  function toggle() {
    if (root.opened) root.close()
    else openFromHotkey()
  }

  function openWithPayload(payloadJson) {
    openFromHotkey()
  }

  Component.onCompleted: refresh()

  onOpenedChanged: {
    if (opened) {
      cursorActive = false
      focusSection = hasMedia ? "playing" : "history"
      refresh()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }

  Process {
    id: historyProc
    clearEnvironment: true
    property string stdoutBuf: ""
    property bool overflow: false
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        if (historyProc.overflow)
          return
        historyProc.stdoutBuf += String(chunk || "")
        if (historyProc.stdoutBuf.length > 131072) {
          historyProc.overflow = true
          historyProc.stdoutBuf = ""
          historyProc.signal(15)
        }
      }
    }
    onExited: {
      root.historyLoading = false
      if (!historyProc.overflow) {
        try {
          var data = JSON.parse(historyProc.stdoutBuf || "{}")
          var recent = data && Array.isArray(data.recent) ? data.recent.slice(0, 4) : []
          var dir = data && typeof data.artDir === "string" ? data.artDir : ""
          root.artDir = dir.slice(-14) === "/evoplayer/art" ? dir : ""
          root.recentRows = recent
          root.dash = data && data.totals && typeof data.totals === "object" ? data.totals : {}
          root.dashReady = true
        } catch (e) {
          root.recentRows = []
          root.dashReady = false
        }
      } else {
        root.dashReady = false
      }
      historyProc.stdoutBuf = ""
      historyProc.overflow = false
    }
  }

  Timer {
    interval: 1000
    running: root.opened && root.playerPlaying
    repeat: true
    onTriggered: {
      if (root.activePlayer && root.activePlayer.isPlaying)
        root.activePlayer.positionChanged()
      root.positionTick = Date.now()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Theme.space(380))
    contentHeight: panel.fittedContentHeight(root.panelContentHeight, Theme.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      clip: true
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) {
          root.cursorActive = true
          return
        }
        root.moveCursor(dx, dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") {
          root.refresh()
        } else if (t === "p" || t === "P") {
          root.runTransport("playPause")
        } else if (t === "n" || t === "N") {
          root.runTransport("next")
        } else if (t === "b" || t === "B") {
          root.runTransport("previous")
        } else if (t === "o" || t === "O") {
          root.raisePlayer()
        }
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: root.panelContentHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      ColumnLayout {
        id: panelColumn
        width: panelFlick.width
        spacing: Theme.space(12)

        Item {
          Layout.fillWidth: true
          implicitHeight: nowPlayingRow.implicitHeight

          RowLayout {
            id: nowPlayingRow
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Theme.space(14)

            BorderSurface {
              Layout.preferredWidth: Math.max(root.nowPlayingArtSize, nowPlayingInfo.implicitHeight)
              Layout.preferredHeight: Math.max(root.nowPlayingArtSize, nowPlayingInfo.implicitHeight)
              Layout.alignment: Qt.AlignTop
              radius: Theme.cornerRadius
              color: Theme.popups.background
              borderSpec: Border.surfaceSpec("popups", "border", Theme.popups.border, 1)

              Image {
                id: heroArt
                anchors.fill: parent
                anchors.margins: Theme.space(2)
                source: Model.safeArtUrl(root.trackArtUrl)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: root.trackArtUrl !== "" && status === Image.Ready
              }

              Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                visible: !heroArt.visible
                text: root.hasMedia ? "󰝚" : "󰿯"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: root.hasMedia ? Theme.font.display : Theme.font.title
              }
            }

            ColumnLayout {
              id: nowPlayingInfo
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignTop
              spacing: Theme.space(8)

              RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space(8)

                Text {
                  textFormat: Text.PlainText
                  Layout.fillWidth: true
                  text: root.heroTitle
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Theme.font.title
                  font.bold: true
                  elide: Text.ElideRight
                  maximumLineCount: 2
                  wrapMode: Text.WordWrap
                }

                BorderSurface {
                  visible: root.heroDetail !== ""
                  implicitWidth: nowPlayingStatusText.implicitWidth + Theme.space(10)
                  implicitHeight: nowPlayingStatusText.implicitHeight + Theme.space(4)
                  color: "transparent"
                  borderSpec: Border.controlSpec("normal", root.foreground, Theme.accent)
                  radius: Theme.cornerRadius

                  Text {
                    textFormat: Text.PlainText
                    id: nowPlayingStatusText
                    anchors.centerIn: parent
                    text: root.heroDetail
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Theme.font.body
                    font.bold: true
                  }
                }
              }

              Text {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                text: root.heroMeta.toUpperCase()
                visible: text !== ""
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Theme.font.caption
                font.bold: true
                font.letterSpacing: 1.2
                elide: Text.ElideRight
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.space(8)
                visible: root.hasMedia

                Rectangle {
                  id: progressTrack
                  Layout.fillWidth: true
                  Layout.preferredHeight: 4
                  implicitHeight: 4
                  radius: 2
                  clip: true
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

                  Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: progressTrack.width * root.playProgress
                    color: root.accent
                  }
                }

                Row {
                  Layout.alignment: Qt.AlignHCenter
                  spacing: Theme.space(6)

                  Button {
                    iconText: "󰒮"
                    foreground: root.foreground
                    hasCursor: root.cursorActive && root.focusSection === "playing" && root.playingIndex === 0
                    bordered: hasCursor
                    enabled: root.activePlayer && root.activePlayer.canGoPrevious
                    opacity: enabled ? 1.0 : 0.4
                    onHovered: function(on) {
                      if (on) {
                        root.cursorActive = true
                        root.focusSection = "playing"
                        root.playingIndex = 0
                      }
                    }
                    onClicked: root.runTransport("previous")
                  }

                  Button {
                    iconText: root.playerPlaying ? "󰏤" : "󰐊"
                    foreground: root.foreground
                    iconSize: Theme.font.iconLarge
                    hasCursor: root.cursorActive && root.focusSection === "playing" && root.playingIndex === 1
                    bordered: hasCursor
                    enabled: root.activePlayer && (root.activePlayer.canTogglePlaying || root.activePlayer.canPlay || root.activePlayer.canPause)
                    opacity: enabled ? 1.0 : 0.4
                    onHovered: function(on) {
                      if (on) {
                        root.cursorActive = true
                        root.focusSection = "playing"
                        root.playingIndex = 1
                      }
                    }
                    onClicked: root.runTransport("playPause")
                  }

                  Button {
                    iconText: "󰒭"
                    foreground: root.foreground
                    hasCursor: root.cursorActive && root.focusSection === "playing" && root.playingIndex === 2
                    bordered: hasCursor
                    enabled: root.activePlayer && root.activePlayer.canGoNext
                    opacity: enabled ? 1.0 : 0.4
                    onHovered: function(on) {
                      if (on) {
                        root.cursorActive = true
                        root.focusSection = "playing"
                        root.playingIndex = 2
                      }
                    }
                    onClicked: root.runTransport("next")
                  }
                }
              }
            }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Theme.space(8)

        RowLayout {
          Layout.fillWidth: true
          spacing: Theme.space(8)

          Repeater {
            model: root.dashCells

            BorderSurface {
              required property var modelData
              Layout.fillWidth: true
              implicitHeight: dashCol.implicitHeight + Theme.spacing.lg * 2
              color: Theme.popups.background
              borderSpec: Border.surfaceSpec("popups", "border", Theme.popups.border, 1)
              radius: Theme.cornerRadius

              Column {
                id: dashCol
                anchors.centerIn: parent
                width: parent.width - Theme.spacing.lg * 2
                spacing: Theme.spacing.labelGap

                Text {
                  textFormat: Text.PlainText
                  width: parent.width
                  text: root.dashValue(modelData.key)
                  color: root.accent
                  font.family: root.fontFamily
                  font.pixelSize: Theme.font.title
                  font.bold: true
                  horizontalAlignment: Text.AlignHCenter
                  elide: Text.ElideRight
                }

                Text {
                  textFormat: Text.PlainText
                  width: parent.width
                  text: modelData.label
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Theme.font.caption
                  horizontalAlignment: Text.AlignHCenter
                  elide: Text.ElideRight
                }
              }
            }
          }
        }

        PanelSectionHeader {
          Layout.fillWidth: true
          text: "HISTORY"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          visible: root.historyLoading && root.history.length === 0
          text: "Loading scrobbles…"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Theme.font.bodySmall
        }

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          visible: !root.historyLoading && root.history.length === 0
          text: "No scrobbles yet"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Theme.font.bodySmall
        }

        ListView {
          Layout.fillWidth: true
          Layout.preferredHeight: Math.min(3, root.history.length) * root.historyRowHeight
          implicitHeight: Layout.preferredHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          model: root.history
          currentIndex: root.focusSection === "history" ? root.selectedIndex : -1
          highlightMoveDuration: 0
          onCurrentIndexChanged: {
            if (root.focusSection === "history" && currentIndex >= 0)
              positionViewAtIndex(currentIndex, ListView.Contain)
          }

          delegate: Item {
            required property var modelData
            required property int index
            width: ListView.view.width
            height: root.historyRowHeight

            readonly property bool selected: root.cursorActive && root.focusSection === "history" && root.selectedIndex === index

            Rectangle {
              anchors.fill: parent
              radius: 4
              color: selected ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : "transparent"
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Theme.space(4)
              anchors.rightMargin: Theme.space(6)
              spacing: Theme.space(8)

              Item {
                Layout.preferredWidth: root.historyThumb
                Layout.preferredHeight: root.historyThumb
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                  anchors.fill: parent
                  radius: Theme.space(3)
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
                }

                Image {
                  id: historyArt
                  anchors.fill: parent
                  source: root.historyArtSource(modelData)
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  cache: true
                  sourceSize.width: root.historyThumb
                  sourceSize.height: root.historyThumb
                  visible: status === Image.Ready
                }

                Text {
                  textFormat: Text.PlainText
                  anchors.centerIn: parent
                  visible: !historyArt.visible
                  text: "󰝚"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Theme.font.body
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Text {
                  textFormat: Text.PlainText
                  Layout.fillWidth: true
                  text: root.historyTitle(modelData)
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Theme.font.bodySmall
                  font.bold: selected
                  elide: Text.ElideRight
                }

                Text {
                  textFormat: Text.PlainText
                  Layout.fillWidth: true
                  visible: text !== ""
                  text: modelData && modelData.album ? String(modelData.album) : ""
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Theme.font.caption
                  elide: Text.ElideRight
                }
              }

              Text {
                textFormat: Text.PlainText
                Layout.alignment: Qt.AlignVCenter
                text: root.historyWhen(modelData)
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Theme.font.caption
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: {
                root.cursorActive = true
                root.focusSection = "history"
                root.selectedIndex = index
              }
              onClicked: root.playHistory(index)
            }
          }
        }
        }
      }
      }
    }
  }
}
