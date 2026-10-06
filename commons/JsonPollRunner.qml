import Quickshell.Io
import QtQuick
import "."

Item {
    id: root

    property var shell: null
    property var settings: ({})
    property var command: []
    property int defaultIntervalSec: 60
    property int timeoutSec: 30
    property var value: ({})
    property bool loading: false
    property bool active: true
    property bool autoStart: true
    property string cacheKey: ""
    property bool keepStale: true
    property int maxStdoutBytes: 262144
    readonly property bool running: proc.running

    signal polled(var json)
    signal exited(int exitCode, string stdoutText, string stderrText)

    function run(command) {
        if (!command || command.length === 0 || proc.running)
            return false
        proc.execCommand = command
        startPollWatchdog()
        proc.running = true
        return true
    }

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
        var cached = Util.hoverPanelCacheRead(shell, cacheKey)
        if (!cached || typeof cached !== "object" || Object.keys(cached).length === 0)
            return false
        value = cached
        polled(cached)
        return true
    }

    function publishCache(json) {
        if (!shell || !cacheKey || !json || typeof json !== "object")
            return
        Util.hoverPanelCacheWrite(shell, cacheKey, json)
    }

    function stopPollWatchdog() {
        pollWatchdog.stop()
    }

    function startPollWatchdog() {
        var ms = Math.max(1000, (parseInt(timeoutSec, 10) || 30) * 1000)
        pollWatchdog.interval = ms
        pollWatchdog.stop()
        pollWatchdog.start()
    }

    function runPoll() {
        if (!active || !command || command.length === 0)
            return
        if (!(keepStale && hasValue()))
            loading = true
        proc.running = false
        proc.running = true
        startPollWatchdog()
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
        property var execCommand: root.command
        command: execCommand
        onStarted: {
            stdoutBuf = ""
            stderrBuf = ""
        }

        property string stdoutBuf: ""
        property string stderrBuf: ""

        stdout: SplitParser {
            splitMarker: ""
            onRead: function(chunk) {
                proc.stdoutBuf += chunk
                if (proc.stdoutBuf.length > root.maxStdoutBytes) {
                    proc.signal(15)
                    proc.stdoutBuf = ""
                }
            }
        }
        stderr: SplitParser {
            splitMarker: ""
            onRead: function(chunk) {
                proc.stderrBuf += chunk
                if (proc.stderrBuf.length > 4096) {
                    proc.signal(15)
                    proc.stderrBuf = ""
                }
            }
        }
        onExited: function(exitCode) {
            root.stopPollWatchdog()
            root.loading = false
            var out = String(proc.stdoutBuf || "")
            var err = String(proc.stderrBuf || "")
            root.exited(exitCode, out, err)
            if (exitCode === 0 && String(out).trim() !== "") {
                root.value = root.parseJson(out)
                root.publishCache(root.value)
                root.polled(root.value)
            }
        }
    }

    Timer {
        id: pollWatchdog
        repeat: false
        onTriggered: {
            if (!proc.running)
                return
            proc.running = false
            root.loading = false
        }
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
        if (!autoStart)
            return
        if (active) {
            if (!hasValue())
                restoreFromCache()
            restartPolling()
        } else {
            intervalTimer.stop()
            stopPollWatchdog()
        }
    }

    Component.onCompleted: {
        if (!autoStart)
            return
        if (!hasValue())
            restoreFromCache()
        if (active)
            restartPolling()
    }
}
