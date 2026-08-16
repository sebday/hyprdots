pragma Singleton

import Quickshell
import QtQuick

Singleton {
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

    function screenForOutput(outputName, fallbackOutput) {
        var screens = Quickshell.screens
        if (!screens || screens.length === 0)
            return null
        var output = String(outputName || "").trim()
        if (!output)
            output = String(fallbackOutput || "").trim()
        if (!output)
            return null
        for (var i = 0; i < screens.length; i++) {
            var screen = screens[i]
            if (screen && String(screen.name) === output)
                return screen
        }
        return null
    }

    function barOutputName(shell, fallbackOutput) {
        if (shell && shell.barConfig && shell.barConfig.output)
            return String(shell.barConfig.output).trim()
        return String(fallbackOutput || "").trim()
    }
}
