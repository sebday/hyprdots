pragma Singleton

import Quickshell
import QtQuick

Singleton {
    readonly property int lowMax: 19
    readonly property int midMax: 49

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
}
