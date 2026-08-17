import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPopupWidth: 0

    readonly property string cacheKey: shell ? String(shell.hoverPopupId || "") : ""

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
        var cached = shell.hoverPopupDataFor(cacheKey)
        if (cached)
            applyPayload(cached)
    }

    function publishCache(json) {
        if (cacheKey && shell && json && typeof json === "object")
            shell.setHoverPopupData(cacheKey, json)
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
        else
            applyPayload(null)
    }

    readonly property int cycleDaysTotal: detail && detail.cycleDaysTotal !== undefined
        ? parseInt(detail.cycleDaysTotal, 10) || 0 : 0
    readonly property int cycleDaysUsed: detail && detail.cycleDaysUsed !== undefined
        ? parseInt(detail.cycleDaysUsed, 10) || 0 : 0
    readonly property int cycleDaysLeft: cycleDaysTotal > 0
        ? Math.max(0, cycleDaysTotal - cycleDaysUsed) : 0
    readonly property real cycleProgress: detail && detail.cycleProgress !== undefined
        ? Number(detail.cycleProgress) || 0 : 0
    readonly property bool showCycleBar: !loading && !isError && cycleDaysTotal > 0
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
    readonly property int heroFont: Theme.fontSizeHero
    readonly property int breakdownFont: Theme.fontSizeXl
    readonly property int tokensFont: Theme.fontSizeL
    readonly property int gaugeLabelFont: Theme.fontSizeS
    readonly property int gaugeSize: 168
    readonly property int gaugeSpacing: 18

    readonly property string cycleDaysPillLabel: root.cycleDaysLeft === 1
        ? "1 day"
        : (root.cycleDaysLeft + " days")

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

            Item {
                Layout.fillWidth: true
                implicitHeight: gaugeRow.implicitHeight

                RowLayout {
                    id: gaugeRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: root.gaugeSpacing

                    UsageGauge {
                        title: "Cursor models"
                        percent: root.cursorPercent
                        gaugeColor: root.cursorColor
                        loading: root.loading
                        labelFont: root.gaugeLabelFont
                        gaugeSize: root.gaugeSize
                    }

                    UsageGauge {
                        title: "Other models"
                        percent: root.otherPercent
                        gaugeColor: root.otherColor
                        loading: root.loading
                        labelFont: root.gaugeLabelFont
                        gaugeSize: root.gaugeSize
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8
            visible: !root.isError && root.showTokens

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

        SectionPanel {
            label: ""
            visible: !root.isError && root.hasModelDetails

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
                            radius: 2
                            color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.12)
                        }

                        Rectangle {
                            height: parent.height
                            width: parent.width * Math.max(0, Math.min(1, modelData.percent / 100))
                            radius: 2
                            color: modelData.color || Theme.accent
                            opacity: 0.9
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

        SectionPanel {
            label: ""
            visible: !root.isError && root.showCycleBar

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: !root.loading

                    Rectangle {
                        radius: 4
                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
                        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.38)
                        border.width: 1
                        implicitWidth: daysPillText.implicitWidth + 16
                        implicitHeight: daysPillText.implicitHeight + 8

                        Text {
                            id: daysPillText
                            anchors.centerIn: parent
                            text: root.cycleDaysPillLabel
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: root.tokensFont
                            font.bold: Theme.fontBold
                        }
                    }

                    Text {
                        text: "left on plan"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.tokensFont
                        opacity: 0.72
                    }

                    Item { Layout.fillWidth: true }
                }

                CycleProgressBar {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4
                    progress: root.cycleProgress
                    barHeight: 4
                }
            }
        }
    }

    component UsageGauge: Item {
        id: gaugeRoot

        property string title: ""
        property int percent: 0
        property color gaugeColor: Theme.accent
        property bool loading: false
        property int labelFont: Theme.fontSizeXxs
        property int gaugeSize: 130

        implicitWidth: gaugeRoot.gaugeSize
        implicitHeight: ring.height + 4 + titleLabel.implicitHeight

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
                var track = Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.14)

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
            font.pixelSize: root.heroFont
            font.bold: Theme.fontBold
        }

        Text {
            id: titleLabel
            anchors.top: ring.bottom
            anchors.topMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 4
            horizontalAlignment: Text.AlignHCenter
            text: gaugeRoot.title
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: gaugeRoot.labelFont
            font.bold: Theme.fontBold
            opacity: 0.65
            wrapMode: Text.WordWrap
        }
    }
}
