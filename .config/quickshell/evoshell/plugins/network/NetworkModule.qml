import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPopupWidth: 0

    readonly property string cacheKey: "evo.network"

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/evo-network"
    readonly property bool active: host && host.opened === true
    readonly property int bodyFont: Theme.hoverPopupBodyFontPixelSize
    readonly property int hintFont: Theme.hoverPopupHintFontPixelSize
    readonly property int maxHistory: 36

    property var info: ({})
    property bool loading: true
    property bool hasTransferStats: false
    property bool hasPingStats: false
    property real prevRxBytes: 0
    property real prevTxBytes: 0
    property real prevSampleTime: 0
    property string prevIface: ""
    property real downloadRate: 0
    property real uploadRate: 0
    property var downHistory: []
    property var upHistory: []
    property var topDown: []
    property var topUp: []
    property bool processesLoading: false
    readonly property int maxProcessRows: 3

    implicitHeight: column.implicitHeight

    readonly property string connectionTitle: {
        if (!info.iface)
            return "Disconnected"
        var parts = [String(info.iface)]
        if (info.ip)
            parts.push(String(info.ip))
        return parts.join(" · ")
    }

    readonly property string linkDetail: {
        if (!info.speed)
            return info.gateway ? "Gateway " + info.gateway : ""
        var mbps = parseInt(info.speed, 10)
        if (isNaN(mbps) || mbps <= 0)
            return info.gateway ? "Gateway " + info.gateway : ""
        var label = mbps >= 1000
            ? (mbps / 1000).toFixed(mbps % 1000 === 0 ? 0 : 1) + " gbit"
            : mbps + " mbit"
        if (info.duplex)
            label += " " + info.duplex
        return label
    }

    readonly property string pingDetail: {
        if (!hasPingStats)
            return ""
        return "Gateway " + formatPing(root.info.router_ping_ms, true)
            + " · Internet " + formatPing(root.info.internet_ping_ms, true)
    }

    function onActivated() {
        if (!info || !info.iface)
            loading = true
        resetThroughput()
        refreshVerbose()
        refreshProcesses()
        pollTimer.start()
        processTimer.start()
    }

    function bootstrapFromCache() {
        if (!shell)
            return
        var cached = shell.hoverPopupDataFor(cacheKey)
        if (!cached || typeof cached !== "object" || !cached.iface)
            return
        info = cached
        loading = false
        if (cached.router_ping_ms !== undefined || cached.internet_ping_ms !== undefined)
            hasPingStats = true
    }

    function publishCache(data) {
        if (shell && data && typeof data === "object" && data.iface)
            shell.setHoverPopupData(cacheKey, data)
    }

    function onDeactivated() {
        pollTimer.stop()
        processTimer.stop()
        if (processesProc.running)
            processesProc.running = false
    }

    function zeroHistory() {
        var out = []
        for (var i = 0; i < maxHistory; i++)
            out.push({ value: 0 })
        return out
    }

    function resetThroughput() {
        prevRxBytes = 0
        prevTxBytes = 0
        prevSampleTime = 0
        prevIface = ""
        downloadRate = 0
        uploadRate = 0
        downHistory = zeroHistory()
        upHistory = zeroHistory()
        topDown = []
        topUp = []
        hasTransferStats = false
        hasPingStats = false
    }

    function parseVerbose(raw) {
        var out = {}
        var lines = String(raw || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (!line) continue
            var tab = line.indexOf("\t")
            if (tab < 1) continue
            out[line.substring(0, tab)] = line.substring(tab + 1)
        }
        return out
    }

    function formatRate(bytesPerSec) {
        var n = Number(bytesPerSec) || 0
        if (n < 1024) return Math.round(n) + " B/s"
        if (n < 1048576) return (n / 1024).toFixed(1) + " KB/s"
        if (n < 1073741824) return (n / 1048576).toFixed(1) + " MB/s"
        return (n / 1073741824).toFixed(2) + " GB/s"
    }

    function formatPing(ms, hasSamples) {
        if (!hasSamples) return "--"
        var v = parseFloat(ms)
        if (!isFinite(v) || v < 0) return "Timeout"
        if (v > 0 && v < 10) return v.toFixed(1) + " ms"
        return Math.round(v) + " ms"
    }

    function pushHistory(history, value) {
        var next = history.slice()
        next.push({ value: value })
        if (next.length > maxHistory)
            next = next.slice(next.length - maxHistory)
        return next
    }

    function padProcessRows(rows) {
        var out = []
        for (var i = 0; i < rows.length && i < maxProcessRows; i++)
            out.push(rows[i])
        while (out.length < maxProcessRows)
            out.push({ name: "—", rate: -1 })
        return out
    }

    readonly property var paddedTopDown: padProcessRows(topDown)
    readonly property var paddedTopUp: padProcessRows(topUp)

    function parseProcesses(raw) {
        var down = []
        var up = []
        var lines = String(raw || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (!line) continue
            var parts = line.split("\t")
            if (parts.length < 3) continue
            var entry = { name: parts[1], rate: parseFloat(parts[2]) || 0 }
            if (parts[0] === "proc_down") down.push(entry)
            else if (parts[0] === "proc_up") up.push(entry)
        }
        topDown = down.slice(0, maxProcessRows)
        topUp = up.slice(0, maxProcessRows)
    }

    function refreshProcesses() {
        if (!processesProc.running)
            processesProc.running = true
    }

    function applyVerbose(raw) {
        loading = false
        var next = parseVerbose(raw)
        info = next
        publishCache(next)

        var now = Date.now() / 1000
        var iface = String(next.iface || "")
        var rx = parseFloat(next.rx_bytes || "0")
        var tx = parseFloat(next.tx_bytes || "0")

        if (next.router_ping_ms !== undefined || next.internet_ping_ms !== undefined)
            hasPingStats = true

        if (next.rx_bytes !== undefined || next.tx_bytes !== undefined)
            hasTransferStats = true

        if (!iface || iface !== prevIface || prevSampleTime === 0) {
            prevIface = iface
            prevRxBytes = rx
            prevTxBytes = tx
            prevSampleTime = now
            downloadRate = 0
            uploadRate = 0
            return
        }

        var dt = now - prevSampleTime
        if (dt > 0) {
            downloadRate = Math.max(0, (rx - prevRxBytes) / dt)
            uploadRate = Math.max(0, (tx - prevTxBytes) / dt)
            downHistory = pushHistory(downHistory, downloadRate)
            upHistory = pushHistory(upHistory, uploadRate)
        }
        prevRxBytes = rx
        prevTxBytes = tx
        prevSampleTime = now
    }

    function refreshVerbose() {
        if (!verboseProc.running)
            verboseProc.running = true
    }

    Timer {
        id: pollTimer
        interval: 1500
        repeat: true
        running: false
        onTriggered: {
            if (root.active)
                root.refreshVerbose()
        }
    }

    Timer {
        id: processTimer
        interval: 3000
        repeat: true
        running: false
        onTriggered: {
            if (root.active)
                root.refreshProcesses()
        }
    }

    Process {
        id: processesProc
        command: ["bash", root.script, "processes"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.processesLoading = false
                root.parseProcesses(text)
            }
        }
        onRunningChanged: {
            if (processesProc.running)
                root.processesLoading = true
        }
        onExited: {
            root.processesLoading = false
        }
    }

    Process {
        id: verboseProc
        command: ["bash", root.script, "verbose"]
        stdout: StdioCollector {
            onStreamFinished: root.applyVerbose(text)
        }
        onExited: function(code) {
            if (code !== 0)
                root.loading = false
        }
    }

    Component.onCompleted: {
        downHistory = zeroHistory()
        upHistory = zeroHistory()
    }

    ColumnLayout {
        id: column
        width: root.hoverPopupWidth
        spacing: Theme.hoverPopupSectionSpacing

        SectionPanel {
            label: ""
            Layout.fillWidth: true
            sectionSpacing: 2

            Text {
                Layout.fillWidth: true
                text: root.connectionTitle
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.bodyFont + 1
                font.bold: Theme.fontBold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.loading ? "Loading…" : root.linkDetail
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFont
                opacity: 0.72
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.pingDetail !== ""
                text: root.pingDetail
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFont
                opacity: 0.55
                elide: Text.ElideRight
            }
        }

        SectionPanel {
            label: "Download"

            Text {
                    text: root.hasTransferStats ? root.formatRate(root.downloadRate) : "--"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: root.bodyFont
                    font.bold: Theme.fontBold
                }

                SparklineChart {
                    Layout.fillWidth: true
                    bars: root.downHistory
                    style: "line"
                    lineColor: Theme.accent
                    chartHeight: Theme.sparklineExpandedHeight
                }
        }

        SectionPanel {
            label: "Upload"

            Text {
                    text: root.hasTransferStats ? root.formatRate(root.uploadRate) : "--"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.bodyFont
                    font.bold: Theme.fontBold
                    opacity: 0.88
                }

                SparklineChart {
                    Layout.fillWidth: true
                    bars: root.upHistory
                    style: "line"
                    lineColor: Theme.foreground
                    chartHeight: Theme.sparklineExpandedHeight
                }
        }

        SectionPanel {
            label: "Top processes"

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 16
                rowSpacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "Download"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                        font.bold: Theme.fontBold
                        opacity: 0.8
                    }

                    Repeater {
                        model: root.paddedTopDown

                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.hintFont
                                elide: Text.ElideRight
                                opacity: modelData.rate < 0 ? 0.45 : 0.85
                            }

                            Text {
                                text: modelData.rate < 0 ? "—" : root.formatRate(modelData.rate)
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: root.hintFont
                                font.bold: Theme.fontBold
                                opacity: modelData.rate < 0 ? 0.45 : 1
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "Upload"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                        font.bold: Theme.fontBold
                        opacity: 0.8
                    }

                    Repeater {
                        model: root.paddedTopUp

                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.hintFont
                                elide: Text.ElideRight
                                opacity: modelData.rate < 0 ? 0.45 : 0.85
                            }

                            Text {
                                text: modelData.rate < 0 ? "—" : root.formatRate(modelData.rate)
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.hintFont
                                font.bold: Theme.fontBold
                                opacity: modelData.rate < 0 ? 0.45 : 0.88
                            }
                        }
                    }
                }
            }
        }
    }
}
