pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string themePath: Quickshell.shellDir + "/theme.json"

    property var themeData: ({})
    property var looksData: ({})

    readonly property string looksStatePath: (Quickshell.env("HOME") || "") + "/.local/state/evo-shell/hypr-looks.json"

    FileView {
        id: themeFile
        path: root.themePath
        watchChanges: true
        printErrors: false
        onLoaded: root.applyThemeFile()
        onLoadFailed: root.applyThemeFile()
        onFileChanged: reload()
    }

    FileView {
        id: looksFile
        path: root.looksStatePath
        watchChanges: true
        printErrors: false
        onLoaded: root.applyLooksFile()
        onLoadFailed: root.applyLooksFile()
        onFileChanged: reload()
    }

    function applyThemeFile() {
        var text = themeFile.text() || ""
        if (!text.trim()) {
            themeData = {}
            return
        }
        try {
            themeData = JSON.parse(text)
        } catch (e) {
            themeData = {}
        }
    }

    function applyLooksFile() {
        var text = looksFile.text() || ""
        if (!text.trim()) {
            looksData = {}
            return
        }
        try {
            looksData = JSON.parse(text)
        } catch (e) {
            looksData = {}
        }
    }

    function looksNumber(key, fallback) {
        var value = looksData[key]
        if (value === undefined || value === null || value === "")
            return fallback
        var n = Number(value)
        return isNaN(n) ? fallback : n
    }

    function themeColor(key, fallback) {
        var value = themeData[key]
        return value ? value : fallback
    }

    function themeNumber(key, fallback) {
        var value = themeData[key]
        if (value === undefined || value === null || value === "")
            return fallback
        var n = Number(value)
        return isNaN(n) ? fallback : n
    }

    function withOpacity(c, alpha) {
        return Qt.rgba(c.r, c.g, c.b, alpha)
    }

    function mixColors(a, b, t) {
        return Qt.rgba(
            a.r + (b.r - a.r) * t,
            a.g + (b.g - a.g) * t,
            a.b + (b.b - a.b) * t,
            1
        )
    }

    readonly property color foreground: themeColor("foreground", "#d3c6aa")
    readonly property color background: themeColor("background", "#2d353b")
    readonly property color accent: themeColor("accent", "#7fbbb3")
    readonly property color urgent: themeColor("urgent", "#e67e80")
    readonly property color mantle: themeColor("mantle", "#252b30")
    // Match hyprland decoration.active_opacity / inactive_opacity (evo settings → hypr-looks.json)
    readonly property real surfaceOpacity: looksNumber("activeOpacity", themeNumber("surfaceOpacity", 0.97))
    readonly property real surfaceOpacityInactive: looksNumber("inactiveOpacity", themeNumber("surfaceOpacityInactive", 0.88))
    readonly property real overlayScrimOpacity: themeNumber("overlayScrimOpacity", 0.72)
    readonly property color overlayScrim: withOpacity(mantle, overlayScrimOpacity)
    readonly property color overlaySurface: withOpacity(mantle, surfaceOpacity)
    readonly property color overlaySurfaceInactive: withOpacity(mantle, surfaceOpacityInactive)
    readonly property color panelBackground: overlaySurface
    property bool panelSurfaceActive: false
    readonly property color panelVeil: withOpacity(mantle, panelSurfaceActive ? surfaceOpacity : surfaceOpacityInactive)
    // Lift mantle toward foreground so row hover/selection reads on overlaySurface.
    readonly property real panelMantleLift: themeNumber("panelMantleLift", 0.12)
    readonly property color panelMantle: withOpacity(
        mixColors(mantle, foreground, panelMantleLift),
        surfaceOpacityInactive
    )
    readonly property string fontFamily: themeColor("fontFamily", "CaskaydiaMono Nerd Font")
    readonly property bool fontBold: true
    readonly property int fontPixelSize: themeNumber("fontPixelSize", 13)
    readonly property int barFontPixelSize: fontPixelSize
    readonly property int panelIconFontPixelSize: fontPixelSize + 3
    readonly property int panelTitleFontPixelSize: fontPixelSize + 1
    readonly property int panelSmallFontPixelSize: Math.max(9, fontPixelSize - 1)
    readonly property int panelDetailFontPixelSize: Math.max(9, fontPixelSize - 2)
    readonly property int panelHintFontPixelSize: Math.max(8, fontPixelSize - 3)
    readonly property int barHeight: 32
    readonly property int barPaddingX: 16
    readonly property int barGap: 8
    readonly property int barSectionGap: 14
    readonly property int sparklineGap: 6
    readonly property int sparklineChartMargin: 10
    readonly property int sparklineHeight: 12
    readonly property int sparklineBarWidth: 3
    readonly property int sparklineWideBarWidth: 8
    readonly property int sparklineCellSize: 7
    readonly property int sparklineBarSpacing: 1
    readonly property int sparklineExpandedHeight: 52
    readonly property int sparklineExpandedBarWidth: 10
    readonly property int sparklineExpandedBarSpacing: 3
    readonly property int sparklineExpandedPadding: 10
    readonly property int notificationWidth: 440
    readonly property int notificationPadding: 18
    readonly property int notificationTitleSize: 22
    readonly property int notificationBodySize: 18
    readonly property int notificationIconSize: 28
    readonly property int notificationStackSlot: 104

    Component.onCompleted: {
        applyThemeFile()
        applyLooksFile()
    }
}
