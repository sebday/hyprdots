import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../commons"

Item {
    id: root

    property var shell: null
    readonly property string home: Quickshell.env("HOME") || ""

    readonly property int defaultLockSeconds: 900
    readonly property var idleConfig: shell && shell.shellConfig && shell.shellConfig.idle ? shell.shellConfig.idle : ({})
    readonly property int lockTimeoutSeconds: secondsFromConfig(idleConfig.lock, defaultLockSeconds)

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
        var lockSvc = shell && typeof shell.serviceFor === "function"
            ? shell.serviceFor("evo.sys.lock-screen.lock")
            : null
        if (lockSvc && typeof lockSvc.beginLock === "function") {
            lockSvc.beginLock()
            return
        }
        if (!lockProc.running) lockProc.running = true
    }

    IdleMonitor {
        id: idleMonitor
        enabled: true
        timeout: root.lockTimeoutSeconds
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) root.lockSystem()
    }

    Process {
        id: lockProc
        command: Util.evoshellIpcCommand(home, shell, ["evo.sys.lock-screen.lock", "lock"])
    }

    IpcHandler {
        target: "evo.sys.lock-screen.idle"

        function status(): string {
            return JSON.stringify({
                idle: idleMonitor.isIdle,
                lock: root.lockTimeoutSeconds,
                lastEvent: root.lastEvent
            })
        }
    }

    Component.onCompleted: logEvent("service-ready")
}
