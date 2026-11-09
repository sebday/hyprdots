import QtQuick
import Quickshell
import Quickshell.Io
import qs.commons
import qs.ui

Item {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var settings: ({})

    readonly property string hoverPanelId: settings.onHover
        ? String(settings.onHover)
        : "evo.panels.network.stats"
    readonly property string script: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-bar-network")
    // Same MiB the panel uses when it labels a rate "MB/s".
    readonly property real fastDownloadBps: 1048576
    property real downloadBps: 0
    property real lastRxBytes: -1
    property real lastSampleMs: 0
    readonly property bool downloadingFast: downloadBps > fastDownloadBps

    implicitWidth: Theme.bar.iconSlot
    implicitHeight: Theme.barHeight
    width: implicitWidth
    height: Theme.barHeight

    function openPanel() {
        Util.openBarPanelFromClick(shell, hoverPanelId, root, barPanel)
    }

    function sampleRx() {
        if (!rxProc.running)
            rxProc.running = true
    }

    function applyRx(raw) {
        var lines = String(raw || "").split("\n")
        var rx = NaN
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (line.indexOf("rx_bytes\t") !== 0)
                continue
            var value = line.substring(9)
            rx = value === "" ? NaN : parseFloat(value)
            break
        }
        if (!isFinite(rx)) {
            downloadBps = 0
            lastRxBytes = -1
            lastSampleMs = 0
            return
        }
        var now = Date.now()
        if (lastRxBytes >= 0 && lastSampleMs > 0 && now > lastSampleMs) {
            var dt = (now - lastSampleMs) / 1000
            if (dt >= 0.4 && dt <= 20 && rx >= lastRxBytes)
                downloadBps = (rx - lastRxBytes) / dt
            else if (rx < lastRxBytes)
                downloadBps = 0
        }
        lastRxBytes = rx
        lastSampleMs = now
    }

    Timer {
        interval: 1500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.sampleRx()
    }

    Process {
        id: rxProc
        command: ["bash", root.script, "rx"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyRx(text)
        }
    }

    Item {
        anchors.centerIn: parent
        width: Theme.bar.iconCanvas
        height: Theme.bar.iconCanvas
        opacity: root.downloadingFast ? iconPulse.pulseOpacity : Theme.barIconOpacity

        OpticalGlyph {
            id: glyph
            anchors.fill: parent
            text: "󰈀"
            fontSize: Theme.bar.iconFont
            color: Theme.barIconColor
        }

        BarIconPulse {
            id: iconPulse
            running: root.downloadingFast
            bindColor: true
            target: glyph
            restColor: Theme.barIconColor
            activeColor: Theme.green
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                if (Util.pinHoverPanelFromBarIfActive(root.shell, root.hoverPanelId))
                    return
            }
            if (mouse.button === Qt.LeftButton)
                root.openPanel()
        }
    }
}
