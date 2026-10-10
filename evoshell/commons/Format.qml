pragma Singleton

import Quickshell
import QtQuick

Singleton {
    function formatRevenue(val, symbol) {
        var n = Math.round(parseFloat(val) || 0)
        var s = String(n)
        var out = ""
        for (var i = 0; i < s.length; i++) {
            if (i > 0 && (s.length - i) % 3 === 0) out += ","
            out += s.charAt(i)
        }
        return String(symbol || "£") + out
    }

    function tempColor(temp) {
        var t = Number(temp)
        if (t >= 30) return Theme.urgent
        if (t >= 24) return Theme.mixColors(Theme.accent, Theme.urgent, 0.62)
        return Theme.accent
    }

    function usagePercentColor(percent) {
        var p = Number(percent)
        if (isNaN(p))
            return Theme.foreground
        p = Math.max(0, Math.min(100, p))
        if (p >= 80)
            return Theme.urgent
        if (p >= 40)
            return Theme.mixColors(Theme.accent, Theme.urgent, (p - 40) / 40)
        return Theme.mixColors(Theme.foreground, Theme.accent, p / 40)
    }
}
