import QtQuick
import Quickshell
import Quickshell.Io
import "../../commons"

Item {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var settings: ({})

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string networkScript: Util.evoshellScript(home, shell, "evo-bar-network-bar")
    readonly property string transmissionScript: Util.evoshellScript(home, shell, "evo-bar-transmission-bar")
    readonly property string hoverPanelId: settings.onHover ? String(settings.onHover) : "evo.panels.network.stats"
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
    readonly property int maxHistory: 36
    readonly property string trayIconText: "󰇚"

    property string labelText: "net"
    property bool networkConnected: false
    property bool transmissionConnected: false
    property bool transmissionError: false
    property real downloadRate: 0
    property real uploadRate: 0
    property real networkDownloadRate: 0
    property real networkUploadRate: 0
    property var downHistory: []
    property var upHistory: []
    property var lastTransmissionPayload: null

    readonly property bool connected: transmissionConnected
    readonly property int trafficPulseThresholdBps: 1048576 // 1 MiB/s
    readonly property bool trafficActive: networkDownloadRate >= trafficPulseThresholdBps
        || networkUploadRate >= trafficPulseThresholdBps
    readonly property bool attentionPulse: trafficActive

    implicitWidth: trayMode ? trayCellWidth : barRow.implicitWidth + Theme.barPaddingX * 2
    implicitHeight: Theme.barHeight
    width: trayMode && parent ? parent.width : implicitWidth
    height: Theme.barHeight

    function zeroHistory() {
        var out = []
        for (var i = 0; i < maxHistory; i++)
            out.push({ value: 0 })
        return out
    }

    function pushHistory(history, value) {
        var next = history.slice()
        next.push({ value: value })
        if (next.length > maxHistory)
            next = next.slice(next.length - maxHistory)
        return next
    }

    function applyThroughputCache(cached) {
        if (!cached || typeof cached !== "object")
            return
        if (cached.network_download_bps !== undefined)
            networkDownloadRate = parseFloat(cached.network_download_bps) || 0
        if (cached.network_upload_bps !== undefined)
            networkUploadRate = parseFloat(cached.network_upload_bps) || 0
        if (cached.download_bps !== undefined)
            downloadRate = parseFloat(cached.download_bps) || 0
        if (cached.upload_bps !== undefined)
            uploadRate = parseFloat(cached.upload_bps) || 0
        if (Array.isArray(cached.downHistory) && cached.downHistory.length > 0)
            downHistory = cached.downHistory.slice()
        if (Array.isArray(cached.upHistory) && cached.upHistory.length > 0)
            upHistory = cached.upHistory.slice()
        if (cached.transmission)
            applyTransmissionJson(cached.transmission, false)
    }

    function publishCache() {
        if (!shell || !hoverPanelId)
            return
        var existing = Util.hoverPanelCacheRead(shell, hoverPanelId)
        var next = {}
        if (existing && typeof existing === "object") {
            for (var k in existing)
                next[k] = existing[k]
        }
        next.network_download_bps = networkDownloadRate
        next.network_upload_bps = networkUploadRate
        next.download_bps = downloadRate
        next.upload_bps = uploadRate
        next.downHistory = downHistory
        next.upHistory = upHistory
        next.connected = networkConnected
        if (lastTransmissionPayload)
            next.transmission = lastTransmissionPayload
        Util.hoverPanelCacheWrite(shell, hoverPanelId, next)
    }

    function bootstrapFromCache() {
        if (!shell || !hoverPanelId)
            return
        applyThroughputCache(Util.hoverPanelCacheRead(shell, hoverPanelId))
    }

    function applyNetworkJson(line) {
        var raw = String(line || "").trim()
        if (!raw)
            return
        try {
            var json = JSON.parse(raw)
            labelText = String(json.label || "off")
            networkConnected = json.connected === true
            var down = parseFloat(json.download_bps || "0")
            var up = parseFloat(json.upload_bps || "0")
            if (!isFinite(down)) down = 0
            if (!isFinite(up)) up = 0
            networkDownloadRate = down
            networkUploadRate = up
            if (!lastTransmissionPayload) {
                downloadRate = down
                uploadRate = up
            }
            downHistory = pushHistory(downHistory, down)
            upHistory = pushHistory(upHistory, up)
            publishCache()
        } catch (e) {
            console.warn("network widget parse failed:", e)
        }
    }

    function applyTransmissionJson(json, publish) {
        if (!json || typeof json !== "object")
            return
        lastTransmissionPayload = json
        transmissionConnected = json.connected === true
        transmissionError = json.class === "error" || !transmissionConnected
        downloadRate = parseFloat(json.download_bps || 0) || 0
        uploadRate = parseFloat(json.upload_bps || 0) || 0
        if (publish !== false)
            publishCache()
    }

    function applyTransmissionLine(line) {
        var raw = String(line || "").trim()
        if (!raw) {
            lastTransmissionPayload = null
            transmissionError = true
            transmissionConnected = false
            publishCache()
            return
        }
        try {
            applyTransmissionJson(JSON.parse(raw), true)
        } catch (e) {
            transmissionError = true
            console.warn("transmission widget parse failed:", e)
        }
    }

    function pollNetwork() {
        if (!networkScript)
            return
        networkProc.command = ["bash", "-lc", networkScript]
        networkProc.running = false
        networkProc.running = true
    }

    function pollTransmission() {
        if (!transmissionScript)
            return
        transmissionProc.command = ["bash", "-lc", transmissionScript]
        transmissionProc.running = false
        transmissionProc.running = true
    }

    Row {
        id: barRow
        anchors.centerIn: parent
        spacing: 4

        Item {
            id: iconBox
            width: root.trayMode ? root.trayIconSize : netIcon.implicitWidth
            height: root.trayMode ? root.trayIconSize : netIcon.implicitHeight

            Text {
                id: netIcon
                anchors.centerIn: parent
                text: root.trayIconText
                opacity: root.attentionPulse
                    ? Theme.barIconPulseMax
                    : (root.connected ? Theme.barIconOpacity : Theme.barIconOpacityDim)
                font.family: Theme.fontFamily
                font.pixelSize: root.trayMode ? root.trayIconSize
                    : (root.iconOnly ? Theme.fontSize2xl : Theme.fontSizeM)
                font.bold: Theme.fontBold
                Behavior on color { ColorAnimation { duration: Theme.motionSlow } }

                BarIconPulse {
                    id: iconPulse
                    target: netIcon
                    running: root.attentionPulse
                }
            }
        }

        Text {
            visible: !root.iconOnly
            text: root.labelText
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeM
            font.bold: Theme.fontBold
        }
    }

    Process {
        id: networkProc
        property string stdoutText: ""
        property string stderrText: ""
        stdout: StdioCollector {
            onStreamFinished: networkProc.stdoutText = text
        }
        stderr: StdioCollector {
            onStreamFinished: networkProc.stderrText = text
        }
        onExited: {
            var raw = String(networkProc.stdoutText || "").trim()
            if (!raw) raw = String(networkProc.stderrText || "").trim()
            root.applyNetworkJson(raw)
        }
    }

    Process {
        id: transmissionProc
        property string stdoutText: ""
        stdout: StdioCollector {
            onStreamFinished: transmissionProc.stdoutText = text
        }
        onExited: root.applyTransmissionLine(transmissionProc.stdoutText)
    }

    HoverHandler {
        enabled: !root.trayMode && root.hoverPanelId !== "" && root.shell
        onHoveredChanged: root.setHoverPanel(hovered)
    }

    BarHoverPinArea {
        visible: !root.trayMode
        shell: root.shell
        popupId: root.hoverPanelId
    }

    Timer {
        id: networkTimer
        interval: Theme.pollNetworkSec * 1000
        repeat: true
        onTriggered: root.pollNetwork()
    }

    Timer {
        id: transmissionTimer
        interval: Math.max(2, parseInt(root.settings.transmissionInterval, 10) || 3) * 1000
        repeat: true
        onTriggered: root.pollTransmission()
    }

    function restartPolling() {
        networkTimer.interval = Theme.pollNetworkSec * 1000
        transmissionTimer.interval = Math.max(2, parseInt(settings.transmissionInterval, 10) || 3) * 1000
        networkTimer.stop()
        transmissionTimer.stop()
        pollNetwork()
        pollTransmission()
        networkTimer.start()
        transmissionTimer.start()
    }

    function setHoverPanel(active) {
        if (!shell || !hoverPanelId) return
        if (active)
            shell.hoverEnter(hoverPanelId, root, barPanel)
        else
            shell.hoverLeave(hoverPanelId)
    }

    function openTransmissionAdd() {
        Util.dismissHoverPanelFromBar(shell, hoverPanelId)
        if (shell) {
            shell.summon("evo.panels.network.transmission", "")
            return
        }
        if (settings.onClick) {
            Quickshell.execDetached(["bash", "-lc", String(settings.onClick)])
            return
        }
        Quickshell.execDetached(Util.evoshellIpcCommand(
            Quickshell.env("HOME") || "", shell,
            ["shell", "summon", "evo.panels.network.transmission", ""]))
    }

    function handleNetworkClick(mouse) {
        if (mouse.button === Qt.RightButton) {
            if (Util.pinHoverPanelFromBarIfActive(shell, hoverPanelId))
                return
            return
        }
        openTransmissionAdd()
    }

    MouseArea {
        id: trayMouseArea
        anchors.fill: parent
        visible: root.trayMode
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: root.setHoverPanel(containsMouse)
        onClicked: function(mouse) { root.handleNetworkClick(mouse) }
    }

    MouseArea {
        id: barMouseArea
        anchors.fill: parent
        visible: !root.trayMode
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) { root.handleNetworkClick(mouse) }
    }

    onSettingsChanged: restartPolling()
    onShellChanged: bootstrapFromCache()
    Component.onCompleted: {
        downHistory = zeroHistory()
        upHistory = zeroHistory()
        bootstrapFromCache()
        restartPolling()
    }
}
