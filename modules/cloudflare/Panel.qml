import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.commons
import qs.ui
import "Api.js" as Api
import "Model.js" as Model
import "components"

Panel {
  id: root
  moduleName: "evo.cloudflare"
  ipcTarget: "evo.cloudflare"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: Theme.foreground
  readonly property color urgent: bar ? bar.urgent : Theme.urgent
  readonly property color accent: Theme.accent
  readonly property color dim: Qt.darker(foreground, 1.4)
  property color themeGreen: "#50fa7b"
  property color themeYellow: "#f1fa8c"
  property color themeOrange: "#ffb86c"
  property color themeMagenta: "#ff79c6"
  property color themeBlue: "#bd93f9"
  property color themeCyan: "#8be9fd"

  function loadThemeColors(raw) {
    var found = {}
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(/^\s*(green|yellow|orange|magenta|pink|mauve|blue|purple|cyan|color[0-9]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
      if (match) found[match[1]] = match[2]
    }
    // evoshell themes only carry ANSI color0..15; named keys win when present.
    themeGreen = found.green || found.color2 || "#50fa7b"
    themeYellow = found.yellow || found.color3 || "#f1fa8c"
    themeOrange = found.orange || found.color11 || "#ffb86c"
    themeMagenta = found.magenta || found.pink || found.mauve || found.color5 || "#ff79c6"
    themeBlue = found.blue || found.purple || found.color4 || "#bd93f9"
    themeCyan = found.cyan || found.color6 || accent
  }

  property FileView themeColorsFile: FileView {
    path: Theme.currentThemePath + "/colors.toml"
    watchChanges: true
    printErrors: false
    onLoaded: root.loadThemeColors(text())
    onFileChanged: reload()
  }

  Connections {
    target: Theme
    function onForegroundChanged() { root.themeColorsFile.reload() }
    function onAccentChanged() { root.themeColorsFile.reload() }
    function onBackgroundChanged() { root.themeColorsFile.reload() }
  }
  readonly property color surface: Theme.popups.background
  readonly property string fontFamily: bar ? bar.fontFamily : Theme.font.family

  readonly property var cf: hostWidget && hostWidget.cf ? hostWidget.cf : null

  readonly property string accountLegendLabel: {
    if (!cf)
      return ""
    void cf.accountName
    void cf.accountId
    if (cf.accountName !== "")
      return cf.accountName
    return ""
  }

  property double nowMs: Date.now()

  readonly property var rows: {
    if (!cf)
      return []
    void cf.lastRefreshMs
    void cf.loggedIn
    void cf.accountId
    void cf.refreshing
    void cf.analyticsRefreshing
    void cf.workers.length
    void cf.pages.length
    void cf.buckets.length
    void cf.databases.length
    void cf.namespaces.length
    void cf.queues.length
    void cf.zones.length
    void cf.analytics.loaded
    void cf.analytics.workerRequests
    void cf.analytics.requestHours
    void cf.analytics.workerErrors
    void cf.analytics.r2Bytes
    void cf.analytics.d1RowsRead
    return buildRows()
  }

  readonly property var groupedSections: {
    var sourceRows = root.rows
    void sourceRows.length
    return groupedSectionsFromRows(sourceRows)
  }

  readonly property var usageSection: sectionByTitle("USAGE")
  readonly property int usageStatCount: {
    var rows = usageSection.rows || []
    var count = 0
    for (var i = 0; i < rows.length; i++) {
      if (rows[i] && rows[i].id !== "worker-requests" && rows[i].id !== "worker-errors") count++
    }
    return count
  }
  readonly property var workersGroup: {
    var rows = resourcesSection.rows || []
    for (var i = 0; i < rows.length; i++) {
      if (rows[i] && rows[i].target === "worker") return rows[i]
    }
    return null
  }
  readonly property int upperStatCount: usageStatCount + (workersGroup ? 1 : 0)
  readonly property var resourcesSection: sectionByTitle("RESOURCES")
  readonly property var attentionSection: sectionByTitle("NEEDS ATTENTION")
  readonly property var recentGroupedSection: sectionByTitle("RECENT ACTIVITY")

  readonly property bool hasDisplaySections:
    root.usageSection.rows.length > 0
    || root.resourcesSection.rows.length > 0
    || root.attentionSection.rows.length > 0
    || root.recentGroupedSection.rows.length > 0

  readonly property bool iconActive: cf && cf.loggedIn && !cf.warning
  readonly property string barTooltip: {
    if (!cf) return "Cloudflare"
    if (cf.accountName !== "") return Model.plain(cf.accountName)
    if (cf.lastError !== "") return Model.plain(cf.lastError)
    return cf.loggedIn ? "Cloudflare" : "Cloudflare — not logged in"
  }

  function sectionByTitle(title) {
    var sections = root.groupedSections
    void sections.length
    for (var i = 0; i < sections.length; i++) {
      if (String(sections[i].title || "").toUpperCase() === title)
        return sections[i]
    }
    return { title: title, rows: [] }
  }

  function buildRows() {
    if (!cf)
      return []
    return Model.buildRows(cf.resourceState(), cf.analytics, {
      deployRows: cf.deployRows,
      overviewDeployRows: cf.overviewDeployRows,
      limits: cf.limits,
      filter: "",
      route: "",
      tokenRows: Api.tokenShortcuts(cf.accountId)
    })
  }

  function groupedSectionsFromRows(sourceRows) {
    var rows = sourceRows || []
    var out = []
    var currentKey = null
    var current = null
    for (var i = 0; i < rows.length; i++) {
      var row = rows[i]
      var key = String(row.section !== undefined ? row.section : "")
      if (key !== currentKey) {
        currentKey = key
        var sectionTitle = String(row.sectionTitle || row.section || "")
        if (!sectionTitle && row.kind === "group" && row.target === "token")
          sectionTitle = "CREATE A TOKEN"
        current = { title: sectionTitle, key: key, rows: [] }
        out.push(current)
      }
      if (current)
        current.rows.push(row)
    }
    return out.filter(function(section) {
      return String(section.title || "") !== "CREATE A TOKEN"
    })
  }

  function openRow(row) {
    if (!row || !cf)
      return
    if (row.kind === "usage")
      cf.refreshAnalytics()
    else if (row.kind === "empty" || row.kind === "note")
      return
    else if (row.kind === "group") {
      if (row.target === "token")
        cf.openUrl(Api.dashAccount("/api-tokens", cf.accountId))
      else if (row.target === "worker")
        cf.openUrl(Api.dashAccount("/workers", cf.accountId))
      else if (row.target === "pages")
        cf.openUrl(Api.dashAccount("/pages", cf.accountId))
      else if (row.target === "r2")
        cf.openUrl(Api.dashAccount("/r2", cf.accountId))
      else if (row.target === "d1")
        cf.openUrl(Api.dashAccount("/workers/d1", cf.accountId))
      else if (row.target === "kv")
        cf.openUrl(Api.dashAccount("/workers/kv", cf.accountId))
      else if (row.target === "queue")
        cf.openUrl(Api.dashAccount("/workers/queues", cf.accountId))
      else if (row.target === "zone")
        cf.openUrl(Api.dashAccount("/zones", cf.accountId))
    } else if (row.kind === "deploy")
      cf.openUrl(Api.dashUrlFor(row, cf.accountId))
    else if (row.liveUrl)
      cf.openUrl(row.liveUrl)
    else
      cf.openUrl(Api.dashUrlFor(row, cf.accountId))
  }

  function rowGlyph(row) {
    if (!row)
      return ""
    if (row.kind === "deploy")
      return Model.glyphFor(row.target === "pages" ? "pages" : "worker")
    if (row.kind === "group")
      return Model.glyphFor(row.target === "token" ? "token" : row.target)
    return Model.glyphFor(row.kind)
  }

  function rowTitle(row) {
    if (!row)
      return ""
    if (row.kind === "usage")
      return String(row.title || "")
    if (row.kind === "group" && row.target === "token")
      return String(row.name || "Create a token")
    if (row.kind === "group")
      return String(row.name || "")
    return String(row.name || row.title || "")
  }

  function statValue(row) {
    if (!row)
      return "—"
    if (row.kind === "usage")
      return usageStatValue(row)
    if (row.kind === "group")
      return String(row.count !== undefined ? row.count : "—")
    return "—"
  }

  function usageStatValue(row) {
    if (!cf || !cf.analytics || !cf.analytics.loaded)
      return "—"
    if (row.metered && row.percent >= 0)
      return Math.round(row.percent * 100) + "%"
    var a = cf.analytics
    switch (String(row.id || "")) {
    case "worker-requests":
      return Model.formatCount(a.workerRequests)
    case "worker-errors":
      return Model.formatCount(a.workerErrors)
    case "r2-storage":
      return Model.formatBytes(a.r2Bytes)
    case "d1-reads":
      return Model.formatCount(a.d1RowsRead)
    default:
      return "—"
    }
  }

  function usageStatLabel(row) {
    if (!row)
      return ""
    switch (String(row.id || "")) {
    case "worker-requests":
      return "24h requests"
    case "worker-errors":
      return "24h errors"
    case "r2-storage":
      if (!cf || !cf.analytics || !cf.analytics.loaded)
        return "R2 objects"
      return Model.formatCount(cf.analytics.r2Objects) + " R2 objects"
    case "d1-reads":
      return "24h D1 reads"
    default:
      return ""
    }
  }

  function statLabel(row) {
    if (!row)
      return ""
    if (row.kind === "usage")
      return usageStatLabel(row)
    if (row.kind === "group")
      return String(row.name || "")
    return ""
  }

  function statTone(row) {
    if (!row)
      return accent
    var id = String(row.id || "")
    var target = String(row.target || "")
    if (id === "r2-storage" || target === "r2") return themeYellow
    if (id === "d1-reads" || target === "d1") return themeGreen
    if (target === "worker") return themeMagenta
    if (target === "pages") return themeBlue
    if (target === "kv") return themeOrange
    if (target === "queue") return themeCyan
    return accent
  }

  function statValueColor(row) {
    if (!row)
      return accent
    if (row.alarming || (row.kind === "usage" && row.metered && row.percent >= 0.9))
      return urgent
    return statTone(row)
  }

  function rowClickable(row) {
    return row && row.selectable !== false
      && row.kind !== "empty"
      && row.kind !== "note"
  }

  function deployStatusLabel(row) {
    if (!row || row.kind !== "deploy")
      return ""
    if (row.failed)
      return "Failed"
    if (row.building)
      return "Building"
    var status = String(row.status || "deployed").toLowerCase()
    if (status === "deployed" || status === "success")
      return "Deployed"
    return status.charAt(0).toUpperCase() + status.slice(1)
  }

  function deployStatusColor(row) {
    if (!row)
      return foreground
    if (row.failed || row.alarming)
      return urgent
    if (row.building)
      return accent
    return accent
  }

  function deployMetaLine(row) {
    if (!row || row.kind !== "deploy")
      return ""
    var parts = []
    parts.push(row.target === "pages" ? "Pages" : "Worker")
    if (row.via)
      parts.push(String(row.via))
    var time = deployTimeLabel(row)
    if (time)
      parts.push(time)
    return parts.join(" · ")
  }

  function deployTimeLabel(row) {
    if (!row || row.kind !== "deploy" || !row.whenMs)
      return ""
    return Model.relativeTime(row.whenMs, root.nowMs)
  }

  function activityStatusLabel(row) {
    if (!row)
      return ""
    if (row.kind === "deploy")
      return deployStatusLabel(row)
    if (row.alarming)
      return "Alert"
    return ""
  }

  function activityTimeLabel(row) {
    if (!row)
      return ""
    if (row.kind === "deploy")
      return deployTimeLabel(row)
    return ""
  }

  function activityStatusColor(row) {
    if (!row)
      return foreground
    if (row.kind === "deploy")
      return deployStatusColor(row)
    if (row.alarming)
      return urgent
    return accent
  }

  function refresh() {
    if (!cf) return
    cf.refresh()
    if (!cf.analytics.loaded)
      cf.refreshAnalytics()
  }

  function openDashboard() {
    if (cf && typeof cf.openUrl === "function")
      cf.openUrl("https://dash.cloudflare.com")
    root.close()
  }

  function openFromHotkey() {
    root.controller.show()
    refresh()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  Component.onCompleted: refresh()

  onOpenedChanged: {
    if (opened) {
      nowMs = Date.now()
      refresh()
      tickTimer.start()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    } else {
      tickTimer.stop()
    }
  }

  Timer {
    id: tickTimer
    interval: 30000
    repeat: true
    onTriggered: root.nowMs = Date.now()
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
            title: root.accountLegendLabel || "Cloudflare"
            meta: cf && cf.actionStatus !== "" ? cf.actionStatus : (cf && cf.busy ? "Refreshing…" : "")
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: root.iconActive ? 1 : 0.7

            iconComponent: Component {
              Text {
                textFormat: Text.PlainText
                text: "󰊠"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Theme.font.display
                opacity: 0.92
              }
            }

            trailingControl: Component {
              Rectangle {
                implicitWidth: zoneCount.implicitWidth + Theme.spacing.lg * 2
                implicitHeight: zoneCount.implicitHeight + Theme.spacing.sm * 2
                radius: implicitHeight / 2
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.14)

                Text {
                  id: zoneCount
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: cf ? String(cf.zones.length) : "0"
                  color: root.accent
                  font.family: root.fontFamily
                  font.pixelSize: Theme.font.displayLarge
                  font.bold: true
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: if (cf) cf.openUrl(Api.dashAccount("/zones", cf.accountId))
                }
              }
            }
          }

          Item {
            id: requestsChart
            visible: cf && cf.analytics && cf.analytics.loaded
            width: parent.width
            implicitHeight: requestsFrame.height + (requestsLegend.visible ? requestsLegend.height / 2 : 0)
            readonly property var hours: {
              var series = cf && cf.analytics ? cf.analytics.requestHours : []
              return series && series.length ? series : []
            }
            readonly property string totalText: cf && cf.analytics
              ? Model.formatCount(cf.analytics.workerRequests)
              : "—"
            readonly property string errorText: cf && cf.analytics
              ? Model.formatCount(cf.analytics.workerErrors)
              : "—"
            readonly property int errorCount: cf && cf.analytics ? (Number(cf.analytics.workerErrors) || 0) : 0

            Rectangle {
              id: requestsFrame
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.topMargin: requestsLegend.visible ? requestsLegend.height / 2 : 0
              height: Theme.font.display + Theme.space(72)
              color: "transparent"
              radius: Theme.space(8)
              border.width: 1
              border.color: Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.9)
              antialiasing: true
            }

            Item {
              id: requestsLegend
              x: Theme.space(14)
              y: 0
              width: requestsLegendText.implicitWidth + Theme.space(8)
              height: Math.max(1, requestsLegendText.implicitHeight)
              visible: requestsChart.visible

              Rectangle {
                anchors.fill: parent
                color: Theme.popups.background
              }

              Text {
                id: requestsLegendText
                x: Theme.space(4)
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: "24h requests"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Theme.font.caption
                font.bold: true
              }
            }

            Text {
              id: requestTotal
              anchors.left: requestsFrame.left
              anchors.leftMargin: Theme.space(14)
              anchors.top: requestsFrame.top
              anchors.topMargin: Theme.space(10)
              textFormat: Text.PlainText
              text: requestsChart.totalText
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Theme.font.display
              font.bold: true
            }

            Text {
              anchors.right: requestsFrame.right
              anchors.rightMargin: Theme.space(14)
              anchors.verticalCenter: requestTotal.verticalCenter
              textFormat: Text.PlainText
              text: requestsChart.errorText
              color: requestsChart.errorCount > 0 ? root.urgent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Theme.font.display
              font.bold: true
            }

            Canvas {
              id: requestBars
              anchors.left: requestsFrame.left
              anchors.right: requestsFrame.right
              anchors.bottom: requestsFrame.bottom
              anchors.leftMargin: Theme.space(14)
              anchors.rightMargin: Theme.space(14)
              anchors.bottomMargin: Theme.space(12)
              height: Theme.space(36)
              antialiasing: true

              property var hours: requestsChart.hours
              onHoursChanged: requestPaint()
              onWidthChanged: requestPaint()
              onHeightChanged: requestPaint()
              onVisibleChanged: if (visible) requestPaint()
              Component.onCompleted: requestPaint()

              onPaint: {
                var ctx = getContext("2d")
                if (ctx.reset) ctx.reset()
                ctx.clearRect(0, 0, width, height)
                var series = hours || []
                var n = series.length
                if (n < 1 || width < 4 || height < 4) return
                var maxV = 0
                var i
                for (i = 0; i < n; i++)
                  maxV = Math.max(maxV, Number(series[i]) || 0)
                var gap = 2
                var barW = Math.max(1, (width - gap * (n - 1)) / n)
                ctx.fillStyle = root.accent
                for (i = 0; i < n; i++) {
                  var value = Number(series[i]) || 0
                  var barH = maxV > 0 ? Math.max(value > 0 ? 2 : 0, (value / maxV) * height) : 0
                  var x = i * (barW + gap)
                  if (barH > 0)
                    ctx.fillRect(x, height - barH, barW, barH)
                  else {
                    ctx.globalAlpha = 0.35
                    ctx.fillRect(x, height - 1, barW, 1)
                    ctx.globalAlpha = 1
                  }
                }
              }
            }
          }

          Flow {
            id: usageFlow
            width: parent.width
            spacing: Theme.space(8)
            visible: root.upperStatCount > 0

            Repeater {
              model: root.usageSection.rows

              StatTile {
                required property var modelData
                visible: modelData.id !== "worker-requests" && modelData.id !== "worker-errors"
                width: {
                  var n = Math.max(1, root.upperStatCount)
                  return (usageFlow.width - usageFlow.spacing * (n - 1)) / n
                }
                value: root.statValue(modelData)
                label: root.statLabel(modelData)
                valueColor: root.statValueColor(modelData)
                clickable: root.rowClickable(modelData)
                onClicked: root.openRow(modelData)
              }
            }

            StatTile {
              visible: root.workersGroup !== null
              width: {
                var n = Math.max(1, root.upperStatCount)
                return (usageFlow.width - usageFlow.spacing * (n - 1)) / n
              }
              value: root.statValue(root.workersGroup)
              label: root.statLabel(root.workersGroup)
              valueColor: root.statValueColor(root.workersGroup)
              clickable: root.rowClickable(root.workersGroup)
              onClicked: root.openRow(root.workersGroup)
            }
          }

          Flow {
            id: resourceFlow
            width: parent.width
            spacing: Theme.space(8)
            visible: root.resourcesSection.rows.length > 0

            Repeater {
              model: root.resourcesSection.rows

              StatTile {
                required property var modelData
                visible: modelData.target !== "zone" && modelData.target !== "worker"
                width: (resourceFlow.width - resourceFlow.spacing * 3) / 4
                value: root.statValue(modelData)
                label: root.statLabel(modelData)
                valueColor: root.statValueColor(modelData)
                clickable: root.rowClickable(modelData)
                onClicked: root.openRow(modelData)
              }
            }
          }

          PanelSectionHeader {
            visible: root.attentionSection.rows.length > 0
            width: parent.width
            text: "NEEDS ATTENTION"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Column {
            width: parent.width
            spacing: 0
            visible: root.attentionSection.rows.length > 0

            Repeater {
              model: root.attentionSection.rows

              ActivityEntry {
                required property var modelData
                required property int index
                width: column.width
                row: modelData
                host: root
                showDivider: index < root.attentionSection.rows.length - 1
              }
            }
          }

          Item {
            id: recentBox
            visible: root.recentGroupedSection.rows.length > 0
            width: parent.width
            implicitHeight: recentFrame.height + (recentLegend.visible ? recentLegend.height / 2 : 0)

            Rectangle {
              id: recentFrame
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.topMargin: recentLegend.visible ? recentLegend.height / 2 : 0
              height: recentColumn.implicitHeight + Theme.space(12)
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
              anchors.topMargin: Theme.space(8)
              anchors.leftMargin: Theme.space(8)
              anchors.rightMargin: Theme.space(8)
              spacing: 0

              Repeater {
                model: root.recentGroupedSection.rows

                ActivityEntry {
                  required property var modelData
                  required property int index
                  width: recentColumn.width
                  row: modelData
                  host: root
                  showDivider: index < root.recentGroupedSection.rows.length - 1
                }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: !!(cf && cf.lastError)
            text: (cf && cf.lastError) ? cf.lastError : ""
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Theme.font.body
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: !root.hasDisplaySections && (!cf || cf.lastError === "")
            text: !cf ? "Loading…" : (cf.busy ? "Loading…" : (cf.loggedIn ? "No data" : "Not logged in"))
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Theme.font.body
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }

  component StatTile: Item {
    id: tile
    property string value: ""
    property string label: ""
    property color valueColor: root.accent
    property bool clickable: false

    signal clicked()

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
      x: Theme.space(8)
      y: 0
      width: Math.min(legendTextItem.implicitWidth + Theme.space(8), Math.max(Theme.space(28), tile.width - Theme.space(12)))
      height: Math.max(1, legendTextItem.implicitHeight)
      visible: tile.label !== ""

      Rectangle {
        anchors.fill: parent
        color: Theme.popups.background
      }

      Text {
        id: legendTextItem
        x: Theme.space(4)
        width: Math.max(1, parent.width - Theme.space(8))
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: tile.label
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Theme.font.caption
        font.bold: true
        elide: Text.ElideRight
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

    MouseArea {
      anchors.fill: parent
      enabled: tile.clickable
      hoverEnabled: enabled
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: tile.clicked()
    }
  }
}
