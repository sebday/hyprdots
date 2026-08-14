import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../../../Commons"

Item {
    id: root
    property var bar: null
    property var settings: ({})

    readonly property int barCount: 10
    readonly property int vizBarWidth: 6
    readonly property int vizBarSpacing: 2
    readonly property int vizHeight: 16
    readonly property int vizPaddingX: Theme.barPaddingX

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool sinkReady: sink !== null && sink.ready

    readonly property int contentWidth: barCount * vizBarWidth + (barCount - 1) * vizBarSpacing

    readonly property real peakGate: 0.09
    readonly property real maxBarLevel: 0.92
    readonly property real transientMargin: 0.02
    readonly property real sustainedCap: 0.28

    readonly property real mid: (barCount - 1) / 2

    property real displayLevel: 0
    property real peakBaseline: 0
    property var barLevels: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    readonly property bool audioActive: sinkReady && linkTracker.linkGroups.length > 0
    // Stay visible while audio is routed — bar height handles sensitivity, not layout.
    readonly property bool hasContent: audioActive

    implicitWidth: hasContent ? contentWidth + vizPaddingX * 2 : 0
    implicitHeight: Theme.barHeight

    function resetBars() {
        displayLevel = 0
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

        // Slow baseline — tracks average level, not each beat.
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
        var max = 0
        for (var k = 0; k < barCount; k++)
            if (levels[k] > max) max = levels[k]
        displayLevel = max
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
        enabled: root.audioActive
        onPeakChanged: root.applyPeak(peakMonitor.peak)
    }

    Timer {
        interval: 40
        running: root.audioActive
        repeat: true
        onTriggered: root.applyPeak(peakMonitor.peak)
    }

    onAudioActiveChanged: if (!audioActive) resetBars()

    Row {
        id: barRow
        anchors.centerIn: parent
        spacing: root.vizBarSpacing
        height: root.vizHeight
        visible: root.hasContent

        Repeater {
            model: root.barCount

            Item {
                required property int index
                width: root.vizBarWidth
                height: barRow.height

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
        anchors.fill: parent
        enabled: root.hasContent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: (settings.onClick || settings.onClickRight) ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton && settings.onClickRight)
                Quickshell.execDetached(["bash", "-lc", String(settings.onClickRight)])
            else if (settings.onClick)
                Quickshell.execDetached(["bash", "-lc", String(settings.onClick)])
        }
    }
}
