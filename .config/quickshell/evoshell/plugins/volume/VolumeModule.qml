import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPopupWidth: 0

    readonly property bool active: host && host.opened === true
    readonly property var audio: shell ? shell.serviceFor("evo.audio") : null
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool sinkReady: sink !== null && sink.ready
    readonly property string sinkLabel: {
        if (!sinkReady) return "No output device"
        var nick = String(sink.nickname || "").trim()
        if (nick) return nick
        var desc = String(sink.description || "").trim()
        if (desc) return desc
        return String(sink.name || "Output")
    }

    readonly property int bodyFont: Theme.hoverPopupBodyFontPixelSize
    readonly property int hintFont: Theme.hoverPopupHintFontPixelSize
    readonly property int iconFont: Theme.hoverPopupIconFontPixelSize
    readonly property bool systemMuted: audio ? audio.muted : false
    readonly property int systemPercent: audio ? audio.percent : 0
    readonly property real systemLevel: audio ? audio.level : 0
    readonly property real systemMax: audio ? audio.maxVolume : 1

    readonly property int barCount: 16
    property var barLevels: (function() {
        var levels = []
        for (var i = 0; i < 16; i++) levels.push(0)
        return levels
    })()
    readonly property bool outputActive: sinkReady && linkTracker.linkGroups.length > 0

    implicitHeight: column.implicitHeight
    width: hoverPopupWidth

    function onActivated() {}

    function onDeactivated() {
        resetBars()
    }

    function stepVolume(direction) {
        if (!audio) return
        if (direction > 0) audio.stepUp()
        else if (direction < 0) audio.stepDown()
    }

    function resetBars() {
        var levels = []
        for (var i = 0; i < barCount; i++) levels.push(0)
        barLevels = levels
    }

    function streamLabel(node) {
        if (!node) return "Unknown stream"
        var props = node.properties
        if (props !== null && props !== undefined) {
            var mediaName = props["media.name"] ? String(props["media.name"]).trim() : ""
            if (mediaName) return mediaName
            var title = props["media.title"] ? String(props["media.title"]).trim() : ""
            var artist = props["media.artist"] ? String(props["media.artist"]).trim() : ""
            if (title && artist) return artist + " — " + title
            if (title) return title
            var app = props["application.name"] ? String(props["application.name"]).trim() : ""
            if (app) return app
        }
        var nick = String(node.nickname || "").trim()
        if (nick) return nick
        var desc = String(node.description || "").trim()
        if (desc) return desc
        return String(node.name || "Stream")
    }

    function applyPeak(peak) {
        if (!active) return
        var levels = barLevels.slice()
        var mid = (barCount - 1) / 2
        var gate = 0.06
        var decay = peak < gate ? 0.42 : 0.9
        for (var i = 0; i < barCount; i++) {
            var dist = Math.abs(i - mid) / mid
            var weight = 1 - dist * dist * 0.55
            var target = Math.max(0, Math.min(1, peak * 1.35 * weight))
            if (target >= levels[i])
                levels[i] = levels[i] * 0.35 + target * 0.65
            else
                levels[i] *= decay
        }
        barLevels = levels
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
        enabled: root.active && root.outputActive
        onPeakChanged: root.applyPeak(peakMonitor.peak)
    }

    Timer {
        interval: 40
        running: root.active && root.outputActive
        repeat: true
        onTriggered: root.applyPeak(peakMonitor.peak)
    }

    ColumnLayout {
        id: column
        width: root.hoverPopupWidth
        spacing: Theme.hoverPopupSectionSpacing

        SectionPanel {
            label: "Volume"

            Text {
                Layout.fillWidth: true
                text: root.sinkLabel
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFont
                opacity: 0.72
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: root.systemMuted ? "󰝟" : "󰕾"
                    color: root.systemMuted ? Theme.foreground : Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: root.iconFont
                    opacity: root.systemMuted ? 0.55 : 1
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6

                    Rectangle {
                        anchors.fill: parent
                        radius: 3
                        color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.14)
                    }

                    Rectangle {
                        height: parent.height
                        width: parent.width * Math.max(0, Math.min(1, root.systemLevel / root.systemMax))
                        radius: 3
                        color: Theme.accent
                        opacity: root.systemMuted ? 0.35 : 0.95
                    }
                }

                Text {
                    text: root.systemMuted ? "Muted" : root.systemPercent + "%"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: root.bodyFont
                    font.bold: Theme.fontBold
                }
            }
        }

        SectionPanel {
            label: "Output"
            visible: root.sinkReady

            Text {
                text: root.outputActive
                    ? linkTracker.linkGroups.length + " active stream" + (linkTracker.linkGroups.length === 1 ? "" : "s")
                    : "Idle"
                color: root.outputActive ? Theme.accent : Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFont
                font.bold: root.outputActive
                opacity: root.outputActive ? 1 : 0.45
            }

            Row {
                Layout.fillWidth: true
                spacing: 2
                height: 28
                visible: root.outputActive
                opacity: 0.9

                Repeater {
                    model: root.barCount

                    Rectangle {
                        required property int index
                        width: Math.max(4, (parent.width - (root.barCount - 1) * 2) / root.barCount)
                        height: Math.max(3, parent.height * root.barLevels[index])
                        anchors.bottom: parent.bottom
                        color: Theme.accent
                        opacity: 0.35 + root.barLevels[index] * 0.65
                        radius: 1
                    }
                }
            }

            Repeater {
                model: root.outputActive ? linkTracker.linkGroups : []

                Item {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: streamRow.implicitHeight

                    PwObjectTracker {
                        objects: modelData && modelData.source ? [modelData.source] : []
                    }

                    Text {
                        id: streamRow
                        width: parent.width
                        text: root.streamLabel(modelData ? modelData.source : null)
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
