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
  moduleName: "evo.github"
  ipcTarget: "evo.github"
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
  readonly property var palette: Theme.heatmapColors

  property bool loading: false
  property var data: null
  property string statusText: ""

  property real shownToday: 0
  property real shownTotal30: 0
  property real shownStreak: 0
  property real shownBest: 0
  property real revealProgress: 0
  property int todayCelebrateToken: 0

  NumberAnimation {
    id: todayCountAnim
    target: root
    property: "shownToday"
    easing.type: Easing.OutCubic
    onFinished: root.todayCelebrateToken++
  }

  Behavior on shownTotal30 {
    enabled: !root.loading
    NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
  }

  Behavior on shownStreak {
    enabled: !root.loading
    NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
  }

  Behavior on shownBest {
    enabled: !root.loading
    NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
  }

  NumberAnimation {
    id: revealAnimation
    target: root
    property: "revealProgress"
    from: 0
    to: 1
    duration: 400
    easing.type: Easing.OutCubic
  }

  readonly property bool hasData: !!(data && data.ok === true)
  readonly property var cells: (data && data.cells instanceof Array) ? data.cells : []
  readonly property bool iconActive: hasData && (data.today || 0) > 0
  readonly property bool iconError: !loading && !hasData && statusText !== ""
  readonly property bool iconBusy: loading
  readonly property bool iconMuted: false
  readonly property string barTooltip: Model.plain(hasData
    ? (data.today + " contribution" + (data.today === 1 ? "" : "s") + " today")
    : "GitHub contributions")

  readonly property int trendsSpacing: 3
  readonly property var trendCells: hasData ? Model.sparkBars(cells, palette, 40) : []
  readonly property string todayLabel: (data && data.today === 1)
    ? "contribution today"
    : "contributions today"
  readonly property color todayIconColor: hasData
    ? Model.contributionColor(data.today, palette)
    : foreground

  readonly property string statusScript: Qt.resolvedUrl("bin/github-status").toString().replace("file://", "")
  readonly property string repoScript: Qt.resolvedUrl("bin/repo-dirty-status").toString().replace("file://", "")
  readonly property string repoSettingsScript: Qt.resolvedUrl("bin/repo-settings").toString().replace("file://", "")
  readonly property string repoCommitScript: Qt.resolvedUrl("bin/repo-agent-commit").toString().replace("file://", "")
  readonly property string repoCommitAllScript: Qt.resolvedUrl("bin/repo-agent-commit-all").toString().replace("file://", "")
  readonly property string repoPushScript: Qt.resolvedUrl("bin/repo-git-push").toString().replace("file://", "")
  readonly property int refreshMinutes: Math.max(5, parseInt(setting("refreshMinutes", 15), 10) || 15)

  property bool repoLoading: true
  property bool repoLoaded: false
  property var repoData: ({ ok: true, repos: [], error: "" })
  property bool repoUnconfigured: false
  property var configuredRepoRoots: []
  property var savedRepoRoots: null
  property var repoSetupCandidates: []
  property string repoSetupError: ""
  property bool repoSetupSaving: false
  readonly property var repoList: (repoData && repoData.ok === true && repoData.repos instanceof Array)
    ? repoData.repos : []
  readonly property bool repoError: !repoLoading && !(repoData && repoData.ok === true)
  readonly property string repoStatusText: repoData && repoData.error ? String(repoData.error) : ""
  readonly property bool showRepoSection: root.hasData && (
    root.repoLoading || root.repoUnconfigured || root.repoList.length > 0
      || root.configuredRepoRoots.length > 0 || root.repoSetupCandidates.length > 0)
  readonly property string repoCleanMessage: Model.repoCleanMessage(root.configuredRepoRoots)
  property string expandedRepoPath: ""
  readonly property var repoTotals: Model.repoTotals(root.repoList)
  readonly property int dirtyRepoCount: repoTotals.dirtyRepos
  readonly property int unpushedRepoCount: repoTotals.unpushedRepos

  function emptyData() {
    return {
      ok: false,
      today: 0,
      total30: 0,
      streak: 0,
      best: 0,
      username: "",
      profileUrl: "https://github.com/",
      cells: []
    }
  }

  function applyPayload(raw) {
    loading = false
    var parsed = Model.parsePayload(raw)
    data = {
      ok: parsed.ok === true,
      today: parsed.ok ? (parsed.today || 0) : 0,
      total30: parsed.ok ? (parsed.total30 || 0) : 0,
      streak: parsed.ok ? (parsed.streak || 0) : 0,
      best: parsed.ok ? (parsed.best || 0) : 0,
      username: parsed.ok ? (parsed.username || "") : "",
      profileUrl: parsed.ok ? (parsed.profileUrl || "https://github.com/") : "https://github.com/",
      cells: parsed.ok && parsed.cells instanceof Array ? parsed.cells : []
    }
    statusText = parsed.ok ? "" : (parsed.error || "No data")
    syncAnimatedStats()
  }

  function syncAnimatedStats() {
    if (!hasData) {
      todayCountAnim.stop()
      shownToday = 0
      shownTotal30 = 0
      shownStreak = 0
      shownBest = 0
      return
    }

    animateTodayCountTo(data.today || 0, false)
    shownTotal30 = data.total30 || 0
    shownStreak = data.streak || 0
    shownBest = data.best || 0
  }

  function animateTodayCountTo(target, fromZero) {
    var next = Number(target) || 0
    var start = fromZero ? 0 : shownToday
    if (!fromZero && Math.round(start) === Math.round(next)) {
      shownToday = next
      return
    }

    todayCountAnim.stop()
    todayCountAnim.from = fromZero ? 0 : start
    todayCountAnim.to = next
    todayCountAnim.duration = Math.min(1100, Math.max(480, next * 24))
    todayCountAnim.start()
  }

  function refresh(force) {
    refreshGithub(force === true)
    if (force === true || root.opened)
      refreshRepos(force === true)
  }

  function refreshGithub(forceRefresh) {
    if (!statusScript || statusProc.running) return
    if (!hasData) loading = true
    var cmd = ["bash", statusScript]
    if (forceRefresh === true) cmd.push("--refresh")
    statusProc.run(cmd)
  }

  function refreshRepos(forceRefresh) {
    if (!repoScript || repoProc.running) return
    if (!repoLoaded) repoLoading = true
    var cmd = ["bash", repoScript]
    if (forceRefresh === true) cmd.push("--refresh")
    // savedRepoRoots covers the gap until shell.json reaches `settings`.
    var roots = setting("repoRoots", savedRepoRoots)
    if (roots !== undefined && roots !== null) cmd.push("--roots", JSON.stringify(roots))
    repoProc.run(cmd)
  }

  function applyRepoPayload(raw) {
    repoLoading = false
    repoLoaded = true
    var parsed = Model.parseRepoPayload(raw)
    repoUnconfigured = parsed.unconfigured === true
    if (!repoUnconfigured && parsed.repoRoots instanceof Array)
      configuredRepoRoots = parsed.repoRoots
    repoData = {
      ok: parsed.ok === true,
      repos: parsed.ok && parsed.repos instanceof Array ? parsed.repos : [],
      error: parsed.ok ? "" : (parsed.error || "Scan failed")
    }
    if (repoUnconfigured)
      loadRepoSetup()
  }

  function loadRepoSetup() {
    if (!repoSettingsScript || repoSetupProc.running) return
    repoSetupError = ""
    repoSetupProc.command = ["bash", repoSettingsScript, "detect"]
    repoSetupProc.running = true
  }

  function setSetupSelected(index, selected) {
    if (index < 0 || index >= repoSetupCandidates.length) return
    var next = repoSetupCandidates.slice()
    var item = next[index]
    next[index] = {
      path: item.path,
      label: item.label,
      exists: item.exists,
      selected: selected === true
    }
    repoSetupCandidates = next
  }

  function saveRepoRoots() {
    if (repoSetupSaving) return
    var shell = root.bar ? root.bar.shell : null
    if (!shell || typeof shell.updateEntryInline !== "function") {
      repoSetupError = "Shell config is not writable from this bar"
      return
    }
    var roots = []
    for (var i = 0; i < repoSetupCandidates.length; i++) {
      var item = repoSetupCandidates[i]
      if (item && item.selected === true)
        roots.push({ path: String(item.path || ""), label: String(item.label || "") })
    }
    repoSetupSaving = true
    repoSetupError = ""
    var next = {}
    var current = root.settings || {}
    for (var key in current) next[key] = current[key]
    next.repoRoots = roots
    savedRepoRoots = roots
    shell.updateEntryInline(root.moduleName, next)
    repoSetupSaving = false
    repoUnconfigured = false
    configuredRepoRoots = roots
    repoSetupCandidates = []
    refreshRepos(true)
  }

  onSettingsChanged: if (repoLoaded) refreshRepos(true)

  function openRepo(path) {
    var dir = path ? String(path) : ""
    if (!dir) return
    Quickshell.execDetached(["xdg-terminal-exec", "--dir=" + dir])
    root.close()
  }

  function agentEnv() {
    return "EVO_GITHUB_AGENT=" + String(setting("agent", "cursor-agent"))
  }

  function runRepoAction(script, path) {
    var dir = path ? String(path) : ""
    if (!dir || !script) return
    Quickshell.execDetached(["env", agentEnv(), "bash", script, dir])
  }

  function commitAllRepos() {
    if (!repoCommitAllScript || repoCommitAllProc.running) return
    var command = ["env", agentEnv(), "bash", repoCommitAllScript]
    for (var i = 0; i < repoList.length; i++) {
      var repo = repoList[i]
      if (!repo || repo.unstaged !== true) continue
      var dir = String(repo.path || "")
      if (dir) command.push(dir)
    }
    if (command.length <= 4) return
    repoCommitAllProc.command = command
    repoCommitAllProc.running = true
  }

  function pushAllRepos() {
    if (!repoPushScript || repoPushAllProc.running) return
    var command = ["bash", repoPushScript]
    for (var i = 0; i < repoList.length; i++) {
      var repo = repoList[i]
      if (!repo || (parseInt(repo.unpushed, 10) || 0) <= 0) continue
      var dir = String(repo.path || "")
      if (dir) command.push(dir)
    }
    if (command.length <= 2) return
    repoPushAllProc.command = command
    repoPushAllProc.running = true
  }

  function toggleRepoExpand(path) {
    var dir = path ? String(path) : ""
    if (!dir) return
    expandedRepoPath = expandedRepoPath === dir ? "" : dir
  }

  function repoExpanded(path) {
    return expandedRepoPath !== "" && expandedRepoPath === String(path || "")
  }

  function openProfile() {
    var url = data && data.profileUrl ? String(data.profileUrl) : "https://github.com/"
    Quickshell.execDetached(["xdg-open", url])
    root.close()
  }

  function openFromHotkey() {
    var wasOpen = root.opened
    root.controller.show()
    if (wasOpen)
      root.refresh(true)
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  Component.onCompleted: {
    data = emptyData()
    refreshGithub()
  }

  onOpenedChanged: if (opened) {
    refreshGithub(true)
    refreshRepos(true)
    refreshTimer.start()
    revealProgress = 0
    revealAnimation.restart()
    animateTodayCountTo(hasData ? (data.today || 0) : 0, true)
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  } else {
    expandedRepoPath = ""
    refreshTimer.stop()
  }

  JsonPollRunner {
    id: statusProc
    autoStart: false
    active: false
    onExited: function(exitCode, stdoutText, stderrText) {
      var raw = String(stdoutText || "").trim()
      if (!raw) {
        root.loading = false
        if (!root.hasData) {
          root.applyPayload('{"class":"error","text":"No data"}')
          root.statusText = "No data"
        }
        return
      }
      root.applyPayload(raw)
      if (String(stderrText || "").trim() !== "" && !root.hasData)
        root.applyPayload(String(stderrText || ""))
    }
  }

  Timer {
    id: refreshTimer
    interval: root.refreshMinutes * 60 * 1000
    repeat: true
    onTriggered: root.refresh()
  }

  JsonPollRunner {
    id: repoProc
    autoStart: false
    active: false
    onExited: function(exitCode, stdoutText, stderrText) {
      var err = String(stderrText || "").trim()
      var raw = String(stdoutText || "").trim()
      if (exitCode !== 0 || !raw) {
        root.repoLoading = false
        if (err)
          root.applyRepoPayload('{"ok":false,"error":"' + err.replace(/"/g, '\\"') + '"}')
        return
      }
      root.applyRepoPayload(raw)
    }
  }

  Process {
    id: repoSetupProc
    onStarted: { stdoutBuf = ""; stderrBuf = "" }

    property string stdoutBuf: ""
    property string stderrBuf: ""
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        repoSetupProc.stdoutBuf += chunk
        if (repoSetupProc.stdoutBuf.length > 262144) {
          repoSetupProc.signal(15)
          repoSetupProc.stdoutBuf = ""
        }
      }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        repoSetupProc.stderrBuf += chunk
        if (repoSetupProc.stderrBuf.length > 4096) {
          repoSetupProc.signal(15)
          repoSetupProc.stderrBuf = ""
        }
      }
    }
      onExited: function(exitCode) {
      var parsed = Model.parseRepoDetectPayload(String(stdoutBuf || ""))
        if (parsed.ok !== true) {
          root.repoSetupError = parsed.error || "Detect failed"
          root.repoSetupCandidates = []
          return
        }
        root.repoSetupCandidates = parsed.candidates
      if (String(stderrBuf || "").trim() !== "")
          root.repoSetupError = String(stderrBuf || "").trim()
    }
  }

  Process {
    id: repoCommitAllProc
    onExited: root.refreshRepos(true)
  }

  Process {
    id: repoPushAllProc
    onExited: root.refreshRepos(true)
  }


  IpcHandler {
    enabled: !!root.hostWidget && root.hostWidget.ownsIpc
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
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Theme.space(640))

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

          Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: root.loading
            text: "Loading contributions…"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Theme.font.body
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: !root.loading && !root.hasData
            text: root.statusText
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Theme.font.body
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
          }

          MouseArea {
            width: parent.width
            visible: !root.loading && root.hasData
            implicitHeight: hero.implicitHeight
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openProfile()

            PanelHero {
              id: hero
              width: parent.width
              title: root.data.username ? ("@" + root.data.username) : "GitHub"
              meta: root.todayLabel
              foreground: root.foreground
              fontFamily: root.fontFamily

              iconComponent: Component {
                Text {
                  textFormat: Text.PlainText
                  text: "󰊤"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Theme.font.display
                  opacity: 0.92
                }
              }

              trailingControl: Component {
                Row {
                  spacing: Theme.space(8)

                  Item {
                    visible: !root.repoLoading && !root.repoError && !root.repoUnconfigured
                      && root.dirtyRepoCount > 0
                    width: visible ? commitAllButton.width : 0
                    height: todayBadge.height

                    RepoIconButton {
                      id: commitAllButton
                      anchors.verticalCenter: parent.verticalCenter
                      icon: "󰜘"
                      tooltip: repoCommitAllProc.running
                        ? "Committing all…"
                        : ("Commit all (" + root.dirtyRepoCount + ")")
                      iconColor: root.urgent
                      hoverColor: root.urgent
                      fontFamily: root.fontFamily
                      onClicked: if (!repoCommitAllProc.running) root.commitAllRepos()
                    }
                  }

                  Item {
                    visible: !root.repoLoading && !root.repoError && !root.repoUnconfigured
                      && root.unpushedRepoCount > 0
                    width: visible ? pushAllButton.width : 0
                    height: todayBadge.height

                    RepoIconButton {
                      id: pushAllButton
                      anchors.verticalCenter: parent.verticalCenter
                      icon: "󰁝"
                      tooltip: repoPushAllProc.running
                        ? "Pushing all…"
                        : ("Push all (" + root.unpushedRepoCount + ")")
                      iconColor: root.accent
                      hoverColor: root.accent
                      fontFamily: root.fontFamily
                      onClicked: if (!repoPushAllProc.running) root.pushAllRepos()
                    }
                  }

                  TodayCountBadge {
                    id: todayBadge
                    loading: root.loading
                    value: root.shownToday
                    fillColor: root.todayIconColor
                    fontFamily: root.fontFamily
                    celebrateToken: root.todayCelebrateToken
                  }
                }
              }
            }
          }

          Row {
            visible: !root.loading && root.hasData
            width: parent.width
            spacing: Theme.space(16)

            StatTile {
              width: (parent.width - parent.spacing * 2) / 3
              animatedValue: root.shownStreak
              streakFormat: true
              label: "streak"
              valueColor: root.data.streak > 0 ? root.accent : root.foreground
            }

            StatTile {
              width: (parent.width - parent.spacing * 2) / 3
              animatedValue: root.shownBest
              showDashWhenZero: true
              label: "best day"
            }

            StatTile {
              width: (parent.width - parent.spacing * 2) / 3
              animatedValue: root.dirtyRepoCount
              label: "dirty repos"
              valueColor: root.urgent
            }
          }

          Column {
            width: parent.width
            spacing: Theme.space(4)
            visible: !root.loading && root.hasData

            Item {
              id: trendsTrack
              width: parent.width
              visible: root.cells.length > 0
              implicitHeight: trendsRow.height

              readonly property int cellCount: root.cells.length
              readonly property int cellSize: cellCount > 0
                ? Math.max(7, Math.min(11, Math.floor(
                    (width - Math.max(0, cellCount - 1) * root.trendsSpacing) / cellCount)))
                : 8
              readonly property int rowHeight: cellSize + Theme.space(2)
              readonly property int chartWidth: cellCount > 0
                ? cellCount * cellSize + Math.max(0, cellCount - 1) * root.trendsSpacing
                : 0

              Row {
                id: trendsRow
                anchors.horizontalCenter: parent.horizontalCenter
                width: trendsTrack.chartWidth
                spacing: root.trendsSpacing

                Repeater {
                  model: root.cells

                  Item {
                    required property var modelData
                    required property int index
                    readonly property var cell: root.trendCells[index] || {}
                    readonly property bool cellHovered: hitArea.containsMouse
                    readonly property real cellReveal: Math.min(
                      1, Math.max(0, root.revealProgress * trendsTrack.cellCount - index))

                    width: trendsTrack.cellSize
                    height: trendsTrack.rowHeight
                    opacity: cellReveal
                    scale: 0.85 + 0.15 * cellReveal
                    transformOrigin: Item.Bottom

                    Rectangle {
                      width: trendsTrack.cellSize
                      height: trendsTrack.cellSize
                      anchors.bottom: parent.bottom
                      anchors.horizontalCenter: parent.horizontalCenter
                      radius: 1
                      color: parent.cell.color || root.palette[0]
                      opacity: parent.cellHovered ? 1 : ((parent.cell.value || 0) > 0 ? 0.92 : 0.55)
                      scale: parent.cellHovered ? 1.12 : 1
                      transformOrigin: Item.Center

                      Behavior on scale {
                        NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                      }
                    }

                    MouseArea {
                      id: hitArea
                      anchors.fill: parent
                      hoverEnabled: true
                      acceptedButtons: Qt.NoButton
                    }
                  }
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              visible: root.cells.length === 0
              text: "No activity data"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Theme.font.bodySmall
              horizontalAlignment: Text.AlignHCenter
            }
          }

          Item {
            id: reposBox
            visible: root.showRepoSection
            width: parent.width
            implicitHeight: reposFrame.height + (reposLegend.visible ? reposLegend.height / 2 : 0)

            Rectangle {
              id: reposFrame
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.topMargin: reposLegend.visible ? reposLegend.height / 2 : 0
              height: reposColumn.implicitHeight + Theme.space(12)
              color: "transparent"
              radius: Theme.space(8)
              border.width: 1
              border.color: Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.9)
              antialiasing: true
            }

            Item {
              id: reposLegend
              x: Theme.space(14)
              y: 0
              width: reposLegendText.implicitWidth + Theme.space(8)
              height: Math.max(1, reposLegendText.implicitHeight)
              visible: reposBox.visible

              Rectangle {
                anchors.fill: parent
                color: Theme.popups.background
              }

              Text {
                id: reposLegendText
                x: Theme.space(4)
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: "local repos"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Theme.font.caption
                font.bold: true
              }
            }

            Column {
              id: reposColumn
              anchors.left: reposFrame.left
              anchors.right: reposFrame.right
              anchors.top: reposFrame.top
              anchors.topMargin: Theme.space(8)
              anchors.leftMargin: Theme.space(12)
              anchors.rightMargin: Theme.space(12)
              spacing: Theme.space(8)

          Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: root.repoLoading
            text: "Scanning repos…"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Theme.font.bodySmall
            horizontalAlignment: Text.AlignHCenter
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: root.repoError
            text: root.repoStatusText
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Theme.font.bodySmall
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
          }

          Column {
            width: parent.width
            visible: root.repoUnconfigured && !root.repoLoading && !root.repoError
            spacing: Theme.space(8)

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: "Choose folders to scan for dirty repos"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Theme.font.bodySmall
              wrapMode: Text.WordWrap
            }

            Repeater {
              model: root.repoSetupCandidates

              CheckBox {
                required property var modelData
                required property int index
                width: parent.width
                text: "~/" + (modelData.label || "")
                checked: modelData.selected === true
                enabled: !root.repoSetupSaving
                font.family: root.fontFamily
                font.pixelSize: Theme.font.bodySmall
                onCheckedChanged: if (checked !== (modelData.selected === true))
                  root.setSetupSelected(index, checked)
              }
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              visible: root.repoSetupCandidates.length === 0 && root.repoSetupError === ""
              text: "No ~/projects, ~/Projects, ~/work, or ~/Work folders found. Add repoRoots to the evo.github bar entry in shell.json."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Theme.font.caption
              wrapMode: Text.WordWrap
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              visible: root.repoSetupError !== ""
              text: root.repoSetupError
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Theme.font.caption
              wrapMode: Text.WordWrap
            }

            MouseArea {
              width: saveRepoRootsLabel.implicitWidth + Theme.space(12)
              height: saveRepoRootsLabel.implicitHeight + Theme.space(8)
              enabled: !root.repoSetupSaving
              hoverEnabled: true
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: root.saveRepoRoots()

              Text {
                textFormat: Text.PlainText
                id: saveRepoRootsLabel
                anchors.centerIn: parent
                text: root.repoSetupSaving ? "Saving…" : "Save folders"
                color: parent.enabled && parent.containsMouse ? root.accent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Theme.font.bodySmall
                font.bold: true
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: !root.repoLoading && !root.repoError && !root.repoUnconfigured && root.repoList.length === 0
            text: root.repoCleanMessage
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Theme.font.bodySmall
            horizontalAlignment: Text.AlignHCenter
          }

          Column {
            id: repoColumn
            width: parent.width
            visible: !root.repoLoading && !root.repoError && !root.repoUnconfigured && root.repoList.length > 0
            spacing: Theme.space(4)

            Repeater {
              model: root.repoList

              Item {
                required property var modelData
                readonly property bool repoOpen: root.repoExpanded(modelData.path)
                width: repoColumn.width
                implicitHeight: repoCard.implicitHeight

                Rectangle {
                  id: repoCard
                  width: parent.width
                  implicitHeight: repoCardColumn.implicitHeight + Theme.space(8)
                  radius: Theme.cornerRadius
                  color: (repoHeaderHit.containsMouse || root.repoExpanded(modelData.path))
                    ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
                    : "transparent"

                  Column {
                    id: repoCardColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: Theme.space(4)
                    anchors.rightMargin: Theme.space(4)
                    anchors.topMargin: Theme.space(4)
                    spacing: Theme.spacing.labelGap

                    Item {
                      id: repoHeader
                      width: parent.width
                      implicitHeight: repoHeaderLayout.implicitHeight

                      RowLayout {
                        id: repoHeaderLayout
                        width: parent.width
                        spacing: Theme.space(8)

                        ColumnLayout {
                          Layout.fillWidth: true
                          Layout.alignment: Qt.AlignVCenter
                          spacing: Theme.spacing.labelGap

                          Text {
                            textFormat: Text.PlainText
                            Layout.fillWidth: true
                            text: modelData.name || ""
                            color: (repoHeaderHit.containsMouse || root.repoExpanded(modelData.path))
                              ? root.accent : root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Theme.font.bodySmall
                            font.bold: true
                            elide: Text.ElideRight
                          }

                          Text {
                            textFormat: Text.PlainText
                            Layout.fillWidth: true
                            text: "~/" + (modelData.parent || "projects") + "/" + (modelData.name || "")
                            color: root.dim
                            font.family: root.fontFamily
                            font.pixelSize: Theme.font.caption
                            elide: Text.ElideRight
                          }
                        }

                        RowLayout {
                          Layout.alignment: Qt.AlignVCenter
                          spacing: Theme.spacing.xs

                          StatusPill {
                            visible: modelData.unstaged === true
                            text: Model.unstagedPillLabel(modelData.dirtyCount)
                            textColor: root.urgent
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                          }

                          StatusPill {
                            visible: (parseInt(modelData.unpushed, 10) || 0) > 0
                            text: Model.unpushedPillLabel(modelData.unpushed)
                            textColor: root.accent
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                          }
                        }
                      }

                      MouseArea {
                        id: repoHeaderHit
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleRepoExpand(modelData.path)
                      }
                    }

                    Item {
                      id: repoDetailsClip
                      width: parent.width
                      height: repoOpen ? detailsColumn.implicitHeight : 0
                      clip: true

                      Behavior on height {
                        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                      }

                      Column {
                        id: detailsColumn
                        width: parent.width
                        spacing: Theme.spacing.labelGap
                        topPadding: Theme.space(2)
                        bottomPadding: Theme.space(2)
                        y: repoOpen ? 0 : -Theme.space(6)
                        opacity: repoOpen ? 1 : 0

                        Behavior on y {
                          NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                        }

                        Behavior on opacity {
                          NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }

                        Repeater {
                          model: Model.repoDetailItems(modelData)

                          Row {
                            required property var modelData
                            width: parent.width
                            spacing: Theme.space(8)

                            Text {
                              textFormat: Text.PlainText
                              width: Theme.space(72)
                              text: modelData.label
                              color: root.dim
                              font.family: root.fontFamily
                              font.pixelSize: Theme.font.caption
                            }

                            Text {
                              textFormat: Text.PlainText
                              width: parent.width - Theme.space(72) - parent.spacing
                              text: modelData.value
                              color: root.foreground
                              font.family: root.fontFamily
                              font.pixelSize: Theme.font.caption
                              wrapMode: Text.Wrap
                            }
                          }
                        }

                        Row {
                          width: parent.width
                          spacing: Theme.space(2)
                          topPadding: Theme.space(4)

                          RepoIconButton {
                            icon: "󰜘"
                            tooltip: "Commit with agent"
                            visible: modelData.unstaged === true
                            iconColor: root.urgent
                            onClicked: root.runRepoAction(root.repoCommitScript, modelData.path)
                          }

                          RepoIconButton {
                            icon: "󰁝"
                            tooltip: "Push"
                            visible: (parseInt(modelData.unpushed, 10) || 0) > 0
                            onClicked: root.runRepoAction(root.repoPushScript, modelData.path)
                          }

                          RepoIconButton {
                            icon: "󰆍"
                            tooltip: "Open in terminal"
                            onClicked: root.openRepo(modelData.path)
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
            }
          }
        }
      }
    }
  }

  component RepoIconButton: MouseArea {
    property string icon: ""
    property string tooltip: ""
    property color iconColor: root.dim
    property color hoverColor: root.accent
    property string fontFamily: root.fontFamily

    width: iconText.implicitWidth + Theme.space(10)
    height: iconText.implicitHeight + Theme.space(6)
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    Text {
      textFormat: Text.PlainText
      id: iconText
      anchors.centerIn: parent
      text: parent.icon
      color: parent.containsMouse ? parent.hoverColor : parent.iconColor
      font.family: parent.fontFamily
      font.pixelSize: Theme.font.body
    }

    PanelToolTip {
      visible: parent.containsMouse
      text: parent.tooltip
      fontFamily: parent.fontFamily
    }
  }

  component TodayCountBadge: Rectangle {
    id: badge
    property bool loading: false
    property real value: 0
    property color fillColor: Theme.accent
    property string fontFamily: Theme.font.family
    property int celebrateToken: 0

    readonly property int rounded: Math.round(value)
    property real popScale: 1

    onCelebrateTokenChanged: if (celebrateToken > 0) celebrate()

    function celebrate() {
      if (loading || rounded <= 0)
        return
      popAnim.restart()
    }

    implicitWidth: countText.implicitWidth + Theme.spacing.lg * 2
    implicitHeight: countText.implicitHeight + Theme.spacing.sm * 2
    radius: implicitHeight / 2
    color: Qt.rgba(fillColor.r, fillColor.g, fillColor.b, 0.14)
    scale: popScale
    transformOrigin: Item.Center

    SequentialAnimation {
      id: popAnim
      NumberAnimation {
        target: badge
        property: "popScale"
        to: 1.07
        duration: 140
        easing.type: Easing.OutCubic
      }
      NumberAnimation {
        target: badge
        property: "popScale"
        to: 1
        duration: 220
        easing.type: Easing.OutBack
      }
    }

    Text {
      textFormat: Text.PlainText
      id: countText
      anchors.centerIn: parent
      text: parent.loading ? "…" : String(parent.rounded)
      color: parent.fillColor
      font.family: parent.fontFamily
      font.pixelSize: Theme.font.displayLarge
      font.bold: true
    }
  }

  component StatusPill: Rectangle {
    property string text: ""
    property color textColor: foreground
    property color foreground: Theme.foreground
    property string fontFamily: Theme.font.family

    implicitWidth: pillText.implicitWidth + Theme.spacing.lg * 2
    implicitHeight: pillText.implicitHeight + Theme.spacing.sm * 2
    radius: 0
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

  component StatTile: Item {
    id: tile
    property string value: ""
    property string label: ""
    property color valueColor: root.accent
    property real animatedValue: -1
    property bool streakFormat: false
    property bool showDashWhenZero: false

    readonly property string displayValue: {
      if (animatedValue < 0)
        return value

      var n = Math.round(animatedValue)
      if (streakFormat)
        return n > 0 ? n + (n === 1 ? " day" : " days") : "—"
      if (showDashWhenZero && n <= 0)
        return "—"
      return String(n)
    }

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
      text: tile.displayValue
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
