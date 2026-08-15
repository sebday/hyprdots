import QtQuick
import Quickshell
import Quickshell.Io
import "../../../Commons"

Item {
    id: root
    property var bar: null
    property var settings: ({})

    property bool loading: false
    property bool isError: false
    property string statusText: ""
    property int todayCount: 0
    property var cells: []

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string script: home + "/.local/bin/evo-bar-github"

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
                statusText = String(json.text || "GitHub error").replace(/<[^>]+>/g, "").trim()
                cells = []
                return
            }

            isError = false
            statusText = ""
            todayCount = parseInt(json.today, 10) || 0
            cells = Array.isArray(json.cells) ? json.cells : []
        } catch (e) {
            console.warn("github widget parse failed:", e)
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
        property string stderrText: ""
        stdout: StdioCollector {
            onStreamFinished: proc.stdoutText = text
        }
        stderr: StdioCollector {
            onStreamFinished: proc.stderrText = text
        }
        onExited: {
            root.loading = false
            var raw = String(proc.stdoutText || "").trim()
            if (!raw) raw = String(proc.stderrText || "").trim()
            root.applyJson(raw)
        }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.sparklineGap

        Text {
            text: root.loading ? " …" : root.isError ? root.statusText : "  " + root.todayCount
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.barFontPixelSize
            font.bold: Theme.fontBold
        }

        Row {
            id: nativeHeatmap
            spacing: Theme.sparklineBarSpacing
            visible: !root.loading && root.cells.length > 0
            height: Theme.sparklineCellSize
            anchors.verticalCenter: parent.verticalCenter

            Item {
                width: Theme.sparklineChartMargin
                height: 1
            }

            Repeater {
                model: root.cells
                Rectangle {
                    required property var modelData
                    width: Theme.sparklineCellSize
                    height: Theme.sparklineCellSize
                    color: modelData.color || Theme.foreground
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.settings.onClick)
                Quickshell.execDetached(["bash", "-lc", String(root.settings.onClick)])
            else
                Quickshell.execDetached(["xdg-open", "https://github.com/sebday"])
        }
    }

    function restartPolling() {
        if (!script) return
        poll()
        intervalTimer.interval = Math.max(1, parseInt(settings.interval, 10) || 300) * 1000
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
