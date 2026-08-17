import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPopupWidth: 0
    property string storeKey: "DIY"
    property string title: "DIY"
    property string adminUrl: ""
    property bool chartFillHeight: false
    property bool demoMode: false

    readonly property string cacheKey: shell ? String(shell.hoverPopupId || "") : ""
    readonly property string storeCacheKey: "shopify-" + storeKey + "-30"

    readonly property string home: Quickshell.env("HOME")
    readonly property string avatarDir: home + "/onedrive/pictures/Avatars"
    readonly property string demoJsonPath: (shell && shell.shellDir)
        ? shell.shellDir + "/plugins/shopify/demo.json"
        : home + "/.config/quickshell/evoshell/plugins/shopify/demo.json"
    readonly property bool active: host && host.opened === true
    readonly property var barSource: host && host.shell ? host.shell.popupAnchorItem : null
    readonly property int hintFont: Theme.fontSizeL
    readonly property int headerIconSize: Theme.fontSize2xl
        + Theme.hoverPopupSectionSpacing
        + Theme.fontSizeL

    readonly property string storeIconUrl: {
        if (demoMode) {
            if (storeKey === "DIY")
                return "file://" + avatarDir + "/pdog.jpg"
            if (storeKey === "TGS")
                return "file://" + avatarDir + "/robot-seb.jpg"
        }
        if (barSource && barSource.storeIconUrl)
            return String(barSource.storeIconUrl)
        if (storeKey === "DIY")
            return "https://diybuildingsupplies.co.uk/cdn/shop/files/diy-square-logo-trans.png?crop=center&height=48&v=1770480698&width=48"
        if (storeKey === "TGS")
            return "https://thegoodsheet.co.uk/cdn/shop/files/logo_osb.png?crop=center&height=48&v=1752889811&width=48"
        return ""
    }

    readonly property string storeIconFallback: {
        if (demoMode) {
            if (storeKey === "DIY") return "P"
            if (storeKey === "TGS") return "R"
        }
        if (barSource && barSource.storeIcon)
            return String(barSource.storeIcon)
        if (storeKey === "DIY") return "D"
        if (storeKey === "TGS") return "T"
        return storeKey ? storeKey.charAt(0) : ""
    }

    property var storeData: ({})

    readonly property var todayDetail: storeData.todayDetail || {}
    readonly property var period: storeData.period || {}
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
        var defs = [
            { label: "Paid", value: parseFloat(channels.paid) || 0, color: "#89b4fa" },
            { label: "Organic", value: parseFloat(channels.organic) || 0, color: "#a6e3a1" },
            { label: "Direct", value: parseFloat(channels.direct) || 0, color: "#f9e2af" },
            { label: "Email", value: parseFloat(channels.email) || 0, color: "#cba6f7" }
        ]
        var out = []
        for (var i = 0; i < defs.length; i++) {
            out.push({
                label: defs[i].label,
                value: defs[i].value,
                color: defs[i].color,
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
        var fromFile = demoPayloadFromFile()
        if (fromFile && Array.isArray(fromFile.bars) && fromFile.bars.length > 0)
            applyPayload(fromFile)
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
        var cached = shell.hoverPopupDataFor(storeCacheKey)
        if (cached) {
            applyPayload(cached)
            return
        }
        if (cacheKey) {
            cached = shell.hoverPopupDataFor(cacheKey)
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

    function shopifyHeader(data, fallbackName) {
        if (!data || (data.revenue === undefined && !data.label))
            return fallbackName + " …"
        var sym = data.symbol || "£"
        if (data.revenue !== undefined)
            return Format.formatRevenue(data.revenue, sym)
        return String(data.label || "").replace(/^[A-Z]\s+/, "")
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

    function applyPayload(json) {
        if (!json || typeof json !== "object")
            storeData = ({})
        else
            storeData = json
        if (demoMode || !shell || !json || typeof json !== "object")
            return
        var days = (json.period && json.period.days) || (Array.isArray(json.bars) ? json.bars.length : 0)
        if (days >= 30)
            shell.setHoverPopupData(storeCacheKey, json)
        else if (cacheKey)
            shell.setHoverPopupData(cacheKey, json)
    }

    onDemoModeChanged: {
        if (demoMode)
            refreshDemoPayload()
        else if (active)
            onActivated()
    }

    onActiveChanged: if (active && !demoMode) syncFromBar()
    onBarSourceChanged: if (active && !demoMode) syncFromBar()

    Connections {
        target: root.barSource
        enabled: root.barSource !== null && !root.demoMode
        function onLastPayloadChanged() {
            if (root.active) root.syncFromBar()
        }
        function onStoreChanged() {
            if (root.active) root.syncFromBar()
        }
    }

    FileView {
        id: demoFile
        path: root.demoJsonPath
        preload: true
        watchChanges: true
        printErrors: false
        onFileChanged: if (root.demoMode) root.refreshDemoPayload()
    }

    JsonPollRunner {
        id: storePoll
        shell: root.shell
        cacheKey: root.storeCacheKey
        active: root.active && !root.demoMode
        defaultIntervalSec: 300
        command: ["bash", root.home + "/.local/bin/evo-bar-shopify", root.storeKey, "30"]
        onPolled: function(json) { root.applyPayload(json) }
    }

    ColumnLayout {
        id: body
        anchors.fill: root.chartFillHeight ? parent : undefined
        width: root.chartFillHeight ? undefined : root.hoverPopupWidth
        spacing: Theme.hoverPopupSectionSpacing

        SectionPanel {
            label: ""

            HoverPopupHeader {
                Layout.fillWidth: true
                value: root.shopifyHeader(root.storeData, root.title)
                href: root.adminUrl
                iconUrl: root.storeIconUrl
                iconFallback: root.storeIconFallback
                iconSize: root.headerIconSize
                titleFont: Math.round(root.headerIconSize * 0.7)
            }
        }

        SectionPanel {
            label: ""
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    columnSpacing: 8
                    rowSpacing: 8

                    Repeater {
                        model: [
                            { label: "Orders", value: root.statOrders() },
                            { label: "Sessions", value: String(root.todayDetail.sessions || "—") },
                            { label: "CVR", value: root.fmtPct(root.todayDetail.cvr) },
                            { label: "AoV", value: root.fmtAov() }
                        ]

                        HoverPopupStatBox {
                            required property var modelData
                            value: String(modelData.value)
                            label: modelData.label
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 8
                    rowSpacing: 8

                    Repeater {
                        model: [
                            { label: "CoS", value: String(root.todayDetail.cos || root.storeData.cos || "—") },
                            { label: "Ad spend", value: root.fmtMoney(root.todayDetail.spend) },
                            {
                                label: root.chartDays + "d revenue",
                                value: root.period.revenue !== undefined
                                    ? Format.formatRevenue(root.period.revenue, root.currency)
                                    : "—"
                            }
                        ]

                        HoverPopupStatBox {
                            required property var modelData
                            value: String(modelData.value)
                            label: modelData.label
                            valueColor: Theme.foreground
                        }
                    }
                }
            }
        }

        SectionPanel {
            fillHeight: root.chartFillHeight
            label: root.chartDays + " day revenue"
            visible: (root.storeData.bars || []).length > 0

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: root.chartFillHeight
                spacing: 6

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: root.chartFillHeight
                    Layout.minimumHeight: 64
                    Layout.preferredHeight: root.chartFillHeight ? -1 : 100

                    SparklineChart {
                        id: revenueChart
                        anchors.fill: parent
                        chartHeight: root.chartFillHeight ? Math.max(64, Math.round(height)) : 100
                        style: "bars"
                        showBarTooltips: true
                        formatBarTooltip: function(bar) {
                            var parts = []
                            if (bar && bar.date)
                                parts.push(Format.formatDay(bar.date))
                            if (bar && bar.value !== undefined && bar.value !== null)
                                parts.push(Format.formatRevenue(bar.value, root.currency))
                            return parts.join(" · ")
                        }
                        bars: root.storeData.bars || []
                    }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width
                        text: "demo mode"
                        visible: root.demoMode
                        z: 1
                        color: Theme.foreground
                        opacity: 0.12
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(28, Math.round(parent.height * 0.22))
                        font.bold: Theme.fontBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        SectionPanel {
            label: "Channels " + root.chartDays + " days"
            visible: root.channelTotal > 0

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: root.channelRows

                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.preferredWidth: 56
                            text: modelData.label
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: 0.72
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 8

                            Rectangle {
                                anchors.fill: parent
                                radius: 2
                                color: Theme.foreground
                                opacity: 0.12
                            }

                            Rectangle {
                                height: parent.height
                                width: Math.max(0, parent.width * modelData.share)
                                radius: 2
                                color: modelData.color
                                opacity: 0.9
                            }
                        }

                        Text {
                            Layout.preferredWidth: 72
                            horizontalAlignment: Text.AlignRight
                            text: Format.formatRevenue(modelData.value, root.currency)
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: 0.85
                        }
                    }
                }
            }
        }
    }
}
