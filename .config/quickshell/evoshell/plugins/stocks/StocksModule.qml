import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPopupWidth: 0

    readonly property string btcCacheKey: "evo.stocks.btc"
    readonly property string spcxCacheKey: "evo.stocks.spcx"

    readonly property string home: Quickshell.env("HOME")
    readonly property bool active: host && host.opened === true
    readonly property int chartHistoryDays: 30
    readonly property int bodyFont: Theme.hoverPopupBodyFontPixelSize
    readonly property int hintFont: Theme.hoverPopupHintFontPixelSize
    readonly property int statFont: Theme.hoverPopupLabelFontPixelSize

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

    function refreshAll() {
        btcPoll.runPoll()
        spcxPoll.runPoll()
    }

    function marketHeader(data, fallbackName) {
        if (!data) return fallbackName + " …"
        var raw = data.detail ? String(data.detail) : (data.text ? String(data.text) : "")
        if (!raw)
            return fallbackName + " …"
        return Format.headerLines(raw.split(" · "), fallbackName + " …")
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

    function fmtBtc(val) {
        var n = parseFloat(val)
        if (isNaN(n) || n <= 0)
            return "—"
        if (n >= 1)
            return n.toFixed(4) + " BTC"
        return n.toFixed(6) + " BTC"
    }

    function fmtQty(val) {
        var n = parseFloat(val)
        if (isNaN(n) || n <= 0)
            return "—"
        return n.toFixed(2) + " shares"
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
            header: root.marketHeader(data, fallbackName),
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

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.hoverPopupSectionSpacing

            HoverPopupHeader {
                Layout.fillWidth: true
                value: panel.market.header
                href: panel.market.href
            }

            Text {
                Layout.fillWidth: true
                visible: panel.market.source !== ""
                text: panel.market.source + (panel.market.quote.pair ? " · " + panel.market.quote.pair : "")
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFont
                opacity: 0.55
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                columnSpacing: 8
                rowSpacing: 8

                Repeater {
                    model: panel.market.name === "BTC" ? [
                        { label: "24h", value: root.fmtSignedPct(panel.market.quote.changePct) },
                        { label: "24h high", value: root.fmtUsd(panel.market.quote.high24h) },
                        { label: "24h low", value: root.fmtUsd(panel.market.quote.low24h) },
                        { label: "24h vol", value: panel.market.quote.volume24h !== undefined
                            ? (parseFloat(panel.market.quote.volume24h).toFixed(1) + " BTC") : "—" }
                    ] : [
                        { label: "Price", value: root.fmtUsd(panel.market.quote.price) },
                        { label: "Shares", value: root.fmtQty(panel.market.position.quantity) },
                        { label: "Avg cost", value: root.fmtUsd(panel.market.position.averagePrice) },
                        { label: "P/L", value: root.fmtSignedPct(panel.market.position.upnlPct) }
                    ]

                    SectionPanel {
                        required property var modelData
                        Layout.fillWidth: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: String(modelData.value)
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: root.statFont + 1
                                font.bold: Theme.fontBold
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.label
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.hintFont
                                opacity: 0.55
                            }
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 8
                rowSpacing: 8
                visible: panel.market.period && panel.market.period.days

                Repeater {
                    model: panel.market.name === "BTC" ? [
                        { label: "Holdings", value: root.fmtBtc(panel.market.position.balance) },
                        { label: "Value", value: root.fmtUsd(panel.market.position.valueUsd) },
                        { label: "Unrealized", value: root.fmtSignedPct(panel.market.position.upnlPct) }
                    ] : [
                        { label: "Value", value: root.fmtUsd(panel.market.position.valueUsd) },
                        { label: "Cost basis", value: root.fmtUsd(panel.market.position.totalCost) },
                        { label: panel.market.days + "d change", value: root.fmtSignedPct(panel.market.period.changePct) }
                    ]

                    SectionPanel {
                        required property var modelData
                        Layout.fillWidth: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: String(modelData.value)
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.statFont + 1
                                font.bold: Theme.fontBold
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.label
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.hintFont
                                opacity: 0.55
                            }
                        }
                    }
                }
            }

            SparklineChart {
                Layout.fillWidth: true
                Layout.preferredHeight: 96
                chartHeight: 96
                style: "line"
                lineColor: panel.market.chartColor
                bars: panel.market.bars
            }
        }
    }

    ColumnLayout {
        id: column
        width: root.hoverPopupWidth
        spacing: Theme.hoverPopupSectionSpacing

        MarketPanel {
            label: "BTC"
            market: root.btc
        }

        MarketPanel {
            label: "SPCX"
            market: root.spcx
        }
    }
}
