pragma Singleton

import Quickshell
import QtQuick

Singleton {
    function formatDay(iso) {
        if (!iso) return ""
        var parts = String(iso).split("-")
        if (parts.length < 3) return String(iso)
        var d = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10))
        var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return days[d.getDay()] + " " + d.getDate()
    }

    function headerLines(parts, fallback) {
        if (!parts || parts.length === 0)
            return fallback
        if (parts.length === 1)
            return parts[0]
        return parts[0] + "\n" + parts.slice(1).join(" · ")
    }

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
}
