pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string stateDir: Util.stateDir(Quickshell.env("HOME") || "")
    readonly property string configDir: Util.configDir(Quickshell.env("HOME") || "")

    readonly property string themePath: root.stateDir + "/theme.json"

    readonly property string looksConfigPath: root.configDir + "/hypr-looks.json"

    readonly property string uiConfigPath: root.configDir + "/ui.json"

    property var themeData: ({})
    property var looksData: ({})
    property var uiData: ({})

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
        path: root.looksConfigPath
        watchChanges: true
        printErrors: false
        onLoaded: root.applyLooksFile()
        onLoadFailed: root.applyLooksFile()
        onFileChanged: reload()
    }

    FileView {
        id: uiFile
        path: root.uiConfigPath
        watchChanges: true
        printErrors: false
        onLoaded: root.applyUiFile()
        onLoadFailed: root.applyUiFile()
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

    function applyUiFile() {
        var text = uiFile.text() || ""
        if (!text.trim()) {
            uiData = {}
            return
        }
        try {
            uiData = JSON.parse(text)
        } catch (e) {
            uiData = {}
        }
    }

    function reloadLooks() {
        looksFile.reload()
    }

    function reloadUi() {
        uiFile.reload()
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
    readonly property color highlight: themeColor("highlight", "#bd93f9")
    // Hyprland general:col.inactive_border default when unset (ff444444).
    readonly property color inactiveBorder: themeColor("inactiveBorder", "#444444")
    readonly property color mantle: themeColor("mantle", "#252b30")
    readonly property string iconThemeName: themeColor("iconTheme", "")
    // Match hyprland decoration.active_opacity / inactive_opacity (settings → hypr-looks.json)
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
    readonly property int shellCornerRadiusPx: {
        var value = looksData.rounding
        if (value !== undefined && value !== null && value !== "") {
            var n = Number(value)
            if (!isNaN(n) && n > 0)
                return Math.round(n)
        }
        return 7
    }
    readonly property int panelCornerRadius: roundingOn ? shellCornerRadiusPx : 0
    readonly property bool fieldsetRoundingOn: uiData.fieldsetRounding !== false
    readonly property int fieldsetCornerRadius: fieldsetRoundingOn ? shellCornerRadiusPx : 0
    readonly property color overlaySurface: withOpacity(mantle, surfaceOpacity)
    readonly property color overlaySurfaceInactive: withOpacity(mantle, surfaceOpacityInactive)
    readonly property color panelBackground: overlaySurface
    readonly property real panelMantleLift: themeNumber("panelMantleLift", 0.12)
    readonly property color panelMantle: mixColors(mantle, foreground, panelMantleLift)
    readonly property color heatmap0: mixColors(mantle, foreground, 0.12)
    readonly property color heatmap1: mixColors(mantle, accent, 0.4)
    readonly property color heatmap2: mixColors(mantle, accent, 0.6)
    readonly property color heatmap3: mixColors(mantle, accent, 0.8)
    readonly property color heatmap4: accent
    readonly property var heatmapColors: [heatmap0, heatmap1, heatmap2, heatmap3, heatmap4]
    readonly property color recapArtistsTint: mixColors(mantle, accent, 0.52)
    readonly property color recapAlbumsTint: mixColors(mantle, urgent, 0.52)
    readonly property color recapTracksTint: mixColors(mantle, highlight, 0.52)
    readonly property var chartPalette: [
        accent,
        mixColors(accent, foreground, 0.4),
        mixColors(mantle, foreground, 0.5),
        mixColors(accent, urgent, 0.35)
    ]

    // Bar poll intervals (fixed; not user-configurable)
    readonly property int pollGithubSec: 60
    readonly property int pollCloudflareSec: 60
    readonly property int pollHomeAssistantSec: 60
    readonly property int pollWeatherSec: 300
    readonly property int pollNetworkSec: 2

    // Motion
    readonly property int motionFast: 120
    readonly property int motionNormal: 180
    readonly property int motionSlow: 220

    // Semantic surface fills
    readonly property color fillNeutralSubtle: foregroundFaint
    readonly property color fillAccentSubtle: withOpacity(accent, 0.14)
    readonly property color fillUrgentSubtle: withOpacity(urgent, 0.14)
    readonly property real opacityBodyText: 0.85

    // Opacity scale
    readonly property real opacityDisabled: 0.45
    readonly property real opacityMuted: 0.55
    readonly property real opacityHover: 0.65
    readonly property real opacitySecondary: 0.72
    readonly property real opacityEmphasis2: 0.82
    readonly property real opacityEmphasis: opacityEmphasis2

    // Bar icon tokens
    readonly property color barIconColor: foreground
    readonly property color barIconColorActive: accent
    readonly property real barIconOpacity: opacityEmphasis2
    readonly property real barIconOpacityActive: 1
    readonly property real barIconOpacityDim: 0.45
    readonly property real barIconPulseMin: 0.55
    readonly property real barIconPulseMax: 1
    readonly property int barIconPulseDuration: 700

    // Fieldset tokens
    readonly property color fieldsetBorderColor: foregroundBorder
    readonly property int fieldsetBorderWidth: 1
    readonly property int fieldsetLegendInset: spacingS
    readonly property int fieldsetLegendMinHeight: fontSizeS + spacingS

    // Hover popup stat grid tokens
    readonly property int hoverPanelStatColumnSpacing: spacingM
    readonly property int hoverPanelStatRowSpacing: spacingS
    readonly property int hoverPanelStatValueFont: fontSizeL
    readonly property int hoverPanelStatLabelFont: fontSizeS

    // Foreground alpha colours
    readonly property color foregroundGhost: withOpacity(foreground, 0.05)
    readonly property color foregroundWash: withOpacity(foreground, 0.06)
    readonly property color foregroundFaint: withOpacity(foreground, 0.08)
    readonly property color foregroundHoverWash: withOpacity(foreground, 0.1)
    readonly property color foregroundRaised: withOpacity(foreground, 0.12)
    readonly property color foregroundDivider: withOpacity(foreground, 0.14)
    readonly property color foregroundSubtle: withOpacity(foreground, 0.16)
    readonly property color foregroundTrack: withOpacity(foreground, 0.18)
    readonly property color foregroundPickerBorder: withOpacity(foreground, 0.22)
    readonly property color foregroundBorder: withOpacity(foreground, 0.32)

    // Spacing scale
    readonly property int spacing2: 2
    readonly property int spacingS: 6
    readonly property int spacingM: 8
    readonly property int spacingL: 10
    readonly property int settingsNavRowPad: spacingL
    readonly property int panelLabelPadH: spacingS

    // Radius scale
    readonly property int radiusS: 2
    readonly property int radiusM: 3
    readonly property int radiusL: fieldsetCornerRadius
    readonly property int radiusToggleTrack: 12
    readonly property int radiusToggleThumb: 9

    readonly property string fontFamily: themeColor("fontFamily", "CaskaydiaMono Nerd Font")
    readonly property bool fontBold: true
    readonly property int fontPixelSize: themeNumber("fontPixelSize", 13)
    readonly property int fontSizeXxs: Math.max(8, fontPixelSize - 3)
    readonly property int fontSizeXs: Math.max(9, fontPixelSize - 2)
    readonly property int fontSizeS: Math.max(9, fontPixelSize - 1)
    readonly property int fontSizeM: fontPixelSize
    readonly property int fontSizeL: fontPixelSize + 1
    readonly property int fontSizeXl: fontPixelSize + 2
    readonly property int fontSize2xl: fontPixelSize + 3
    readonly property int fontSize3xl: fontPixelSize + 5
    readonly property int fontSize4xl: fontPixelSize + 7
    readonly property int fontSize5xl: fontPixelSize + 8
    readonly property int fontSize6xl: fontPixelSize + 9
    readonly property int fontSize7xl: fontSizeS * 2
    readonly property int fontSize8xl: fontPixelSize * 2
    readonly property int fontSize9xl: fontPixelSize + 15
    readonly property int fontSizeHero: fontPixelSize * 3
    readonly property int fontSizeHeroLg: fontPixelSize * 4
    readonly property int hoverPanelSectionSpacing: 10
    readonly property int panelSectionSpacing: 14
    readonly property int hoverPanelContentPad: 16
    readonly property int panelContentPad: 10
    readonly property int panelDockPad: panelContentPad + spacingS
    readonly property int hoverPanelMargin: 16
    readonly property int hoverPanelTopPad: hoverPanelMargin - 10
    readonly property int hoverPanelBorderWidth: 2
    readonly property int hoverPanelRevealDuration: motionNormal
    readonly property int hoverPanelRevealOffset: 10
    readonly property int hoverPanelRevealMaxWait: 200
    readonly property int barHoverTopPad: 10
    readonly property int barHoverContentTopPad: barHoverTopPad - 10
    readonly property int overlayWidthDefault: hoverPanelWidthStandard
    readonly property int overlayMargin: hoverPanelMargin
    readonly property int overlayContentInset: hoverPanelMargin + hoverPanelBorderWidth
    readonly property int overlayTopInset: hoverPanelTopPad + hoverPanelBorderWidth
    readonly property int overlaySideInset: overlayContentInset
    readonly property real specialWorkspaceDim: 0.6
    readonly property int screenEdgeInset: barHoverTopPad
    readonly property int hoverPanelWidthStandard: 440
    readonly property int hoverPanelWidthWide: 580
    readonly property int overlayPanelWidth: 600
    readonly property int systemPanelWidth: 800
    readonly property int systemMenuPanelWidth: 480
    readonly property real menuPanelHeightRatio: 0.5
    readonly property real menuPanelWidthRatio: 0.25
    readonly property int settingsSideTabWidth: 152
    readonly property int settingsSideTabIconWidth: 24
    readonly property int systemMenuPanelHeight: 600

    function menuPanelHeight(screenHeight) {
        var h = screenHeight > 0 ? screenHeight : 1080
        return Math.max(320, Math.round(h * menuPanelHeightRatio))
    }

    function menuPanelWidth(screenWidth) {
        var w = screenWidth > 0 ? screenWidth : 1920
        return Math.round(w * menuPanelWidthRatio)
    }
    readonly property int settingsPanelWidth: systemPanelWidth
    readonly property int systemMenuWidth: systemMenuPanelWidth
    readonly property int clipboardPanelWidth: Math.round(systemPanelWidth / 2)
    readonly property int barHeight: 32
    readonly property int barPaddingX: 16
    readonly property int barGap: 8
    readonly property int barSectionGap: 14
    readonly property int sparklineGap: 6
    readonly property int sparklineChartMargin: 10
    readonly property int hoverPanelChartPadH: sparklineChartMargin + spacingS
    readonly property int sparklineHeight: 12
    readonly property int sparklineWideBarWidth: 8
    readonly property int sparklineCellSize: 7
    readonly property int sparklineBarSpacing: 1
    readonly property int sparklineExpandedHeight: 52
    readonly property int sparklineExpandedBarWidth: 10
    readonly property int sparklineExpandedBarSpacing: 3
    readonly property int notificationWidth: 440
    readonly property int notificationPadding: 14
    readonly property int notificationArtSize: 84
    readonly property int notificationMediaPad: 16
    readonly property int notificationStackSlot: 104

    Component.onCompleted: {
        applyThemeFile()
        applyLooksFile()
        applyUiFile()
    }
}
