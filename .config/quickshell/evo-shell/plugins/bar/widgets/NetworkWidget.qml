import QtQuick
import Quickshell
import Quickshell.Io
import "../../../Commons"

Item {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var settings: ({})

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string script: home + "/.local/bin/evo-bar-network.sh"
    readonly property string hoverPopupId: settings.onHover ? String(settings.onHover) : "evo.network"

    property string displayText: "󰈀 net"
    property string tooltipText: ""

    implicitWidth: label.implicitWidth + Theme.barPaddingX * 2
    implicitHeight: Theme.barHeight

    function applyJson(line) {
        var raw = String(line || "").trim()
        if (!raw) return
        try {
            var json = JSON.parse(raw)
            var text = String(json.text || json.content || "󰈀 net").trim()
            displayText = text || "󰈀 net"
            tooltipText = String(json.tooltip || "").trim()
        } catch (e) {
            console.warn("network widget parse failed:", e)
        }
    }

    function poll() {
        if (!script) return
        proc.command = ["bash", "-lc", script]
        proc.running = false
        proc.running = true
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.displayText
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.barFontPixelSize
        font.bold: Theme.fontBold
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
            var raw = String(proc.stdoutText || "").trim()
            if (!raw) raw = String(proc.stderrText || "").trim()
            root.applyJson(raw)
        }
    }

    HoverHandler {
        enabled: root.hoverPopupId !== "" && root.shell
        onHoveredChanged: {
            if (!root.shell || !root.hoverPopupId) return
            if (hovered)
                root.shell.hoverEnter(root.hoverPopupId, root, root.barPanel)
            else
                root.shell.hoverLeave(root.hoverPopupId)
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    Timer {
        id: intervalTimer
        interval: Math.max(1, parseInt(root.settings.interval, 10) || 5) * 1000
        repeat: true
        onTriggered: root.poll()
    }

    function restartPolling() {
        intervalTimer.interval = Math.max(1, parseInt(settings.interval, 10) || 5) * 1000
        intervalTimer.stop()
        poll()
        intervalTimer.start()
    }

    onSettingsChanged: restartPolling()
    Component.onCompleted: restartPolling()
}
