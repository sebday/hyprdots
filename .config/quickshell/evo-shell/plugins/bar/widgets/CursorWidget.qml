import QtQuick
import Quickshell
import Quickshell.Io
import "../../../Commons"

Item {
    id: root

    property var bar: null
    property var shell: null
    property var settings: ({})

    property bool loading: false
    property bool isError: false
    property string mainText: ""
    property int cycleDaysUsed: 0
    property int cycleDaysTotal: 0
    property real cycleProgress: 0

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string script: home + "/.local/bin/evo-bar-cursor.sh"
    readonly property bool showCycleBar: !loading && !isError && cycleDaysTotal > 0

    implicitWidth: contentRow.implicitWidth + Theme.barPaddingX * 2
    implicitHeight: Theme.barHeight

    function applyJson(line) {
        loading = false
        var raw = String(line || "").trim()
        if (!raw) return
        try {
            var json = JSON.parse(raw)
            if (json.class === "error") {
                isError = true
                mainText = String(json.text || "󰆧 …")
                cycleDaysUsed = 0
                cycleDaysTotal = 0
                cycleProgress = 0
                return
            }
            isError = false
            mainText = String(json.text || "").replace(/<[^>]+>/g, "").trim()
            cycleDaysUsed = parseInt(json.cycleDaysUsed, 10) || 0
            cycleDaysTotal = parseInt(json.cycleDaysTotal, 10) || 0
            cycleProgress = Number(json.cycleProgress) || 0
        } catch (e) {
            console.warn("cursor widget parse failed:", e)
        }
    }

    function poll() {
        if (!script) return
        loading = true
        proc.command = ["bash", "-lc", script]
        proc.running = false
        proc.running = true
    }

    Process {
        id: proc
        property string stdoutText: ""
        stdout: StdioCollector {
            onStreamFinished: proc.stdoutText = text
        }
        onExited: {
            root.loading = false
            root.applyJson(proc.stdoutText)
        }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.sparklineGap

        Text {
            id: label
            text: root.loading ? "󰆧 …" : root.mainText
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.barFontPixelSize
            font.bold: Theme.fontBold
        }

        Row {
            visible: root.showCycleBar
            spacing: 0
            height: cycleBar.height
            anchors.verticalCenter: parent.verticalCenter

            Item {
                width: Theme.sparklineChartMargin
                height: 1
            }

            Item {
                id: cycleBar
                width: 36
                height: 4

                Rectangle {
                    anchors.fill: parent
                    radius: 2
                    color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.12)
                }

                Rectangle {
                    height: parent.height
                    width: parent.width * Math.max(0, Math.min(1, root.cycleProgress))
                    radius: 2
                    color: Theme.accent
                    opacity: 0.9
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (shell) shell.toggle("evo.cursor-usage", "")
        }
    }

    function restartPolling() {
        if (!script) return
        poll()
        intervalTimer.interval = Math.max(60, parseInt(settings.interval, 10) || 300) * 1000
        intervalTimer.stop()
        intervalTimer.start()
    }

    Timer {
        id: intervalTimer
        interval: 300000
        repeat: true
        onTriggered: root.poll()
    }

    onSettingsChanged: restartPolling()
    Component.onCompleted: restartPolling()
}
