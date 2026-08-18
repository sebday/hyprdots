import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../../Commons"

Item {
    id: root

    property var host: null
    property var shell: null

    readonly property string hyprScript: Quickshell.env("HOME") + "/.local/bin/evo-hyprland"
    readonly property string barScript: Quickshell.env("HOME") + "/.local/bin/evo-layout"
    readonly property string fontScript: Quickshell.env("HOME") + "/.local/bin/evo-font"
    readonly property string mediaScript: Quickshell.env("HOME") + "/.local/bin/evo-media"
    readonly property string fontStatePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/evoshell/font.json"
    readonly property string themeNamePath: Quickshell.env("HOME") + "/.themes/current/.theme-name"

    property bool roundingOn: false
    property string currentThemeName: ""
    property bool gapsOn: false
    property bool animationsOn: false
    property int activeOpacityPercent: 97
    property int inactiveOpacityPercent: 88
    property bool barOnDp1Top: false
    property bool notificationsOnHdmiBottom: true
    property bool fieldsetRoundingOn: true
    property string fontFamily: "CaskaydiaMono Nerd Font"
    property var fontFamilies: []
    property var mediaShows: []
    property string mediaTvRoot: ""
    property bool hyprReady: false
    property bool barReady: false
    property bool notificationsReady: false
    property bool uiReady: false
    property bool fontReady: false
    property bool mediaReady: false
    readonly property bool ready: hyprReady && barReady && fontReady
    readonly property bool fontBusy: fontSetProc.running
    readonly property bool mediaBusy: mediaSetProc.running
    readonly property bool settingsBusy: fontBusy || mediaBusy || hyprToggleProc.running || hyprSetProc.running
        || barToggleProc.running || notificationsToggleProc.running || uiToggleProc.running
    readonly property bool active: host && host.opened && host.activeModule === "settings"

    Keys.onEscapePressed: if (host) host.dismiss()

    function refresh() {
        Theme.reloadLooks()
        if (!loadHyprProc.running) loadHyprProc.running = true
        if (!loadBarProc.running) loadBarProc.running = true
        if (!loadFontProc.running) loadFontProc.running = true
        if (!loadFontListProc.running) loadFontListProc.running = true
        if (!loadNotificationsProc.running) loadNotificationsProc.running = true
        if (!loadUiProc.running) loadUiProc.running = true
        if (!loadMediaProc.running) loadMediaProc.running = true
    }

    function toggleHypr(key) {
        if (!hyprReady || settingsBusy) return
        hyprToggleProc.target = key
        hyprToggleProc.running = true
    }

    function setHyprOpacity(key, percent) {
        if (!hyprReady || settingsBusy) return
        hyprSetProc.key = key
        hyprSetProc.value = String(percent)
        hyprSetProc.running = true
    }

    function toggleBar() {
        if (!barReady || settingsBusy) return
        barToggleProc.running = true
    }

    function toggleNotifications() {
        if (!notificationsReady || settingsBusy) return
        notificationsToggleProc.running = true
    }

    function toggleFieldsetRounding() {
        if (!uiReady || settingsBusy) return
        uiToggleProc.running = true
    }

    function setFont(key, value) {
        if (!fontReady || settingsBusy) return
        fontSetProc.key = key
        fontSetProc.value = String(value)
        fontSetProc.running = true
    }

    function setMediaShows(names) {
        if (!mediaReady || settingsBusy) return
        mediaSetProc.payload = JSON.stringify(names || [])
        mediaSetProc.running = true
    }

    readonly property var mediaShowNames: {
        var out = []
        for (var i = 0; i < mediaShows.length; i++)
            out.push(mediaShows[i].name)
        return out
    }

    readonly property var mediaSelectedShows: {
        var out = []
        for (var i = 0; i < mediaShows.length; i++) {
            if (mediaShows[i].enabled)
                out.push(mediaShows[i].name)
        }
        return out
    }

    function onActivated() {
        themeNameFile.reload()
        themePicker.reload()
        refresh()
        Qt.callLater(function() { root.forceActiveFocus() })
    }

    onActiveChanged: {
        if (active)
            Qt.callLater(function() { root.forceActiveFocus() })
    }

    function parseHyprState(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.roundingOn = data.roundingOn === true
            root.gapsOn = data.gapsOn === true
            root.animationsOn = data.animationsOn === true
            root.activeOpacityPercent = Math.round(Number(data.activeOpacity || 0.97) * 100)
            root.inactiveOpacityPercent = Math.round(Number(data.inactiveOpacity || 0.88) * 100)
            root.hyprReady = true
        } catch (e) {
            root.hyprReady = false
        }
    }

    function parseBarState(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.barOnDp1Top = data.barOnDp1Top === true
            root.barReady = true
        } catch (e) {
            root.barReady = false
        }
    }

    function parseNotificationsState(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.notificationsOnHdmiBottom = data.notificationsOnHdmiBottom === true
            root.notificationsReady = true
        } catch (e) {
            root.notificationsReady = false
        }
    }

    function parseUiState(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.fieldsetRoundingOn = data.fieldsetRounding !== false
            root.uiReady = true
        } catch (e) {
            root.uiReady = false
        }
    }

    function parseFontState(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            if (data.family)
                root.fontFamily = String(data.family)
            root.fontReady = true
        } catch (e) {
            root.fontReady = false
        }
    }

    function parseFontList(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.fontFamilies = Array.isArray(data.families) ? data.families : []
        } catch (e) {
            root.fontFamilies = []
        }
    }

    function parseMediaSettings(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.mediaShows = Array.isArray(data.available) ? data.available : []
            root.mediaTvRoot = data.tvRoot ? String(data.tvRoot) : ""
            root.mediaReady = data.ok === true
        } catch (e) {
            root.mediaShows = []
            root.mediaTvRoot = ""
            root.mediaReady = false
        }
    }

    Process {
        id: loadHyprProc
        command: ["bash", root.hyprScript, "get"]
        stdout: StdioCollector {
            onStreamFinished: root.parseHyprState(text)
        }
        onExited: Theme.reloadLooks()
    }

    Process {
        id: loadBarProc
        command: ["bash", root.barScript, "bar", "get"]
        stdout: StdioCollector {
            onStreamFinished: root.parseBarState(text)
        }
    }

    Process {
        id: loadNotificationsProc
        command: ["bash", root.barScript, "notifications", "get"]
        stdout: StdioCollector {
            onStreamFinished: root.parseNotificationsState(text)
        }
    }

    Process {
        id: loadUiProc
        command: ["bash", root.barScript, "ui", "get"]
        stdout: StdioCollector {
            onStreamFinished: root.parseUiState(text)
        }
    }

    Process {
        id: loadFontProc
        command: ["bash", root.fontScript, "get"]
        stdout: StdioCollector {
            onStreamFinished: root.parseFontState(text)
        }
    }

    FileView {
        id: fontStateFile
        path: root.fontStatePath
        watchChanges: true
        printErrors: false
        onLoaded: root.parseFontState(fontStateFile.text())
        onFileChanged: reload()
    }

    FileView {
        id: themeNameFile
        path: root.themeNamePath
        watchChanges: true
        printErrors: false
        onLoaded: root.currentThemeName = String(themeNameFile.text() || "").trim()
        onFileChanged: reload()
    }

    Process {
        id: loadFontListProc
        command: ["bash", root.fontScript, "list"]
        stdout: StdioCollector {
            onStreamFinished: root.parseFontList(text)
        }
    }

    Process {
        id: hyprToggleProc
        property string target: ""
        command: ["bash", root.hyprScript, "toggle", hyprToggleProc.target]
        stdout: StdioCollector {
            onStreamFinished: root.parseHyprState(text)
        }
        onExited: Theme.reloadLooks()
    }

    Process {
        id: hyprSetProc
        property string key: ""
        property string value: ""
        command: ["bash", root.hyprScript, "set", hyprSetProc.key, hyprSetProc.value]
        stdout: StdioCollector {
            onStreamFinished: root.parseHyprState(text)
        }
        onExited: Theme.reloadLooks()
    }

    Process {
        id: barToggleProc
        command: ["bash", root.barScript, "bar", "toggle"]
        stdout: StdioCollector {
            onStreamFinished: root.parseBarState(text)
        }
    }

    Process {
        id: notificationsToggleProc
        command: ["bash", root.barScript, "notifications", "toggle"]
        stdout: StdioCollector {
            onStreamFinished: root.parseNotificationsState(text)
        }
    }

    Process {
        id: uiToggleProc
        command: ["bash", root.barScript, "ui", "toggle", "fieldsetRounding"]
        stdout: StdioCollector {
            onStreamFinished: root.parseUiState(text)
        }
        onExited: Theme.reloadUi()
    }

    Process {
        id: fontSetProc
        property string key: ""
        property string value: ""
        command: ["bash", root.fontScript, "set", fontSetProc.key, fontSetProc.value]
        stdout: StdioCollector {
            onStreamFinished: root.parseFontState(text)
        }
    }

    Process {
        id: loadMediaProc
        command: ["bash", root.mediaScript, "settings", "get"]
        stdout: StdioCollector {
            onStreamFinished: root.parseMediaSettings(text)
        }
    }

    Process {
        id: mediaSetProc
        property string payload: "[]"
        command: ["bash", root.mediaScript, "settings", "set", mediaSetProc.payload]
        stdout: StdioCollector {
            onStreamFinished: root.parseMediaSettings(text)
        }
    }

    Flickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: settingsColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        ColumnLayout {
            id: settingsColumn
            width: parent.width
            spacing: 16

            SectionPanel {
                contentPad: Theme.panelContentPad
                legendBackground: Theme.background
                label: ""
                sectionSpacing: 12

                HoverPopupLabelPill {
                    text: "Hyprland"
                    fontSize: Theme.fontSizeS
                }

                ToggleRow {
                    Layout.fillWidth: true
                    label: "Border radius"
                    detail: "7px"
                    checked: root.roundingOn
                    enabled: root.hyprReady && !settingsBusy
                    onToggled: root.toggleHypr("rounding")
                }

                ToggleRow {
                    Layout.fillWidth: true
                    label: "Window gaps"
                    detail: "10px in 20px out"
                    checked: root.gapsOn
                    enabled: root.hyprReady && !settingsBusy
                    onToggled: root.toggleHypr("gaps")
                }

                ToggleRow {
                    Layout.fillWidth: true
                    label: "Animations"
                    detail: "Bezier sliding"
                    checked: root.animationsOn
                    enabled: root.hyprReady && !settingsBusy
                    onToggled: root.toggleHypr("animations")
                }

                SliderSetting {
                    Layout.fillWidth: true
                    label: "Active opacity"
                    value: root.activeOpacityPercent
                    valueSuffix: "%"
                    minimum: 0
                    maximum: 100
                    step: 1
                    enabled: root.hyprReady && !settingsBusy
                    onValueEdited: function(v) {
                        root.activeOpacityPercent = v
                    }
                    onValueCommitted: function(v) {
                        root.activeOpacityPercent = v
                        root.setHyprOpacity("active", v)
                    }
                }

                SliderSetting {
                    Layout.fillWidth: true
                    label: "Inactive opacity"
                    value: root.inactiveOpacityPercent
                    valueSuffix: "%"
                    minimum: 0
                    maximum: 100
                    step: 1
                    enabled: root.hyprReady && !settingsBusy
                    onValueEdited: function(v) {
                        root.inactiveOpacityPercent = v
                    }
                    onValueCommitted: function(v) {
                        root.inactiveOpacityPercent = v
                        root.setHyprOpacity("inactive", v)
                    }
                }
            }

            SectionPanel {
                contentPad: Theme.panelContentPad
                legendBackground: Theme.background
                label: ""
                sectionSpacing: 12

                HoverPopupLabelPill {
                    text: "Evoshell"
                    fontSize: Theme.fontSizeS
                }

                FontFamilyPicker {
                    Layout.fillWidth: true
                    label: "Font family"
                    value: root.fontFamily
                    model: root.fontFamilies
                    enabled: root.fontReady && !settingsBusy
                    onActivated: function(family) {
                        root.fontFamily = family
                        root.setFont("family", family)
                    }
                }

                ToggleRow {
                    Layout.fillWidth: true
                    label: "Bar position"
                    detail: root.barOnDp1Top ? "Bottom screen" : "Top screen"
                    checked: root.barOnDp1Top
                    enabled: root.barReady && !settingsBusy
                    onToggled: root.toggleBar()
                }

                ToggleRow {
                    Layout.fillWidth: true
                    label: "Notification position"
                    detail: root.notificationsOnHdmiBottom ? "Top screen" : "Bottom screen"
                    checked: !root.notificationsOnHdmiBottom
                    enabled: root.notificationsReady && !settingsBusy
                    onToggled: root.toggleNotifications()
                }

                ToggleRow {
                    Layout.fillWidth: true
                    label: "Fieldset radius"
                    detail: root.fieldsetRoundingOn ? "4px" : "Square"
                    checked: root.fieldsetRoundingOn
                    enabled: root.uiReady && !settingsBusy
                    onToggled: root.toggleFieldsetRounding()
                }

                MultiSelectPicker {
                    Layout.fillWidth: true
                    label: "Media popup TV shows"
                    placeholder: root.mediaTvRoot ? "No folders found" : "TV folder not found"
                    options: root.mediaShowNames
                    selected: root.mediaSelectedShows
                    enabled: root.mediaReady && !settingsBusy && root.mediaShowNames.length > 0
                    onSelectionChanged: function(next) {
                        root.setMediaShows(next)
                    }
                }
            }

            SectionPanel {
                contentPad: Theme.panelContentPad
                legendBackground: Theme.background
                label: ""

                HoverPopupLabelPill {
                    text: "Theme"
                    fontSize: Theme.fontSizeS
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: themePicker.implicitHeight

                    PreviewPickerGrid {
                        id: themePicker
                        width: parent.width
                        kind: "themes"
                        columns: 3
                        tileWidth: Math.floor((parent.width - spacing * 2) / 3)
                        tileHeight: 58
                        spacing: Theme.spacingM
                        previewDpr: 1.5
                        selectedKey: root.currentThemeName
                        keyboardFocus: false
                    }
                }
            }
        }
    }
}
