import QtQuick
import Quickshell
import Quickshell.Io
import "../../Commons"

Item {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var settings: ({})

    readonly property string hoverPopupId: settings.onHover
        ? String(settings.onHover)
        : (trayMode ? "evo.bar.network.transmission" : "")
    readonly property bool trayMode: settings.trayMode === true
    readonly property int trayIconSize: {
        var n = parseInt(settings.trayIconSize, 10)
        return isNaN(n) || n <= 0 ? 18 : n
    }
    readonly property int trayCellWidth: {
        var n = parseInt(settings.trayCellWidth, 10)
        return isNaN(n) || n <= 0 ? trayIconSize + 4 : n
    }

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string script: home + "/.local/bin/evo-bar-transmission-bar"
    readonly property string trayIconText: "󰇚"

    property bool loading: false
    property bool connected: false
    property bool isError: false
    property string statusText: ""
    property string labelText: "0"
    property real downloadRate: 0
    property real uploadRate: 0
    property int activeCount: 0
    property int downloadingCount: 0
    property var lastPayload: null

    readonly property bool trafficActive: connected && (downloadRate > 0 || uploadRate > 0)
    readonly property color iconColor: {
        if (isError || !connected)
            return Theme.urgent
        if (downloadRate > 0)
            return "#a6e3a1"
        if (uploadRate > 0)
            return Theme.accent
        return Theme.foreground
    }

    implicitWidth: trayMode ? trayCellWidth : contentRow.implicitWidth + Theme.barPaddingX * 2
    implicitHeight: Theme.barHeight
    width: trayMode && parent ? parent.width : implicitWidth
    height: Theme.barHeight

    function applyJson(line) {
        loading = false
        var raw = String(line || "").trim()
        if (!raw) {
            lastPayload = null
            return
        }
        try {
            var json = JSON.parse(raw)
            lastPayload = json
            if (root.shell && root.hoverPopupId)
                Util.hoverPopupCacheWrite(root.shell, root.hoverPopupId, json)

            connected = json.connected === true
            isError = json.class === "error" || !connected
            statusText = String(json.tooltip || "")
            labelText = String(json.label || "0")
            downloadRate = parseFloat(json.download_bps || 0) || 0
            uploadRate = parseFloat(json.upload_bps || 0) || 0
            activeCount = parseInt(json.active, 10) || 0
            downloadingCount = parseInt(json.downloading, 10) || 0
        } catch (e) {
            isError = true
            connected = false
            console.warn("transmission widget parse failed:", e)
        }
    }

    function poll() {
        if (!script) return
        proc.command = ["bash", "-lc", script]
        proc.running = false
        proc.running = true
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 4

        Text {
            id: trayIcon
            text: root.trayIconText
            color: root.iconColor
            opacity: root.connected ? (root.trafficActive ? iconPulse.opacity : 1) : 0.45
            font.family: Theme.fontFamily
            font.pixelSize: root.trayMode ? root.trayIconSize : Theme.fontSizeM
            font.bold: Theme.fontBold
            Behavior on color { ColorAnimation { duration: 220 } }

            SequentialAnimation {
                id: iconPulse
                running: root.trafficActive
                loops: Animation.Infinite
                NumberAnimation {
                    target: trayIcon
                    property: "opacity"
                    from: 0.55
                    to: 1
                    duration: 700
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: trayIcon
                    property: "opacity"
                    from: 1
                    to: 0.55
                    duration: 700
                    easing.type: Easing.InOutSine
                }
            }
        }

        Text {
            visible: !root.trayMode && root.labelText !== "0"
            text: root.labelText
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeM
            font.bold: Theme.fontBold
        }
    }

    Process {
        id: proc
        property string stdoutText: ""
        stdout: StdioCollector {
            onStreamFinished: proc.stdoutText = text
        }
        onExited: root.applyJson(proc.stdoutText)
    }

    MouseArea {
        id: trayMouseArea
        anchors.fill: parent
        visible: root.trayMode
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onContainsMouseChanged: root.setHoverPopup(containsMouse)
        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton && root.shell) {
                root.shell.popupAnchorItem = root
                root.shell.popupAnchorWindow = root.barPanel
                root.shell.summon("evo.bar.network.stats", '{"transmissionAdd":true}')
                root.shell.pinHoverPopup("evo.bar.network.stats")
                return
            }
            if (mouse.button === Qt.RightButton) {
                if (Util.pinHoverPopupFromBarIfActive(root.shell, root.hoverPopupId))
                    return
                var dir = root.home + "/downloads"
                Quickshell.execDetached(["xdg-open", dir])
            }
        }
    }

    HoverHandler {
        enabled: !root.trayMode && root.hoverPopupId !== "" && root.shell
        onHoveredChanged: root.setHoverPopup(hovered)
    }

    BarHoverPinArea {
        visible: !root.trayMode
        shell: root.shell
        popupId: root.hoverPopupId
    }

    Timer {
        id: intervalTimer
        interval: Math.max(2, parseInt(root.settings.interval, 10) || 3) * 1000
        repeat: true
        onTriggered: root.poll()
    }

    function bootstrapFromCache() {
        if (!shell || !hoverPopupId)
            return false
        var cached = Util.hoverPopupCacheRead(shell, hoverPopupId)
        if (!cached)
            return false
        try {
            lastPayload = cached
            connected = cached.connected === true
            isError = cached.class === "error" || !connected
            statusText = String(cached.tooltip || "")
            labelText = String(cached.label || "0")
            downloadRate = parseFloat(cached.download_bps || 0) || 0
            uploadRate = parseFloat(cached.upload_bps || 0) || 0
            activeCount = parseInt(cached.active, 10) || 0
            downloadingCount = parseInt(cached.downloading, 10) || 0
            loading = false
            return true
        } catch (e) {
            return false
        }
    }

    function restartPolling() {
        intervalTimer.interval = Math.max(2, parseInt(settings.interval, 10) || 3) * 1000
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
    onShellChanged: bootstrapFromCache()
    Component.onCompleted: {
        bootstrapFromCache()
        restartPolling()
    }
}
