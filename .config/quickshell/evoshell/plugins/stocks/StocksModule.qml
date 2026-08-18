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
    readonly property int bodyFont: Theme.fontSize3xl
    readonly property int hintFont: Theme.fontSizeL
    readonly property int labelFont: Theme.fontSizeL
    readonly property int statFont: Theme.fontSizeXl
    readonly property int heroFont: Theme.fontSize5xl
    readonly property int headerIconSize: Math.round(root.heroFont * 1.15)
    readonly property int headerBlockHeight: root.headerIconSize
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

    function marketMetaPills(market) {
        var out = []
        var change = market.quote ? market.quote.changePct : undefined
        if (change !== undefined && change !== null && !isNaN(parseFloat(change))) {
            var changeColor = signedColor(change)
            out.push({
                text: fmtSignedPct(change) + " 24h",
                color: changeColor,
                fill: Theme.withOpacity(changeColor, 0.14)
            })
        }
        var upnl = market.position ? market.position.upnlPct : undefined
        if (upnl !== undefined && upnl !== null && !isNaN(parseFloat(upnl))) {
            var upnlColor = signedColor(upnl)
            out.push({
                text: fmtSignedPct(upnl) + " P/L",
                color: upnlColor,
                fill: Theme.withOpacity(upnlColor, 0.14)
            })
        }
        return out
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

    implicitHeight: column.implicitHeight

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

        readonly property var metaPills: root.marketMetaPills(marketHeader.market)

        RowLayout {
            id: headerRow
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 14

            RowLayout {
                spacing: 12
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter

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
                        opacity: Theme.opacityEmphasis
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: marketHeader.priceText
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.heroFont
                    font.bold: Theme.fontBold
                    horizontalAlignment: Text.AlignLeft
                    lineHeight: root.heroFont
                    lineHeightMode: Text.FixedHeight
                }
            }

            Item { Layout.fillWidth: true }

            RowLayout {
                spacing: Theme.spacingS
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                visible: marketHeader.metaPills.length > 0

                Repeater {
                    model: marketHeader.metaPills

                    HoverPopupLabelPill {
                        required property var modelData
                        text: modelData.text
                        fontSize: Theme.fontSizeS
                        textColor: modelData.color
                        fill: modelData.fill
                        textOpacity: 1
                    }
                }
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

                    HoverPopupStatBox {
                        required property var modelData
                        value: String(modelData.value)
                        label: modelData.label
                        valueFontSize: root.statFont
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
