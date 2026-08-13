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
    property var hourly: []
    property string sunrise: ""
    property string sunset: ""
    property bool hourlyExpanded: false

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
            { icon: "󰍹", label: String(systemData.wm || "") }
        ].filter(function(row) { return row.label })
    }

    readonly property bool liveStatsReady: systemData && systemData.ok === true
        && systemData.cpuPercent !== undefined
    readonly property real liveCpuPercent: liveStatsReady ? Number(systemData.cpuPercent || 0) : 0
    readonly property int liveStatLabelWidth: 26
    readonly property int liveStatPercentWidth: 34
    readonly property int liveStatSizeWidth: 72

    readonly property var liveDiskRows: {
        if (!liveStatsReady) return []
        var rows = [{
            name: "/",
            percent: Number(systemData.diskPercent || 0),
            total: String(systemData.diskTotalLabel || "")
        }]
        if (Number(systemData.storageTotal || 0) > 0) {
            rows.push({
                name: "sto",
                percent: Number(systemData.storagePercent || 0),
                total: String(systemData.storageTotalLabel || "")
            })
        }
        if (Number(systemData.externalTotal || 0) > 0) {
            rows.push({
                name: "ext",
                percent: Number(systemData.externalPercent || 0),
                total: String(systemData.externalTotalLabel || "")
            })
        }
        return rows
    }

    readonly property int weatherColWidth: 88
    readonly property int weatherColSpacing: 18
    readonly property string currentHourLabel: {
        if (!current || !current.time) return ""
        var t = String(current.time)
        var idx = t.indexOf("T")
        if (idx < 0) return ""
        return t.slice(idx + 1, idx + 3) + ":00"
    }

    readonly property string distroLabel: {
        if (!systemData || systemData.ok !== true) return ""
        var parts = []
        if (systemData.os)
            parts.push(String(systemData.os))
        var age = String(systemData.installAge || "")
        var uptime = String(systemData.uptime || "")
        if (age && uptime)
            parts.push(age + ", up " + uptime)
        else if (age)
            parts.push(age)
        else if (uptime)
            parts.push("up " + uptime)
        return parts.join(" · ")
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
            root.hourly = Array.isArray(data.hourly) ? data.hourly : []
            root.sunrise = String(data.sunrise || "")
            root.sunset = String(data.sunset || "")
        } catch (e) {
            root.weatherOk = false
            root.weatherError = "Weather unavailable"
            root.current = null
            root.daily = []
            root.hourly = []
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
        if (json.cpuPercent !== undefined) next.cpuPercent = json.cpuPercent
        if (json.uptime !== undefined) next.uptime = json.uptime
        next.ok = true
        root.systemData = next
    }

    function meterColor(fraction) {
        var f = Math.max(0, Math.min(1, fraction))
        if (f >= 0.9) return Theme.urgent
        if (f >= 0.7) return Theme.accent
        return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.82)
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

    onActiveChanged: if (!active) resetBars()

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

                                TreeCpuStatRow {
                                    visible: root.liveStatsReady || livePoll.loading
                                }

                                TreeStatRow {
                                    visible: root.liveStatsReady
                                    statName: "mem"
                                    statPercent: Math.round(Number(root.systemData.memPercent || 0)) + "%"
                                    statValue: String(root.systemData.memTotalLabel || "")
                                    barFraction: Number(root.systemData.memPercent || 0) / 100
                                }

                                Repeater {
                                    model: root.liveDiskRows

                                    TreeStatRow {
                                        required property var modelData
                                        statName: modelData.name
                                        statPercent: Math.round(modelData.percent) + "%"
                                        statValue: modelData.total
                                        barFraction: modelData.percent / 100
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: root.treeGutter
                                    visible: !root.liveStatsReady && livePoll.loading
                                    text: "Loading…"
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.panelHintFontPixelSize
                                    opacity: 0.55
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

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 22
                            visible: root.weatherOk && root.hourly.length > 0

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: root.hourlyExpanded ? "−" : "+"
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.panelSmallFontPixelSize
                                    font.bold: Theme.fontBold
                                }

                                Text {
                                    text: "Show more"
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.panelHintFontPixelSize
                                    opacity: 0.55
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.hourlyExpanded = !root.hourlyExpanded
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 4
                            columnSpacing: 8
                            rowSpacing: 10
                            visible: root.weatherOk && root.hourlyExpanded && root.hourly.length > 0

                            Repeater {
                                model: root.hourly

                                ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 2

                                    readonly property bool isNow: String(modelData.time || "") === root.currentHourLabel
                                    readonly property bool isPast: {
                                        var hour = String(modelData.time || "")
                                        var now = root.currentHourLabel
                                        return hour !== "" && now !== "" && hour < now
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: String(modelData.time || "").slice(0, 2)
                                        color: parent.isNow ? Theme.accent : Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.panelHintFontPixelSize
                                        font.bold: Theme.fontBold
                                        opacity: parent.isNow ? 1 : (parent.isPast ? 0.35 : 0.65)
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: (modelData.temp !== undefined ? String(modelData.temp) : "—") + "°"
                                        color: parent.isNow ? Theme.accent : Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.panelHintFontPixelSize
                                        font.bold: Theme.fontBold
                                        opacity: parent.isPast && !parent.isNow ? 0.45 : 1
                                    }
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
                        host: root.host
                    }
                }
            }
        }
    }

    component TreeCpuStatRow: RowLayout {
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
            Layout.preferredWidth: root.liveStatLabelWidth
            text: "cpu"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelHintFontPixelSize
            font.bold: Theme.fontBold
            opacity: 0.8
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 8

            Rectangle {
                anchors.fill: parent
                radius: 1
                color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.1)
            }

            Canvas {
                id: cpuChart
                anchors.fill: parent

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)

                    var frac = Math.max(0, Math.min(1, root.liveCpuPercent / 100))
                    if (frac <= 0) return

                    var pad = 1
                    var gap = 1
                    var innerW = Math.max(1, width - pad * 2)
                    var innerH = Math.max(1, height - pad * 2)
                    var cell = Math.max(1, innerH)
                    var cols = Math.max(1, Math.floor((innerW + gap) / (cell + gap)))
                    var filled = Math.round(frac * cols)
                    var color = root.meterColor(frac)

                    for (var i = 0; i < filled; i++) {
                        var x = pad + i * (cell + gap)
                        ctx.fillStyle = color
                        ctx.fillRect(
                            Math.round(x),
                            Math.round(pad),
                            Math.max(1, Math.floor(cell)),
                            Math.max(1, Math.floor(cell))
                        )
                    }
                }

                Connections {
                    target: root
                    function onLiveCpuPercentChanged() { cpuChart.requestPaint() }
                }

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }
        }

        Text {
            Layout.preferredWidth: root.liveStatPercentWidth
            horizontalAlignment: Text.AlignRight
            text: livePoll.loading && !root.liveStatsReady
                ? "…"
                : Math.round(root.liveCpuPercent) + "%"
            color: root.meterColor(root.liveCpuPercent / 100)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelHintFontPixelSize
            font.bold: Theme.fontBold
        }

        Item {
            Layout.preferredWidth: root.liveStatSizeWidth
            Layout.preferredHeight: 1
        }
    }

    component TreeStatRow: RowLayout {
        property string statName: ""
        property string statValue: ""
        property string statPercent: ""
        property real barFraction: -1

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
            Layout.preferredWidth: root.liveStatLabelWidth
            text: statName
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelHintFontPixelSize
            font.bold: Theme.fontBold
            opacity: 0.8
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 8
            visible: barFraction >= 0

            Rectangle {
                anchors.fill: parent
                radius: 1
                color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.1)
            }

            Rectangle {
                height: parent.height
                width: parent.width * Math.max(0, Math.min(1, barFraction))
                radius: 1
                color: root.meterColor(barFraction)
            }
        }

        Text {
            Layout.preferredWidth: root.liveStatPercentWidth
            horizontalAlignment: Text.AlignRight
            text: statPercent
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelHintFontPixelSize
        }

        Text {
            Layout.preferredWidth: root.liveStatSizeWidth
            horizontalAlignment: Text.AlignRight
            visible: statValue !== ""
            text: statValue
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelHintFontPixelSize
            opacity: 0.72
        }
    }

    component TreeBranchRow: RowLayout {
        property string icon: ""
        property string label: ""

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
            text: icon
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelSmallFontPixelSize
            opacity: 0.85
        }

        Text {
            Layout.fillWidth: true
            text: label
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelSmallFontPixelSize
            elide: Text.ElideRight
        }
    }
}
