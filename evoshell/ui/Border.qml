pragma Singleton

import QtQuick
import Quickshell
import qs.commons

// Uniform flat border specs: { color, widths: { top, right, bottom, left } }.
Singleton {
    function widths(width) {
        var n = Math.max(0, Math.round(Number(width) || 0))
        return { top: n, right: n, bottom: n, left: n }
    }

    function flat(color, width) {
        return { color: color || "transparent", widths: widths(width) }
    }

    function none() {
        return flat("transparent", 0)
    }

    function surfaceSpec(section, token, color, fallbackWidth) {
        return flat(color, fallbackWidth === undefined ? Theme.space(2) : fallbackWidth)
    }

    function localOrSurfaceSpec(section, token, localColor, defaultColor, fallbackWidth) {
        return flat(localColor || defaultColor, fallbackWidth)
    }

    function controlWidth(state) {
        if (state === "focus") return Theme.focusBorderWidth
        if (state === "hover" || state === "hover-cursor") return Theme.hoverBorderWidth
        if (state === "selected") return Theme.selectedBorderWidth
        return Theme.normalBorderWidth
    }

    function controlSpec(state, foreground, accent, urgent) {
        var color
        if (state === "focus") color = Theme.focusBorderFor(foreground, accent, urgent)
        else if (state === "hover" || state === "hover-cursor") color = Theme.hoverBorderFor(foreground, accent, urgent)
        else if (state === "selected") color = Theme.selectedBorderFor(foreground, accent, urgent)
        else color = Theme.normalBorderFor(foreground, accent, urgent)
        return flat(color, controlWidth(state))
    }

    function controlHasWidth(state) { return controlWidth(state) > 0 }
    function needsOverlay(spec) { return false }
    function canUseNative(spec) { return true }
    function top(spec) { return spec && spec.widths ? spec.widths.top : 0 }
    function right(spec) { return spec && spec.widths ? spec.widths.right : 0 }
    function bottom(spec) { return spec && spec.widths ? spec.widths.bottom : 0 }
    function left(spec) { return spec && spec.widths ? spec.widths.left : 0 }
    function uniformWidth(spec) { return spec && spec.widths ? spec.widths.top : 0 }
    function color(spec) { return spec ? spec.color : "transparent" }
}
