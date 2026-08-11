pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string themePath: Quickshell.shellDir + "/theme.json"

    property var themeData: ({})

    FileView {
        id: themeFile
        path: root.themePath
        watchChanges: true
        printErrors: false
        onLoaded: root.applyThemeFile()
        onLoadFailed: root.applyThemeFile()
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

    readonly property color foreground: themeColor("foreground", "#d3c6aa")
    readonly property color background: themeColor("background", "#2d353b")
    readonly property color accent: themeColor("accent", "#7fbbb3")
    readonly property color urgent: themeColor("urgent", "#e67e80")
    readonly property color mantle: themeColor("mantle", "#252b30")
    // Match hyprland decoration.active_opacity / inactive_opacity in ~/.config/hypr/looks.lua
    readonly property real surfaceOpacity: themeNumber("surfaceOpacity", 0.97)
    readonly property real surfaceOpacityInactive: themeNumber("surfaceOpacityInactive", 0.88)
    readonly property color panelBackground: withOpacity(background, surfaceOpacity)
    readonly property color panelMantle: withOpacity(mantle, surfaceOpacity)
    readonly property string fontFamily: "CaskaydiaMono Nerd Font"
    readonly property bool fontBold: true
    readonly property int fontPixelSize: 13
    readonly property int barHeight: 32
    readonly property int barPaddingX: 16
    readonly property int barGap: 8
    readonly property int barSectionGap: 14
    readonly property int sparklineGap: 6
    readonly property int sparklineChartMargin: 10
    readonly property int sparklineHeight: 12
    readonly property int sparklineBarWidth: 3
    readonly property int sparklineWideBarWidth: 6
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

    Component.onCompleted: applyThemeFile()
}
