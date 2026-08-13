pragma Singleton

import Quickshell
import QtQuick

Singleton {
    readonly property string overlayOutput: "DP-1"

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
}
