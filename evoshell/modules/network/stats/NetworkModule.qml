import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.commons
import qs.ui

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPanelWidth: 0

    readonly property string cacheKey: "evo.panels.network.stats"

    readonly property string script: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-bar-network")
    readonly property bool active: host && host.opened === true
    readonly property var barSource: shell ? shell.popupAnchorItem : null
    readonly property int bodyFont: Theme.fontSize3xl
    readonly property int hintFont: Theme.fontSizeL
    readonly property int statFont: Theme.fontSizeXl
    readonly property int throughputChartHeight: 120
    readonly property int maxHistory: 36

    property var info: ({})
    property bool loading: true
    readonly property bool contentReady: !loading
    property bool hasTransferStats: false
    property bool hasPingStats: false
    property real networkDownloadRate: 0
    property real networkUploadRate: 0
    property var downHistory: []
    property var upHistory: []
    property var topDown: []
    property var topUp: []
    property var lastDownloadProcess: null
    property bool processesLoading: false
    readonly property int maxProcessRows: 1

    readonly property var topDownloadProcess: root.topDown.length > 0 ? root.topDown[0] : null

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

    readonly property bool isWifi: String(info.type || "") === "wifi"
    readonly property string heroMeta: {
        if (root.loading && !info.iface)
            return "Loading…"
        if (!info.iface)
            return "Offline"
        var kind = info.type ? String(info.type) : "connected"
        return info.gateway ? kind + " · gateway " + info.gateway : kind
    }

    readonly property string internetPing: {
        if (root.loading && !info.iface)
            return "…"
        if (!info.iface)
            return "—"
        return root.formatPing(root.info.internet_ping_ms, root.hasPingStats)
    }

    readonly property var networkStats: {
        var down = { label: "download", value: root.hasTransferStats ? root.formatRate(root.networkDownloadRate) : "--", color: Theme.ansiFallback("green") }
        var up = { label: "upload", value: root.hasTransferStats ? root.formatRate(root.networkUploadRate) : "--", color: Theme.urgent }
        if (root.loading) {
            return [
                { label: "Interface", value: "…" },
                { label: "IP", value: "…" },
                { label: "Link", value: "…" },
                { label: "Gateway", value: "…" },
                down,
                up
            ]
        }
        if (!info.iface) {
            return [
                { label: "Interface", value: "Offline" },
                { label: "IP", value: "—" },
                { label: "Link", value: "—" },
                { label: "Gateway", value: "—" },
                down,
                up
            ]
        }
        return [
            { label: "Interface", value: String(info.iface) },
            { label: "IP", value: info.ip ? String(info.ip) : "—" },
            { label: "Link", value: root.linkSpeedLabel },
            { label: "Gateway", value: root.formatPing(root.info.router_ping_ms, root.hasPingStats) },
            down,
            up
        ]
    }

    function onActivated() {
        syncFromBar()
        if (!info || !info.iface)
            loading = true
        refreshVerbose()
        refreshProcesses()
        pollTimer.start()
        processTimer.start()
    }

    function applyThroughputCache(data) {
        if (!data || typeof data !== "object")
            return
        if (data.network_download_bps !== undefined || data.network_upload_bps !== undefined) {
            networkDownloadRate = parseFloat(data.network_download_bps) || 0
            networkUploadRate = parseFloat(data.network_upload_bps) || 0
            hasTransferStats = data.connected === true || !!info.iface
        } else if (data.download_bps !== undefined || data.upload_bps !== undefined) {
            networkDownloadRate = parseFloat(data.download_bps) || 0
            networkUploadRate = parseFloat(data.upload_bps) || 0
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
            networkDownloadRate = item.networkDownloadRate || 0
            networkUploadRate = item.networkUploadRate || 0
            hasTransferStats = item.networkConnected === true
            return
        }
        if (shell)
            applyThroughputCache(Util.hoverPanelCacheRead(shell, cacheKey))
    }

    function bootstrapFromCache() {
        if (!shell)
            return
        var cached = Util.hoverPanelCacheRead(shell, cacheKey)
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
            data.network_download_bps = bar.networkDownloadRate
            data.network_upload_bps = bar.networkUploadRate
            data.downHistory = bar.downHistory
            data.upHistory = bar.upHistory
            data.connected = bar.networkConnected
        } else {
            var existing = Util.hoverPanelCacheRead(shell, cacheKey)
            if (existing && typeof existing === "object") {
                if (existing.downHistory)
                    data.downHistory = existing.downHistory
                if (existing.upHistory)
                    data.upHistory = existing.upHistory
                if (existing.network_download_bps !== undefined)
                    data.network_download_bps = existing.network_download_bps
                if (existing.network_upload_bps !== undefined)
                    data.network_upload_bps = existing.network_upload_bps
                if (existing.connected !== undefined)
                    data.connected = existing.connected
            }
        }
        Util.hoverPanelCacheWrite(shell, cacheKey, data)
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
        if (down.length > 0)
            lastDownloadProcess = { name: down[0].name, rate: down[0].rate }
        else if (lastDownloadProcess)
            topDown = [{ name: lastDownloadProcess.name, rate: 0 }]
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

    readonly property real barNetworkDownloadRate: root.barSource ? (root.barSource.networkDownloadRate || 0) : 0
    readonly property real barNetworkUploadRate: root.barSource ? (root.barSource.networkUploadRate || 0) : 0
    readonly property var barDownHistory: root.barSource ? root.barSource.downHistory : null
    readonly property var barUpHistory: root.barSource ? root.barSource.upHistory : null

    function syncFromBarRates() {
        if (root.active)
            root.syncFromBar()
    }

    onBarNetworkDownloadRateChanged: syncFromBarRates()
    onBarNetworkUploadRateChanged: syncFromBarRates()
    onBarDownHistoryChanged: syncFromBarRates()
    onBarUpHistoryChanged: syncFromBarRates()

    ColumnLayout {
        id: column
        width: root.hoverPanelWidth
        spacing: Theme.hoverPanelSectionSpacing

        PanelHero {
            Layout.fillWidth: true
            title: "Network"
            meta: root.heroMeta
            foreground: Theme.foreground
            fontFamily: Theme.fontFamily
            iconOpacity: root.info.iface ? 1 : 0.5

            iconComponent: Component {
                Text {
                    textFormat: Text.PlainText
                    text: root.isWifi ? "󰖩" : "󰈀"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.font.display
                    opacity: 0.92
                }
            }

            trailingControl: Component {
                PingBadge {
                    value: root.internetPing
                    fillColor: root.internetPing === "Timeout" ? Theme.urgent : Theme.accent
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            visible: !root.loading || !!(root.info && root.info.iface)
            columns: 3
            columnSpacing: 8
            rowSpacing: Theme.hoverPanelSectionSpacing

            Repeater {
                model: root.networkStats

                HoverPanelStatBox {
                    required property var modelData
                    value: String(modelData.value)
                    label: modelData.label
                    valueColor: modelData.color || Theme.accent
                    valueFontSize: Theme.fontSizeXl
                    boxHeight: Theme.font.heading + Theme.space(56)
                }
            }
        }

        SectionPanel {
            label: ""
            Layout.fillWidth: true

            HoverPanelLabelPill {
                text: "Speeds"
                icon: "󰁅"
                fontSize: Theme.font.caption
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingM

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.throughputChartHeight
                    Layout.minimumHeight: root.throughputChartHeight

                    SparklineChart {
                        anchors.fill: parent
                        bars: root.downHistory
                        secondaryBars: root.upHistory
                        style: "line"
                        lineColor: Theme.ansiFallback("green")
                        secondaryLineColor: Theme.urgent
                        chartHeight: height
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.hintFont + 6
                    Layout.minimumHeight: root.hintFont + 6

                    RowLayout {
                        anchors.fill: parent
                        spacing: Theme.spacingM

                        Text {
                            Layout.fillWidth: true
                            text: root.lastDownloadProcess
                                ? root.lastDownloadProcess.name
                                : (root.processesLoading ? "…" : "—")
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                            opacity: root.lastDownloadProcess ? 0.85 : 0.45
                        }

                        Text {
                            text: root.topDownloadProcess
                                ? root.formatRate(root.topDownloadProcess.rate)
                                : (root.processesLoading ? "…" : "—")
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            font.bold: Theme.fontBold
                            verticalAlignment: Text.AlignVCenter
                            opacity: root.topDownloadProcess && root.topDownloadProcess.rate > 0 ? 1 : 0.45
                        }
                    }
                }
            }
        }
    }

    component PingBadge: Rectangle {
        property string value: ""
        property color fillColor: Theme.accent

        implicitWidth: pingText.implicitWidth + Theme.spacing.lg * 2
        implicitHeight: pingText.implicitHeight + Theme.spacing.sm * 2
        radius: implicitHeight / 2
        color: Qt.rgba(fillColor.r, fillColor.g, fillColor.b, 0.14)

        Text {
            id: pingText
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: parent.value
            color: parent.fillColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.font.displayLarge
            font.bold: true
        }
    }
}
