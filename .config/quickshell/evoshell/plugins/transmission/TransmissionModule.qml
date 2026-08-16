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

    readonly property string cacheKey: shell ? String(shell.hoverPopupId || "") : ""
    readonly property string script: Quickshell.env("HOME") + "/.local/bin/evo-transmission popup"
    readonly property bool active: host && host.opened === true
    readonly property var barSource: host && host.shell ? host.shell.popupAnchorItem : null
    readonly property int bodyFont: Theme.hoverPopupBodyFontPixelSize
    readonly property int hintFont: Theme.hoverPopupHintFontPixelSize
    readonly property int titleFont: Theme.hoverPopupLabelFontPixelSize
    readonly property int statFont: Theme.hoverPopupLabelFontPixelSize
    readonly property string transmissionBin: Quickshell.env("HOME") + "/.local/bin/evo-transmission"

    property bool loading: true
    property bool connected: false
    property string errorText: ""
    property real downloadRate: 0
    property real uploadRate: 0
    property int activeCount: 0
    property int downloadingCount: 0
    property var torrents: []

    implicitHeight: column.implicitHeight

    function onActivated() {
        loading = !hasDisplayData()
        syncFromBar()
        refresh()
        pollTimer.start()
    }

    function bootstrapFromCache() {
        if (!cacheKey || !shell)
            return
        var cached = shell.hoverPopupDataFor(cacheKey)
        if (cached)
            applyPayload(cached)
    }

    function onDeactivated() {
        pollTimer.stop()
        if (popupProc.running)
            popupProc.running = false
    }

    function hasDisplayData() {
        return torrents.length > 0 || activeCount > 0 || downloadRate > 0 || uploadRate > 0
    }

    function formatRate(bytesPerSec) {
        var n = Number(bytesPerSec) || 0
        if (n < 1024) return Math.round(n) + " B/s"
        if (n < 1048576) return (n / 1024).toFixed(1) + " KB/s"
        if (n < 1073741824) return (n / 1048576).toFixed(1) + " MB/s"
        return (n / 1073741824).toFixed(2) + " GB/s"
    }

    function formatBytes(n) {
        n = Number(n) || 0
        if (n < 1024) return Math.round(n) + " B"
        if (n < 1048576) return (n / 1024).toFixed(1) + " KB"
        if (n < 1073741824) return (n / 1048576).toFixed(1) + " MB"
        return (n / 1073741824).toFixed(2) + " GB"
    }

    function formatEta(eta) {
        var n = parseInt(eta, 10)
        if (isNaN(n) || n < 0) return "—"
        if (n === 0) return "Done"
        if (n < 60) return n + "s"
        if (n < 3600) return Math.floor(n / 60) + "m"
        return Math.floor(n / 3600) + "h " + Math.floor((n % 3600) / 60) + "m"
    }

    function statusLabel(status) {
        switch (parseInt(status, 10)) {
        case 4: return "Downloading"
        case 6: return "Seeding"
        case 0: return "Stopped"
        case 3: return "Queued"
        default: return "Active"
        }
    }

    function applyPayload(json) {
        if (!json || typeof json !== "object")
            return
        loading = false
        connected = json.connected === true
        errorText = String(json.error || "")
        downloadRate = parseFloat(json.download_bps || 0) || 0
        uploadRate = parseFloat(json.upload_bps || 0) || 0
        activeCount = parseInt(json.active, 10) || 0
        downloadingCount = parseInt(json.downloading, 10) || 0
        torrents = Array.isArray(json.torrents) ? json.torrents : []
        publishCache(json)
    }

    function publishCache(json) {
        if (!shell || !cacheKey || !json)
            return
        shell.setHoverPopupData(cacheKey, json)
    }

    function syncFromBar() {
        var item = barSource
        if (item && item.lastPayload)
            applyPayload(item.lastPayload)
        else if (shell)
            applyPayload(shell.hoverPopupDataFor(cacheKey))
    }

    function refresh() {
        if (!script || popupProc.running)
            return
        popupProc.running = true
    }

    function removeTorrent(torrentId) {
        var id = parseInt(torrentId, 10)
        if (isNaN(id) || removeProc.running)
            return

        var next = []
        for (var i = 0; i < torrents.length; i++) {
            if (parseInt(torrents[i].id, 10) !== id)
                next.push(torrents[i])
        }
        torrents = next

        removeProc.command = [root.transmissionBin, "remove", String(id)]
        removeProc.running = true
    }

    Process {
        id: popupProc
        command: ["bash", "-lc", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = String(text || "").trim()
                if (!raw) {
                    root.loading = false
                    return
                }
                try {
                    root.applyPayload(JSON.parse(raw))
                } catch (e) {
                    root.loading = false
                    root.errorText = "Parse error"
                }
            }
        }
        onExited: root.loading = false
    }

    Process {
        id: removeProc
        onExited: {
            if (popupProc.running)
                popupProc.running = false
            root.refresh()
        }
    }

    Timer {
        id: pollTimer
        interval: 2000
        repeat: true
        onTriggered: root.refresh()
    }

    ColumnLayout {
        id: column
        width: root.hoverPopupWidth
        spacing: Theme.hoverPopupSectionSpacing

        HoverPopupHeader {
            Layout.fillWidth: true
            iconFallback: "󰇚"
            titleFont: root.titleFont
            detailFont: root.hintFont
            value: root.loading
                ? "Transmission\nLoading…"
                : (root.errorText
                    ? "Transmission\n" + root.errorText
                    : "Transmission\n" + root.formatRate(root.downloadRate) + " ↓ · "
                        + root.formatRate(root.uploadRate) + " ↑")
        }

        SectionPanel {
            Layout.fillWidth: true
            label: "Session"
            sectionSpacing: 8
            contentPad: Theme.hoverPopupContentPad

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 12
                rowSpacing: 4

                Text {
                    text: "Active"
                    color: Theme.foreground
                    opacity: 0.65
                    font.family: Theme.fontFamily
                    font.pixelSize: root.statFont
                }
                Text {
                    text: String(root.activeCount)
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.statFont
                    font.bold: Theme.fontBold
                }

                Text {
                    text: "Downloading"
                    color: Theme.foreground
                    opacity: 0.65
                    font.family: Theme.fontFamily
                    font.pixelSize: root.statFont
                }
                Text {
                    text: String(root.downloadingCount)
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.statFont
                    font.bold: Theme.fontBold
                }
            }
        }

        SectionPanel {
            Layout.fillWidth: true
            label: "Torrents"
            sectionSpacing: 8
            contentPad: Theme.hoverPopupContentPad
            visible: root.torrents.length > 0

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: root.torrents

                    ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                Layout.fillWidth: true
                                text: String(modelData.name || "Torrent")
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.titleFont
                                font.bold: Theme.fontBold
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Item {
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                Layout.alignment: Qt.AlignTop

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰆴"
                                    color: removeBtn.containsMouse ? Theme.urgent : Theme.foreground
                                    opacity: removeBtn.containsMouse ? 1 : 0.55
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.hintFont
                                    font.bold: Theme.fontBold
                                }

                                MouseArea {
                                    id: removeBtn
                                    anchors.fill: parent
                                    z: 1
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: function(mouse) {
                                        mouse.accepted = true
                                        root.removeTorrent(modelData.id)
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                var pct = Math.round(Number(modelData.percent || 0))
                                var down = root.formatRate(modelData.rate_down || 0)
                                var up = root.formatRate(modelData.rate_up || 0)
                                var eta = root.formatEta(modelData.eta)
                                return pct + "% · " + root.statusLabel(modelData.status)
                                    + " · " + down + " · ETA " + eta
                            }
                            color: Theme.foreground
                            opacity: 0.72
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            wrapMode: Text.NoWrap
                            elide: Text.ElideRight
                        }

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 4

                            CycleProgressBar {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                barWidth: width
                                progress: Math.max(0, Math.min(1, Number(modelData.percent || 0) / 100))
                            }
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: !root.loading && root.torrents.length === 0 && !root.errorText
            text: root.connected ? "No active torrents" : "Transmission offline"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: root.hintFont
            opacity: 0.65
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
