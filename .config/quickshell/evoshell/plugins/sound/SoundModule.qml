import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null

    readonly property bool active: host && host.opened === true
    readonly property var audio: host && host.shell ? host.shell.serviceFor("evo.audio") : null
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

    readonly property int bodyFont: Theme.panelTitleFontPixelSize
    readonly property int hintFont: Theme.panelHintFontPixelSize
    readonly property int iconFont: Theme.panelIconFontPixelSize

    property MprisPlayer trackedPlayer: null
    property real positionTick: 0

    readonly property var allPlayers: {
        var values = Mpris.players.values
        return values ? values : []
    }

    readonly property MprisPlayer player: trackedPlayer
    readonly property bool hasPlayer: player !== null
    readonly property bool playerPlaying: hasPlayer && player.isPlaying
    readonly property real trackPosition: {
        var _ = positionTick
        return hasPlayer ? player.position : 0
    }
    readonly property real trackLength: hasPlayer && player.lengthSupported ? player.length : 0
    readonly property real trackProgress: trackLength > 0
        ? Math.max(0, Math.min(1, trackPosition / trackLength))
        : 0
    readonly property string trackTitle: hasPlayer ? String(player.trackTitle || "Unknown track") : ""
    readonly property string trackArtist: hasPlayer ? String(player.trackArtist || player.trackAlbumArtist || "") : ""
    readonly property string trackAlbum: hasPlayer ? String(player.trackAlbum || "") : ""
    readonly property string trackArtUrl: hasPlayer ? String(player.trackArtUrl || "") : ""
    readonly property string playerName: hasPlayer ? String(player.identity || "Media player") : ""
    readonly property string playbackLabel: {
        if (!hasPlayer) return ""
        if (player.isPlaying) return "Playing"
        if (player.playbackState === MprisPlaybackState.Paused) return "Paused"
        return "Stopped"
    }
    readonly property string loopLabel: {
        if (!hasPlayer || !player.loopSupported) return ""
        if (player.loopState === MprisLoopState.Track) return "󰑖"
        if (player.loopState === MprisLoopState.Playlist) return "󰑐"
        return ""
    }
    readonly property bool shuffleOn: hasPlayer && player.shuffleSupported && player.shuffle
    readonly property bool showPlayerVolume: player !== null && player.volumeSupported
    readonly property int playerVolumePercent: {
        if (player === null || !player.volumeSupported) return 0
        return Math.round(player.volume * 100)
    }
    readonly property bool systemMuted: audio ? audio.muted : false
    readonly property int systemPercent: audio ? audio.percent : 0
    readonly property real systemLevel: audio ? audio.level : 0
    readonly property real systemMax: audio ? audio.maxVolume : 1

    function stepVolume(direction) {
        if (!audio) return
        if (direction > 0) audio.stepUp()
        else if (direction < 0) audio.stepDown()
    }

    function togglePlayback() {
        if (player && player.canTogglePlaying)
            player.togglePlaying()
    }

    readonly property int barCount: 16
    property var barLevels: (function() {
        var levels = []
        for (var i = 0; i < 16; i++) levels.push(0)
        return levels
    })()
    readonly property bool outputActive: sinkReady && linkTracker.linkGroups.length > 0

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    function playerInList(candidate, list) {
        if (!candidate || !list) return false
        for (var i = 0; i < list.length; i++) {
            if (list[i] === candidate) return true
        }
        return false
    }

    function onActivated() {
        refreshTrackedPlayer()
    }

    function onDeactivated() {
        resetBars()
    }

    function refreshTrackedPlayer() {
        var list = allPlayers
        if (!list || list.length === 0) {
            trackedPlayer = null
            return
        }
        for (var i = 0; i < list.length; i++) {
            if (list[i] && list[i].isPlaying) {
                trackedPlayer = list[i]
                return
            }
        }
        if (!trackedPlayer || !playerInList(trackedPlayer, list))
            trackedPlayer = list[0]
    }

    function formatTime(us) {
        var totalSec = Math.max(0, Math.floor((Number(us) || 0) / 1000000))
        var min = Math.floor(totalSec / 60)
        var sec = totalSec % 60
        return min + ":" + (sec < 10 ? "0" : "") + sec
    }

    function resetBars() {
        var levels = []
        for (var i = 0; i < barCount; i++) levels.push(0)
        barLevels = levels
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

    Timer {
        interval: 500
        running: root.active && root.playerPlaying
        repeat: true
        onTriggered: root.positionTick = Date.now()
    }

  Instantiator {
        model: Mpris.players

        Connections {
            required property MprisPlayer modelData
            target: modelData

            function onIsPlayingChanged() {
                if (modelData.isPlaying)
                    root.trackedPlayer = modelData
            }

            function onTrackTitleChanged() {
                if (modelData.isPlaying)
                    root.trackedPlayer = modelData
            }
        }
    }

    onActiveChanged: {
        if (active)
            refreshTrackedPlayer()
        else
            resetBars()
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: 10

        FramedPanel {
            label: "Now playing"
            Layout.fillWidth: true
            visible: root.hasPlayer

            ColumnLayout {
                width: parent.width
                spacing: 10

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: nowPlayingRow.implicitHeight

                RowLayout {
                    id: nowPlayingRow
                    width: parent.width
                    spacing: 12

                Item {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.fieldsetCornerRadius
                        color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)
                        visible: root.trackArtUrl === ""
                    }

                    Image {
                        anchors.fill: parent
                        visible: root.trackArtUrl !== ""
                        source: root.trackArtUrl
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                        layer.enabled: true
                        layer.smooth: true
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.trackArtUrl === ""
                        text: "󰎈"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: root.iconFont
                        opacity: 0.75
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: root.trackTitle
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.bodyFont
                        font.bold: Theme.fontBold
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.trackArtist !== ""
                        text: root.trackArtist
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                        opacity: 0.82
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.trackAlbum !== ""
                        text: root.trackAlbum
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                        opacity: 0.55
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.playerName + " · " + root.playbackLabel
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                        opacity: 0.72
                        elide: Text.ElideRight
                    }
                }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.player && root.player.canTogglePlaying
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.togglePlayback()
                }
            }

            ColumnLayout {
                width: parent.width
                spacing: 6
                visible: root.trackLength > 0 || root.playerPlaying

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: progressTrack.height

                    Rectangle {
                        id: progressTrack
                        anchors.fill: parent
                        height: 4
                        radius: 2
                        color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.14)
                    }

                    Rectangle {
                        height: parent.height
                        width: parent.width * root.trackProgress
                        radius: 2
                        color: Theme.accent
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.player && root.player.canTogglePlaying
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.togglePlayback()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: root.formatTime(root.trackPosition)
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                        opacity: 0.65
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        visible: root.loopLabel !== "" || root.shuffleOn
                        text: (root.shuffleOn ? "󰒟 " : "") + root.loopLabel
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                        opacity: 0.55
                    }

                    Text {
                        text: root.trackLength > 0 ? root.formatTime(root.trackLength) : ""
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                        opacity: 0.65
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.hasPlayer && (root.player.canGoPrevious || root.player.canTogglePlaying || root.player.canGoNext)

                Item { Layout.fillWidth: true }

                Text {
                    text: "󰒮"
                    color: Theme.foreground
                    opacity: root.player && root.player.canGoPrevious ? 0.85 : 0.25
                    font.family: Theme.fontFamily
                    font.pixelSize: root.iconFont

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        enabled: root.player && root.player.canGoPrevious
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.player.previous()
                    }
                }

                Text {
                    text: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: root.iconFont + 2

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        enabled: root.player && root.player.canTogglePlaying
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.player.togglePlaying()
                    }
                }

                Text {
                    text: "󰒭"
                    color: Theme.foreground
                    opacity: root.player && root.player.canGoNext ? 0.85 : 0.25
                    font.family: Theme.fontFamily
                    font.pixelSize: root.iconFont

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        enabled: root.player && root.player.canGoNext
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.player.next()
                    }
                }

                Item { Layout.fillWidth: true }
            }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: !root.hasPlayer
            text: "Nothing playing"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: root.bodyFont
            opacity: 0.55
        }

        FramedPanel {
            label: "Volume"
            Layout.fillWidth: true

            ColumnLayout {
                width: parent.width
                spacing: 8

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

                Text {
                    Layout.fillWidth: true
                    visible: root.showPlayerVolume
                    text: "Player volume " + root.playerVolumePercent + "%"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.hintFont
                    opacity: 0.55
                }

                Text {
                    Layout.fillWidth: true
                    text: "Scroll to adjust volume · click track to play/pause"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.hintFont
                    opacity: 0.38
                    wrapMode: Text.Wrap
                }
            }
        }

        FramedPanel {
            label: "Output"
            Layout.fillWidth: true
            visible: root.sinkReady

            ColumnLayout {
                width: parent.width
                spacing: 8

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
            }
        }

        FramedPanel {
            label: "Players"
            Layout.fillWidth: true
            visible: root.allPlayers.length > 1

            ColumnLayout {
                width: parent.width
                spacing: 4

                Repeater {
                    model: root.allPlayers

                    Item {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: playerRow.implicitHeight

                        RowLayout {
                            id: playerRow
                            width: parent.width
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: String(modelData.identity || "Player")
                                color: root.trackedPlayer === modelData ? Theme.accent : Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.hintFont
                                font.bold: root.trackedPlayer === modelData
                                elide: Text.ElideRight
                                opacity: modelData.isPlaying ? 1 : 0.55
                            }

                            Text {
                                text: modelData.isPlaying ? "Playing" : "Idle"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.hintFont
                                opacity: 0.45
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.trackedPlayer = modelData
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: function(wheel) {
            if (wheel.angleDelta.y > 0) root.stepVolume(1)
            else if (wheel.angleDelta.y < 0) root.stepVolume(-1)
            wheel.accepted = true
        }
    }
}
