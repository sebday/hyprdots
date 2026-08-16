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
    readonly property string btopScript: home + "/.local/bin/evo-bar-btop"
    readonly property string cpuIcon: "󰍛"
    readonly property color cpuColor: Format.loadPercentColor(cpuPercent)

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

    function showBtop() {
        Quickshell.execDetached(["bash", btopScript, "show"])
    }

    function hideBtop() {
        Quickshell.execDetached(["bash", btopScript, "hide"])
    }

    function onBtopHoverChanged(hovered) {
        if (hovered) {
            btopHideTimer.stop()
            btopShowTimer.restart()
            return
        }
        btopShowTimer.stop()
        btopHideTimer.restart()
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            id: cpuIconText
            text: root.cpuIcon
            color: root.cpuColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.barFontPixelSize
            font.bold: Theme.fontBold
            Layout.alignment: Qt.AlignVCenter
            opacity: root.loading ? 0.55 : 1

            Behavior on color {
                ColorAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
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

    HoverHandler {
        id: btopHover
        onHoveredChanged: root.onBtopHoverChanged(hovered)
    }

    Timer {
        id: btopShowTimer
        interval: 90
        repeat: false
        onTriggered: root.showBtop()
    }

    Timer {
        id: btopHideTimer
        interval: 300
        repeat: false
        onTriggered: root.hideBtop()
    }

    onSettingsChanged: restartPolling()
    Component.onCompleted: restartPolling()
    Component.onDestruction: hideBtop()
}
