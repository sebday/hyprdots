import Quickshell.Io
import QtQuick

Item {
    id: root

    property var shell: null
    property var settings: ({})
    property var command: []
    property int defaultIntervalSec: 60
    property var value: ({})
    property bool loading: false
    property bool active: true
    property string cacheKey: ""
    property bool keepStale: true

    signal polled(var json)

    function parseJson(raw) {
        try {
            return JSON.parse(String(raw || "").trim() || "{}")
        } catch (e) {
            return ({})
        }
    }

    function hasValue() {
        return value && typeof value === "object" && Object.keys(value).length > 0
    }

    function restoreFromCache() {
        if (!shell || !cacheKey)
            return false
        var cached = Util.hoverPopupCacheRead(shell, cacheKey)
        if (!cached || typeof cached !== "object" || Object.keys(cached).length === 0)
            return false
        value = cached
        polled(cached)
        return true
    }

    function publishCache(json) {
        if (!shell || !cacheKey || !json || typeof json !== "object")
            return
        Util.hoverPopupCacheWrite(shell, cacheKey, json)
    }

    function runPoll() {
        if (!active || !command || command.length === 0)
            return
        if (!(keepStale && hasValue()))
            loading = true
        proc.running = false
        proc.running = true
    }

    function restartPolling() {
        var sec = Math.max(1, parseInt(settings.interval, 10) || defaultIntervalSec)
        intervalTimer.interval = sec * 1000
        intervalTimer.stop()
        runPoll()
        if (active)
            intervalTimer.start()
    }

    Process {
        id: proc
        command: root.command
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                root.value = root.parseJson(text)
                root.publishCache(root.value)
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
    onShellChanged: {
        if (shell && !hasValue())
            restoreFromCache()
    }
    onActiveChanged: {
        if (active) {
            if (!hasValue())
                restoreFromCache()
            restartPolling()
        } else {
            intervalTimer.stop()
        }
    }

    Component.onCompleted: {
        if (!hasValue())
            restoreFromCache()
        if (active)
            restartPolling()
    }
}
