import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "../../../Commons"

Item {
    id: root

    property var host: null

    readonly property string home: Quickshell.env("HOME")
    readonly property string weatherScript: home + "/.local/bin/evo-panel-weather.sh"
    readonly property string systemScript: home + "/.local/bin/evo-panel-info-system.sh"
    readonly property string mediaScript: home + "/.local/bin/evo-panel-info-media.sh"
    readonly property bool active: host && host.opened === true

    property bool weatherLoading: false
    property bool weatherOk: false
    property string weatherError: ""
    property string location: "Derby"
    property var current: null
    property var daily: []
    property string sunrise: ""
    property string sunset: ""

    property bool systemLoading: false
    property var systemData: ({})

    property var mediaData: ({})

    readonly property bool mediaPlaying: mediaData.playing === true
    readonly property bool mediaOk: mediaData.ok === true
    readonly property string mediaTitle: mediaOk ? String(mediaData.title || "") : ""
    readonly property string mediaArtist: mediaOk ? String(mediaData.artist || "") : ""
    readonly property string mediaArtUrl: mediaOk ? String(mediaData.artUrl || "") : ""
    readonly property real mediaProgress: {
        var len = Number(mediaData.length || 0)
        var pos = Number(mediaData.position || 0)
        if (len <= 0) return 0
        return Math.max(0, Math.min(1, pos / len))
    }
    readonly property bool mediaHasProgress: Number(mediaData.length || 0) > 0

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool sinkReady: sink !== null && sink.ready

    readonly property int vizBarCount: 8
    readonly property int vizBarWidth: 5
    readonly property int vizBarSpacing: 2
    readonly property int vizHeight: 14

    property real peakBaseline: 0
    property var barLevels: [0, 0, 0, 0, 0, 0, 0, 0]

    readonly property real vizMid: (vizBarCount - 1) / 2
    readonly property real peakGate: 0.09
    readonly property real maxBarLevel: 0.92
    readonly property real transientMargin: 0.02
    readonly property real sustainedCap: 0.28

    readonly property int statBarHeight: 4
    readonly property int statBarRadius: 2
    readonly property int statBarWidth: 48
    readonly property int statNameColWidth: 58
    readonly property int statValueColWidth: 72
    readonly property int statPercentColWidth: 34
    readonly property int treeGutter: 18
    readonly property int treeStemX: 8
    readonly property int treeRowHeight: 22
    readonly property color treeLineColor: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.22)

    readonly property string themeNamePath: home + "/.themes/current/.theme-name"
    readonly property string themePreviewPath: home + "/.themes/current/preview.png"

    property string themeName: ""

    readonly property var systemDetailRows: {
        if (!systemData || systemData.ok !== true) return []
        return [
            { icon: "󰹢", label: String(systemData.kernel || "") },
            { icon: "󰏖", label: systemData.packages ? (systemData.packages + " packages") : "" },
            { icon: "󰍹", label: String(systemData.gpu || "") },
            { icon: "󰻠", label: String(systemData.cpu || "") },
            { icon: "󰌢", label: String(systemData.host || "") },
            { icon: "󰍹", label: String(systemData.wm || "") },
            { icon: "󰅐", label: String(systemData.uptime || "") }
        ].filter(function(row) { return row.label })
    }

    readonly property var systemMonitors: Array.isArray(systemData.monitors) ? systemData.monitors : []

    readonly property string primaryMonitor: {
        var panel = host && host.shell && host.shell.shellConfig && host.shell.shellConfig.panel
        return panel && panel.output ? String(panel.output) : "DP-1"
    }

    readonly property int weatherColWidth: 88
    readonly property int weatherColSpacing: 18

    readonly property string distroLabel: {
        if (!systemData || systemData.ok !== true) return ""
        return [systemData.os, systemData.installAge].filter(Boolean).join(" · ")
    }

    function dismissHost() {
        if (host && typeof host.dismiss === "function")
            host.dismiss()
    }

    function onActivated() {
        refreshWeather()
        refreshSystem()
        mediaPoll.runPoll()
        livePoll.runPoll()
        cursorUsage.onActivated()
        Qt.callLater(function() {
            if (root.active)
                focusSink.forceActiveFocus()
        })
    }

    function refreshWeather() {
        if (weatherProc.running) return
        weatherLoading = true
        weatherProc.running = true
    }

    function refreshSystem() {
        if (systemProc.running) return
        systemLoading = true
        systemProc.running = true
    }

    function parseWeather(raw) {
        weatherLoading = false
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.weatherOk = data.ok === true
            root.weatherError = String(data.error || "")
            root.location = String(data.location || "Derby")
            root.current = data.current || null
            root.daily = Array.isArray(data.daily) ? data.daily : []
            root.sunrise = String(data.sunrise || "")
            root.sunset = String(data.sunset || "")
        } catch (e) {
            root.weatherOk = false
            root.weatherError = "Weather unavailable"
            root.current = null
            root.daily = []
            root.sunrise = ""
            root.sunset = ""
        }
    }

    function parseSystem(raw) {
        systemLoading = false
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.systemData = data && data.ok === true ? data : { ok: false }
        } catch (e) {
            root.systemData = { ok: false }
        }
    }

    function applyLiveStats(json) {
        if (!json || json.ok !== true) return
        var next = {}
        for (var k in root.systemData) next[k] = root.systemData[k]
        next.memTotal = json.memTotal
        next.memPercent = json.memPercent
        next.memTotalLabel = json.memTotalLabel
        next.diskTotal = json.diskTotal
        next.diskPercent = json.diskPercent
        next.diskTotalLabel = json.diskTotalLabel
        next.storageTotal = json.storageTotal
        next.storagePercent = json.storagePercent
        next.storageTotalLabel = json.storageTotalLabel
        next.externalTotal = json.externalTotal
        next.externalPercent = json.externalPercent
        next.externalTotalLabel = json.externalTotalLabel
        if (Array.isArray(json.monitors)) next.monitors = json.monitors
        next.ok = true
        root.systemData = next
    }

    function shortMonitorName(name) {
        var n = String(name || "")
        if (n.indexOf("HDMI-A-") === 0) return n.replace("HDMI-A-", "A-")
        return n
    }

    function monitorLayoutRects(monitors, areaW, areaH) {
        if (!monitors || monitors.length === 0 || areaW <= 0 || areaH <= 0) return []

        var pad = 4
        var gap = 3
        var minX = Infinity
        var minY = Infinity
        var maxX = -Infinity
        var maxY = -Infinity

        for (var i = 0; i < monitors.length; i++) {
            var m = monitors[i]
            var sc = Number(m.scale) || 1
            var lw = Number(m.width) / sc
            var lh = Number(m.height) / sc
            var mx = Number(m.x)
            var my = Number(m.y)
            if (mx < minX) minX = mx
            if (my < minY) minY = my
            if (mx + lw > maxX) maxX = mx + lw
            if (my + lh > maxY) maxY = my + lh
        }

        var totalW = maxX - minX
        var totalH = maxY - minY
        if (totalW <= 0 || totalH <= 0) return []

        var innerW = areaW - pad * 2
        var innerH = areaH - pad * 2
        var scale = Math.min(innerW / totalW, innerH / totalH)
        var drawnW = totalW * scale
        var drawnH = totalH * scale
        var offsetX = pad + (innerW - drawnW) / 2
        var offsetY = pad + (innerH - drawnH) / 2
        var out = []

        for (var j = 0; j < monitors.length; j++) {
            var mon = monitors[j]
            var monScale = Number(mon.scale) || 1
            var monW = Number(mon.width) / monScale
            var monH = Number(mon.height) / monScale
            var res = mon.resolution
                ? String(mon.resolution)
                : (String(mon.width) + "×" + String(mon.height))
            out.push({
                name: mon.name,
                resolution: res,
                primary: String(mon.name) === root.primaryMonitor,
                x: offsetX + (Number(mon.x) - minX) * scale + gap / 2,
                y: offsetY + (Number(mon.y) - minY) * scale + gap / 2,
                w: Math.max(10, monW * scale - gap),
                h: Math.max(8, monH * scale - gap)
            })
        }

        return out
    }

    function applyMedia(json) {
        root.mediaData = json || {}
    }

    function toggleMedia() {
        if (!mediaOk || mediaToggleProc.running) return
        mediaToggleProc.running = true
    }

    function resetBars() {
        peakBaseline = 0
        barLevels = [0, 0, 0, 0, 0, 0, 0, 0]
    }

    function barWeight(index) {
        var dist = Math.abs(index - vizMid) / vizMid
        return 1 - dist * dist * 0.68
    }

    function edgeFactor(index) {
        return Math.abs(index - vizMid) / vizMid
    }

    function decayBars(levels, factor) {
        for (var i = 0; i < vizBarCount; i++) {
            var ef = edgeFactor(i)
            levels[i] *= factor - ef * 0.1
        }
    }

    function applyPeak(peak) {
        var levels = barLevels.slice()

        if (peak < peakBaseline)
            peakBaseline = peakBaseline * 0.96 + peak * 0.04
        else
            peakBaseline = peakBaseline * 0.99 + peak * 0.01

        if (peak < peakGate) {
            decayBars(levels, 0.48)
        } else {
            var excursion = Math.max(0, peak - peakBaseline - transientMargin)
            var transient = Math.min(1, excursion / 0.14)
            transient = Math.pow(transient, 1.25)

            var sustained = Math.max(0, peak - peakGate - 0.01)
            sustained = Math.pow(Math.min(1, sustained / 0.28), 1.35) * sustainedCap

            var baseTarget = Math.min(maxBarLevel, transient * 1.44 + sustained)
            decayBars(levels, 0.96)

            if (baseTarget > 0.01) {
                for (var j = 0; j < vizBarCount; j++) {
                    var target = baseTarget * barWeight(j)
                    var edge = edgeFactor(j)
                    if (target >= levels[j]) {
                        var attack = 0.28 + edge * 0.34
                        levels[j] = levels[j] * (1 - attack) + target * attack
                    } else {
                        var retain = 0.38 - edge * 0.1
                        levels[j] = levels[j] * retain + target * (1 - retain)
                    }
                }
            }
        }

        barLevels = levels
    }

    Process {
        id: weatherProc
        command: ["bash", root.weatherScript]
        stdout: StdioCollector {
            onStreamFinished: root.parseWeather(text)
        }
        onExited: function(exitCode) {
            if (root.weatherLoading && exitCode !== 0) {
                root.weatherLoading = false
                root.weatherOk = false
                root.weatherError = "Weather unavailable"
            }
        }
    }

    Process {
        id: systemProc
        command: ["bash", root.systemScript]
        stdout: StdioCollector {
            onStreamFinished: root.parseSystem(text)
        }
        onExited: function(exitCode) {
            if (root.systemLoading && exitCode !== 0) {
                root.systemLoading = false
                root.systemData = { ok: false }
            }
        }
    }

    Process {
        id: mediaToggleProc
        command: ["bash", root.mediaScript, "toggle"]
        onExited: mediaPoll.runPoll()
    }

    JsonPollRunner {
        id: mediaPoll
        active: root.active
        defaultIntervalSec: 5
        settings: ({ interval: root.mediaPlaying ? 1 : 5 })
        command: ["bash", root.mediaScript]
        onPolled: function(json) { root.applyMedia(json) }
    }

    JsonPollRunner {
        id: livePoll
        active: root.active
        defaultIntervalSec: 3
        command: ["bash", root.systemScript, "--live"]
        onPolled: function(json) { root.applyLiveStats(json) }
    }

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    PwNodeLinkTracker {
        id: linkTracker
        node: root.sink
    }

    PwNodePeakMonitor {
        id: peakMonitor
        node: root.sink
        enabled: root.active && root.sinkReady && linkTracker.linkGroups.length > 0
        onPeakChanged: root.applyPeak(peakMonitor.peak)
    }

    Timer {
        interval: 40
        running: root.active && root.sinkReady && linkTracker.linkGroups.length > 0
        repeat: true
        onTriggered: root.applyPeak(peakMonitor.peak)
    }

    onActiveChanged: if (!active) resetBars()

    FileView {
        id: themeNameFile
        path: root.themeNamePath
        watchChanges: true
        printErrors: false
        onLoaded: root.themeName = String(text() || "").trim()
        onLoadFailed: root.themeName = ""
        onFileChanged: reload()
    }

    FileView {
        id: themePreviewFile
        path: root.themePreviewPath
        watchChanges: true
        printErrors: false
        onFileChanged: root.reloadThemePreview()
    }

    function reloadThemePreview() {
        themePreviewImage.source = ""
        themePreviewImage.source = Util.fileUrl(themePreviewPath)
    }

    onThemeNameChanged: reloadThemePreview()

    Item {
        id: focusSink
        anchors.fill: parent
        focus: root.active
        Keys.enabled: root.active
        Keys.onEscapePressed: root.dismissHost()

        Flickable {
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: infoColumn.implicitHeight + 10
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            ColumnLayout {
                id: infoColumn
                width: parent.width
                y: 10
                spacing: 14

                FramedPanel {
                    label: "Now playing"
                    contentFill: true
                    Layout.fillWidth: true
                    Layout.preferredHeight: 132

                    Item {
                        anchors.fill: parent

                        RowLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            visible: root.mediaOk && (root.mediaTitle || root.mediaArtist)

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: 88
                                Layout.preferredHeight: 88
                                radius: 0
                                color: Theme.panelMantle
                                border.color: Theme.accent
                                border.width: 1
                                clip: true

                                Image {
                                        anchors.fill: parent
                                        source: root.mediaArtUrl
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        visible: root.mediaArtUrl !== ""
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: root.mediaArtUrl === ""
                                    text: "󰝚"
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 28
                                    opacity: 0.65
                                }
                            }

                            ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.mediaTitle || "Unknown track"
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.panelTitleFontPixelSize
                                        font.bold: Theme.fontBold
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                        wrapMode: Text.Wrap
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.mediaArtist || " "
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.panelSmallFontPixelSize
                                        opacity: 0.72
                                        elide: Text.ElideRight
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 4
                                        visible: root.mediaHasProgress

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 2
                                            color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.12)
                                        }

                                        Rectangle {
                                            height: parent.height
                                            width: parent.width * root.mediaProgress
                                            radius: 2
                                            color: Theme.accent
                                            opacity: 0.9
                                        }
                                    }

                                    Row {
                                        Layout.fillWidth: true
                                        spacing: root.vizBarSpacing
                                        height: root.vizHeight
                                        visible: linkTracker.linkGroups.length > 0

                                        Repeater {
                                            model: root.vizBarCount

                                            Item {
                                                required property int index
                                                width: root.vizBarWidth
                                                height: parent.height

                                                readonly property real level: root.barLevels[index]

                                                Rectangle {
                                                    width: root.vizBarWidth
                                                    height: Math.max(2, parent.height * parent.level)
                                                    anchors.bottom: parent.bottom
                                                    color: Theme.accent
                                                    opacity: 0.35 + parent.level * 0.65
                                                }
                                            }
                                        }
                                    }
                                }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            visible: !root.mediaOk || (!root.mediaTitle && !root.mediaArtist)

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "󰝚"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 24
                                opacity: 0.35
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Nothing playing"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.panelSmallFontPixelSize
                                opacity: 0.45
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.mediaOk
                            cursorShape: root.mediaOk ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.toggleMedia()
                        }
                    }
                }

                FramedPanel {
                    label: "System"
                    Layout.fillWidth: true

                    ColumnLayout {
                        width: parent.width
                        spacing: 10

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 96
                            radius: 0
                            color: Theme.panelMantle
                            border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.18)
                            border.width: 1
                            clip: true

                            Image {
                                id: themePreviewImage
                                anchors.fill: parent
                                source: Util.fileUrl(root.themePreviewPath)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 36
                                gradient: Gradient {
                                    GradientStop { position: 0; color: "transparent" }
                                    GradientStop {
                                        position: 1
                                        color: Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.92)
                                    }
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 8
                                text: root.themeName || "theme"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.panelHintFontPixelSize
                                font.bold: Theme.fontBold
                                elide: Text.ElideRight
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: themePreviewImage.status === Image.Error || themePreviewImage.status === Image.Null
                                text: "󰸌"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 28
                                opacity: 0.3
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 88
                            visible: root.systemMonitors.length > 0

                            Repeater {
                                model: root.monitorLayoutRects(root.systemMonitors, parent.width, parent.height)

                                Item {
                                    required property var modelData
                                    x: modelData.x
                                    y: modelData.y
                                    width: modelData.w
                                    height: modelData.h

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 2
                                        color: modelData.primary
                                            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                            : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.07)
                                        border.color: modelData.primary
                                            ? Theme.accent
                                            : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.28)
                                        border.width: modelData.primary ? 1.5 : 1
                                    }

                                    Column {
                                        anchors.centerIn: parent
                                        width: parent.width - 4
                                        spacing: 1

                                        Text {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            text: root.shortMonitorName(modelData.name)
                                            color: modelData.primary ? Theme.accent : Theme.foreground
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 8
                                            font.bold: modelData.primary
                                            opacity: modelData.primary ? 0.9 : 0.55
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            text: modelData.resolution
                                            color: modelData.primary ? Theme.foreground : Theme.foreground
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.panelHintFontPixelSize
                                            font.bold: modelData.primary
                                            opacity: modelData.primary ? 0.95 : 0.65
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.systemLoading && root.distroLabel === "" && root.systemDetailRows.length === 0
                            text: "Loading…"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.panelSmallFontPixelSize
                            opacity: 0.5
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: root.distroLabel !== ""

                            Text {
                                text: "󰣇"
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.panelSmallFontPixelSize
                                font.bold: Theme.fontBold
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.distroLabel
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.panelSmallFontPixelSize
                                font.bold: Theme.fontBold
                                elide: Text.ElideRight
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            visible: root.systemDetailRows.length > 0 || root.systemData.ok === true
                            implicitHeight: systemTreeColumn.implicitHeight

                            Rectangle {
                                visible: root.systemDetailRows.length > 0 || root.systemData.ok === true
                                x: root.treeStemX
                                width: 1
                                anchors.top: systemTreeColumn.top
                                anchors.bottom: systemTreeColumn.bottom
                                anchors.topMargin: root.treeRowHeight / 2
                                anchors.bottomMargin: root.treeRowHeight / 2
                                color: root.treeLineColor
                            }

                            ColumnLayout {
                                id: systemTreeColumn
                                width: parent.width
                                spacing: 0

                                Repeater {
                                    model: root.systemDetailRows

                                    TreeBranchRow {
                                        required property var modelData
                                        icon: modelData.icon
                                        label: modelData.label
                                    }
                                }

                                TreeBranchRow {
                                    visible: root.systemData.ok === true
                                    icon: "󰾆"
                                    statName: "RAM"
                                    statValue: root.systemData.memTotalLabel || ""
                                    statPercent: Math.round(Number(root.systemData.memPercent || 0)) + "%"
                                    barFraction: Number(root.systemData.memPercent || 0) / 100
                                    isLast: false
                                }

                                TreeBranchRow {
                                    visible: root.systemData.ok === true
                                    icon: "󰋊"
                                    statName: "/"
                                    statValue: root.systemData.diskTotalLabel || ""
                                    statPercent: Math.round(Number(root.systemData.diskPercent || 0)) + "%"
                                    barFraction: Number(root.systemData.diskPercent || 0) / 100
                                    isLast: false
                                }

                                TreeBranchRow {
                                    visible: root.systemData.ok === true && Number(root.systemData.storageTotal || 0) > 0
                                    icon: "󰋊"
                                    statName: "storage"
                                    statValue: root.systemData.storageTotalLabel || ""
                                    statPercent: Math.round(Number(root.systemData.storagePercent || 0)) + "%"
                                    barFraction: Number(root.systemData.storagePercent || 0) / 100
                                    isLast: !(root.systemData.ok === true && Number(root.systemData.externalTotal || 0) > 0)
                                }

                                TreeBranchRow {
                                    visible: root.systemData.ok === true && Number(root.systemData.externalTotal || 0) > 0
                                    icon: "󰋊"
                                    statName: "external"
                                    statValue: root.systemData.externalTotalLabel || ""
                                    statPercent: Math.round(Number(root.systemData.externalPercent || 0)) + "%"
                                    barFraction: Number(root.systemData.externalPercent || 0) / 100
                                    isLast: true
                                }
                            }
                        }
                    }
                }

                FramedPanel {
                    label: root.location || "Weather"
                    Layout.fillWidth: true

                    ColumnLayout {
                        width: parent.width
                        spacing: 8

                        RowLayout {
                            id: weatherRow
                            Layout.alignment: Qt.AlignHCenter
                            spacing: root.weatherColSpacing

                            ColumnLayout {
                                Layout.preferredWidth: root.weatherColWidth
                                spacing: 4

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "Now"
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.panelHintFontPixelSize
                                    opacity: 0.65
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: root.weatherColWidth
                                    Layout.preferredHeight: 28
                                    spacing: 6

                                    Text {
                                        text: root.current ? String(root.current.icon || "󰖐") : "󰖐"
                                        color: Theme.accent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 28
                                        font.bold: Theme.fontBold
                                    }

                                    Text {
                                        text: root.weatherLoading ? "…" : (root.current ? (String(root.current.temp) + "°") : "—")
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 24
                                        font.bold: Theme.fontBold
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: root.weatherLoading
                                        ? "Loading…"
                                        : (root.weatherOk && root.current
                                            ? String(root.current.label || "")
                                            : (root.weatherError || "Unavailable"))
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.panelHintFontPixelSize
                                    opacity: 0.55
                                    elide: Text.ElideRight
                                }
                            }

                            Repeater {
                                model: root.daily

                                ColumnLayout {
                                    required property var modelData
                                    Layout.preferredWidth: root.weatherColWidth
                                    spacing: 4

                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: String(modelData.dow || "")
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.panelHintFontPixelSize
                                        opacity: 0.65
                                    }

                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: root.weatherColWidth
                                        Layout.preferredHeight: 28
                                        spacing: 4

                                        Text {
                                            Layout.alignment: Qt.AlignVCenter
                                            text: String(modelData.icon || "󰖐")
                                            color: Theme.accent
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 16
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignVCenter
                                            text: String(modelData.min) + "—" + String(modelData.max) + "°"
                                            color: Theme.foreground
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.panelHintFontPixelSize
                                            font.bold: Theme.fontBold
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: String(modelData.label || "")
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.panelHintFontPixelSize
                                        opacity: 0.5
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 18
                            visible: root.weatherOk && (root.sunrise !== "" || root.sunset !== "")

                            RowLayout {
                                spacing: 4
                                visible: root.sunrise !== ""

                                Text {
                                    text: "󰖜"
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.panelSmallFontPixelSize
                                }

                                Text {
                                    text: root.sunrise
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.panelSmallFontPixelSize
                                    opacity: 0.75
                                }
                            }

                            RowLayout {
                                spacing: 4
                                visible: root.sunset !== ""

                                Text {
                                    text: "󰖛"
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.panelSmallFontPixelSize
                                }

                                Text {
                                    text: root.sunset
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.panelSmallFontPixelSize
                                    opacity: 0.75
                                }
                            }
                        }
                    }
                }

                FramedPanel {
                    label: "Cursor"
                    Layout.fillWidth: true

                    UsageModule {
                        id: cursorUsage
                        width: parent.width
                        embedded: true
                        embeddedActive: root.active
                        host: root.host
                    }
                }
            }
        }
    }

    component TreeBranchRow: RowLayout {
        id: branchRow

        property string icon: ""
        property string label: ""
        property string statName: ""
        property string statValue: ""
        property string statPercent: ""
        property real barFraction: -1
        property bool isLast: false

        readonly property bool isStatRow: statName !== ""

        Layout.fillWidth: true
        Layout.preferredHeight: root.treeRowHeight
        spacing: 6

        Item {
            Layout.preferredWidth: root.treeGutter
            Layout.preferredHeight: root.treeRowHeight

            Rectangle {
                x: root.treeStemX
                anchors.verticalCenter: parent.verticalCenter
                width: root.treeGutter - root.treeStemX - 2
                height: 1
                color: root.treeLineColor
            }
        }

        Text {
            text: branchRow.icon
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelSmallFontPixelSize
            opacity: 0.85
        }

        Text {
            visible: !branchRow.isStatRow
            Layout.fillWidth: true
            text: branchRow.label
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelSmallFontPixelSize
            elide: Text.ElideRight
        }

        Text {
            visible: branchRow.isStatRow
            Layout.preferredWidth: root.statNameColWidth
            text: branchRow.statName
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelSmallFontPixelSize
            elide: Text.ElideRight
        }

        Text {
            visible: branchRow.isStatRow
            Layout.preferredWidth: root.statValueColWidth
            text: branchRow.statValue
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelSmallFontPixelSize
            elide: Text.ElideRight
        }

        Text {
            visible: branchRow.isStatRow
            Layout.preferredWidth: root.statPercentColWidth
            horizontalAlignment: Text.AlignRight
            text: branchRow.statPercent
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelSmallFontPixelSize
        }

        Item {
            visible: branchRow.isStatRow
            Layout.fillWidth: true
        }

        Item {
            visible: branchRow.barFraction >= 0
            Layout.preferredWidth: root.statBarWidth
            Layout.preferredHeight: root.statBarHeight

            Rectangle {
                anchors.fill: parent
                radius: root.statBarRadius
                color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.12)
            }

            Rectangle {
                height: parent.height
                width: parent.width * Math.max(0, Math.min(1, branchRow.barFraction))
                radius: root.statBarRadius
                color: Theme.accent
                opacity: 0.9
            }
        }
    }
}
