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
    property var torrents: []
    property real lastRxBytes: -1
    property real lastTxBytes: -1
    property real lastByteSampleMs: 0

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

    readonly property string heroThroughput: root.hasTransferStats
        ? root.formatRate(root.networkDownloadRate + root.networkUploadRate)
        : "--"

    readonly property var networkStats: {
        var downParts = root.hasTransferStats ? root.rateParts(root.networkDownloadRate) : { value: "--", unit: "" }
        var upParts = root.hasTransferStats ? root.rateParts(root.networkUploadRate) : { value: "--", unit: "" }
        var ping = root.pingParts(root.info.router_ping_ms, root.hasPingStats)
        var down = { label: "download", value: downParts.value, unit: downParts.unit, kpi: true, color: Theme.ansiFallback("green") }
        var up = { label: "upload", value: upParts.value, unit: upParts.unit, kpi: true, color: Theme.urgent }
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
            { label: "Gateway", value: ping.value, unit: ping.unit, kpi: true },
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
        refreshTransfers()
        pollTimer.start()
        processTimer.start()
    }

    function historyHasSignal(series) {
        if (!Array.isArray(series))
            return false
        for (var i = 0; i < series.length; i++) {
            var value = parseFloat(series[i] && series[i].value)
            if (isFinite(value) && value > 0)
                return true
        }
        return false
    }

    function applyThroughputCache(data) {
        if (!data || typeof data !== "object")
            return
        var downRate = NaN
        var upRate = NaN
        if (data.network_download_bps !== undefined || data.network_upload_bps !== undefined) {
            downRate = parseFloat(data.network_download_bps)
            upRate = parseFloat(data.network_upload_bps)
        } else if (data.download_bps !== undefined || data.upload_bps !== undefined) {
            downRate = parseFloat(data.download_bps)
            upRate = parseFloat(data.upload_bps)
        }
        if ((isFinite(downRate) && downRate > 0) || (isFinite(upRate) && upRate > 0)) {
            networkDownloadRate = isFinite(downRate) ? downRate : 0
            networkUploadRate = isFinite(upRate) ? upRate : 0
            hasTransferStats = true
        }
        if (historyHasSignal(data.downHistory))
            downHistory = data.downHistory.slice()
        if (historyHasSignal(data.upHistory))
            upHistory = data.upHistory.slice()
    }

    function syncFromBar() {
        if (lastByteSampleMs > 0)
            return
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
        if (hasTransferStats && lastByteSampleMs > 0) {
            data.network_download_bps = networkDownloadRate
            data.network_upload_bps = networkUploadRate
            data.downHistory = downHistory
            data.upHistory = upHistory
            data.connected = true
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
        if (transfersProc.running)
            transfersProc.running = false
        lastRxBytes = -1
        lastTxBytes = -1
        lastByteSampleMs = 0
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

    function rateParts(bytesPerSec) {
        var n = Number(bytesPerSec) || 0
        if (n < 1024) return { value: String(Math.round(n)), unit: "B/s" }
        if (n < 1048576) {
            var kb = Math.round(n / 1024)
            if (kb >= 1024)
                return { value: (n / 1048576).toFixed(1), unit: "MB/s" }
            return { value: String(kb), unit: "KB/s" }
        }
        if (n < 1073741824) return { value: (n / 1048576).toFixed(1), unit: "MB/s" }
        return { value: (n / 1073741824).toFixed(2), unit: "GB/s" }
    }

    function formatRate(bytesPerSec) {
        var parts = root.rateParts(bytesPerSec)
        if (!parts.unit)
            return parts.value
        return parts.value + " " + parts.unit
    }

    function pingParts(ms, hasSamples) {
        if (!hasSamples) return { value: "--", unit: "" }
        var v = parseFloat(ms)
        if (!isFinite(v) || v < 0) return { value: "Timeout", unit: "" }
        if (v > 0 && v < 10) return { value: v.toFixed(1), unit: "ms" }
        return { value: String(Math.round(v)), unit: "ms" }
    }

    function appendHistory(series, value) {
        var next = []
        var src = series || []
        var start = src.length >= maxHistory ? src.length - maxHistory + 1 : 0
        for (var i = start; i < src.length; i++)
            next.push(src[i])
        next.push({ value: value })
        return next
    }

    function noteThroughput(next) {
        var rx = parseFloat(next && next.rx_bytes)
        var tx = parseFloat(next && next.tx_bytes)
        var now = Date.now()
        if (!isFinite(rx) || !isFinite(tx))
            return
        if (lastRxBytes >= 0 && lastTxBytes >= 0 && lastByteSampleMs > 0 && now > lastByteSampleMs) {
            var dt = (now - lastByteSampleMs) / 1000
            if (dt >= 0.4 && dt <= 20 && rx >= lastRxBytes && tx >= lastTxBytes) {
                var down = (rx - lastRxBytes) / dt
                var up = (tx - lastTxBytes) / dt
                networkDownloadRate = down
                networkUploadRate = up
                hasTransferStats = true
                downHistory = appendHistory(downHistory, down)
                upHistory = appendHistory(upHistory, up)
            }
        }
        lastRxBytes = rx
        lastTxBytes = tx
        lastByteSampleMs = now
    }

    function formatPercent(value) {
        var n = Number(value)
        if (!isFinite(n) || n < 0)
            return ""
        if (n > 100)
            n = 100
        var rounded = Math.round(n * 10) / 10
        var text = Math.abs(rounded - Math.round(rounded)) < 0.05
            ? String(Math.round(rounded))
            : rounded.toFixed(1)
        return text + "%"
    }

    function formatEta(seconds) {
        var s = Number(seconds)
        if (!isFinite(s) || s < 0)
            return ""
        s = Math.round(s)
        if (s < 60)
            return s + "s"
        if (s < 3600)
            return Math.round(s / 60) + " min"
        var hours = Math.floor(s / 3600)
        var mins = Math.round((s % 3600) / 60)
        if (mins === 60) {
            hours += 1
            mins = 0
        }
        if (mins === 0)
            return hours + "h"
        return hours + "h " + mins + "m"
    }

    function torrentMeta(entry) {
        if (!entry)
            return ""
        if (entry.status === 3)
            return "Queued"
        var pct = formatPercent(entry.percent)
        var eta = formatEta(entry.eta)
        if (pct && eta)
            return pct + " · " + eta
        return pct || eta
    }

    function parseTransfers(raw) {
        var lines = String(raw || "").split("\n")
        var ok = false
        var list = []
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (!line)
                continue
            if (line === "transfers_ok") {
                ok = true
                continue
            }
            var parts = line.split("\t")
            if (parts[0] !== "torrent" || parts.length < 5)
                continue
            list.push({
                name: parts[1] || "download",
                percent: parseFloat(parts[2]) || 0,
                down: parseFloat(parts[3]) || 0,
                up: parseFloat(parts[4]) || 0,
                eta: parts.length > 5 ? parseFloat(parts[5]) : -1,
                status: parts.length > 6 ? (parseInt(parts[6], 10) || 0) : 0
            })
        }
        if (!ok)
            return
        torrents = list.slice(0, 6)
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

    function refreshTransfers() {
        if (!transfersProc.running)
            transfersProc.running = true
    }

    function applyVerbose(raw) {
        var text = String(raw || "")
        if (!text.trim())
            return
        loading = false
        var next = parseVerbose(text)
        info = next

        if (next.router_ping_ms !== undefined || next.internet_ping_ms !== undefined)
            hasPingStats = true

        if (!next.iface) {
            hasTransferStats = false
            lastRxBytes = -1
            lastTxBytes = -1
            lastByteSampleMs = 0
            return
        }

        noteThroughput(next)
        publishCache(next)
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
            if (!root.active)
                return
            root.refreshVerbose()
            root.refreshTransfers()
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
            waitForEnd: true
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
        id: transfersProc
        command: ["bash", root.script, "transfers"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseTransfers(text)
        }
    }

    Process {
        id: verboseProc
        command: ["bash", root.script, "verbose"]
        stdout: StdioCollector {
            waitForEnd: true
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
                ThroughputBadge {
                    text: root.heroThroughput
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
                    unit: modelData.unit ? String(modelData.unit) : ""
                    label: modelData.label
                    valueColor: modelData.color || Theme.accent
                    valueFontSize: modelData.kpi ? Theme.font.display : Theme.fontSizeXl
                    unitFontSize: Theme.font.body
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

                Repeater {
                    model: root.torrents

                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                            opacity: 0.9
                        }

                        Text {
                            text: root.torrentMeta(modelData)
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            verticalAlignment: Text.AlignVCenter
                            opacity: 0.55
                            visible: text !== ""
                        }

                        Text {
                            text: root.formatRate(modelData.down)
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            font.bold: Theme.fontBold
                            verticalAlignment: Text.AlignVCenter
                            opacity: modelData.down > 0 ? 1 : 0.45
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.hintFont + 6
                    Layout.minimumHeight: root.hintFont + 6
                    visible: root.torrents.length === 0

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

    component ThroughputBadge: Rectangle {
        id: badge

        property string text: "--"

        implicitWidth: rateText.implicitWidth + Theme.spacing.lg * 2
        implicitHeight: rateText.implicitHeight + Theme.spacing.sm * 2
        radius: implicitHeight / 2
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)

        Text {
            id: rateText
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: badge.text
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.font.heading
            font.bold: true
        }
    }
}
