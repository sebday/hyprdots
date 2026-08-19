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
    readonly property string tasksScript: Quickshell.env("HOME") + "/.local/bin/evo-tasks"
    readonly property string weatherScript: Quickshell.env("HOME") + "/.local/bin/evo-weather"
    readonly property string fontStatePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/evoshell/font.json"
    readonly property string themeNamePath: Quickshell.env("HOME") + "/.themes/current/.theme-name"
    readonly property string themeListScript: Quickshell.env("HOME") + "/.local/bin/evo-menu-list"
    readonly property string home: Quickshell.env("HOME")
    readonly property string wallpaperStatePath: (Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")) + "/evoshell/wallpaper"

    property var themeEntries: []
    property string currentThemePreview: ""
    property var wallpaperEntries: []
    property string currentWallpaperPath: ""
    property string currentWallpaperPreview: ""

    readonly property string themePreviewSource: {
        if (currentThemePreview !== "")
            return currentThemePreview
        var name = String(currentThemeName || "").trim()
        if (!name)
            return ""
        return home + "/.themes/" + name + "/preview.png"
    }

    readonly property string themeDisplayName: {
        var name = String(currentThemeName || "").trim()
        return name !== "" ? name : "Theme"
    }

    readonly property string wallpaperPreviewSource: {
        if (currentWallpaperPreview !== "")
            return currentWallpaperPreview
        return String(currentWallpaperPath || "").trim()
    }

    readonly property string wallpaperDisplayName: {
        var path = String(currentWallpaperPath || "").trim()
        if (!path)
            return "Wallpaper"
        for (var i = 0; i < wallpaperEntries.length; i++) {
            if (String(wallpaperEntries[i].command || "").indexOf(path) >= 0)
                return String(wallpaperEntries[i].name || "")
        }
        var parts = path.split("/")
        return parts.length ? parts[parts.length - 1] : "Wallpaper"
    }

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
    property string mediaTvRoot: ""
    property string mediaFilmsRoot: ""
    property bool mediaReady: false
    property bool suppressMediaPathCommit: false
    property bool hyprReady: false
    property bool barReady: false
    property bool notificationsReady: false
    property bool uiReady: false
    property bool fontReady: false
    property string obsidianVault: ""
    property string detectedObsidianVault: ""
    property string tasksFile: ""
    property bool tasksReady: false
    property string weatherLocation: ""
    property bool weatherReady: false
    readonly property bool ready: hyprReady && barReady && fontReady
    readonly property bool fontBusy: fontSetProc.running
    readonly property bool mediaBusy: mediaTvSetProc.running || mediaFilmsSetProc.running
        || mediaTvPickProc.running || mediaFilmsPickProc.running
    readonly property bool tasksBusy: taskVaultSetProc.running || taskVaultPickProc.running
    readonly property bool weatherBusy: weatherSetProc.running
    readonly property var weatherLocationPresets: [
        "Derby", "London", "Manchester", "Birmingham", "Leeds", "Bristol",
        "Nottingham", "Sheffield", "Liverpool", "Glasgow", "Edinburgh", "Cardiff", "Belfast"
    ]
    readonly property var weatherLocationOptions: {
        var options = weatherLocationPresets.slice()
        var current = String(weatherLocation || "").trim()
        if (!current)
            return options
        for (var i = 0; i < options.length; i++) {
            if (String(options[i]) === current)
                return options
        }
        options.unshift(current)
        return options
    }
    readonly property string weatherLocationValue: {
        var value = String(weatherLocation || "").trim()
        return value !== "" ? value : "Derby"
    }
    readonly property bool settingsBusy: fontBusy || mediaBusy || tasksBusy || weatherBusy || hyprToggleProc.running || hyprSetProc.running
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
        if (!loadTasksProc.running) loadTasksProc.running = true
        if (!loadWeatherProc.running) loadWeatherProc.running = true
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

    function setMediaTvRoot(path) {
        if (!mediaReady || settingsBusy)
            return
        mediaTvSetProc.path = String(path || "")
        mediaTvSetProc.running = true
    }

    function setMediaFilmsRoot(path) {
        if (!mediaReady || settingsBusy)
            return
        mediaFilmsSetProc.path = String(path || "")
        mediaFilmsSetProc.running = true
    }

    function finishMediaPick(raw) {
        suppressMediaPathCommit = false
        if (raw !== undefined && String(raw || "").trim())
            parseMediaSettings(raw)
    }

    function pickMediaTv() {
        if (!mediaReady || settingsBusy)
            return
        suppressMediaPathCommit = true
        mediaTvPickProc.running = true
    }

    function pickMediaFilms() {
        if (!mediaReady || settingsBusy)
            return
        suppressMediaPathCommit = true
        mediaFilmsPickProc.running = true
    }

    function openThemePicker() {
        if (!shell)
            return
        shell.toggle("evo.theme")
    }

    function openWallpaperPicker() {
        if (!shell)
            return
        shell.toggle("evo.wallpaper")
    }

    function parseThemeList(raw) {
        var lines = String(raw || "").split("\n")
        var out = []
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line)
                continue
            var parts = line.split("\t")
            out.push({
                name: parts[0] || "",
                command: parts[1] || "",
                preview: parts[2] || ""
            })
        }
        themeEntries = out
        syncThemePreview()
    }

    function syncThemePreview() {
        currentThemePreview = ""
        var name = String(currentThemeName || "").trim()
        if (!name)
            return
        for (var i = 0; i < themeEntries.length; i++) {
            if (String(themeEntries[i].name) === name) {
                currentThemePreview = String(themeEntries[i].preview || "")
                return
            }
        }
    }

    function parseWallpaperList(raw) {
        var lines = String(raw || "").split("\n")
        var out = []
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line)
                continue
            var parts = line.split("\t")
            out.push({
                name: parts[0] || "",
                command: parts[1] || "",
                preview: parts[2] || ""
            })
        }
        wallpaperEntries = out
        syncWallpaperPreview()
    }

    function syncWallpaperPreview() {
        currentWallpaperPreview = ""
        var path = String(currentWallpaperPath || "").trim()
        if (!path)
            return
        for (var i = 0; i < wallpaperEntries.length; i++) {
            if (String(wallpaperEntries[i].command || "").indexOf(path) >= 0) {
                currentWallpaperPreview = String(wallpaperEntries[i].preview || "")
                return
            }
        }
    }

    function onActivated() {
        themeNameFile.reload()
        wallpaperStateFile.reload()
        if (!loadThemeListProc.running)
            loadThemeListProc.running = true
        if (!loadWallpaperListProc.running)
            loadWallpaperListProc.running = true
        refresh()
        Qt.callLater(function() { root.forceActiveFocus() })
    }

    onCurrentThemeNameChanged: syncThemePreview()
    onCurrentWallpaperPathChanged: syncWallpaperPreview()

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
            root.mediaTvRoot = data.tvRoot ? String(data.tvRoot) : ""
            root.mediaFilmsRoot = data.filmsRoot ? String(data.filmsRoot) : ""
            root.mediaReady = data.ok === true
        } catch (e) {
            root.mediaTvRoot = ""
            root.mediaFilmsRoot = ""
            root.mediaReady = false
        }
    }

    function parseTasksSettings(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.obsidianVault = String(data.obsidianVault || "")
            root.detectedObsidianVault = String(data.detectedVault || "")
            root.tasksFile = String(data.tasksFile || "")
            root.tasksReady = data.ok === true
        } catch (e) {
            root.obsidianVault = ""
            root.detectedObsidianVault = ""
            root.tasksFile = ""
            root.tasksReady = false
        }
    }

    function setObsidianVault(path) {
        if (!tasksReady || settingsBusy)
            return
        taskVaultSetProc.path = String(path || "")
        taskVaultSetProc.running = true
    }

    function pickObsidianVault() {
        if (!tasksReady || settingsBusy)
            return
        taskVaultPickProc.running = true
    }

    function parseWeatherSettings(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.weatherLocation = String(data.name || "")
            root.weatherReady = data.ok === true
        } catch (e) {
            root.weatherLocation = ""
            root.weatherReady = false
        }
    }

    function setWeatherLocation(location) {
        if (!weatherReady || settingsBusy)
            return
        var trimmed = String(location || "").trim()
        if (!trimmed || trimmed === root.weatherLocation)
            return
        weatherSetProc.location = trimmed
        weatherSetProc.running = true
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
        onLoaded: {
            root.currentThemeName = String(themeNameFile.text() || "").trim()
            root.syncThemePreview()
        }
        onFileChanged: reload()
    }

    FileView {
        id: wallpaperStateFile
        path: root.wallpaperStatePath
        watchChanges: true
        printErrors: false
        onLoaded: {
            root.currentWallpaperPath = String(wallpaperStateFile.text() || "").trim()
            root.syncWallpaperPreview()
        }
        onFileChanged: reload()
    }

    Process {
        id: loadThemeListProc
        command: [root.themeListScript, "themes"]
        stdout: StdioCollector {
            onStreamFinished: root.parseThemeList(text)
        }
    }

    Process {
        id: loadWallpaperListProc
        command: [root.themeListScript, "wallpapers"]
        stdout: StdioCollector {
            onStreamFinished: root.parseWallpaperList(text)
        }
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
        id: mediaTvSetProc
        property string path: ""
        command: ["bash", "-lc",
            Util.shellQuote(root.mediaScript) + " settings set tv " + Util.shellQuote(mediaTvSetProc.path)
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                if (String(text || "").trim())
                    root.parseMediaSettings(text)
            }
        }
    }

    Process {
        id: mediaFilmsSetProc
        property string path: ""
        command: ["bash", "-lc",
            Util.shellQuote(root.mediaScript) + " settings set films " + Util.shellQuote(mediaFilmsSetProc.path)
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                if (String(text || "").trim())
                    root.parseMediaSettings(text)
            }
        }
    }

    Process {
        id: mediaTvPickProc
        command: ["bash", root.mediaScript, "settings", "pick", "tv"]
        stdout: StdioCollector {
            onStreamFinished: root.finishMediaPick(text)
        }
    }

    Process {
        id: mediaFilmsPickProc
        command: ["bash", root.mediaScript, "settings", "pick", "films"]
        stdout: StdioCollector {
            onStreamFinished: root.finishMediaPick(text)
        }
    }

    Process {
        id: loadTasksProc
        command: ["bash", root.tasksScript, "settings", "get"]
        stdout: StdioCollector {
            onStreamFinished: root.parseTasksSettings(text)
        }
    }

    Process {
        id: taskVaultSetProc
        property string path: ""
        command: ["bash", root.tasksScript, "settings", "set", "vault", taskVaultSetProc.path]
        stdout: StdioCollector {
            onStreamFinished: {
                if (String(text || "").trim())
                    root.parseTasksSettings(text)
            }
        }
    }

    Process {
        id: taskVaultPickProc
        command: ["bash", root.tasksScript, "settings", "pick"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (String(text || "").trim())
                    root.parseTasksSettings(text)
            }
        }
    }

    Process {
        id: loadWeatherProc
        command: ["bash", root.weatherScript, "settings", "get"]
        stdout: StdioCollector {
            onStreamFinished: root.parseWeatherSettings(text)
        }
    }

    Process {
        id: weatherSetProc
        property string location: ""
        command: ["bash", root.weatherScript, "settings", "set", weatherSetProc.location]
        stdout: StdioCollector {
            onStreamFinished: {
                if (String(text || "").trim())
                    root.parseWeatherSettings(text)
            }
        }
    }

    readonly property int settingsContentTopPad: 8

    Flickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: settingsColumn.implicitHeight + settingsContentTopPad + Theme.spacing2
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        ColumnLayout {
            id: settingsColumn
            width: parent.width
            y: settingsContentTopPad
            spacing: 16

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
                    checked: root.barOnDp1Top
                    enabled: root.barReady && !settingsBusy
                    onToggled: root.toggleBar()
                }

                ToggleRow {
                    Layout.fillWidth: true
                    label: "Notification position"
                    checked: !root.notificationsOnHdmiBottom
                    enabled: root.notificationsReady && !settingsBusy
                    onToggled: root.toggleNotifications()
                }

                ToggleRow {
                    Layout.fillWidth: true
                    label: "Fieldset radius"
                    checked: root.fieldsetRoundingOn
                    enabled: root.uiReady && !settingsBusy
                    onToggled: root.toggleFieldsetRounding()
                }

                ToggleRow {
                    Layout.fillWidth: true
                    label: "Border radius"
                    checked: root.roundingOn
                    enabled: root.hyprReady && !settingsBusy
                    onToggled: root.toggleHypr("rounding")
                }

                ToggleRow {
                    Layout.fillWidth: true
                    label: "Window gaps"
                    checked: root.gapsOn
                    enabled: root.hyprReady && !settingsBusy
                    onToggled: root.toggleHypr("gaps")
                }

                ToggleRow {
                    Layout.fillWidth: true
                    label: "Animations"
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
                    text: "Locations"
                    fontSize: Theme.fontSizeS
                }

                FontFamilyPicker {
                    Layout.fillWidth: true
                    label: "Weather"
                    previewFont: false
                    value: root.weatherLocationValue
                    model: root.weatherLocationOptions
                    enabled: root.weatherReady && !settingsBusy
                    onActivated: function(location) {
                        root.setWeatherLocation(location)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "Obsidian vault"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeS
                        opacity: Theme.opacityMuted
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: 6
                            color: Theme.foregroundWash
                            border.color: Theme.foregroundDivider
                            border.width: 1

                            TextInput {
                                id: obsidianVaultInput
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeS
                                selectionColor: Theme.accent
                                selectedTextColor: Theme.mantle
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                text: root.obsidianVault
                                enabled: root.tasksReady && !settingsBusy
                                onEditingFinished: root.setObsidianVault(text)
                            }
                        }

                        Item {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34

                            Text {
                                anchors.centerIn: parent
                                text: "󰉖"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXl
                                opacity: obsidianVaultPickMouse.enabled
                                    ? (obsidianVaultPickMouse.containsMouse ? 1 : 0.72)
                                    : 0.35
                            }

                            MouseArea {
                                id: obsidianVaultPickMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: root.tasksReady && !settingsBusy
                                onClicked: root.pickObsidianVault()
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "TV folder"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeS
                        opacity: Theme.opacityMuted
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: 6
                            color: Theme.foregroundWash
                            border.color: Theme.foregroundDivider
                            border.width: 1

                            TextInput {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeS
                                selectionColor: Theme.accent
                                selectedTextColor: Theme.mantle
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                text: root.mediaTvRoot
                                enabled: root.mediaReady && !settingsBusy
                                onEditingFinished: {
                                    if (!root.suppressMediaPathCommit)
                                        root.setMediaTvRoot(text)
                                }
                            }
                        }

                        Item {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34

                            Text {
                                anchors.centerIn: parent
                                text: "󰉖"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXl
                                opacity: mediaTvPickMouse.enabled
                                    ? (mediaTvPickMouse.containsMouse ? 1 : 0.72)
                                    : 0.35
                            }

                            MouseArea {
                                id: mediaTvPickMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: root.mediaReady && !settingsBusy
                                onClicked: root.pickMediaTv()
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "Films folder"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeS
                        opacity: Theme.opacityMuted
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: 6
                            color: Theme.foregroundWash
                            border.color: Theme.foregroundDivider
                            border.width: 1

                            TextInput {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeS
                                selectionColor: Theme.accent
                                selectedTextColor: Theme.mantle
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                text: root.mediaFilmsRoot
                                enabled: root.mediaReady && !settingsBusy
                                onEditingFinished: {
                                    if (!root.suppressMediaPathCommit)
                                        root.setMediaFilmsRoot(text)
                                }
                            }
                        }

                        Item {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34

                            Text {
                                anchors.centerIn: parent
                                text: "󰉖"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXl
                                opacity: mediaFilmsPickMouse.enabled
                                    ? (mediaFilmsPickMouse.containsMouse ? 1 : 0.72)
                                    : 0.35
                            }

                            MouseArea {
                                id: mediaFilmsPickMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: root.mediaReady && !settingsBusy
                                onClicked: root.pickMediaFilms()
                            }
                        }
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

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: themeCard.implicitHeight + 16
                    radius: 6
                    color: themePickMouse.containsMouse ? Theme.foregroundHoverWash : Theme.foregroundWash
                    border.color: Theme.foregroundDivider
                    border.width: 1

                    ColumnLayout {
                        id: themeCard
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: Theme.spacingS

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 120
                            radius: 4
                            color: Theme.overlaySurface
                            clip: true

                            Image {
                                id: themePreviewImage
                                anchors.fill: parent
                                source: root.themePreviewSource ? Util.fileUrl(root.themePreviewSource) : ""
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                asynchronous: true
                                cache: true
                                visible: root.themePreviewSource !== "" && status !== Image.Error
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: root.themePreviewSource === "" || themePreviewImage.status === Image.Error
                                text: "󰸌"
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize6xl
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: root.themeDisplayName
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeM
                            font.bold: Theme.fontBold
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: themePickMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openThemePicker()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: wallpaperCard.implicitHeight + 16
                    radius: 6
                    color: wallpaperPickMouse.containsMouse ? Theme.foregroundHoverWash : Theme.foregroundWash
                    border.color: Theme.foregroundDivider
                    border.width: 1

                    ColumnLayout {
                        id: wallpaperCard
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: Theme.spacingS

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 120
                            radius: 4
                            color: Theme.overlaySurface
                            clip: true

                            Image {
                                id: wallpaperPreviewImage
                                anchors.fill: parent
                                source: root.wallpaperPreviewSource ? Util.fileUrl(root.wallpaperPreviewSource) : ""
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                asynchronous: true
                                cache: true
                                visible: root.wallpaperPreviewSource !== "" && status !== Image.Error
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: root.wallpaperPreviewSource === "" || wallpaperPreviewImage.status === Image.Error
                                text: "󰏘"
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize6xl
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: root.wallpaperDisplayName
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeM
                            font.bold: Theme.fontBold
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: wallpaperPickMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openWallpaperPicker()
                    }
                }
            }
        }
    }
}
