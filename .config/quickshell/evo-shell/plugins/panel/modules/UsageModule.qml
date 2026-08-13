import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../../Commons"

Item {
    id: root

    property var host: null

    readonly property string home: Quickshell.env("HOME")
    readonly property string script: home + "/.local/bin/evo-bar-cursor.sh"
    readonly property bool active: host && host.opened === true

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
        if (expandModels)
            modelSplitExpanded = true
        usagePoll.runPoll()
    }

    readonly property int cycleDaysTotal: detail && detail.cycleDaysTotal !== undefined
        ? parseInt(detail.cycleDaysTotal, 10) || 0 : 0
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

    property bool expandModels: false
    property bool modelSplitExpanded: expandModels
    property int breakdownInset: 0

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
    }

    JsonPollRunner {
        id: usagePoll
        active: root.active
        defaultIntervalSec: 300
        command: ["bash", root.script]
        onPolled: function(json) { root.applyPayload(json) }
    }

    Connections {
        target: usagePoll
        function onLoadingChanged() { root.loading = usagePoll.loading }
    }

    implicitHeight: contentColumn.implicitHeight
    implicitWidth: contentColumn.implicitWidth

    ColumnLayout {
        id: contentColumn
        width: parent.width
        spacing: 12

            Text {
                Layout.fillWidth: true
                visible: root.isError
                text: root.errorText
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.panelSmallFontPixelSize
                opacity: 0.8
                wrapMode: Text.WordWrap
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 148
                visible: !root.isError

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 14

                    UsageGauge {
                        title: "Cursor models"
                        percent: root.cursorPercent
                        gaugeColor: root.cursorColor
                        loading: root.loading
                    }

                    UsageGauge {
                        title: "Other models"
                        percent: root.otherPercent
                        gaugeColor: root.otherColor
                        loading: root.loading
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                visible: !root.isError && root.hasModelDetails

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: root.modelSplitExpanded ? "−" : "+"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.panelSmallFontPixelSize
                        font.bold: Theme.fontBold
                    }

                    Text {
                        text: "Model breakdown"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.panelHintFontPixelSize
                        opacity: 0.55
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.modelSplitExpanded = !root.modelSplitExpanded
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: root.breakdownInset
                Layout.rightMargin: root.breakdownInset
                spacing: 8
                visible: !root.isError && root.hasModelDetails && root.modelSplitExpanded

                Repeater {
                    model: root.modelSplit

                    ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: root.modelLabel(modelData.model)
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.panelHintFontPixelSize
                                font.bold: Theme.fontBold
                                elide: Text.ElideRight
                            }

                            Text {
                                text: root.loading
                                    ? "…"
                                    : Math.round(modelData.percent) + "% · "
                                        + root.formatTokens(modelData.tokens)
                                color: modelData.color || Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.panelHintFontPixelSize
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
                    font.pixelSize: Theme.panelHintFontPixelSize
                    opacity: 0.6
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: tokensRow.implicitHeight
                visible: root.showTokens

                RowLayout {
                    id: tokensRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 0

                    Text {
                        text: root.loading ? "…" : (root.formatTokens(root.detail.tokensTotal) + " tokens")
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.panelSmallFontPixelSize
                    }

                    Text {
                        visible: !root.loading
                        text: " · "
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.panelSmallFontPixelSize
                        opacity: 0.45
                    }

                    Text {
                        visible: !root.loading
                        text: root.formatTokens(root.detail.tokensToday) + " today"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.panelSmallFontPixelSize
                    }

                    Item {
                        visible: root.showCycleBar
                        width: Theme.sparklineChartMargin
                        height: 1
                    }

                    CycleProgressBar {
                        visible: root.showCycleBar
                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: implicitHeight
                        progress: root.cycleProgress
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

        implicitWidth: 118
        implicitHeight: 142

        readonly property real sweep: Math.max(0, Math.min(100, percent)) / 100
        readonly property int ringSize: 104
        readonly property real ringRadius: 40
        readonly property real ringLineWidth: 10

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
            font.pixelSize: 22
            font.bold: Theme.fontBold
        }

        Text {
            anchors.top: ring.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 4
            horizontalAlignment: Text.AlignHCenter
            text: gaugeRoot.title
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.bold: Theme.fontBold
            opacity: 0.7
            wrapMode: Text.WordWrap
        }
    }
}
