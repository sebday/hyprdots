import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.commons
import qs.ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "evo.cursor"
  ipcTarget: "evo.cursor"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property bool openedFromHotkey: false
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: Theme.foreground
  readonly property color urgent: bar ? bar.urgent : Theme.urgent
  readonly property color accent: Theme.accent
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property color surface: Theme.popups.background
  readonly property string fontFamily: bar ? bar.fontFamily : Theme.font.family
  readonly property var palette: Model.heatmapColors(accent)

  readonly property string statusScript: Qt.resolvedUrl("bin/cursor-usage").toString().replace("file://", "")
  readonly property int refreshIntervalSec: Math.max(30, parseInt(setting("refreshIntervalSec", 300), 10) || 300)
  readonly property int gaugeSpacing: Theme.space(12)
  readonly property int usageContentWidth: Math.max(Theme.space(340), panel.contentWidth - Theme.space(24))
  readonly property int gaugeSize: Math.max(Theme.space(96), Math.floor((usageContentWidth - gaugeSpacing) / 2))
  readonly property int usageBlockWidth: gaugeSize * 2 + gaugeSpacing
  readonly property int gaugeLabelFont: Math.max(Theme.font.body, Math.round(gaugeSize * 0.22))
  readonly property int usageStatTileCount: (showTokens ? 2 : 0) + (cycleDaysTotal > 0 ? 1 : 0)

  property bool loading: true
  property var data: Model.parsePayload("")

  property real shownCursorPercent: 0
  property real shownOtherPercent: 0
  property int usageCelebrateToken: 0

  NumberAnimation {
    id: cursorPercentAnim
    target: root
    property: "shownCursorPercent"
    easing.type: Easing.OutCubic
    onFinished: root.usageCelebrateToken++
  }

  NumberAnimation {
    id: otherPercentAnim
    target: root
    property: "shownOtherPercent"
    easing.type: Easing.OutCubic
  }

  readonly property var detail: data.detail || Model.emptyDetail()
  readonly property bool hasData: data.ok === true
  readonly property bool isError: !hasData && data.error !== ""
  readonly property bool showTokens: hasData && Model.showTokens(detail)
  readonly property bool hasModelDetails: hasData && Model.hasModelDetails(detail)
  property bool breakdownOpen: false
  readonly property var modelSplit: Array.isArray(detail.modelSplit) ? detail.modelSplit : []
  readonly property color cycleColor: Model.cycleColor(detail, palette)
  readonly property color cursorColor: detail.cursorColor || palette[2]
  readonly property color otherColor: detail.otherColor || palette[4]
  readonly property color themeGreen: hostWidget ? hostWidget.themeGreen : Theme.ansiFallback("green")
  readonly property color themeBlue: hostWidget ? hostWidget.themeBlue : Theme.ansiFallback("blue")
  readonly property color themeOrange: hostWidget ? hostWidget.themeOrange : Theme.ansiFallback("orange")
  readonly property color themeRed: hostWidget ? hostWidget.themeRed : Theme.ansiFallback("red")
  readonly property color cursorGaugeColor: Model.usageStageColor(shownCursorPercent, themeGreen, themeBlue, themeOrange, themeRed)
  readonly property color otherGaugeColor: Model.usageStageColor(shownOtherPercent, themeGreen, themeBlue, themeOrange, themeRed)
  readonly property int cycleDaysUsed: parseInt(data.cycleDaysUsed, 10) || 0
  readonly property int cycleDaysTotal: parseInt(data.cycleDaysTotal, 10) || 0
  readonly property bool iconActive: Model.iconActive(data)
  readonly property bool iconError: isError
  readonly property bool iconBusy: loading
  readonly property bool iconMuted: false
  readonly property string barTooltip: Model.barTooltip(data, loading)
  readonly property string barValue: Model.barValue(data)
  readonly property string heroMeta: {
    if (loading) return "Refreshing…"
    if (isError) return data.error || "Unavailable"
    if (detail.membership) return String(detail.membership)
    if (hasData) return (data.cursorPercent || 0) + "% cursor · " + (data.otherPercent || 0) + "% other"
    return ""
  }

  function applyPayload(raw) {
    loading = false
    data = Model.parsePayload(raw)
    syncAnimatedStats(false)
  }

  function syncAnimatedStats(fromZero) {
    if (!hasData) {
      cursorPercentAnim.stop()
      otherPercentAnim.stop()
      shownCursorPercent = 0
      shownOtherPercent = 0
      return
    }

    animateStat(cursorPercentAnim, "shownCursorPercent", data.cursorPercent || 0, fromZero)
    animateStat(otherPercentAnim, "shownOtherPercent", data.otherPercent || 0, fromZero)
  }

  function animateStat(anim, propertyName, target, fromZero) {
    var next = Number(target) || 0
    var current = root[propertyName] || 0
    if (!fromZero && Math.round(current) === Math.round(next)) {
      root[propertyName] = next
      return
    }

    anim.stop()
    anim.from = fromZero ? 0 : current
    anim.to = next
    anim.duration = Math.min(900, Math.max(420, next * 10))
    anim.start()
  }

  function refresh(force) {
    if (!statusScript || statusProc.running) return
    if (!hasData) loading = true
    statusProc.command = force === true ? ["bash", statusScript, "--force"] : ["bash", statusScript]
    statusProc.running = true
  }

  function openDashboard() {
    Quickshell.execDetached(["xdg-open", "https://cursor.com/dashboard/spending"])
    root.close()
  }

  function open() {
    openedFromHotkey = false
    setCenterHoverRevealSuppressed(false)
    root.controller.show()
    root.refresh()
  }

  function openFromHotkey() {
    openedFromHotkey = true
    root.controller.show()
    root.refresh()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
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

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  Component.onCompleted: refresh()

  onOpenedChanged: if (opened) {
    breakdownOpen = false
    shownCursorPercent = 0
    shownOtherPercent = 0
    refresh()
    refreshTimer.start()
    if (hasData) syncAnimatedStats(true)
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  } else {
    refreshTimer.stop()
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
          if (!root.hasData) root.applyPayload('{"class":"error","message":"No data"}')
          return
        }
        root.applyPayload(raw)
      root.loading = false
    }
  }

  Timer {
    id: refreshTimer
    interval: root.refreshIntervalSec * 1000
    repeat: true
    onTriggered: root.refresh()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
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
            width: parent.width
            title: "Cursor"
            meta: root.heroMeta
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: root.loading ? 0.7 : (root.iconError ? 1 : (root.iconActive ? 1 : 0.7))

            iconComponent: Component {
              CursorIcon {
                iconSize: Theme.font.display
                color: root.foreground
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: root.isError
            text: root.data.error || ""
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Theme.font.body
            wrapMode: Text.WordWrap
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: root.isError
            text: "Open Cursor spending →"
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Theme.font.bodySmall
            font.bold: true

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.openDashboard()
            }
          }

          Row {
            visible: !root.isError && (root.showTokens || root.cycleDaysTotal > 0)
            width: parent.width
            spacing: Theme.space(16)

            PanelStatTile {
              visible: root.cycleDaysTotal > 0
              width: root.usageStatTileCount > 0
                ? (parent.width - parent.spacing * (root.usageStatTileCount - 1)) / root.usageStatTileCount
                : parent.width
              loading: root.loading
              value: root.loading ? "…" : String(Model.cycleDaysLeft(root.data))
              cycleSuffix: root.loading ? "" : (Model.cycleDaysLeft(root.data) === 1 ? "day left" : "days left")
              label: ""
              valueColor: root.cycleColor
              foreground: root.foreground
              dim: root.dim
              fontFamily: root.fontFamily
              showCycleChart: true
              cycleDaysTotal: root.cycleDaysTotal
              cycleDaysUsed: root.cycleDaysUsed
            }

            PanelStatTile {
              visible: root.showTokens
              width: root.usageStatTileCount > 0
                ? (parent.width - parent.spacing * (root.usageStatTileCount - 1)) / root.usageStatTileCount
                : parent.width
              loading: root.loading
              value: Model.formatTokens(root.detail.tokensTotal || 0)
              label: "tokens"
              foreground: root.foreground
              dim: root.dim
              fontFamily: root.fontFamily
            }

            PanelStatTile {
              visible: root.showTokens
              width: root.usageStatTileCount > 0
                ? (parent.width - parent.spacing * (root.usageStatTileCount - 1)) / root.usageStatTileCount
                : parent.width
              loading: root.loading
              value: Model.formatTokensNearestM(root.detail.tokensToday || 0)
              label: "today"
              foreground: root.foreground
              dim: root.dim
              fontFamily: root.fontFamily
            }

          }

          Item {
            width: parent.width
            visible: !root.isError
            implicitHeight: usageBlock.implicitHeight

            Column {
              id: usageBlock
              anchors.horizontalCenter: parent.horizontalCenter
              width: root.usageBlockWidth
              spacing: Theme.space(12)

              Row {
                width: parent.width
                spacing: root.gaugeSpacing

                UsageGauge {
                  width: root.gaugeSize
                  percent: root.shownCursorPercent
                  gaugeColor: root.cursorGaugeColor
                  title: "Cursor"
                  titleColor: root.cursorGaugeColor
                  loading: root.loading
                  gaugeSize: root.gaugeSize
                  labelFontSize: root.gaugeLabelFont
                  foreground: root.foreground
                  trackColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
                  fontFamily: root.fontFamily
                  celebrateToken: root.usageCelebrateToken
                }

                UsageGauge {
                  width: root.gaugeSize
                  percent: root.shownOtherPercent
                  gaugeColor: root.otherGaugeColor
                  title: "Other"
                  titleColor: root.otherGaugeColor
                  loading: root.loading
                  gaugeSize: root.gaugeSize
                  labelFontSize: root.gaugeLabelFont
                  foreground: root.foreground
                  trackColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
                  fontFamily: root.fontFamily
                }
              }
            }
          }

          Item {
            id: breakdownHeader
            visible: !root.isError && root.hasModelDetails
            width: parent.width
            height: breakdownTitle.implicitHeight

            PanelSectionHeader {
              id: breakdownTitle
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "BREAKDOWN"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: root.breakdownOpen ? "−" : "+"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Theme.font.caption
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.breakdownOpen = !root.breakdownOpen
            }
          }

          Column {
            width: parent.width
            spacing: Theme.space(12)
            visible: breakdownHeader.visible && root.breakdownOpen

            Repeater {
              model: root.modelSplit

              Column {
                required property var modelData
                required property int index
                width: column.width
                spacing: Theme.spacing.xs

                readonly property color barColor: Model.breakdownBarColor(root.palette, index)

                Item {
                  width: parent.width
                  height: 4

                  Rectangle {
                    anchors.fill: parent
                    radius: Theme.cornerRadius
                    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                  }

                  Rectangle {
                    height: parent.height
                    width: parent.width * Math.max(0, Math.min(1, modelData.percent / 100))
                    radius: Theme.cornerRadius
                    color: barColor
                    opacity: 0.85
                  }
                }

                Row {
                  width: parent.width
                  spacing: Theme.space(12)

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width - detailText.implicitWidth - parent.spacing
                    text: Model.modelLabel(modelData.model)
                    color: root.palette[0]
                    font.family: root.fontFamily
                    font.pixelSize: Theme.font.caption
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Text {
                    textFormat: Text.PlainText
                    id: detailText
                    text: root.loading
                      ? "…"
                      : Math.round(modelData.percent) + "% · "
                        + Model.formatTokens(modelData.tokens)
                    color: root.palette[0]
                    font.family: root.fontFamily
                    font.pixelSize: Theme.font.caption
                    font.bold: true
                  }
                }
              }
            }

            Row {
              width: parent.width
              visible: root.detail.onDemand === true
              spacing: Theme.spacing.sm

              Text {
                textFormat: Text.PlainText
                text: "On-demand usage enabled"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Theme.font.bodySmall
              }

              StatusPill {
                visible: root.detail.onDemandUsed > 0
                text: Number(root.detail.onDemandUsed).toLocaleString() + " used"
                textColor: root.accent
                foreground: root.foreground
                fontFamily: root.fontFamily
              }
            }
          }
        }
      }
    }
  }

  component UsageGauge: Item {
    id: gaugeRoot

    property real percent: 0
    property color gaugeColor: Theme.accent
    property bool loading: false
    property int gaugeSize: 130
    property int labelFontSize: Theme.font.body
    property color foreground: Theme.foreground
    property color trackColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
    property string fontFamily: Theme.font.family
    property int celebrateToken: 0
    property string title: ""
    property color titleColor: gaugeColor

    property real popScale: 1

    onCelebrateTokenChanged: if (celebrateToken > 0) popAnim.restart()

    implicitWidth: gaugeRoot.gaugeSize
    implicitHeight: ring.height
    scale: popScale
    transformOrigin: Item.Center

    SequentialAnimation {
      id: popAnim
      NumberAnimation {
        target: gaugeRoot
        property: "popScale"
        to: 1.06
        duration: 140
        easing.type: Easing.OutCubic
      }
      NumberAnimation {
        target: gaugeRoot
        property: "popScale"
        to: 1
        duration: 220
        easing.type: Easing.OutBack
      }
    }

    readonly property int ringSize: Math.round(gaugeRoot.gaugeSize * 0.91)
    readonly property real ringRadius: gaugeRoot.gaugeSize * 0.34
    readonly property real ringLineWidth: Math.max(10, gaugeRoot.gaugeSize * 0.077)
    readonly property real sweep: Math.max(0, Math.min(100, percent)) / 100

    Canvas {
      id: ring
      anchors.horizontalCenter: parent.horizontalCenter
      width: gaugeRoot.ringSize
      height: gaugeRoot.ringSize
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var cx = width / 2
        var cy = height / 2
        var r = gaugeRoot.ringRadius
        var lw = gaugeRoot.ringLineWidth

        ctx.beginPath()
        ctx.arc(cx, cy, r, 0, Math.PI * 2)
        ctx.strokeStyle = gaugeRoot.trackColor
        ctx.lineWidth = lw
        ctx.lineCap = "round"
        ctx.stroke()

        if (gaugeRoot.sweep > 0) {
          ctx.beginPath()
          ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + gaugeRoot.sweep * Math.PI * 2)
          ctx.strokeStyle = gaugeRoot.gaugeColor
          ctx.lineWidth = lw
          ctx.lineCap = "round"
          ctx.stroke()
        }
      }
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      Connections {
        target: gaugeRoot
        function onPercentChanged() { ring.requestPaint() }
        function onGaugeColorChanged() { ring.requestPaint() }
        function onTrackColorChanged() { ring.requestPaint() }
      }
      Component.onCompleted: requestPaint()
    }

    Column {
      anchors.centerIn: ring
      spacing: Theme.spacing.xs

      Text {
        textFormat: Text.PlainText
        anchors.horizontalCenter: parent.horizontalCenter
        text: gaugeRoot.loading ? "…" : (Math.round(gaugeRoot.percent) + "%")
        color: gaugeRoot.foreground
        font.family: gaugeRoot.fontFamily
        font.pixelSize: gaugeRoot.labelFontSize
        font.bold: true
      }

      Text {
        textFormat: Text.PlainText
        visible: gaugeRoot.title !== "" && !gaugeRoot.loading
        anchors.horizontalCenter: parent.horizontalCenter
        text: gaugeRoot.title
        color: gaugeRoot.titleColor
        font.family: gaugeRoot.fontFamily
        font.pixelSize: Theme.font.caption
        font.bold: true
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

  component PanelStatTile: Item {
    id: tileRoot

    property string value: ""
    property string label: ""
    property color valueColor: foreground
    property color foreground: Theme.foreground
    property color dim: Qt.darker(foreground, 1.4)
    property string fontFamily: Theme.font.family
    property bool loading: false
    property bool showCycleChart: false
    property string cycleSuffix: ""
    property int cycleDaysTotal: 0
    property int cycleDaysUsed: 0

    readonly property string displayValue: loading ? "…" : value
    readonly property string legendText: label !== "" ? label : cycleSuffix
    readonly property color frameColor: Qt.rgba(dim.r, dim.g, dim.b, 0.9)
    readonly property real cycleFill: cycleDaysTotal > 0
      ? Math.max(0, Math.min(1, cycleDaysUsed / cycleDaysTotal))
      : 0

    implicitWidth: Theme.space(108)
    implicitHeight: Theme.font.heading + Theme.space(56)

    Rectangle {
      id: frame
      anchors.fill: parent
      anchors.topMargin: legendChip.visible ? legendChip.height / 2 : 0
      color: "transparent"
      radius: Theme.space(8)
      border.width: tileRoot.showCycleChart ? 0 : 1
      border.color: tileRoot.frameColor
      antialiasing: true
    }

    Canvas {
      id: progressBorder
      anchors.fill: frame
      visible: tileRoot.showCycleChart
      antialiasing: true

      onPaint: {
        var ctx = getContext("2d")
        if (ctx.reset) ctx.reset()
        ctx.clearRect(0, 0, width, height)
        var lw = 2
        var radius = Math.min(Theme.space(8), Math.max(0, (Math.min(width, height) - lw) / 2))
        var left = lw / 2
        var top = lw / 2
        var w = Math.max(0, width - lw)
        var h = Math.max(0, height - lw)
        if (w < 4 || h < 4) return

        var right = left + w
        var bottom = top + h
        var topHalf = Math.max(0, w / 2 - radius)
        var side = Math.max(0, h - 2 * radius)
        var across = Math.max(0, w - 2 * radius)
        var sweep = Math.PI / 2

        ctx.lineWidth = lw
        ctx.lineJoin = "round"
        ctx.lineCap = "butt"

        ctx.beginPath()
        ctx.moveTo(left + w / 2, top)
        ctx.lineTo(right - radius, top)
        ctx.arc(right - radius, top + radius, radius, -sweep, 0)
        ctx.lineTo(right, bottom - radius)
        ctx.arc(right - radius, bottom - radius, radius, 0, sweep)
        ctx.lineTo(left + radius, bottom)
        ctx.arc(left + radius, bottom - radius, radius, sweep, Math.PI)
        ctx.lineTo(left, top + radius)
        ctx.arc(left + radius, top + radius, radius, Math.PI, Math.PI + sweep)
        ctx.lineTo(left + w / 2, top)
        ctx.strokeStyle = tileRoot.frameColor
        ctx.stroke()

        var fill = Math.max(0, Math.min(1, tileRoot.cycleFill))
        if (fill <= 0) return

        var remain = (topHalf * 2 + side * 2 + across + sweep * radius * 4) * fill
        ctx.strokeStyle = tileRoot.valueColor
        ctx.lineCap = "round"

        function paintLine(x1, y1, x2, y2, len) {
          if (remain <= 0 || len <= 0) return
          var portion = Math.min(1, remain / len)
          remain -= len * portion
          ctx.beginPath()
          ctx.moveTo(x1, y1)
          ctx.lineTo(x1 + (x2 - x1) * portion, y1 + (y2 - y1) * portion)
          ctx.stroke()
        }

        function paintArc(cx, cy, a0, delta) {
          var len = Math.abs(delta) * radius
          if (remain <= 0 || len <= 0) return
          var portion = Math.min(1, remain / len)
          remain -= len * portion
          ctx.beginPath()
          ctx.arc(cx, cy, radius, a0, a0 + delta * portion, delta < 0)
          ctx.stroke()
        }

        paintLine(left + w / 2, top, left + radius, top, topHalf)
        paintArc(left + radius, top + radius, -sweep, -sweep)
        paintLine(left, top + radius, left, bottom - radius, side)
        paintArc(left + radius, bottom - radius, Math.PI, -sweep)
        paintLine(left + radius, bottom, right - radius, bottom, across)
        paintArc(right - radius, bottom - radius, sweep, -sweep)
        paintLine(right, bottom - radius, right, top + radius, side)
        paintArc(right - radius, top + radius, 0, -sweep)
        paintLine(right - radius, top, left + w / 2, top, topHalf)
      }

      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      onVisibleChanged: if (visible) requestPaint()
      Connections {
        target: tileRoot
        function onCycleFillChanged() { progressBorder.requestPaint() }
        function onValueColorChanged() { progressBorder.requestPaint() }
        function onFrameColorChanged() { progressBorder.requestPaint() }
      }
      Component.onCompleted: requestPaint()
    }

    Item {
      id: legendChip
      x: Theme.space(14)
      y: 0
      width: legendTextItem.implicitWidth + Theme.space(8)
      height: Math.max(1, legendTextItem.implicitHeight)
      visible: tileRoot.legendText !== ""

      Rectangle {
        anchors.fill: parent
        color: Theme.popups.background
      }

      Text {
        id: legendTextItem
        x: Theme.space(4)
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: tileRoot.legendText
        color: tileRoot.dim
        font.family: tileRoot.fontFamily
        font.pixelSize: Theme.font.caption
        font.bold: true
      }
    }

    Item {
      anchors.fill: frame
      anchors.leftMargin: Theme.space(14)
      anchors.rightMargin: Theme.space(14)
      anchors.topMargin: Theme.space(8)
      anchors.bottomMargin: Theme.space(8)

      Text {
        anchors.centerIn: parent
        width: parent.width
        textFormat: Text.PlainText
        text: tileRoot.displayValue
        color: tileRoot.valueColor
        font.family: tileRoot.fontFamily
        font.pixelSize: Theme.font.display
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
      }
    }
  }
}
