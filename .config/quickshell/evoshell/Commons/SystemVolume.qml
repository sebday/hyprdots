pragma Singleton

import Quickshell
import QtQuick

Singleton {
    readonly property int lowMax: 20
    readonly property int midMax: 50

    function icon(level, muted) {
        if (muted) return "󰝟"
        var v = Number(level || 0)
        if (v <= lowMax) return "󰕿"
        if (v <= midMax) return "󰖀"
        return "󰕾"
    }

    function iconOpacity(level, muted) {
        if (muted) return 0.45
        var v = Number(level || 0)
        if (v <= lowMax) return 0.42
        return 0.9
    }

    function flashOpacity(flash) {
        return flash > 0 ? 0.55 + flash * 0.45 : 0
    }

    function flashLabelPixelSize(baseSize) {
        var n = parseInt(baseSize, 10)
        if (isNaN(n) || n <= 0) n = 18
        return Math.max(8, n - 5)
    }
}
