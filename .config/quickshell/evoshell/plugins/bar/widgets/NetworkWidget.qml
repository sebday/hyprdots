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
    readonly property string script: home + "/.local/bin/evo-network bar"
    readonly property string hoverPopupId: settings.onHover ? String(settings.onHover) : "evo.network"
    readonly property bool iconOnly: settings.iconOnly !== false
    readonly property bool trayMode: settings.trayMode === true
    readonly property int trayIconSize: {
        var n = parseInt(settings.trayIconSize, 10)
        return isNaN(n) || n <= 0 ? 18 : n
    }
    readonly property int trayCellWidth: {
        var n = parseInt(settings.trayCellWidth, 10)
        return isNaN(n) || n <= 0 ? trayIconSize + 4 : n
    }
    readonly property real rateThreshold: 1048576

    property string iconText: "󰈀"
    property string labelText: "net"
    property bool connected: false
    property real downloadRate: 0
    property real uploadRate: 0

    readonly property color gapIdleColor: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.2)
    readonly property color gapColor: {
        if (!connected)
            return "transparent"
        if (downloadRate > rateThreshold && uploadRate > rateThreshold)
            return downloadRate >= uploadRate ? "#a6e3a1" : Theme.urgent
        if (downloadRate > rateThreshold)
            return "#a6e3a1"
        if (uploadRate > rateThreshold)
            return Theme.urgent
        return gapIdleColor
    }
    readonly property bool showGap: connected

    implicitWidth: trayMode ? trayCellWidth : barRow.implicitWidth + Theme.barPaddingX * 2
    implicitHeight: Theme.barHeight
    width: trayMode && parent ? parent.width : implicitWidth
    height: Theme.barHeight

    function applyJson(line) {
        var raw = String(line || "").trim()
        if (!raw) return
        try {
            var json = JSON.parse(raw)
            iconText = String(json.icon || "󰤮")
            labelText = String(json.label || "off")
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

        Item {
            width: netIcon.implicitWidth
            height: netIcon.implicitHeight

            Rectangle {
                anchors.centerIn: parent
                width: Math.max(4, Math.round(root.trayIconSize * 0.28))
                height: width
                radius: width / 2
                color: root.gapColor
                visible: root.showGap
            }

            Text {
                id: netIcon
                anchors.centerIn: parent
                text: root.iconText
                color: Theme.foreground
                opacity: root.connected ? 1 : 0.4
                font.family: Theme.fontFamily
                font.pixelSize: root.trayMode ? root.trayIconSize
                    : (root.iconOnly ? Theme.panelIconFontPixelSize : Theme.barFontPixelSize)
                font.bold: Theme.fontBold
            }
        }

        Text {
            visible: !root.iconOnly
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

    MouseArea {
        anchors.fill: parent
        visible: root.trayMode
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onContainsMouseChanged: root.setHoverPopup(containsMouse)
    }

    HoverHandler {
        enabled: !root.trayMode && root.hoverPopupId !== "" && root.shell
        onHoveredChanged: root.setHoverPopup(hovered)
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

    function setHoverPopup(active) {
        if (!shell || !hoverPopupId) return
        if (active)
            shell.hoverEnter(hoverPopupId, root, barPanel)
        else
            shell.hoverLeave(hoverPopupId)
    }

    onSettingsChanged: restartPolling()
    Component.onCompleted: restartPolling()
}
