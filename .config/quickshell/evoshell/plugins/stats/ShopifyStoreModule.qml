import Quickshell
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

    readonly property string cacheKey: shell ? String(shell.hoverPopupId || "") : ""
    readonly property string storeCacheKey: "shopify-" + storeKey + "-30"

    readonly property string home: Quickshell.env("HOME")
    readonly property bool active: host && host.opened === true
    readonly property var barSource: host && host.shell ? host.shell.popupAnchorItem : null
    readonly property int bodyFont: Theme.hoverPopupBodyFontPixelSize
    readonly property int hintFont: Theme.hoverPopupHintFontPixelSize
    readonly property int statFont: Theme.hoverPopupLabelFontPixelSize

    readonly property string storeIconUrl: {
        if (barSource && barSource.storeIconUrl)
            return String(barSource.storeIconUrl)
        if (storeKey === "DIY")
            return "https://diybuildingsupplies.co.uk/cdn/shop/files/diy-square-logo-trans.png?crop=center&height=48&v=1770480698&width=48"
        if (storeKey === "TGS")
            return "https://thegoodsheet.co.uk/cdn/shop/files/logo_osb.png?crop=center&height=48&v=1752889811&width=48"
        return ""
    }

    readonly property string storeIconFallback: {
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

    implicitHeight: body.implicitHeight

    function onActivated() {
        syncFromBar()
        storePoll.runPoll()
    }

    function bootstrapFromCache() {
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
        var item = barSource
        if (item && item.store === storeKey && item.lastPayload)
            applyPayload(item.lastPayload)
    }

    function shopifyHeader(data, fallbackName) {
        if (!data || (data.revenue === undefined && !data.label))
            return fallbackName + " …"
        var sym = data.symbol || "£"
        var cos = data.cos || "—"
        var revenue = data.revenue !== undefined
            ? Format.formatRevenue(data.revenue, sym)
            : String(data.label || "").replace(/^[A-Z]\s+/, "")
        var rest = [cos]
        if (typeof data.orders === "number")
            rest.push(data.orders + " orders")
        return Format.headerLines([revenue].concat(rest), fallbackName + " …")
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

    function applyPayload(json) {
        if (!json || typeof json !== "object")
            storeData = ({})
        else
            storeData = json
        if (!shell || !json || typeof json !== "object")
            return
        var days = (json.period && json.period.days) || (Array.isArray(json.bars) ? json.bars.length : 0)
        if (days >= 30)
            shell.setHoverPopupData(storeCacheKey, json)
        else if (cacheKey)
            shell.setHoverPopupData(cacheKey, json)
    }

    onActiveChanged: if (active) syncFromBar()
    onBarSourceChanged: if (active) syncFromBar()

    Connections {
        target: root.barSource
        enabled: root.barSource !== null
        function onLastPayloadChanged() {
            if (root.active) root.syncFromBar()
        }
        function onStoreChanged() {
            if (root.active) root.syncFromBar()
        }
    }

    JsonPollRunner {
        id: storePoll
        shell: root.shell
        cacheKey: root.storeCacheKey
        active: root.active
        defaultIntervalSec: 300
        command: ["bash", root.home + "/.local/bin/evo-bar-shopify", root.storeKey, "30"]
        onPolled: function(json) { root.applyPayload(json) }
    }

    ColumnLayout {
        id: body
        width: root.hoverPopupWidth
        spacing: Theme.hoverPopupSectionSpacing

        SectionPanel {
            label: ""

            HoverPopupHeader {
                Layout.fillWidth: true
                value: root.shopifyHeader(root.storeData, root.title)
                href: root.adminUrl
                iconUrl: root.storeIconUrl
                iconFallback: root.storeIconFallback
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: [
                    { label: "Orders", value: String(root.todayDetail.orders || root.storeData.orders || "—") },
                    { label: "Sessions", value: String(root.todayDetail.sessions || "—") },
                    { label: "CVR", value: root.fmtPct(root.todayDetail.cvr) },
                    { label: "Margin", value: root.fmtPct(root.todayDetail.marginPct) }
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
                            font.pixelSize: root.statFont + 2
                            font.bold: Theme.fontBold
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

        SectionPanel {
            label: root.chartDays + " day revenue"
            visible: (root.storeData.bars || []).length > 0

            SparklineChart {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                chartHeight: 100
                style: "line"
                lineColor: Theme.accent
                bars: root.storeData.bars || []
            }
        }

        SectionPanel {
            label: "Orders"
            visible: (root.storeData.orderBars || []).length > 0

            SparklineChart {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                chartHeight: 72
                bars: root.storeData.orderBars || []
            }
        }

        SectionPanel {
            label: "Channels today"
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
