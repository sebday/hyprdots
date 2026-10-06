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
  moduleName: "evo.stocks"
  ipcTarget: "evo.stocks"
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

  readonly property int chartHistoryDays: 30
  readonly property int chartBlockHeight: 112
  readonly property int refreshSeconds: 300

  property bool btcLoading: false
  property bool spcxLoading: false
  property var btcData: ({})
  property var spcxData: ({})

  readonly property var btc: Model.marketSection(btcData, "BTC", "https://www.tradingview.com/symbols/BTCUSD/", accent, chartHistoryDays)
  readonly property var spcx: Model.marketSection(spcxData, "SPCX", "https://app.trading212.com/", Theme.highlight, chartHistoryDays)

  readonly property string market: {
    var raw = settings && settings.market !== undefined && settings.market !== null
      ? String(settings.market).toLowerCase()
      : ""
    if (raw === "btc" || raw === "spcx") return raw
    return ""
  }
  readonly property bool spcxMarket: market === "spcx"
  readonly property var activeData: spcxMarket ? spcxData : btcData
  readonly property bool activeLoading: spcxMarket ? spcxLoading : btcLoading

  readonly property bool iconActive: Model.hasPosition(activeData)
  readonly property bool iconError: market !== "" && !activeLoading && activeData && activeData.ok === false
  readonly property bool iconBusy: activeLoading && !(activeData && activeData.ok === true)
  readonly property bool iconMuted: false
  readonly property string barTooltip: market === "" ? "" : Model.plain(Model.marketTooltip(spcxMarket ? "SPCX" : "BTC", activeData))
  readonly property string barValue: {
    if (market === "") return ""
    var name = spcxMarket ? "SPCX" : "BTC"
    var priced = Model.barPrice(name, activeData)
    if (priced !== "") return priced
    return Model.plain(Model.marketSymbolIcon(name))
  }

  readonly property string btcScript: Qt.resolvedUrl("bin/btc-status").toString().replace("file://", "")
  readonly property string spcxScript: Qt.resolvedUrl("bin/spcx-status").toString().replace("file://", "")
  readonly property string newsScript: Qt.resolvedUrl("bin/market-news").toString().replace("file://", "")

  property bool newsLoading: false
  property var newsData: ({ items: [] })
  property bool ready: false
  property int priceAttempts: 0

  readonly property bool loading: activeLoading

  function applyBtcPayload(raw) {
    btcLoading = false
    var parsed = Model.parseMarketPayload(raw)
    if (parsed.ok) btcData = parsed
  }

  function applySpcxPayload(raw) {
    spcxLoading = false
    var parsed = Model.parseMarketPayload(raw)
    if (parsed.ok) spcxData = parsed
  }

  function refreshBtc() {
    if (!btcScript || btcProc.running) return
    btcLoading = true
    btcProc.stdoutBuf = ""
    btcProc.stderrBuf = ""
    btcProc.command = ["bash", btcScript, String(chartHistoryDays)]
    btcProc.running = true
  }

  function refreshSpcx() {
    if (!spcxScript || spcxProc.running) return
    spcxLoading = true
    spcxProc.stdoutBuf = ""
    spcxProc.stderrBuf = ""
    spcxProc.command = ["bash", spcxScript, String(chartHistoryDays)]
    spcxProc.running = true
  }

  function retryPrice() {
    if (!ready || market === "" || priceAttempts >= 2) return
    priceAttempts++
    Qt.callLater(function() {
      if (root.spcxMarket) root.refreshSpcx()
      else root.refreshBtc()
    })
  }

  function applyNewsPayload(raw) {
    newsLoading = false
    var parsed = Model.parseNewsPayload(raw)
    if (parsed.ok) newsData = parsed
  }

  function refreshNews() {
    if (!newsScript || newsProc.running || market === "") return
    newsLoading = true
    newsProc.command = ["bash", newsScript, market]
    newsProc.running = true
  }

  function refresh() {
    if (market === "") return
    if (spcxMarket) refreshSpcx()
    else refreshBtc()
    refreshNews()
  }

  function ensureStarted() {
    if (!ready || market === "") return
    refresh()
  }

  function openMarketUrl(url) {
    if (!url) return
    Quickshell.execDetached(["xdg-open", url])
    root.close()
  }

  function openNewsUrl(url) {
    var safe = Model.httpsUrl(url)
    if (!safe) return
    Quickshell.execDetached(["xdg-open", safe])
    root.close()
  }

  function openFromHotkey() {
    root.controller.show()
    root.refresh()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  Component.onCompleted: {
    ready = true
    // Settings arrive after the panel is constructed. A deferred refresh
    // still runs once market is set, without waiting for a click.
    Qt.callLater(root.ensureStarted)
  }

  onMarketChanged: Qt.callLater(root.ensureStarted)

  onOpenedChanged: if (opened) {
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Process {
    id: btcProc

    property string stdoutBuf: ""
    property string stderrBuf: ""
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        btcProc.stdoutBuf += chunk
        if (btcProc.stdoutBuf.length > 262144) {
          btcProc.signal(15)
          btcProc.stdoutBuf = ""
        }
      }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        btcProc.stderrBuf += chunk
        if (btcProc.stderrBuf.length > 4096) {
          btcProc.signal(15)
          btcProc.stderrBuf = ""
        }
      }
    }
      onExited: function(exitCode) {
      var raw = String(stdoutBuf || "").trim()
        if (!raw) {
          root.btcLoading = false
          root.retryPrice()
          return
        }
        root.priceAttempts = 0
        root.applyBtcPayload(raw)
    }
  }

  Process {
    id: spcxProc

    property string stdoutBuf: ""
    property string stderrBuf: ""
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        spcxProc.stdoutBuf += chunk
        if (spcxProc.stdoutBuf.length > 262144) {
          spcxProc.signal(15)
          spcxProc.stdoutBuf = ""
        }
      }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        spcxProc.stderrBuf += chunk
        if (spcxProc.stderrBuf.length > 4096) {
          spcxProc.signal(15)
          spcxProc.stderrBuf = ""
        }
      }
    }
      onExited: function(exitCode) {
      var raw = String(stdoutBuf || "").trim()
        if (!raw) {
          root.spcxLoading = false
          root.retryPrice()
          return
        }
        root.priceAttempts = 0
        root.applySpcxPayload(raw)
    }
  }

  Timer {
    id: refreshTimer
    interval: root.refreshSeconds * 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }



  Process {
    id: newsProc
    onStarted: { stdoutBuf = ""; stderrBuf = "" }

    property string stdoutBuf: ""
    property string stderrBuf: ""
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        newsProc.stdoutBuf += chunk
        if (newsProc.stdoutBuf.length > 65536) {
          newsProc.signal(15)
          newsProc.stdoutBuf = ""
        }
      }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        newsProc.stderrBuf += chunk
        if (newsProc.stderrBuf.length > 4096) {
          newsProc.signal(15)
          newsProc.stderrBuf = ""
        }
      }
    }
    onExited: function(exitCode) {
      var raw = String(stdoutBuf || "").trim()
      if (!raw) {
        root.newsLoading = false
        return
      }
      root.applyNewsPayload(raw)
    }
  }

  Loader {
    active: root.market !== ""
    sourceComponent: Component {
      IpcHandler {
        target: "evo.stocks." + root.market

        function open(): void { root.openFromHotkey() }
        function close(): void { root.close() }
        function show(): void { root.openFromHotkey() }
        function hide(): void { root.close() }
        function toggle(): void { root.toggle() }
        function refresh(): string { root.refresh(); return "ok" }
      }
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

          Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: root.loading && !root.iconActive
            text: "Loading…"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Theme.font.body
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
          }

          MarketSection {
            width: parent.width
            visible: root.market !== ""
            market: root.spcxMarket ? root.spcx : root.btc
            loading: root.activeLoading
          }

          NewsSection {
            width: parent.width
            visible: root.market !== ""
            loading: root.newsLoading
            items: root.newsData && root.newsData.items ? root.newsData.items : []
          }
        }
      }
    }
  }

  component NewsSection: Column {
    id: news
    property bool loading: false
    property var items: []
    spacing: Theme.space(6)

    Text {
      textFormat: Text.PlainText
      width: parent.width
      text: "News"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Theme.font.caption
      font.bold: true
    }

    Text {
      textFormat: Text.PlainText
      width: parent.width
      visible: news.loading && (!news.items || news.items.length === 0)
      text: "Fetching headlines…"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Theme.font.caption
    }

    Text {
      textFormat: Text.PlainText
      width: parent.width
      visible: !news.loading && (!news.items || news.items.length === 0)
      text: "No headlines"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Theme.font.caption
    }

    Repeater {
      model: news.items || []

      NewsRow {
        required property var modelData
        width: news.width
        title: String(modelData.title || "")
        source: String(modelData.source || "")
        url: String(modelData.url || "")
      }
    }
  }

  component NewsRow: MouseArea {
    property string title: ""
    property string source: ""
    property string url: ""
    implicitHeight: newsRow.implicitHeight
    enabled: url.indexOf("https://") === 0
    hoverEnabled: enabled
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: root.openNewsUrl(url)

    RowLayout {
      id: newsRow
      width: parent.width
      spacing: Theme.space(8)

      Text {
        textFormat: Text.PlainText
        Layout.fillWidth: true
        text: title
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Theme.font.body
        elide: Text.ElideRight
      }

      Text {
        textFormat: Text.PlainText
        visible: source !== ""
        text: source
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Theme.font.caption
        elide: Text.ElideRight
        Layout.maximumWidth: parent.width * 0.4
      }
    }
  }

  component MarketSection: Column {
    id: section
    property var market: ({})
    property bool loading: false
    spacing: Theme.space(12)

    MouseArea {
      width: parent.width
      implicitHeight: marketHero.implicitHeight
      enabled: market.href !== ""
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: root.openMarketUrl(market.href)

      PanelHero {
        id: marketHero
        width: parent.width
        title: market.name || "Market"
        meta: market.source || market.priceLabel || ""
        detail: section.loading ? "…" : (market.price || "")
        foreground: root.foreground
        fontFamily: root.fontFamily

        iconComponent: Component {
          Text {
            textFormat: Text.PlainText
            text: Model.marketSymbolIcon(market.name)
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Theme.font.display
            opacity: 0.92
          }
        }
      }
    }

    GridLayout {
      width: parent.width
      columns: 4
      columnSpacing: Theme.space(16)
      rowSpacing: Theme.space(16)

      Repeater {
        model: Model.marketStatBoxes(market, root.accent, root.urgent, root.foreground)

        StatBox {
          required property var modelData
          Layout.fillWidth: true
          value: String(modelData.value)
          label: modelData.label
          valueColor: modelData.valueColor !== undefined ? modelData.valueColor : root.accent
          special: modelData.special === true
          customFill: modelData.customFill === true
          foreground: root.foreground
          dim: root.dim
          fontFamily: root.fontFamily
        }
      }
    }

    Item {
      width: parent.width
      height: root.chartBlockHeight

      SparklineChart {
        anchors.fill: parent
        style: "candlestick"
        bullishColor: market.chartColor || root.accent
        bearishColor: root.urgent
        chartHeight: root.chartBlockHeight
        bars: market.bars || []
        showEmptyLabel: false
        opacity: (market.bars || []).length > 0 ? 1 : 0.18

        Behavior on opacity {
          NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
          }
        }
      }
    }
  }

  component StatBox: Item {
    id: tile
    property string value: ""
    property string label: ""
    property color valueColor: foreground
    property bool special: false
    property bool customFill: false
    property color foreground: Theme.foreground
    property color dim: Qt.darker(foreground, 1.4)
    property string fontFamily: Theme.font.family

    implicitWidth: Theme.space(108)
    implicitHeight: Theme.font.heading + Theme.space(56)

    Rectangle {
      id: frame
      anchors.fill: parent
      anchors.topMargin: legendChip.visible ? legendChip.height / 2 : 0
      color: "transparent"
      radius: Theme.space(8)
      border.width: 1
      border.color: Qt.rgba(tile.dim.r, tile.dim.g, tile.dim.b, 0.9)
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
        color: tile.dim
        font.family: tile.fontFamily
        font.pixelSize: Theme.font.caption
        font.bold: true
      }
    }

    Text {
      anchors.fill: frame
      anchors.leftMargin: Theme.space(6)
      anchors.rightMargin: Theme.space(6)
      textFormat: Text.PlainText
      text: tile.value
      color: tile.special ? tile.valueColor : tile.foreground
      font.family: tile.fontFamily
      font.pixelSize: Theme.font.display
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
      fontSizeMode: Text.HorizontalFit
      minimumPixelSize: Theme.font.caption
    }
  }
}
