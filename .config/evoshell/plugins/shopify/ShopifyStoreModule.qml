import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "."
import "../commons"

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPanelWidth: 0
    property string storeKey: "STORE_A"
    property string title: "Store A"
    property string adminUrl: ""
    property string adminSlug: ""
    property string legendTitle: title
    property bool chartFillHeight: false
    property bool demoMode: false

    readonly property string cacheKey: shell ? String(shell.hoverPanelId || "") : ""
    readonly property string storeCacheKey: "shopify-" + storeKey + "-30"

    readonly property string home: Quickshell.env("HOME")
    readonly property string shopifyScript: (shell && shell.configDir)
        ? shell.configDir + "/plugins/shopify/bin/evo-panel-shopify"
        : home + "/.config/evoshell/plugins/shopify/bin/evo-panel-shopify"
    readonly property string demoJsonPath: (shell && shell.configDir)
        ? shell.configDir + "/plugins/shopify/demo.json"
        : home + "/.config/evoshell/plugins/shopify/demo.json"
    readonly property bool active: host && host.opened === true
    readonly property var barSource: host && host.shell ? host.shell.popupAnchorItem : null
    readonly property int hintFont: Theme.fontSizeL
    readonly property color sectionLegendBackground: Theme.background

    readonly property string legendStoreKey: storeKey

    readonly property string legendDisplayTitle: legendTitle || title

    readonly property string storeAdminSlug: String(adminSlug || "").trim()

    readonly property string liveAnalyticsUrl: storeAdminSlug !== ""
        ? "https://admin.shopify.com/store/" + storeAdminSlug + "/analytics/live"
        : adminUrl

    readonly property bool hasLiveAnalyticsLink: liveAnalyticsUrl !== ""

    property var storeData: ({})
    property string activeChartMetric: "revenue"

    readonly property var chartMetricCatalog: ({
        revenue: { id: "revenue", label: "revenue", barsKey: "bars", valueKind: "currency", showOrders: true, chartStyle: "bar" },
        orders: { id: "orders", label: "orders", barsKey: "orderBars", valueKind: "integer", showOrders: false, chartStyle: "bar" },
        sessions: { id: "sessions", label: "sessions", barsKey: "sessionBars", valueKind: "integer", showOrders: false, chartStyle: "line" },
        cvr: { id: "cvr", label: "CVR", barsKey: "cvrBars", valueKind: "percent", showOrders: false, chartStyle: "line" },
        aov: { id: "aov", label: "AoV", barsKey: "aovBars", valueKind: "currency", showOrders: false, chartStyle: "line" },
        cos: { id: "cos", label: "CoS", barsKey: "cosBars", valueKind: "percent", showOrders: false, chartStyle: "line" },
        spend: { id: "spend", label: "ad spend", barsKey: "spendBars", valueKind: "currency", showOrders: false, chartStyle: "line" },
        periodRevenue: { id: "periodRevenue", label: "revenue", barsKey: "bars", valueKind: "currency", showOrders: true, chartStyle: "bar" }
    })

    readonly property string activeChartColorMode: {
        if (activeChartMetric === "revenue" || activeChartMetric === "periodRevenue")
            return "revenue"
        if (activeChartMetric === "cos")
            return "cos"
        return "default"
    }

    readonly property var activeChartMetricDef: root.chartMetricDef(root.activeChartMetric)
        || root.chartMetricDef("revenue")

    readonly property string chartSectionTitle: root.chartDays + " day "
        + (root.activeChartMetricDef ? root.activeChartMetricDef.label : "revenue")

    readonly property var todayDetail: storeData.todayDetail || {}
    readonly property var period: storeData.period || {}
    readonly property var month: storeData.month || {}
    readonly property var channels: storeData.channels || {}
    readonly property string currency: storeData.symbol || "£"
    readonly property int chartDays: period.days || (storeData.bars ? storeData.bars.length : 30)

    readonly property real channelTotal: {
        var ch = channels
        return (parseFloat(ch.paid) || 0)
            + (parseFloat(ch.organic) || 0)
            + (parseFloat(ch.direct) || 0)
            + (parseFloat(ch.email) || 0)
    }

    readonly property var channelRows: {
        var total = channelTotal
        var palette = Theme.chartPalette
        var defs = [
            { label: "Paid", value: parseFloat(channels.paid) || 0 },
            { label: "Organic", value: parseFloat(channels.organic) || 0 },
            { label: "Direct", value: parseFloat(channels.direct) || 0 },
            { label: "Email", value: parseFloat(channels.email) || 0 }
        ]
        var out = []
        for (var i = 0; i < defs.length; i++) {
            out.push({
                label: defs[i].label,
                value: defs[i].value,
                color: palette[i % palette.length],
                share: total > 0 ? defs[i].value / total : 0
            })
        }
        return out
    }

    implicitHeight: root.chartFillHeight ? 0 : body.implicitHeight

    function onActivated() {
        if (demoMode) {
            refreshDemoPayload()
            return
        }
        syncFromBar()
        storePoll.runPoll()
    }

    function demoPayloadFromFile() {
        try {
            var raw = String(demoFile.text() || "").trim()
            if (!raw)
                return null
            var all = JSON.parse(raw)
            if (!all || typeof all !== "object")
                return null
            var key = storeKey
            return all[key] || all[key.toLowerCase()] || null
        } catch (e) {
            return null
        }
    }

    function refreshDemoPayload() {
        if (!demoMode)
            return
        var fromFile = demoPayloadFromFile()
        if (!fromFile || !Array.isArray(fromFile.bars) || fromFile.bars.length === 0)
            return
        applyPayload(fromFile)
    }

    function chartMetricDef(id) {
        return root.chartMetricCatalog[id] || null
    }

    function chartBarsForMetric(id) {
        var def = chartMetricDef(id)
        if (!def)
            return []
        var bars = storeData[def.barsKey]
        return Array.isArray(bars) ? bars : []
    }

    function chartMetricClickable(id) {
        return chartBarsForMetric(id).length > 0
    }

    function setChartMetric(id) {
        if (!chartMetricClickable(id))
            return
        activeChartMetric = id
    }

    function activeChartBars() {
        return chartBarsForMetric(activeChartMetric)
    }

    function themeBarArray(bars) {
        if (!Array.isArray(bars))
            return []
        var out = []
        for (var i = 0; i < bars.length; i++) {
            var bar = Object.assign({}, bars[i])
            var level = parseInt(bar.colorLevel, 10)
            if (!isNaN(level) && level >= 0 && level < Theme.heatmapColors.length)
                bar.color = Theme.heatmapColors[level]
            out.push(bar)
        }
        return out
    }

    function applyDemoTheming(json) {
        var themed = Object.assign({}, json)
        var barKeys = ["bars", "orderBars", "sessionBars", "spendBars", "cvrBars", "aovBars", "cosBars"]
        for (var k = 0; k < barKeys.length; k++) {
            var key = barKeys[k]
            if (Array.isArray(json[key]))
                themed[key] = themeBarArray(json[key])
        }
        return themed
    }

    function statTodayRevenue() {
        var rev = root.todayDetail.revenue
        if (rev !== undefined && rev !== null)
            return Format.formatRevenue(rev, currency)
        if (storeData.revenue !== undefined && storeData.revenue !== null)
            return Format.formatRevenue(storeData.revenue, currency)
        return "—"
    }

    function statOrders() {
        if (todayDetail.orders !== undefined && todayDetail.orders !== null)
            return String(todayDetail.orders)
        if (storeData.orders !== undefined && storeData.orders !== null)
            return String(storeData.orders)
        return "—"
    }

    function bootstrapFromCache() {
        if (demoMode) {
            refreshDemoPayload()
            return
        }
        if (!shell)
            return
        var cached = shell.hoverPanelDataFor(storeCacheKey)
        if (cached) {
            applyPayload(cached)
            return
        }
        if (cacheKey) {
            cached = shell.hoverPanelDataFor(cacheKey)
            if (cached)
                applyPayload(cached)
        }
    }

    function syncFromBar() {
        if (demoMode)
            return
        var item = barSource
        if (item && item.store === storeKey && item.lastPayload)
            applyPayload(item.lastPayload)
    }

    function openAdmin() {
        if (!liveAnalyticsUrl)
            return
        Quickshell.execDetached(["bash", "-lc", "xdg-open " + Util.shellQuote(liveAnalyticsUrl)])
    }

    function fmtPct(val) {
        var n = parseFloat(val)
        if (isNaN(n))
            return "—"
        return (n * 100).toFixed(1) + "%"
    }

    function fmtMoney(val) {
        var n = parseFloat(val)
        if (isNaN(n) || n <= 0)
            return "—"
        return Format.formatRevenue(n, currency)
    }

    function fmtAov() {
        var revenue = parseFloat(root.todayDetail.revenue)
        var orders = parseFloat(root.todayDetail.orders || root.storeData.orders)
        if (isNaN(revenue) || isNaN(orders) || orders <= 0)
            return "—"
        return Format.formatRevenue(revenue / orders, currency)
    }

    function fmtMonthForecast() {
        var val = parseFloat(root.month.forecastRevenue)
        if (isNaN(val) || val <= 0)
            return "—"
        return Format.formatRevenue(val, currency)
    }

    function applyPayload(json) {
        if (!json || typeof json !== "object")
            return
        if (Object.keys(json).length === 0)
            return
        if (!Array.isArray(json.bars) && !json.todayDetail && json.revenue === undefined)
            return
        if (demoMode && Array.isArray(json.bars)) {
            storeData = applyDemoTheming(json)
            return
        }
        storeData = json
        if (demoMode || !shell || !json || typeof json !== "object")
            return
        var days = (json.period && json.period.days) || (Array.isArray(json.bars) ? json.bars.length : 0)
        if (days >= 30)
            shell.setHoverPanelData(storeCacheKey, json)
        else if (cacheKey)
            shell.setHoverPanelData(cacheKey, json)
    }

    onDemoModeChanged: {
        if (demoMode) {
            storeData = ({})
            Qt.callLater(refreshDemoPayload)
        } else if (active) {
            onActivated()
        }
    }

    onShellChanged: if (shell && active && !demoMode) Qt.callLater(onActivated)

    onStoreKeyChanged: {
        activeChartMetric = "revenue"
        if (active && !demoMode)
            onActivated()
    }

    onActiveChanged: if (active && !demoMode) syncFromBar()
    onBarSourceChanged: if (active && !demoMode) syncFromBar()

    readonly property var barLastPayload: root.barSource ? root.barSource.lastPayload : null
    readonly property var barStore: root.barSource ? root.barSource.store : null

    onBarLastPayloadChanged: if (root.active && !root.demoMode) root.syncFromBar()
    onBarStoreChanged: if (root.active && !root.demoMode) root.syncFromBar()

    FileView {
        id: demoFile
        path: root.demoJsonPath
        preload: true
        watchChanges: true
        printErrors: false
        onLoaded: if (root.demoMode) root.refreshDemoPayload()
        onFileChanged: reload()
    }

    JsonPollRunner {
        id: storePoll
        shell: root.shell
        cacheKey: root.storeCacheKey
        active: root.active && !root.demoMode
        defaultIntervalSec: 300
        command: ["bash", root.shopifyScript, root.storeKey, "30"]
        onPolled: function(json) { root.applyPayload(json) }
    }

    ColumnLayout {
        id: body
        anchors.fill: root.chartFillHeight ? parent : undefined
        width: root.chartFillHeight ? undefined : root.hoverPanelWidth
        spacing: Theme.hoverPanelSectionSpacing

        SectionPanel {
            label: ""
            legendBackground: root.sectionLegendBackground
            Layout.fillWidth: true
            Layout.minimumHeight: implicitHeight

            HoverPanelLabelPill {
                text: root.legendDisplayTitle
                icon: "󰒚"
                fontSize: Theme.fontSizeS
                clickable: root.hasLiveAnalyticsLink
                onClicked: root.openAdmin()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingM

                GridLayout {
                    Layout.fillWidth: true
                    columns: 5
                    columnSpacing: 8
                    rowSpacing: 8

                    HoverPanelStatBox {
                        label: "Revenue"
                        value: root.statTodayRevenue()
                        clickable: root.chartMetricClickable("revenue")
                        customFill: root.activeChartMetric === "revenue"
                        customFillColor: Theme.fillAccentSubtle
                        onClicked: root.setChartMetric("revenue")
                    }

                    HoverPanelStatBox {
                        label: "Orders"
                        value: root.statOrders()
                        clickable: root.chartMetricClickable("orders")
                        customFill: root.activeChartMetric === "orders"
                        customFillColor: Theme.fillAccentSubtle
                        onClicked: root.setChartMetric("orders")
                    }

                    HoverPanelStatBox {
                        label: "Sessions"
                        value: String(root.todayDetail.sessions || "—")
                        clickable: root.chartMetricClickable("sessions")
                        customFill: root.activeChartMetric === "sessions"
                        customFillColor: Theme.fillAccentSubtle
                        onClicked: root.setChartMetric("sessions")
                    }

                    HoverPanelStatBox {
                        label: "CVR"
                        value: root.fmtPct(root.todayDetail.cvr)
                        clickable: root.chartMetricClickable("cvr")
                        customFill: root.activeChartMetric === "cvr"
                        customFillColor: Theme.fillAccentSubtle
                        onClicked: root.setChartMetric("cvr")
                    }

                    HoverPanelStatBox {
                        label: "AoV"
                        value: root.fmtAov()
                        clickable: root.chartMetricClickable("aov")
                        customFill: root.activeChartMetric === "aov"
                        customFillColor: Theme.fillAccentSubtle
                        onClicked: root.setChartMetric("aov")
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    columnSpacing: 8
                    rowSpacing: 8

                    HoverPanelStatBox {
                        label: "CoS"
                        value: String(root.todayDetail.cos || root.storeData.cos || "—")
                        clickable: root.chartMetricClickable("cos")
                        customFill: root.activeChartMetric === "cos"
                        customFillColor: Theme.fillAccentSubtle
                        onClicked: root.setChartMetric("cos")
                    }

                    HoverPanelStatBox {
                        label: "Ad spend"
                        value: root.fmtMoney(root.todayDetail.spend)
                        clickable: root.chartMetricClickable("spend")
                        customFill: root.activeChartMetric === "spend"
                        customFillColor: Theme.fillAccentSubtle
                        onClicked: root.setChartMetric("spend")
                    }

                    HoverPanelStatBox {
                        label: root.chartDays + "d revenue"
                        value: root.period.revenue !== undefined
                            ? Format.formatRevenue(root.period.revenue, root.currency)
                            : "—"
                        valueColor: Theme.foreground
                        clickable: root.chartMetricClickable("periodRevenue")
                        customFill: root.activeChartMetric === "periodRevenue"
                        customFillColor: Theme.fillAccentSubtle
                        onClicked: root.setChartMetric("periodRevenue")
                    }

                    HoverPanelStatBox {
                        label: "Forecast"
                        value: root.fmtMonthForecast()
                    }
                }
            }
        }

        SectionPanel {
            fillHeight: root.chartFillHeight
            label: revenueChart.hasTooltip
                ? revenueChart.tooltipLabel
                : root.chartSectionTitle
            labelProminent: true
            legendBackground: root.sectionLegendBackground
            visible: root.activeChartBars().length > 0
            Layout.minimumHeight: root.chartFillHeight ? 120 : implicitHeight

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 120

                RevenueBarChart {
                    id: revenueChart
                    anchors.fill: parent
                    bars: root.activeChartBars()
                    currency: root.currency
                    valueKind: root.activeChartMetricDef
                        ? root.activeChartMetricDef.valueKind
                        : "currency"
                    showOrdersInTooltip: root.activeChartMetricDef
                        ? root.activeChartMetricDef.showOrders
                        : true
                    colorMode: root.activeChartColorMode
                    chartStyle: root.activeChartMetricDef
                        ? root.activeChartMetricDef.chartStyle
                        : "bar"
                }
            }
        }

        SectionPanel {
            label: ""
            legendBackground: root.sectionLegendBackground
            visible: root.channelTotal > 0
            Layout.minimumHeight: implicitHeight

            HoverPanelLabelPill {
                text: "Channels " + root.chartDays + " days"
                icon: "󰒋"
                fontSize: Theme.fontSizeS
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingM

                Repeater {
                    model: root.channelRows

                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Text {
                            Layout.preferredWidth: 56
                            text: modelData.label
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: Theme.opacitySecondary
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 8

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusS
                                color: Theme.foreground
                                opacity: 0.12
                            }

                            Rectangle {
                                height: parent.height
                                width: Math.max(0, parent.width * modelData.share)
                                radius: Theme.radiusS
                                color: modelData.color
                                opacity: Theme.opacityEmphasis
                            }
                        }

                        Text {
                            Layout.preferredWidth: 72
                            horizontalAlignment: Text.AlignRight
                            text: Format.formatRevenue(modelData.value, root.currency)
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: Theme.opacityBodyText
                        }
                    }
                }
            }
        }
    }
}
