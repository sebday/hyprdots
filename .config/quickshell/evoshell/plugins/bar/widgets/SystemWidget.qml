import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Commons"

Item {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var settings: ({})

    property bool loading: false
    property int cpuPercent: 0
    property string detailText: "…"

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string script: home + "/.local/bin/evo-bar-system"
    readonly property string btopScript: home + "/.local/bin/evo-system-btop"
    readonly property string cpuIcon: "󰍛"
    readonly property color cpuColor: Format.usagePercentColor(cpuPercent)

    implicitWidth: contentRow.implicitWidth + Theme.barPaddingX * 2
    implicitHeight: Theme.barHeight

    function applyJson(line) {
        loading = false
        var raw = String(line || "").trim()
        if (!raw) {
            return
        }
        try {
            var json = JSON.parse(raw)
            cpuPercent = parseInt(json.cpuPercent, 10) || 0
            detailText = json.detail ? String(json.detail) : "—"
        } catch (e) {
            console.warn("system widget parse failed:", e)
        }
    }

    function poll() {
        if (!script) return
        loading = true
        proc.command = ["bash", "-lc", script]
        proc.running = false
        proc.running = true
    }

    function restartPolling() {
        intervalTimer.interval = Math.max(1, parseInt(settings.interval, 10) || 5) * 1000
        intervalTimer.stop()
        poll()
        intervalTimer.start()
    }

    function toggleBtop() {
        Quickshell.execDetached(["bash", btopScript, "toggle"])
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: root.cpuIcon
            color: root.loading ? Theme.foreground : root.cpuColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.barFontPixelSize
            font.bold: Theme.fontBold
            Layout.alignment: Qt.AlignVCenter
            opacity: root.loading ? 0.55 : 1
        }

        Text {
            text: root.loading ? "…" : root.detailText
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.barFontPixelSize
            font.bold: Theme.fontBold
            Layout.alignment: Qt.AlignVCenter
            opacity: root.loading ? 0.55 : 0.92
        }
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: root.applyJson(text)
        }
        onExited: root.loading = false
    }

    Timer {
        id: intervalTimer
        interval: Math.max(1, parseInt(root.settings.interval, 10) || 5) * 1000
        repeat: true
        onTriggered: root.poll()
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleBtop()
    }

    onSettingsChanged: restartPolling()
    Component.onCompleted: restartPolling()
}
