import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"

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

    function dismissHost() {
        if (host && typeof host.dismiss === "function")
            host.dismiss()
    }

    function onActivated() {
        usagePoll.runPoll()
        Qt.callLater(function() {
            if (root.active)
                focusSink.forceActiveFocus()
        })
    }

    function membershipLabel(raw) {
        var s = String(raw || "").replace(/_/g, " ")
        if (!s) return "Cursor"
        return s.charAt(0).toUpperCase() + s.slice(1)
    }

    function formatIsoDate(iso) {
        if (!iso) return "—"
        var d = new Date(String(iso))
        if (isNaN(d.getTime())) return String(iso).slice(0, 10)
        return Qt.formatDate(d, "d MMM yyyy")
    }

    function cycleLabel() {
        var start = formatIsoDate(detail.billingCycleStart)
        var end = formatIsoDate(detail.billingCycleEnd)
        if (start === "—" && end === "—") return ""
        return start + " → " + end
    }

    function openDashboard() {
        dismissHost()
        Quickshell.execDetached(["bash", "-lc", "xdg-open https://cursor.com/dashboard?tab=usage"])
    }

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

    Item {
        id: focusSink
        anchors.fill: parent
        focus: root.active
        Keys.enabled: root.active
        Keys.onEscapePressed: root.dismissHost()

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            // Hero
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "󰆧"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 40
                    font.bold: Theme.fontBold
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: root.loading ? "Loading…" : membershipLabel(root.detail.membership)
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.bold: Theme.fontBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.cycleLabel() !== ""
                        text: root.cycleLabel()
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        opacity: 0.65
                        elide: Text.ElideRight
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.isError
                text: root.errorText
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 13
                opacity: 0.8
                wrapMode: Text.WordWrap
            }

            FramedPanel {
                label: "Tokens"
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                visible: !root.isError && (root.detail.tokensTotal || root.detail.tokensToday)

                Column {
                    width: parent.width
                    spacing: 6

                    Row {
                        width: parent.width
                        spacing: 8

                        Text {
                            width: parent.width - valueTotal.width - parent.spacing
                            text: "Total this cycle"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            opacity: 0.7
                        }

                        Text {
                            id: valueTotal
                            text: root.loading ? "…" : root.formatTokens(root.detail.tokensTotal) + " tokens"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: Theme.fontBold
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 8

                        Text {
                            width: parent.width - valueToday.width - parent.spacing
                            text: "Today"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            opacity: 0.7
                        }

                        Text {
                            id: valueToday
                            text: root.loading ? "…" : root.formatTokens(root.detail.tokensToday) + " tokens"
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: Theme.fontBold
                        }
                    }
                }
            }

            // Dual donut gauges
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 168
                visible: !root.isError

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 28

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

            FramedPanel {
                label: "Plan"
                Layout.fillWidth: true
                visible: !root.isError && (root.modelSplit.length > 0 || root.detail.onDemand === true)

                Column {
                    width: parent.width
                    spacing: 8

                    Column {
                        width: parent.width
                        visible: root.modelSplit.length > 0
                        spacing: 6

                        Repeater {
                            model: root.modelSplit

                            Column {
                                required property var modelData
                                width: parent.width
                                spacing: 3

                                Row {
                                    width: parent.width
                                    spacing: 8

                                    Text {
                                        width: parent.width - pctLabel.width - parent.spacing
                                        text: root.modelLabel(modelData.model)
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.bold: Theme.fontBold
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        id: pctLabel
                                        text: root.loading
                                            ? "…"
                                            : Math.round(modelData.percent) + "% · "
                                                + root.formatTokens(modelData.tokens)
                                        color: modelData.color || Theme.accent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.bold: Theme.fontBold
                                    }
                                }

                                Item {
                                    width: parent.width
                                    height: 4

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
                    }

                    Text {
                        width: parent.width
                        visible: root.detail.onDemand === true
                        text: "On-demand usage enabled"
                            + (root.detail.onDemandUsed ? (" · " + Number(root.detail.onDemandUsed).toLocaleString() + " used") : "")
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        opacity: 0.6
                    }
                }
            }

            Item { Layout.fillHeight: true }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "Open dashboard"
                color: dashMouse.containsMouse ? Theme.accent : Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: Theme.fontBold
                opacity: 0.8

                MouseArea {
                    id: dashMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openDashboard()
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

        implicitWidth: 132
        implicitHeight: 156

        readonly property real sweep: Math.max(0, Math.min(100, percent)) / 100

        Canvas {
            id: ring
            anchors.horizontalCenter: parent.horizontalCenter
            width: 120
            height: 120
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var cx = width / 2
                var cy = height / 2
                var r = 46
                var lw = 11
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
