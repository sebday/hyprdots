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
    readonly property string playerScript: Quickshell.env("HOME") + "/.local/bin/evo-player"
    readonly property string tasksScript: Quickshell.env("HOME") + "/.local/bin/evo-tasks"
    readonly property string weatherScript: Quickshell.env("HOME") + "/.local/bin/evo-weather"
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
    property string mediaTvRoot: ""
    property string mediaFilmsRoot: ""
    property bool mediaReady: false
    property bool suppressMediaPathCommit: false
    property bool hyprReady: false
    property bool barReady: false
    property bool notificationsReady: false
    property bool uiReady: false
    property bool fontReady: false
    property string scUser: ""
    property string scCookiesFrom: ""
    property string musicLibrary: ""
    property bool playerReady: false
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
    readonly property bool playerBusy: playerSetProc.running || playerLibraryPickProc.running
    readonly property bool tasksBusy: taskVaultSetProc.running || taskVaultPickProc.running
    readonly property bool weatherBusy: weatherSetProc.running
    readonly property bool settingsBusy: fontBusy || mediaBusy || playerBusy || tasksBusy || weatherBusy || hyprToggleProc.running || hyprSetProc.running
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
        if (!loadPlayerProc.running) loadPlayerProc.running = true
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

    function setMusicLibrary(path) {
        if (!playerReady || settingsBusy)
            return
        playerSetProc.key = "paths.root"
        playerSetProc.value = String(path || "")
        playerSetProc.running = true
    }

    function pickMusicLibrary() {
        if (!playerReady || settingsBusy)
            return
        playerLibraryPickProc.running = true
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
            root.mediaTvRoot = data.tvRoot ? String(data.tvRoot) : ""
            root.mediaFilmsRoot = data.filmsRoot ? String(data.filmsRoot) : ""
            root.mediaReady = data.ok === true
        } catch (e) {
            root.mediaTvRoot = ""
            root.mediaFilmsRoot = ""
            root.mediaReady = false
        }
    }

    function parsePlayerConfig(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            var sc = data.soundcloud || {}
            var paths = data.paths || {}
            root.scUser = String(sc.user || "")
            root.scCookiesFrom = String(sc.cookies_from || "")
            root.musicLibrary = String(paths.root || "")
            root.playerReady = true
        } catch (e) {
            root.playerReady = false
        }
    }

    function setPlayerConfig(key, value) {
        if (!playerReady || settingsBusy)
            return
        playerSetProc.key = key
        playerSetProc.value = String(value || "")
        playerSetProc.running = true
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
        id: loadPlayerProc
        command: ["bash", root.playerScript, "config", "get", "--json"]
        stdout: StdioCollector {
            onStreamFinished: root.parsePlayerConfig(text)
        }
    }

    Process {
        id: playerSetProc
        property string key: ""
        property string value: ""
        command: ["bash", root.playerScript, "config", "set", playerSetProc.key, playerSetProc.value, "--json"]
        stdout: StdioCollector {
            onStreamFinished: root.parsePlayerConfig(text)
        }
    }

    Process {
        id: playerLibraryPickProc
        command: ["bash", root.playerScript, "config", "pick"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (String(text || "").trim())
                    root.parsePlayerConfig(text)
            }
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
                    text: "Hyprland"
                    fontSize: Theme.fontSizeS
                }

                ToggleRow {
                    Layout.fillWidth: true
                    label: "Border radius"
                    detail: root.roundingOn ? "Rounded" : "Square"
                    checked: root.roundingOn
                    enabled: root.hyprReady && !settingsBusy
                    onToggled: root.toggleHypr("rounding")
                }

                ToggleRow {
                    Layout.fillWidth: true
                    label: "Window gaps"
                    detail: "10 in 20 out"
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
                    text: "Weather"
                    fontSize: Theme.fontSizeS
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "Location"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeS
                        opacity: Theme.opacityMuted
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: 6
                        color: Theme.foregroundWash
                        border.color: Theme.foregroundDivider
                        border.width: 1

                        TextInput {
                            id: weatherLocationInput
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
                            text: root.weatherLocation
                            enabled: root.weatherReady && !settingsBusy
                            onEditingFinished: root.setWeatherLocation(text)
                        }
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
                    detail: root.fieldsetRoundingOn ? "Rounded" : "Square"
                    checked: root.fieldsetRoundingOn
                    enabled: root.uiReady && !settingsBusy
                    onToggled: root.toggleFieldsetRounding()
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

                    Text {
                        visible: root.tasksFile !== ""
                        text: root.tasksFile !== "" ? ("tasks: " + root.tasksFile) : ""
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        opacity: Theme.opacityMuted
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }
                }

            }

            SectionPanel {
                contentPad: Theme.panelContentPad
                legendBackground: Theme.background
                label: ""
                sectionSpacing: 12

                HoverPopupLabelPill {
                    text: "Media library"
                    fontSize: Theme.fontSizeS
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
                sectionSpacing: 12

                HoverPopupLabelPill {
                    text: "Evoplayer"
                    fontSize: Theme.fontSizeS
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "Music library"
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
                                text: root.musicLibrary
                                enabled: root.playerReady && !settingsBusy
                                onEditingFinished: root.setMusicLibrary(text)
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
                                opacity: musicLibraryPickMouse.enabled
                                    ? (musicLibraryPickMouse.containsMouse ? 1 : 0.72)
                                    : 0.35
                            }

                            MouseArea {
                                id: musicLibraryPickMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: root.playerReady && !settingsBusy
                                onClicked: root.pickMusicLibrary()
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "SoundCloud user"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeS
                        opacity: Theme.opacityMuted
                    }

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
                            text: root.scUser
                            enabled: root.playerReady && !settingsBusy
                            onEditingFinished: root.setPlayerConfig("soundcloud.user", text)
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "Cookies browser"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeS
                        opacity: Theme.opacityMuted
                    }

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
                            text: root.scCookiesFrom
                            enabled: root.playerReady && !settingsBusy
                            onEditingFinished: root.setPlayerConfig("soundcloud.cookies_from", text)
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
