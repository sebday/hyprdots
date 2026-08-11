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

    function formatValue(val, prefix) {
        var n = parseFloat(val)
        if (isNaN(n)) return String(val || "")
        var sym = String(prefix || "")
        if (Math.abs(n) >= 1000) {
            var s = String(Math.round(n))
            var out = ""
            for (var i = 0; i < s.length; i++) {
                if (i > 0 && (s.length - i) % 3 === 0) out += ","
                out += s.charAt(i)
            }
            return sym + out
        }
        return sym + n.toFixed(2)
    }
}
