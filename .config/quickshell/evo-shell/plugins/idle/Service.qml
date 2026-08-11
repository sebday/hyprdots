import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: root

    property var shell: null

    readonly property int defaultScreensaverSeconds: 1800
    readonly property int defaultLockSeconds: 900
    readonly property var idleConfig: shell && shell.shellConfig && shell.shellConfig.idle ? shell.shellConfig.idle : ({})
    readonly property int screensaverTimeoutSeconds: secondsFromConfig(idleConfig.screensaver, defaultScreensaverSeconds)
    readonly property int lockTimeoutSeconds: secondsFromConfig(idleConfig.lock, defaultLockSeconds)
    readonly property int firstIdleTimeoutSeconds: Math.min(screensaverTimeoutSeconds, lockTimeoutSeconds)
    readonly property int screensaverDelaySeconds: Math.max(0, screensaverTimeoutSeconds - firstIdleTimeoutSeconds)
    readonly property int lockDelaySeconds: Math.max(0, lockTimeoutSeconds - firstIdleTimeoutSeconds)

    property bool idledThisCycle: false
    property string lastEvent: "starting"

    function secondsFromConfig(value, fallback) {
        var n = parseInt(value, 10)
        return isNaN(n) || n < 0 ? fallback : n
    }

    function logEvent(event) {
        lastEvent = event
        console.log("evo idle " + new Date().toISOString() + " " + event)
    }

    function lockSystem() {
        logEvent("lock-requested")
        screensaverTimer.stop()
        lockTimer.stop()
        idledThisCycle = false
        if (!lockProc.running) lockProc.running = true
    }

    function blankDisplays() {
        logEvent("screensaver-blank")
        if (!blankProc.running) blankProc.running = true
    }

    function wakeDisplays() {
        if (!wakeProc.running) wakeProc.running = true
    }

    function startIdleCycle() {
        if (idledThisCycle) return
        logEvent("idle-cycle-start")
        idledThisCycle = true
        if (screensaverDelaySeconds === 0) blankDisplays()
        else screensaverTimer.restart()
        if (lockDelaySeconds === 0) lockSystem()
        else lockTimer.restart()
    }

    function cancelIdleCycle(reason) {
        logEvent("idle-cycle-cancel:" + reason)
        screensaverTimer.stop()
        lockTimer.stop()
        if (idledThisCycle) wakeDisplays()
        idledThisCycle = false
    }

    function handleIdleChanged() {
        if (idleMonitor.isIdle) startIdleCycle()
        else cancelIdleCycle("activity")
    }

    IdleMonitor {
        id: idleMonitor
        enabled: true
        timeout: root.firstIdleTimeoutSeconds
        respectInhibitors: true
        onIsIdleChanged: root.handleIdleChanged()
    }

    Timer {
        id: screensaverTimer
        interval: root.screensaverDelaySeconds * 1000
        repeat: false
        onTriggered: root.blankDisplays()
    }

    Timer {
        id: lockTimer
        interval: root.lockDelaySeconds * 1000
        repeat: false
        onTriggered: if (root.idledThisCycle) root.lockSystem()
    }

    Process {
        id: lockProc
        command: ["bash", "-lc", "$HOME/.local/bin/evo-shell-ipc lock lock"]
    }

    Process {
        id: blankProc
        command: ["bash", "-lc", "hyprctl dispatch dpms off 2>/dev/null || true"]
    }

    Process {
        id: wakeProc
        command: ["bash", "-lc", "hyprctl dispatch dpms on 2>/dev/null || true"]
    }

    IpcHandler {
        target: "idle"

        function status(): string {
            return JSON.stringify({
                idle: idleMonitor.isIdle,
                inIdleCycle: root.idledThisCycle,
                screensaver: root.screensaverTimeoutSeconds,
                lock: root.lockTimeoutSeconds,
                lastEvent: root.lastEvent
            })
        }
    }

    Component.onCompleted: logEvent("service-ready")
}
