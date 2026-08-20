import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../../Commons"

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPopupWidth: 0

    readonly property string btcCacheKey: "evo.bar.popups.stocks.btc"
    readonly property string spcxCacheKey: "evo.bar.popups.stocks.spcx"

    readonly property string home: Quickshell.env("HOME")
    readonly property bool active: host && host.opened === true
    readonly property int chartHistoryDays: 30
    readonly property int hintFont: Theme.fontSizeL
    readonly property int labelFont: Theme.fontSizeL
    readonly property int statFont: Theme.fontSizeXl
    readonly property int chartBlockHeight: 96
    readonly property int statRowHeight: Theme.fontSizeL
        + Theme.fontSizeL + 36

    property var btcData: ({})
    property var spcxData: ({})

    function onActivated() {
        refreshAll()
    }

    function bootstrapFromCache() {
        if (!shell)
            return
        var btc = shell.hoverPopupDataFor(btcCacheKey)
        var spcx = shell.hoverPopupDataFor(spcxCacheKey)
        if (btc && typeof btc === "object")
            btcData = btc
        if (spcx && typeof spcx === "object")
            spcxData = spcx
    }

    Component.onCompleted: bootstrapFromCache()

    function refreshAll() {
        btcPoll.runPoll()
        spcxPoll.runPoll()
    }

    function marketStatBoxes(market) {
        var position = market.position || {}
        var quote = market.quote || {}
        var price = quote.price
        var priceValue = price !== undefined && price !== null
            ? root.fmtUsd(price)
            : "—"
        var quantityValue = market.name === "BTC"
            ? root.fmtBtc(position.balance)
            : root.fmtQty(position.quantity)
        var quantityLabel = market.name === "BTC" ? "BTC" : "Shares"
        var upnl = position.upnlPct
        var upnlColor = signedColor(upnl)
        return [
            { label: "Price", value: priceValue, special: true },
            { label: "Value", value: root.fmtPositionValue(position) },
            { label: quantityLabel, value: quantityValue },
            {
                label: "P/L",
                value: root.fmtSignedPct(upnl),
                valueColor: upnlColor,
                customFill: true,
                customFillColor: Theme.withOpacity(upnlColor, 0.14)
            }
        ]
    }

    function signedColor(val) {
        var n = parseFloat(val)
        if (isNaN(n) || n === 0)
            return Theme.foreground
        return n > 0 ? Theme.accent : Theme.urgent
    }

    function marketSymbolIcon(name) {
        if (name === "BTC")
            return "₿"
        if (name === "SPCX")
            return "𝕏"
        return name ? String(name).charAt(0) : "?"
    }

    function openMarketUrl(url) {
        if (!url)
            return
        Quickshell.execDetached(["bash", "-lc", "xdg-open " + Util.shellQuote(url)])
    }

    function fmtPct(val, signed) {
        var n = parseFloat(val)
        if (isNaN(n))
            return "—"
        var s = (n * (Math.abs(n) <= 1 && String(val).indexOf("%") < 0 ? 1 : 1)).toFixed(2)
        if (signed === false)
            return s + "%"
        return (n >= 0 ? "+" : "") + s + "%"
    }

    function fmtSignedPct(val) {
        var n = parseFloat(val)
        if (isNaN(n))
            return "—"
        return (n >= 0 ? "+" : "") + n.toFixed(2) + "%"
    }

    function fmtUsd(val) {
        var n = parseFloat(val)
        if (isNaN(n))
            return "—"
        return Format.formatRevenue(n, "$")
    }

    function fmtGbp(val) {
        var n = parseFloat(val)
        if (isNaN(n))
            return "—"
        return Format.formatRevenue(n, "£")
    }

    function fmtPositionValue(position) {
        if (!position || typeof position !== "object")
            return "—"
        if (position.value !== undefined && position.value !== null)
            return root.fmtGbp(position.value)
        if (position.valueUsd !== undefined && position.valueUsd !== null)
            return root.fmtUsd(position.valueUsd)
        return "—"
    }

    function fmtBtc(val) {
        var n = parseFloat(val)
        if (isNaN(n) || n <= 0)
            return "—"
        return n.toFixed(3)
    }

    function fmtQty(val) {
        var n = parseFloat(val)
        if (isNaN(n) || n <= 0)
            return "—"
        return n.toFixed(2)
    }

    function chartBars(data) {
        var bars = Array.isArray(data.bars) ? data.bars : []
        if (bars.length <= chartHistoryDays)
            return bars
        return bars.slice(bars.length - chartHistoryDays)
    }

    function chartDays(data) {
        var period = data.period || {}
        if (period.days)
            return Math.min(chartHistoryDays, period.days)
        var bars = chartBars(data)
        return bars.length > 0 ? bars.length : chartHistoryDays
    }

    function marketSection(data, fallbackName, href, chartColor) {
        return {
            name: fallbackName,
            href: href,
            source: String(data.source || ""),
            quote: data.quote || {},
            period: data.period || {},
            position: data.position || {},
            bars: root.chartBars(data),
            days: root.chartDays(data),
            chartColor: chartColor
        }
    }

    readonly property var btc: marketSection(btcData, "BTC", "https://www.tradingview.com/symbols/BTCUSD/", Theme.accent)
    readonly property var spcx: marketSection(spcxData, "SPCX", "https://app.trading212.com/", "#f9e2af")

    JsonPollRunner {
        id: btcPoll
        shell: root.shell
        cacheKey: root.btcCacheKey
        active: root.active
        defaultIntervalSec: 60
        command: ["bash", root.home + "/.local/bin/evo-bar-btc", String(root.chartHistoryDays)]
        onPolled: function(json) { root.btcData = json }
    }

    JsonPollRunner {
        id: spcxPoll
        shell: root.shell
        cacheKey: root.spcxCacheKey
        active: root.active
        defaultIntervalSec: 60
        command: ["bash", root.home + "/.local/bin/evo-bar-spcx", String(root.chartHistoryDays)]
        onPolled: function(json) { root.spcxData = json }
    }

    implicitHeight: column.implicitHeight

    component MarketPanel: SectionPanel {
        id: panel
        property var market: ({})

        HoverPopupLabelPill {
            text: panel.market.name
            icon: root.marketSymbolIcon(panel.market.name)
            fontSize: Theme.fontSizeS
            clickable: panel.market.href !== ""
            onClicked: root.openMarketUrl(panel.market.href)
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.hoverPopupSectionSpacing

            GridLayout {
                Layout.fillWidth: true
                Layout.minimumHeight: root.statRowHeight
                columns: 4
                columnSpacing: 8
                rowSpacing: 8

                Repeater {
                    model: root.marketStatBoxes(panel.market)

                    HoverPopupStatBox {
                        required property var modelData
                        value: String(modelData.value)
                        label: modelData.label
                        valueFontSize: root.statFont
                        special: modelData.special === true
                        valueColor: modelData.valueColor !== undefined ? modelData.valueColor : Theme.accent
                        customFill: modelData.customFill === true
                        customFillColor: modelData.customFillColor !== undefined
                            ? modelData.customFillColor
                            : Theme.panelMantle
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.chartBlockHeight
                Layout.minimumHeight: root.chartBlockHeight

                SparklineChart {
                    anchors.fill: parent
                    style: "candlestick"
                    bullishColor: panel.market.chartColor
                    chartHeight: root.chartBlockHeight
                    bars: panel.market.bars
                    showEmptyLabel: false
                    opacity: panel.market.bars.length > 0 ? 1 : 0.18

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        id: column
        width: root.hoverPopupWidth
        spacing: Theme.hoverPopupSectionSpacing

        MarketPanel {
            label: ""
            market: root.btc
        }

        MarketPanel {
            label: ""
            market: root.spcx
        }
    }
}
