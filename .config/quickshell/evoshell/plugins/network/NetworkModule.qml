import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../transmission"

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPopupWidth: 0

    readonly property string cacheKey: "evo.network"

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/evo-network"
    readonly property bool active: host && host.opened === true
    readonly property var barSource: shell ? shell.popupAnchorItem : null
    readonly property int bodyFont: Theme.fontSize3xl
    readonly property int hintFont: Theme.fontSizeL
    readonly property int statFont: Theme.fontSizeXl
    readonly property int maxHistory: 36

    property var info: ({})
    property bool loading: true
    property bool hasTransferStats: false
    property bool hasPingStats: false
    property real downloadRate: 0
    property real uploadRate: 0
    property var downHistory: []
    property var upHistory: []
    property var topDown: []
    property var topUp: []
    property bool processesLoading: false
    readonly property int maxProcessRows: 3

    implicitHeight: column.implicitHeight

    readonly property string linkSpeedLabel: {
        if (!info.speed)
            return "—"
        var mbps = parseInt(info.speed, 10)
        if (isNaN(mbps) || mbps <= 0)
            return "—"
        var label = mbps >= 1000
            ? (mbps / 1000).toFixed(mbps % 1000 === 0 ? 0 : 1) + " gbit"
            : mbps + " mbit"
        if (info.duplex)
            label += " " + info.duplex
        return label
    }

    readonly property var networkStatRow1: {
        if (root.loading) {
            return [
                { label: "Link", value: "…" },
                { label: "Gateway", value: "…" },
                { label: "Internet", value: "…" }
            ]
        }
        if (!info.iface) {
            return [
                { label: "Link", value: "—" },
                { label: "Gateway", value: "—" },
                { label: "Internet", value: "—" }
            ]
        }
        return [
            { label: "Link", value: root.linkSpeedLabel },
            { label: "Gateway", value: root.formatPing(root.info.router_ping_ms, root.hasPingStats) },
            { label: "Internet", value: root.formatPing(root.info.internet_ping_ms, root.hasPingStats) }
        ]
    }

    readonly property var networkStatRow2: {
        if (root.loading) {
            return [
                { label: "Interface", value: "…" },
                { label: "IP", value: "…" }
            ]
        }
        if (!info.iface) {
            return [
                { label: "Interface", value: "Offline" },
                { label: "IP", value: "—" }
            ]
        }
        return [
            { label: "Interface", value: String(info.iface) },
            { label: "IP", value: info.ip ? String(info.ip) : "—" }
        ]
    }

    function onActivated() {
        if (!info || !info.iface)
            loading = true
        syncFromBar()
        refreshVerbose()
        refreshProcesses()
        pollTimer.start()
        processTimer.start()
    }

    function applyThroughputCache(data) {
        if (!data || typeof data !== "object")
            return
        if (data.download_bps !== undefined || data.upload_bps !== undefined) {
            downloadRate = parseFloat(data.download_bps) || 0
            uploadRate = parseFloat(data.upload_bps) || 0
            hasTransferStats = data.connected === true || !!info.iface
        }
        if (Array.isArray(data.downHistory) && data.downHistory.length > 0)
            downHistory = data.downHistory.slice()
        if (Array.isArray(data.upHistory) && data.upHistory.length > 0)
            upHistory = data.upHistory.slice()
    }

    function syncFromBar() {
        var item = barSource
        if (item && Array.isArray(item.downHistory) && item.downHistory.length > 0) {
            downHistory = item.downHistory.slice()
            upHistory = item.upHistory.slice()
            downloadRate = item.downloadRate || 0
            uploadRate = item.uploadRate || 0
            hasTransferStats = item.connected === true
            return
        }
        if (shell)
            applyThroughputCache(shell.hoverPopupDataFor(cacheKey))
    }

    function bootstrapFromCache() {
        if (!shell)
            return
        var cached = shell.hoverPopupDataFor(cacheKey)
        if (!cached || typeof cached !== "object")
            return
        if (cached.iface) {
            info = cached
            loading = false
            if (cached.router_ping_ms !== undefined || cached.internet_ping_ms !== undefined)
                hasPingStats = true
        }
        applyThroughputCache(cached)
    }

    function publishCache(data) {
        if (!shell || !data || typeof data !== "object" || !data.iface)
            return
        var bar = barSource
        if (bar) {
            data.download_bps = bar.downloadRate
            data.upload_bps = bar.uploadRate
            data.downHistory = bar.downHistory
            data.upHistory = bar.upHistory
            data.connected = bar.connected
        } else {
            var existing = shell.hoverPopupDataFor(cacheKey)
            if (existing && typeof existing === "object") {
                if (existing.downHistory)
                    data.downHistory = existing.downHistory
                if (existing.upHistory)
                    data.upHistory = existing.upHistory
                if (existing.download_bps !== undefined)
                    data.download_bps = existing.download_bps
                if (existing.upload_bps !== undefined)
                    data.upload_bps = existing.upload_bps
                if (existing.connected !== undefined)
                    data.connected = existing.connected
            }
        }
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

        if (next.router_ping_ms !== undefined || next.internet_ping_ms !== undefined)
            hasPingStats = true

        if (next.iface)
            hasTransferStats = true

        syncFromBar()
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
        bootstrapFromCache()
    }

    Connections {
        target: root.barSource
        enabled: root.barSource !== null
        function onDownloadRateChanged() {
            if (root.active)
                root.syncFromBar()
        }
        function onUploadRateChanged() {
            if (root.active)
                root.syncFromBar()
        }
        function onDownHistoryChanged() {
            if (root.active)
                root.syncFromBar()
        }
        function onUpHistoryChanged() {
            if (root.active)
                root.syncFromBar()
        }
    }

    ColumnLayout {
        id: column
        width: root.hoverPopupWidth
        spacing: Theme.hoverPopupSectionSpacing

        SectionPanel {
            label: ""
            Layout.fillWidth: true
            visible: !root.loading || root.info.iface

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 8

                    Repeater {
                        model: root.networkStatRow1

                        SectionPanel {
                            required property var modelData
                            Layout.fillWidth: true
                            label: ""
                            filled: true
                            contentPad: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: String(modelData.value)
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXl
                                    font.bold: Theme.fontBold
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData.label
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.hintFont
                                    opacity: 0.55
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 8

                    Repeater {
                        model: root.networkStatRow2

                        SectionPanel {
                            required property var modelData
                            Layout.fillWidth: true
                            label: ""
                            filled: true
                            contentPad: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: String(modelData.value)
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXl
                                    font.bold: Theme.fontBold
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData.label
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.hintFont
                                    opacity: 0.55
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
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

        SectionPanel {
            label: "Transmission"
            Layout.fillWidth: true

            TransmissionPanel {
                Layout.fillWidth: true
                active: root.active
                shell: root.shell
                barSource: root.barSource
            }
        }
    }
}
