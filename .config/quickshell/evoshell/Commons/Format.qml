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

    function tempColor(temp) {
        var t = Number(temp)
        if (t >= 30) return Theme.urgent
        if (t >= 24) return Theme.mixColors(Theme.accent, Theme.urgent, 0.62)
        return Theme.accent
    }

    function usagePercentColor(percent) {
        var p = Number(percent)
        if (isNaN(p)) return Theme.foreground
        if (p >= 80) return Theme.urgent
        if (p >= 50) return Theme.mixColors(Theme.accent, Theme.urgent, 0.62)
        return Theme.accent
    }

    function contributionColor(count) {
        var n = parseInt(count, 10) || 0
        var colors = ["#45475a", "#89b4fa", "#74c7ec", "#89dceb", "#cba6f7"]
        var level = 0
        if (n >= 30) level = 4
        else if (n >= 18) level = 3
        else if (n >= 10) level = 2
        else if (n >= 1) level = 1
        return colors[level]
    }
}
