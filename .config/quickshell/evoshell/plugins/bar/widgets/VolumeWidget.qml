import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../../Commons"

Item {
    id: root

    property var bar: null
    property var barPanel: null
    property var settings: ({})
    property var shell: null

    readonly property string mediaHoverPopupId: settings.mediaOnHover
        ? String(settings.mediaOnHover)
        : "evo.media"
    readonly property string volumeHoverPopupId: settings.onHover
        ? String(settings.onHover)
        : "evo.volume"
    readonly property bool trayMode: settings.trayMode === true
    readonly property int trayIconSize: {
        var n = parseInt(settings.trayIconSize, 10)
        return isNaN(n) || n <= 0 ? 18 : n
    }
    readonly property int trayCellWidth: {
        var n = parseInt(settings.trayCellWidth, 10)
        return isNaN(n) || n <= 0 ? trayIconSize + 4 : n
    }
    readonly property var audio: shell ? shell.serviceFor("evo.audio") : null
    readonly property int systemVolumePercent: audio ? audio.percent : 0
    readonly property bool systemVolumeMuted: audio ? audio.muted : false

    property real volumeFlash: 0
    property int _trackedSystemPercent: -1
    property bool volumeHovered: false

    readonly property int barCount: 10
    readonly property int vizBarWidth: 6
    readonly property int vizBarSpacing: 2
    readonly property int vizHeight: 16
    readonly property int sectionSpacing: 8

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool sinkReady: sink !== null && sink.ready
    readonly property int cavaWidth: barCount * vizBarWidth + (barCount - 1) * vizBarSpacing
    readonly property real peakGate: 0.09
    readonly property real maxBarLevel: 0.92
    readonly property real transientMargin: 0.02
    readonly property real sustainedCap: 0.28
    readonly property real mid: (barCount - 1) / 2

    property real peakBaseline: 0
    property var barLevels: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    readonly property bool audioActive: sinkReady && linkTracker.linkGroups.length > 0
    readonly property string volumeText: audio ? audio.displayText : "󰕾"

    readonly property string trayIconText: {
        if (volumeFlash > 0)
            return root.systemVolumePercent + "%"
        return SystemVolume.icon(root.systemVolumePercent, root.systemVolumeMuted)
    }

    readonly property real trayIconOpacity: {
        if (volumeFlash > 0)
            return SystemVolume.flashOpacity(volumeFlash)
        return SystemVolume.iconOpacity(root.systemVolumePercent, root.systemVolumeMuted)
    }

    readonly property color trayIconColor: {
        if (volumeFlash > 0)
            return Theme.accent
        if (root.systemVolumeMuted || root.systemVolumePercent <= 0)
            return Theme.foreground
        return Theme.accent
    }
    readonly property int horizontalPad: trayMode ? 0 : Theme.barPaddingX

    implicitWidth: trayMode
        ? trayCellWidth
        : contentRow.implicitWidth + horizontalPad * 2
    implicitHeight: Theme.barHeight
    width: trayMode && parent ? parent.width : implicitWidth
    height: Theme.barHeight

    function zeroHistory() {
        peakBaseline = 0
        barLevels = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    }

    function decayBars(levels, factor) {
        for (var i = 0; i < barCount; i++) {
            var ef = edgeFactor(i)
            levels[i] *= factor - ef * 0.1
        }
    }

    function barWeight(index) {
        var dist = Math.abs(index - mid) / mid
        return 1 - dist * dist * 0.68
    }

    function edgeFactor(index) {
        return Math.abs(index - mid) / mid
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
                for (var j = 0; j < barCount; j++) {
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

    function openMixer() {
        if (settings.onClick)
            Quickshell.execDetached(["bash", "-lc", String(settings.onClick)])
        else
            Quickshell.execDetached(["ghostty", "--class=TUI.main", "-e", "wiremix"])
    }

    function openAlsamixer() {
        if (settings.onClickRight)
            Quickshell.execDetached(["bash", "-lc", String(settings.onClickRight)])
        else
            Quickshell.execDetached(["ghostty", "--class=TUI.main", "-e", "alsamixer"])
    }

    function handleCavaClick(mouse) {
        if (mouse.button === Qt.RightButton)
            openAlsamixer()
        else
            openMixer()
    }

    function handleVolumeClick(mouse) {
        if (mouse.button === Qt.RightButton)
            openAlsamixer()
        else
            openMixer()
    }

    function setMediaHoverPopup(active) {
        if (!shell || !mediaHoverPopupId) return
        if (active)
            shell.hoverEnter(mediaHoverPopupId, mediaLabel, barPanel)
        else
            shell.hoverLeave(mediaHoverPopupId)
    }

    function setVolumeHoverPopup(active) {
        volumeHovered = active
        if (!shell || !volumeHoverPopupId) return
        if (active)
            shell.hoverEnter(volumeHoverPopupId, volumeLabel, barPanel)
        else
            shell.hoverLeave(volumeHoverPopupId)
    }

    function handleWheel(wheel) {
        if (!audio) return
        if (wheel.angleDelta.y > 0) audio.stepUp()
        else if (wheel.angleDelta.y < 0) audio.stepDown()
        pulseVolumeFlash()
        wheel.accepted = true
    }

    function pulseVolumeFlash() {
        volumeFlash = 1
        volumeFlashTimer.restart()
        peekVolumePopup()
    }

    function peekVolumePopup() {
        if (!shell || !volumeHoverPopupId || volumeHovered) return
        shell.peekHoverPopup(volumeHoverPopupId, volumeLabel, barPanel, volumeFlashTimer.interval)
    }

    onSystemVolumePercentChanged: {
        if (_trackedSystemPercent < 0) {
            _trackedSystemPercent = systemVolumePercent
            return
        }
        if (systemVolumePercent !== _trackedSystemPercent) {
            _trackedSystemPercent = systemVolumePercent
            pulseVolumeFlash()
        }
    }

    onSystemVolumeMutedChanged: pulseVolumeFlash()

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
        enabled: root.audioActive
        onPeakChanged: root.applyPeak(peakMonitor.peak)
    }

    Timer {
        interval: 40
        running: root.audioActive
        repeat: true
        onTriggered: root.applyPeak(peakMonitor.peak)
    }

    Timer {
        id: volumeFlashTimer
        interval: 2800
        repeat: false
        onTriggered: root.volumeFlash = 0
    }

    Behavior on volumeFlash {
        NumberAnimation {
            duration: 500
            easing.type: Easing.OutCubic
        }
    }

    onAudioActiveChanged: if (!audioActive) zeroHistory()

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: root.sectionSpacing

        Text {
            id: mediaLabel
            visible: !root.trayMode
            text: "󰍹"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: root.trayMode ? root.trayIconSize : Theme.barFontPixelSize
            font.bold: Theme.fontBold
            anchors.verticalCenter: parent.verticalCenter

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: root.setMediaHoverPopup(containsMouse)
            }
        }

        Item {
            width: !root.trayMode && root.audioActive ? root.cavaWidth : 0
            height: root.vizHeight
            visible: !root.trayMode && root.audioActive

            Row {
                anchors.centerIn: parent
                spacing: root.vizBarSpacing
                height: parent.height

                Repeater {
                    model: root.barCount

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

            MouseArea {
                enabled: !root.trayMode
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onWheel: function(wheel) { root.handleWheel(wheel) }
                onClicked: function(mouse) { root.handleCavaClick(mouse) }
            }
        }

        Text {
            id: volumeLabel
            text: root.trayMode ? root.trayIconText : root.volumeText
            color: root.trayMode ? root.trayIconColor : Theme.foreground
            opacity: root.trayMode ? root.trayIconOpacity : 1
            font.family: Theme.fontFamily
            font.pixelSize: root.trayMode
                ? (volumeFlash > 0
                    ? SystemVolume.flashLabelPixelSize(root.trayIconSize)
                    : root.trayIconSize)
                : Theme.barFontPixelSize
            font.bold: Theme.fontBold
            anchors.verticalCenter: parent.verticalCenter

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: root.setVolumeHoverPopup(containsMouse)
                onWheel: function(wheel) { root.handleWheel(wheel) }
                onClicked: function(mouse) { root.handleVolumeClick(mouse) }
            }
        }
    }
}
