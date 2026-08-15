pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string themePath: Quickshell.shellDir + "/theme.json"

    property var themeData: ({})
    property var looksData: ({})

    readonly property string looksStatePath: (Quickshell.env("HOME") || "") + "/.local/state/evoshell/hypr-looks.json"
    readonly property string iconsThemePath: (Quickshell.env("HOME") || "") + "/.themes/current/icons.theme"

    property string iconThemeName: ""

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

    FileView {
        id: iconsThemeFile
        path: root.iconsThemePath
        watchChanges: true
        printErrors: false
        onLoaded: root.applyIconsThemeFile()
        onLoadFailed: root.iconThemeName = ""
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

    function applyIconsThemeFile() {
        var text = iconsThemeFile.text() || ""
        var line = text.split("\n")[0] || ""
        iconThemeName = line.trim()
    }

    function reloadLooks() {
        looksFile.reload()
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
    // Hyprland general:col.inactive_border default when unset (ff444444).
    readonly property color inactiveBorder: themeColor("inactiveBorder", "#444444")
    readonly property color mantle: themeColor("mantle", "#252b30")
    // Match hyprland decoration.active_opacity / inactive_opacity (evo settings → hypr-looks.json)
    readonly property real surfaceOpacity: {
        var value = looksData.activeOpacity
        if (value === undefined || value === null || value === "")
            return themeNumber("surfaceOpacity", 0.97)
        var n = Number(value)
        return isNaN(n) ? themeNumber("surfaceOpacity", 0.97) : n
    }
    readonly property real surfaceOpacityInactive: {
        var value = looksData.inactiveOpacity
        if (value === undefined || value === null || value === "")
            return themeNumber("surfaceOpacityInactive", 0.88)
        var n = Number(value)
        return isNaN(n) ? themeNumber("surfaceOpacityInactive", 0.88) : n
    }
    readonly property bool roundingOn: looksData.roundingOn === true
    readonly property bool gapsOn: looksData.gapsOn === true
    readonly property int gapsOut: gapsOn ? 20 : 0
    readonly property int panelCornerRadius: roundingOn ? 4 : 0
    readonly property int fieldsetCornerRadius: 4
    readonly property real overlayScrimOpacity: themeNumber("overlayScrimOpacity", 0.72)
    readonly property color overlayScrim: withOpacity(mantle, overlayScrimOpacity)
    readonly property color overlaySurface: withOpacity(mantle, surfaceOpacity)
    readonly property color overlaySurfaceInactive: withOpacity(mantle, surfaceOpacityInactive)
    readonly property color panelBackground: overlaySurface
    readonly property real panelMantleLift: themeNumber("panelMantleLift", 0.12)
    readonly property color panelMantle: mixColors(mantle, foreground, panelMantleLift)
    readonly property string fontFamily: themeColor("fontFamily", "CaskaydiaMono Nerd Font")
    readonly property bool fontBold: true
    readonly property int fontPixelSize: themeNumber("fontPixelSize", 13)
    readonly property int barFontPixelSize: fontPixelSize
    readonly property int panelIconFontPixelSize: fontPixelSize + 3
    readonly property int panelTitleFontPixelSize: fontPixelSize + 1
    readonly property int panelSmallFontPixelSize: Math.max(9, fontPixelSize - 1)
    readonly property int panelDetailFontPixelSize: Math.max(9, fontPixelSize - 2)
    readonly property int panelHintFontPixelSize: Math.max(8, fontPixelSize - 3)
    readonly property int tooltipBodyFontPixelSize: fontPixelSize + 6
    readonly property int tooltipHintFontPixelSize: fontPixelSize + 2
    readonly property int tooltipTitleFontPixelSize: fontPixelSize + 6
    readonly property int tooltipIconFontPixelSize: fontPixelSize + 8
    readonly property int tooltipLabelFontPixelSize: fontPixelSize + 1
    readonly property int tooltipSectionSpacing: 10
    readonly property int panelSectionSpacing: 14
    readonly property int tooltipContentPad: 16
    readonly property int panelContentPad: 10
    readonly property int tooltipMargin: 16
    readonly property int tooltipWidthStandard: 440
    readonly property int tooltipWidthWide: 580
    readonly property int popupHeroFontPixelSize: fontPixelSize * 4
    readonly property int popupTitleFontPixelSize: fontPixelSize * 3
    readonly property int popupBodyFontPixelSize: fontPixelSize * 2
    readonly property int popupSmallFontPixelSize: Math.max(9, fontPixelSize - 1) * 2
    readonly property int popupHintFontPixelSize: Math.max(8, fontPixelSize - 3) * 2
    readonly property int barHeight: 32
    readonly property int barPaddingX: 16
    readonly property int barGap: 8
    readonly property int barSectionGap: 14
    readonly property int sparklineGap: 6
    readonly property int sparklineChartMargin: 10
    readonly property int sparklineHeight: 12
    readonly property int sparklineWideBarWidth: 8
    readonly property int sparklineCellSize: 7
    readonly property int sparklineBarSpacing: 1
    readonly property int sparklineExpandedHeight: 52
    readonly property int sparklineExpandedBarWidth: 10
    readonly property int sparklineExpandedBarSpacing: 3
    readonly property int notificationWidth: 500
    readonly property int notificationPadding: 16
    readonly property int notificationTitleSize: 22
    readonly property int notificationBodySize: 18
    readonly property int notificationIconSize: 28
    readonly property int notificationArtSize: 80
    readonly property int notificationVolumeHeight: 80
    readonly property int notificationMediaPad: 22
    readonly property int notificationStackSlot: 104

    Component.onCompleted: {
        applyThemeFile()
        applyLooksFile()
        applyIconsThemeFile()
    }
}
