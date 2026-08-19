import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPopupWidth: 0

    readonly property string cacheKey: {
        if (host && host.effectivePluginId)
            return host.effectivePluginId
        return shell ? String(shell.hoverPopupId || "") : ""
    }

    readonly property bool active: host && host.opened === true
    readonly property var barSource: host && host.shell ? host.shell.popupAnchorItem : null

    property bool loading: false
    property bool isError: false
    property string errorText: ""
    property var detail: ({})

    readonly property int cursorPercent: detail && detail.cursorPercent !== undefined
        ? parseInt(detail.cursorPercent, 10) || 0 : 0
    readonly property int otherPercent: detail && detail.otherPercent !== undefined
        ? parseInt(detail.otherPercent, 10) || 0 : 0
    readonly property string cursorColor: detail && detail.cursorColor
        ? String(detail.cursorColor) : Theme.accent
    readonly property string otherColor: detail && detail.otherColor
        ? String(detail.otherColor) : Theme.foreground

    function onActivated() {
        syncFromBar()
    }

    function hasDisplayData() {
        return !isError && detail && typeof detail === "object" && Object.keys(detail).length > 0
    }

    function bootstrapFromCache() {
        if (!cacheKey || !shell)
            return
        var cached = Util.hoverPopupCacheRead(shell, cacheKey)
        if (cached)
            applyPayload(cached)
    }

    function publishCache(json) {
        if (cacheKey && shell && json && typeof json === "object")
            Util.hoverPopupCacheWrite(shell, cacheKey, json)
    }

    function syncFromBar() {
        var item = barSource
        if (item && item.polling) {
            if (!hasDisplayData())
                loading = true
            return
        }
        if (item && item.lastPayload)
            applyPayload(item.lastPayload)
        else {
            var cached = Util.hoverPopupCacheRead(shell, cacheKey)
            if (cached)
                applyPayload(cached)
            else
                applyPayload(null)
        }
    }

    readonly property color cycleColor: Theme.heatmap3
    readonly property bool showTokens: !isError && !!(detail.tokensTotal || detail.tokensToday)

    function formatTokens(n) {
        var v = Number(n) || 0
        if (v >= 1e9) return (v / 1e9).toFixed(2) + "B"
        if (v >= 1e6) return (v / 1e6).toFixed(2) + "M"
        if (v >= 1e3) return (v / 1e3).toFixed(1) + "K"
        return String(Math.round(v))
    }

    function modelLabel(name) {
        return String(name || "")
            .replace(/^cursor-/, "")
            .replace(/-/g, " ")
    }

    readonly property var modelSplit: Array.isArray(detail.modelSplit) ? detail.modelSplit : []
    readonly property bool hasModelDetails: root.modelSplit.length > 0 || root.detail.onDemand === true

    readonly property int smallFont: Theme.fontSize4xl
    readonly property int hintFont: Theme.fontSizeL
    readonly property int breakdownFont: Theme.fontSizeS
    readonly property int tokensFont: Theme.fontSizeL
    readonly property int gaugeSpacing: 12
    readonly property int usageChartPadH: Theme.hoverPopupChartPadH
    readonly property int usageContentWidth: Math.max(Theme.hoverPopupWidthStandard, root.hoverPopupWidth)
        - Theme.hoverPopupContentPad * 2
        - root.usageChartPadH * 2
    readonly property int gaugeSize: Math.max(96, Math.floor((root.usageContentWidth - root.gaugeSpacing) / 2))
    readonly property int gaugeLabelFont: Math.max(Theme.fontSizeL, Math.round(root.gaugeSize * 0.22))
    readonly property int usageBlockWidth: root.gaugeSize * 2 + root.gaugeSpacing

    readonly property int cycleDaysLeft: {
        var used = parseInt(root.detail.cycleDaysUsed, 10) || 0
        var total = parseInt(root.detail.cycleDaysTotal, 10) || 0
        return Math.max(0, total - used)
    }
    readonly property string cycleDaysLeftText: {
        if (root.loading)
            return "…"
        var left = root.cycleDaysLeft
        return left === 1 ? "1 day" : left + " days"
    }
    readonly property real cycleElapsed: {
        var used = parseInt(root.detail.cycleDaysUsed, 10) || 0
        var total = parseInt(root.detail.cycleDaysTotal, 10) || 0
        if (total <= 0)
            return 0
        return Math.max(0, Math.min(1, used / total))
    }

    function applyPayload(json) {
        loading = false
        if (!json || typeof json !== "object") {
            isError = true
            errorText = "No data"
            detail = ({})
            return
        }
        if (json.class === "error") {
            isError = true
            errorText = String(json.message || json.text || "Unavailable")
            detail = ({})
            return
        }
        isError = false
        errorText = ""
        detail = json.detail && typeof json.detail === "object" ? json.detail : ({})
        publishCache(json)
    }

    onActiveChanged: if (active) syncFromBar()
    onBarSourceChanged: if (active) syncFromBar()

    Connections {
        target: root.barSource
        enabled: root.barSource !== null
        function onLastPayloadChanged() {
            if (root.active) root.syncFromBar()
        }
        function onPollingChanged() {
            if (root.active) root.syncFromBar()
        }
    }

    implicitHeight: contentColumn.implicitHeight

    ColumnLayout {
        id: contentColumn
        width: root.hoverPopupWidth
        spacing: Theme.hoverPopupSectionSpacing

        Text {
            Layout.fillWidth: true
            visible: root.isError
            text: root.errorText
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: root.smallFont
            opacity: 0.8
            wrapMode: Text.WordWrap
        }

        SectionPanel {
            label: ""
            visible: !root.isError

            HoverPopupLabelPill {
                text: "Usage"
                icon: "󰆧"
                fontSize: Theme.fontSizeS
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
                visible: root.showTokens

                HoverPopupStatBox {
                    value: root.loading ? "…" : root.formatTokens(root.detail.tokensTotal)
                    label: "tokens"
                }

                HoverPopupStatBox {
                    value: root.loading ? "…" : root.formatTokens(root.detail.tokensToday)
                    label: "today"
                    valueColor: Theme.accent
                }
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: usageBlock.implicitHeight

                ColumnLayout {
                    id: usageBlock
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.usageBlockWidth
                    spacing: Theme.spacingL

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.gaugeSpacing

                        ColumnLayout {
                            Layout.preferredWidth: root.gaugeSize
                            spacing: Theme.spacingS

                            UsageGauge {
                                Layout.alignment: Qt.AlignHCenter
                                percent: root.cursorPercent
                                gaugeColor: root.cursorColor
                                loading: root.loading
                                gaugeSize: root.gaugeSize
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Cursor"
                                color: root.cursorColor
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                                font.bold: Theme.fontBold
                            }
                        }

                        ColumnLayout {
                            Layout.preferredWidth: root.gaugeSize
                            spacing: Theme.spacingS

                            UsageGauge {
                                Layout.alignment: Qt.AlignHCenter
                                percent: root.otherPercent
                                gaugeColor: root.otherColor
                                loading: root.loading
                                gaugeSize: root.gaugeSize
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Other"
                                color: root.otherColor
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                                font.bold: Theme.fontBold
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        HoverPopupLabelPill {
                            text: root.cycleDaysLeftText
                            fieldsetLegend: false
                            fontSize: Theme.fontSizeXs
                            textColor: root.cycleColor
                            fill: Theme.withOpacity(root.cycleColor, 0.14)
                            textOpacity: 1
                        }

                        Text {
                            text: "left"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.bold: Theme.fontBold
                            opacity: 0.72
                        }

                        CycleProgressBar {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 4
                            Layout.alignment: Qt.AlignVCenter
                            progress: root.cycleElapsed
                            color: root.cycleColor
                            barHeight: 4
                        }
                    }
                }
            }
        }

        SectionPanel {
            label: ""
            visible: !root.isError && root.hasModelDetails

            HoverPopupLabelPill {
                text: "Breakdown"
                icon: "󰄪"
                fontSize: Theme.fontSizeS
            }

            Repeater {
                model: root.modelSplit

                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 140
                            text: root.modelLabel(modelData.model)
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.breakdownFont
                            font.bold: Theme.fontBold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                            text: root.loading
                                ? "…"
                                : Math.round(modelData.percent) + "% · "
                                    + root.formatTokens(modelData.tokens)
                            color: modelData.color || Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: root.breakdownFont
                            font.bold: Theme.fontBold
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 4

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusS
                            color: Theme.foregroundRaised
                        }

                        Rectangle {
                            height: parent.height
                            width: parent.width * Math.max(0, Math.min(1, modelData.percent / 100))
                            radius: Theme.radiusS
                            color: modelData.color || Theme.accent
                            opacity: Theme.opacityEmphasis
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.detail.onDemand === true
                text: "On-demand usage enabled"
                    + (root.detail.onDemandUsed ? (" · " + Number(root.detail.onDemandUsed).toLocaleString() + " used") : "")
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.breakdownFont
                opacity: 0.6
            }
        }
    }

    component UsageGauge: Item {
        id: gaugeRoot

        property int percent: 0
        property color gaugeColor: Theme.accent
        property bool loading: false
        property int gaugeSize: 130

        implicitWidth: gaugeRoot.gaugeSize
        implicitHeight: ring.height

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
                var track = Theme.foregroundDivider

                ctx.beginPath()
                ctx.arc(cx, cy, r, 0, Math.PI * 2)
                ctx.strokeStyle = track
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
            }
            Component.onCompleted: requestPaint()
        }

        Text {
            anchors.centerIn: ring
            text: gaugeRoot.loading ? "…" : (gaugeRoot.percent + "%")
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: root.gaugeLabelFont
            font.bold: Theme.fontBold
        }
    }
}
