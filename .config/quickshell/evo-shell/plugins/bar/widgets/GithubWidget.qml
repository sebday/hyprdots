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
    property var heatmap: []
    property var cells: []

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string script: home + "/.local/bin/evo-bar-github.sh"
    readonly property bool useNativeCells: cells.length > 0

    implicitWidth: contentRow.implicitWidth + Theme.barPaddingX * 2
    implicitHeight: Theme.barHeight

    function parseSpans(text) {
        var spans = []
        var re = /<span foreground='([^']+)'>([^<]*)<\/span>/g
        var m
        var s = String(text || "")
        while ((m = re.exec(s)) !== null) {
            spans.push({ color: m[1], char: m[2] || "■" })
        }
        return spans
    }

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
                heatmap = []
                return
            }

            isError = false
            statusText = ""

            if (json.today !== undefined && json.today !== null)
                todayCount = parseInt(json.today, 10) || 0
            else {
                var text = String(json.text || "")
                var prefix = text.split("<span")[0].trim()
                var countMatch = prefix.match(/(\d+)\s*$/)
                todayCount = countMatch ? parseInt(countMatch[1], 10) : 0
            }

            if (Array.isArray(json.cells) && json.cells.length > 0) {
                cells = json.cells
                heatmap = []
            } else {
                cells = []
                var fallbackText = String(json.text || "")
                heatmap = parseSpans(fallbackText)
            }
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
            font.pixelSize: Theme.fontPixelSize
            font.bold: Theme.fontBold
        }

        Row {
            id: nativeHeatmap
            spacing: Theme.sparklineBarSpacing
            visible: !root.loading && root.useNativeCells
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

        Row {
            spacing: Theme.sparklineBarSpacing
            visible: !root.loading && !root.useNativeCells && root.heatmap.length > 0
            anchors.verticalCenter: parent.verticalCenter

            Item {
                width: Theme.sparklineChartMargin
                height: 1
            }

            Repeater {
                model: root.heatmap
                Text {
                    required property var modelData
                    text: modelData.char
                    color: modelData.color
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSize
                    font.bold: Theme.fontBold
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
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
