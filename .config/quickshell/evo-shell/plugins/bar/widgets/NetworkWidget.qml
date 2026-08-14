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
    readonly property real rateThreshold: 1048576

    property string iconText: "󰈀"
    property string labelText: "net"
    property string tooltipText: ""
    property bool connected: false
    property real downloadRate: 0
    property real uploadRate: 0

    readonly property color dotIdleColor: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.28)
    readonly property color dotColor: {
        if (!connected)
            return dotIdleColor
        if (downloadRate > rateThreshold && uploadRate > rateThreshold)
            return downloadRate >= uploadRate ? "#a6e3a1" : Theme.urgent
        if (downloadRate > rateThreshold)
            return "#a6e3a1"
        if (uploadRate > rateThreshold)
            return Theme.urgent
        return dotIdleColor
    }

    implicitWidth: barRow.implicitWidth + Theme.barPaddingX * 2
    implicitHeight: Theme.barHeight

    function applyJson(line) {
        var raw = String(line || "").trim()
        if (!raw) return
        try {
            var json = JSON.parse(raw)
            iconText = String(json.icon || "󰤮")
            labelText = String(json.label || "off")
            tooltipText = String(json.tooltip || "").trim()
            connected = json.connected === true
            downloadRate = parseFloat(json.download_bps || "0")
            uploadRate = parseFloat(json.upload_bps || "0")
            if (!isFinite(downloadRate)) downloadRate = 0
            if (!isFinite(uploadRate)) uploadRate = 0
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

    Row {
        id: barRow
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: root.iconText
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.barFontPixelSize
            font.bold: Theme.fontBold
        }

        Rectangle {
            width: 5
            height: 5
            radius: 2.5
            color: root.dotColor
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.labelText
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.barFontPixelSize
            font.bold: Theme.fontBold
        }
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
        interval: Math.max(1, parseInt(root.settings.interval, 10) || 2) * 1000
        repeat: true
        onTriggered: root.poll()
    }

    function restartPolling() {
        intervalTimer.interval = Math.max(1, parseInt(settings.interval, 10) || 2) * 1000
        intervalTimer.stop()
        poll()
        intervalTimer.start()
    }

    onSettingsChanged: restartPolling()
    Component.onCompleted: restartPolling()
}
