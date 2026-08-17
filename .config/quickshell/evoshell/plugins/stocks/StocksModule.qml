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
    readonly property int headerPriceFont: Theme.hoverPopupTitleFontPixelSize
    readonly property int headerIconSize: Math.round(Theme.popupTitleFontPixelSize * 1.25)
    readonly property int headerBlockHeight: root.headerIconSize
    readonly property int chartBlockHeight: 96
    readonly property int statRowHeight: Theme.hoverPopupLabelFontPixelSize
        + Theme.hoverPopupHintFontPixelSize + 36
    readonly property int marketPanelMinHeight: root.headerBlockHeight + root.statRowHeight
        + root.chartBlockHeight + Theme.hoverPopupSectionSpacing * 2
    readonly property int stableContentHeight: (marketPanelMinHeight + 48) * 2
        + Theme.hoverPopupSectionSpacing

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

    function fmtBtc(val) {
        var n = parseFloat(val)
        if (isNaN(n) || n <= 0)
            return "—"
        return n.toFixed(3) + " BTC"
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

    function marketStatBoxes(market) {
        var position = market.position || {}
        var quantityValue = market.name === "BTC"
            ? root.fmtBtc(position.balance)
            : root.fmtQty(position.quantity)
        var quantityLabel = market.name === "BTC" ? "BTC" : "Shares"
        return [
            { label: "Value", value: root.fmtUsd(position.valueUsd) },
            { label: quantityLabel, value: quantityValue },
            { label: "Avg cost", value: root.fmtUsd(position.averagePrice) },
            { label: "P/L", value: root.fmtSignedPct(position.upnlPct) }
        ]
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
        command: [root.home + "/.local/bin/evo", "bar", "btc", String(root.chartHistoryDays)]
        onPolled: function(json) { root.btcData = json }
    }

    JsonPollRunner {
        id: spcxPoll
        shell: root.shell
        cacheKey: root.spcxCacheKey
        active: root.active
        defaultIntervalSec: 60
        command: [root.home + "/.local/bin/evo", "bar", "spcx", String(root.chartHistoryDays)]
        onPolled: function(json) { root.spcxData = json }
    }

    implicitHeight: Math.max(root.stableContentHeight, column.implicitHeight)

    component MarketHeader: Item {
        id: marketHeader
        property var market: ({})

        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight

        readonly property string priceText: {
            var price = market.quote ? market.quote.price : undefined
            return price !== undefined && price !== null
                ? root.fmtUsd(price)
                : "—"
        }

        RowLayout {
            id: headerRow
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 14

            Item {
                Layout.preferredWidth: root.headerIconSize
                Layout.preferredHeight: root.headerIconSize
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    text: root.marketSymbolIcon(market.name)
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(root.headerIconSize * 0.78)
                    font.bold: Theme.fontBold
                    opacity: 0.9
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: marketHeader.priceText
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.headerPriceFont
                font.bold: Theme.fontBold
            }
        }

        MouseArea {
            anchors.fill: parent
            visible: market.href !== ""
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openMarketUrl(market.href)
        }
    }

    component MarketPanel: SectionPanel {
        id: panel
        property var market: ({})

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.hoverPopupSectionSpacing

            MarketHeader {
                Layout.fillWidth: true
                Layout.preferredHeight: root.headerBlockHeight
                market: panel.market
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.minimumHeight: root.statRowHeight
                columns: 4
                columnSpacing: 8
                rowSpacing: 8

                Repeater {
                    model: root.marketStatBoxes(panel.market)

                    SectionPanel {
                        required property var modelData
                        Layout.fillWidth: true
                        label: ""
                        filled: true
                        contentPad: 10

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

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.chartBlockHeight
                Layout.minimumHeight: root.chartBlockHeight

                SparklineChart {
                    anchors.fill: parent
                    style: "line"
                    lineColor: panel.market.chartColor
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
