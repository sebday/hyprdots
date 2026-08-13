pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string overlayOutput: "DP-1"
    property string focusedOutputName: ""

    function fileUrl(path) {
        var value = String(path || "").trim()
        if (!value) return ""
        if (value.indexOf("file://") === 0) return value
        return "file://" + value
    }

    function shellQuote(value) {
        var s = String(value || "")
        return "'" + s.replace(/'/g, "'\\''") + "'"
    }

    function isPlainObject(value) {
        return value !== null && typeof value === "object" && !Array.isArray(value)
    }

    function screenForOutput(outputName, fallbackToFirst) {
        var screens = Quickshell.screens
        if (!screens || screens.length === 0) return null
        var output = String(outputName || "").trim()
        if (!output)
            return fallbackToFirst !== false ? screens[0] : null
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i]
            if (s && String(s.name) === output) return s
        }
        return fallbackToFirst !== false ? screens[0] : null
    }

    function screenForOverlay() {
        return screenForOutput(overlayOutput, true)
    }

    function hyprMonitorList() {
        var monitors = Hyprland.monitors
        if (!monitors) return []
        if (monitors.values) return monitors.values
        var out = []
        var n = monitors.count || 0
        for (var i = 0; i < n; i++) {
            var m = monitors.get ? monitors.get(i) : monitors[i]
            if (m) out.push(m)
        }
        return out
    }

    function updateFocusedOutput() {
        var name = ""
        try {
            var list = hyprMonitorList()
            for (var i = 0; i < list.length; i++) {
                var m = list[i]
                if (!m) continue
                if (m.focused) {
                    name = String(m.name || "")
                    break
                }
                var ipc = m.lastIpcObject
                if (ipc && ipc.focused) {
                    name = String(m.name || ipc.name || "")
                    break
                }
            }
            if (!name && Hyprland.focusedMonitor && Hyprland.focusedMonitor.name)
                name = String(Hyprland.focusedMonitor.name)
        } catch (e) {}
        if (name)
            focusedOutputName = name
    }

    function screenForFocused() {
        try { Hyprland.refreshMonitors() } catch (e) {}
        updateFocusedOutput()
        if (focusedOutputName) {
            var matched = screenForOutput(focusedOutputName, false)
            if (matched) return matched
        }
        return screenForOutput("", true)
    }

    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() { root.updateFocusedOutput() }
    }

    Process {
        id: focusSeed
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var mons = JSON.parse(String(text || "[]"))
                    for (var i = 0; i < mons.length; i++) {
                        if (mons[i] && mons[i].focused) {
                            root.focusedOutputName = String(mons[i].name)
                            break
                        }
                    }
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: {
        try { Hyprland.refreshMonitors() } catch (e) {}
        updateFocusedOutput()
        focusSeed.running = true
    }
}
