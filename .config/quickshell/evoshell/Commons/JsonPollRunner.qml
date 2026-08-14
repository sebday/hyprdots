import Quickshell.Io
import QtQuick

Item {
    id: root

    property var settings: ({})
    property var command: []
    property int defaultIntervalSec: 60
    property var value: ({})
    property bool loading: false
    property bool active: true

    signal polled(var json)

    function parseJson(raw) {
        try {
            return JSON.parse(String(raw || "").trim() || "{}")
        } catch (e) {
            return ({})
        }
    }

    function runPoll() {
        if (!active || !command || command.length === 0) return
        loading = true
        proc.running = false
        proc.running = true
    }

    function restartPolling() {
        var sec = Math.max(1, parseInt(settings.interval, 10) || defaultIntervalSec)
        intervalTimer.interval = sec * 1000
        intervalTimer.stop()
        runPoll()
        if (active) intervalTimer.start()
    }

    Process {
        id: proc
        command: root.command
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                root.value = root.parseJson(text)
                root.polled(root.value)
            }
        }
        onExited: root.loading = false
    }

    Timer {
        id: intervalTimer
        repeat: true
        onTriggered: root.runPoll()
    }

    onSettingsChanged: if (active) restartPolling()
    onCommandChanged: if (active) restartPolling()
    onActiveChanged: {
        if (active) restartPolling()
        else intervalTimer.stop()
    }

    Component.onCompleted: if (active) restartPolling()
}
