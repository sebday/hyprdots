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
    property bool sliderOnly: false

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

    readonly property int bodyFont: Theme.fontSize3xl
    readonly property int hintFont: Theme.fontSizeL
    readonly property int iconFont: Theme.fontSize4xl
    readonly property int sliderBodyHeight: host ? host.minContentHeight : 180
    readonly property color fillOverlayText: Theme.foreground
    readonly property bool systemMuted: audio ? audio.muted : false
    readonly property int systemPercent: audio ? audio.percent : 0
    readonly property real systemLevel: audio ? audio.level : 0
    readonly property real sliderMax: 1
    readonly property real sliderRatio: Math.max(0, Math.min(1, systemLevel / sliderMax))

    readonly property int barCount: 16
    property var barLevels: (function() {
        var levels = []
        for (var i = 0; i < 16; i++) levels.push(0)
        return levels
    })()
    readonly property bool outputActive: sinkReady && linkTracker.linkGroups.length > 0

    implicitHeight: root.sliderOnly ? sliderPopup.implicitHeight : column.implicitHeight
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

    function setLevelFromRatio(ratio) {
        if (!audio) return
        var r = Math.max(0, Math.min(1, ratio))
        audio.setVolume(r * sliderMax)
    }

    function setLevelFromVerticalRatio(y, height) {
        if (!height)
            return
        setLevelFromRatio(1 - Math.max(0, Math.min(1, y / height)))
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

    Item {
        id: sliderPopup
        visible: root.sliderOnly
        width: root.hoverPopupWidth
        implicitHeight: root.sliderBodyHeight

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: parent.height * root.sliderRatio
            color: Theme.accent
            opacity: root.systemMuted ? 0.35 : 0.95
            radius: Theme.panelCornerRadius
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            onPressed: function(mouse) {
                root.setLevelFromVerticalRatio(mouse.y, height)
            }

            onPositionChanged: function(mouse) {
                if (pressed)
                    root.setLevelFromVerticalRatio(mouse.y, height)
            }

            onWheel: function(wheel) {
                if (wheel.angleDelta.y > 0)
                    root.stepVolume(1)
                else if (wheel.angleDelta.y < 0)
                    root.stepVolume(-1)
                wheel.accepted = true
            }
        }

        RowLayout {
            z: 1
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingM

            Text {
                text: root.systemMuted ? "Muted" : root.systemPercent + "%"
                color: root.fillOverlayText
                font.family: Theme.fontFamily
                font.pixelSize: root.bodyFont
                font.bold: Theme.fontBold
                style: Text.PlainText
            }

            Text {
                text: SystemVolume.icon(root.systemPercent, root.systemMuted)
                color: root.fillOverlayText
                font.family: Theme.fontFamily
                font.pixelSize: root.iconFont
                opacity: root.systemMuted ? 0.55 : 1

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.audio) root.audio.toggleMute()
                }
            }
        }
    }

    ColumnLayout {
        id: column
        visible: !root.sliderOnly
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.hoverPopupSectionSpacing

        SectionPanel {
            label: "Volume"
            visible: !root.sliderOnly

            Text {
                Layout.fillWidth: true
                text: root.sinkLabel
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFont
                opacity: Theme.opacitySecondary
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingL

                Text {
                    text: SystemVolume.icon(root.systemPercent, root.systemMuted)
                    color: root.systemMuted ? Theme.foreground : Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: root.iconFont
                    opacity: SystemVolume.iconOpacity(root.systemPercent, root.systemMuted)

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.audio) root.audio.toggleMute()
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6

                    Rectangle {
                        id: levelTrack
                        anchors.fill: parent
                        radius: Theme.radiusM
                        color: Theme.foregroundDivider
                    }

                    Rectangle {
                        height: parent.height
                        width: parent.width * root.sliderRatio
                        radius: Theme.radiusM
                        color: Theme.accent
                        opacity: root.systemMuted ? 0.35 : 0.95
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        function ratioAt(x) {
                            return Math.max(0, Math.min(1, x / width))
                        }

                        onPressed: function(mouse) {
                            root.setLevelFromRatio(ratioAt(mouse.x))
                        }

                        onPositionChanged: function(mouse) {
                            if (pressed)
                                root.setLevelFromRatio(ratioAt(mouse.x))
                        }

                        onWheel: function(wheel) {
                            if (wheel.angleDelta.y > 0)
                                root.stepVolume(1)
                            else if (wheel.angleDelta.y < 0)
                                root.stepVolume(-1)
                            wheel.accepted = true
                        }
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
            visible: !root.sliderOnly && root.sinkReady

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
                spacing: Theme.spacing2
                height: 28
                visible: root.outputActive
                opacity: Theme.opacityEmphasis

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
