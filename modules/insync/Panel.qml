import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.commons
import qs.ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "evo.insync"
  ipcTarget: "evo.insync"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: bar && bar.barForeground ? bar.barForeground : Theme.foreground
  readonly property color urgent: bar ? bar.urgent : Theme.urgent
  readonly property color accent: Theme.accent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Theme.font.family

  readonly property string statusScript: Qt.resolvedUrl("bin/insync-status").toString().replace("file://", "")
  readonly property string toggleHint: root.data && root.data.paused ? "Resume syncing" : "Pause syncing"
  readonly property int pollMs: 2000

  property bool loading: true
  property var data: Model.emptyData()
  property real shownSynced: 0
  property real shownSyncing: 0

  Behavior on shownSynced {
    NumberAnimation { duration: 450; easing.type: Easing.OutCubic }
  }

  Behavior on shownSyncing {
    NumberAnimation { duration: 450; easing.type: Easing.OutCubic }
  }

  readonly property bool iconActive: Model.iconActive(data, loading)
  readonly property bool warningState: Model.hasWarning(data)
  readonly property bool iconError: warningState || !!(data && data.error)
  readonly property bool iconBusy: iconActive
  readonly property bool iconMuted: !loading && ((data && data.paused) || Model.isUnavailable(data))
  readonly property string barTooltip: Model.barTooltip(data, loading)
  readonly property string statusLine: Model.heroMeta(data, loading)
  readonly property color statusLineColor: Model.statusLineColor(data, loading, accent, urgent, foreground)
  readonly property real syncedBytes: Math.max(0, Number(data && data.syncedBytes) || 0)
  readonly property var displayAccounts: Array.isArray(data && data.accounts) ? data.accounts : []
  readonly property var displayErrors: Array.isArray(data && data.errors) ? data.errors : []
  readonly property var displayRecent: Model.recentFiles(data)

  function applyAccountFields(parsed) {
    if (!parsed || typeof parsed !== "object") return
    var current = data && typeof data === "object" ? data : Model.emptyData()
    data = {
      ok: parsed.ok === true,
      error: String(parsed.error || ""),
      status: String(parsed.status || ""),
      paused: parsed.paused === true,
      accounts: Array.isArray(parsed.accounts) ? parsed.accounts : [],
      files: parsed.paused === true ? [] : (Array.isArray(current.files) ? current.files : []),
      errors: Array.isArray(parsed.errors) ? parsed.errors : [],
      recent: Array.isArray(parsed.recent) ? parsed.recent : (Array.isArray(current.recent) ? current.recent : []),
      syncedFiles: Number(parsed.syncedFiles) || 0,
      syncedBytes: Number(parsed.syncedBytes) || 0
    }
    loading = false
    syncAnimatedStats()
  }

  function applyFiles(parsed) {
    if (!parsed || typeof parsed !== "object") return
    var current = data && typeof data === "object" ? data : Model.emptyData()
    data = {
      ok: parsed.ok === true,
      error: String(parsed.error || ""),
      status: String(parsed.status || ""),
      paused: parsed.paused === true,
      accounts: Array.isArray(parsed.accounts) ? parsed.accounts : (Array.isArray(current.accounts) ? current.accounts : []),
      files: Array.isArray(parsed.files) ? parsed.files : [],
      errors: Array.isArray(parsed.errors) ? parsed.errors : [],
      recent: Array.isArray(parsed.recent) ? parsed.recent : [],
      syncedFiles: Number(parsed.syncedFiles) || 0,
      syncedBytes: Number(parsed.syncedBytes) || 0
    }
    syncAnimatedStats()
  }

  function syncAnimatedStats() {
    var current = data && typeof data === "object" ? data : Model.emptyData()
    shownSynced = Number(current.syncedFiles) || 0
    shownSyncing = current.paused === true || !Array.isArray(current.files) ? 0 : current.files.length
  }

  function applyPayload(raw, fromCache) {
    var parsed = Model.parsePayload(raw)
    if (fromCache) {
      applyAccountFields(parsed)
      return
    }
    applyAccountFields(parsed)
    applyFiles(parsed)
    loading = false
  }

  function bootstrapFromCache() {
    if (!statusScript || cacheProc.running) return
    cacheProc.command = ["bash", statusScript, "account-cache"]
    cacheProc.running = true
  }

  function refresh() {
    if (!statusScript || statusProc.running) return
    if (!data.ok && displayAccounts.length === 0) loading = true
    statusProc.command = ["bash", statusScript, "popup"]
    statusProc.running = true
  }

  function runAction(subcmd) {
    if (actionProc.running) return
    actionProc.command = ["bash", statusScript, subcmd]
    actionProc.running = true
  }

  function togglePaused() {
    if (actionProc.running) return
    var current = data && typeof data === "object" ? data : Model.emptyData()
    var wasPaused = current.paused === true
    data = {
      ok: current.ok,
      error: current.error,
      status: current.status,
      paused: !wasPaused,
      accounts: Array.isArray(current.accounts) ? current.accounts : [],
      files: [],
      errors: Array.isArray(current.errors) ? current.errors : [],
      recent: Array.isArray(current.recent) ? current.recent : [],
      syncedFiles: Number(current.syncedFiles) || 0,
      syncedBytes: Number(current.syncedBytes) || 0
    }
    syncAnimatedStats()
    root.runAction(wasPaused ? "resume" : "pause")
  }

  function showFloating() {
    if (!statusScript) return
    Quickshell.execDetached(["bash", statusScript, "show"])
  }

  function openFromHotkey() {
    root.controller.show()
    root.refresh()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  Component.onCompleted: {
    bootstrapFromCache()
    refresh()
  }

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
    id: cacheProc
    onStarted: { stdoutBuf = ""; stderrBuf = "" }

    property string stdoutBuf: ""
    property string stderrBuf: ""
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        cacheProc.stdoutBuf += chunk
        if (cacheProc.stdoutBuf.length > 262144) {
          cacheProc.signal(15)
          cacheProc.stdoutBuf = ""
        }
      }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        cacheProc.stderrBuf += chunk
        if (cacheProc.stderrBuf.length > 4096) {
          cacheProc.signal(15)
          cacheProc.stderrBuf = ""
        }
      }
    }
      onExited: function(exitCode) {
      var raw = String(stdoutBuf || "").trim()
        if (!raw) return
        root.applyPayload(raw, true)
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
    onExited: {
      var raw = String(stdoutBuf || "").trim()
        if (!raw) {
          root.loading = false
          return
        }
        root.applyPayload(raw, false)

      root.loading = false
    }
  }

  Process {
    id: actionProc
    onExited: root.refresh()
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
      onTabRequested: function(direction) { root.switchPanel(direction) }

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
            id: hero
            width: parent.width
            title: "Insync"
            meta: root.statusLine
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: !root.data.paused ? (root.iconActive ? 1 : 0.7) : 0.5

            iconComponent: Component {
              Text {
                textFormat: Text.PlainText
                text: "󰋼"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Theme.font.display
                opacity: 0.92
              }
            }

            trailingControl: Component {
              ToggleSwitch {
                id: pauseSwitch
                checked: !root.data.paused
                busy: actionProc.running
                foreground: hero.foreground
                onToggled: root.togglePaused()

                PanelToolTip {
                  visible: pauseSwitch.containsMouse
                  text: root.toggleHint
                  fontFamily: hero.fontFamily
                }
              }
            }
          }

          Row {
            visible: !root.loading && root.data.ok === true
            width: parent.width
            spacing: Theme.space(16)

            StatTile {
              width: (parent.width - parent.spacing * 2) / 3
              value: Model.formatCount(root.shownSynced)
              label: "synced"
            }

            StatTile {
              width: (parent.width - parent.spacing * 2) / 3
              value: Model.formatCount(root.shownSyncing)
              label: "syncing"
              valueColor: root.shownSyncing > 0 ? root.accent : root.foreground
            }

            StatTile {
              width: (parent.width - parent.spacing * 2) / 3
              value: Model.formatBytes(root.syncedBytes)
              label: "size"
            }
          }

          Item {
            id: accountsBox
            visible: root.displayAccounts.length > 0
            width: parent.width
            implicitHeight: accountsFrame.height + (accountsLegend.visible ? accountsLegend.height / 2 : 0)

            Rectangle {
              id: accountsFrame
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.topMargin: accountsLegend.visible ? accountsLegend.height / 2 : 0
              height: accountsColumn.implicitHeight + Theme.space(32)
              color: "transparent"
              radius: Theme.space(8)
              border.width: 1
              border.color: Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.9)
              antialiasing: true
            }

            Item {
              id: accountsLegend
              x: Theme.space(14)
              y: 0
              width: accountsLegendText.implicitWidth + Theme.space(8)
              height: Math.max(1, accountsLegendText.implicitHeight)
              visible: accountsBox.visible

              Rectangle {
                anchors.fill: parent
                color: Theme.popups.background
              }

              Text {
                id: accountsLegendText
                x: Theme.space(4)
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: "accounts"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Theme.font.caption
                font.bold: true
              }
            }

            Column {
              id: accountsColumn
              anchors.left: accountsFrame.left
              anchors.right: accountsFrame.right
              anchors.top: accountsFrame.top
              anchors.topMargin: Theme.space(16)
              anchors.leftMargin: Theme.space(12)
              anchors.rightMargin: Theme.space(12)
              spacing: Theme.space(8)

              Repeater {
                model: root.displayAccounts

                AccountRow {
                  required property var modelData
                  width: accountsColumn.width
                  account: modelData
                }
              }
            }
          }

          PanelSeparator {
            visible: root.displayErrors.length > 0
            foreground: root.foreground
          }

          PanelSectionHeader {
            visible: root.displayErrors.length > 0
            width: parent.width
            text: "ERRORS"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Repeater {
            model: root.displayErrors

            Text {
              textFormat: Text.PlainText
              required property var modelData
              width: column.width
              text: String(modelData)
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Theme.font.bodySmall
              wrapMode: Text.WordWrap
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: String(root.data && root.data.error ? root.data.error : "") !== "" && root.displayErrors.length === 0
            text: root.data && root.data.error ? String(root.data.error) : ""
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Theme.font.body
            wrapMode: Text.WordWrap
          }

          Item {
            id: recentBox
            visible: root.displayRecent.length > 0
            width: parent.width
            implicitHeight: recentFrame.height + (recentLegend.visible ? recentLegend.height / 2 : 0)

            Rectangle {
              id: recentFrame
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.topMargin: recentLegend.visible ? recentLegend.height / 2 : 0
              height: recentColumn.implicitHeight + Theme.space(32)
              color: "transparent"
              radius: Theme.space(8)
              border.width: 1
              border.color: Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.9)
              antialiasing: true
            }

            Item {
              id: recentLegend
              x: Theme.space(14)
              y: 0
              width: recentLegendText.implicitWidth + Theme.space(8)
              height: Math.max(1, recentLegendText.implicitHeight)
              visible: recentBox.visible

              Rectangle {
                anchors.fill: parent
                color: Theme.popups.background
              }

              Text {
                id: recentLegendText
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
              anchors.topMargin: Theme.space(16)
              anchors.leftMargin: Theme.space(12)
              anchors.rightMargin: Theme.space(12)
              spacing: Theme.space(8)

              Repeater {
                model: root.displayRecent

                RecentRow {
                  required property var modelData
                  width: recentColumn.width
                  file: modelData
                }
              }
            }
          }
        }
      }
    }
  }

  component RecentRow: Row {
    property var file: null
    spacing: Theme.spacing.sm
    width: parent.width

    Item {
      id: iconSlot
      width: details.height
      height: details.height

      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: Model.fileIcon(file ? file.name : "")
        color: root.foreground
        opacity: 0.72
        font.family: root.fontFamily
        font.pixelSize: Math.round(parent.height * 0.78)
      }
    }

    Column {
      id: details
      width: parent.width - iconSlot.width - parent.spacing
      spacing: Theme.spacing.labelGap

      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: Model.plain(file && file.name, 160)
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Theme.font.body
        elide: Text.ElideMiddle
      }

      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: Model.recentMeta(file)
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Theme.font.caption
        elide: Text.ElideRight
      }
    }
  }

  component AccountRow: Row {
    property var account: null
    spacing: Theme.spacing.sm
    width: parent.width

    Item {
      id: iconSlot
      width: details.height
      height: details.height

      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: Model.providerIcon(account ? account.provider : "")
        color: root.foreground
        opacity: 0.72
        font.family: root.fontFamily
        font.pixelSize: Math.round(parent.height * 0.78)
      }
    }

    Column {
      id: details
      width: parent.width - iconSlot.width - parent.spacing
      spacing: Theme.spacing.labelGap

      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: String(account && account.email ? account.email : "")
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Theme.font.body
        font.bold: true
        elide: Text.ElideRight
      }

      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: String(account && account.provider ? account.provider : "Account")
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Theme.font.caption
        elide: Text.ElideRight
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
