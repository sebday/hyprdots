import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../commons"
import "../../pluginManifest.js" as PluginManifest

Item {
    id: root

    property var host: null
    property var shell: null

    readonly property string hyprScript: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-hyprland")
    readonly property string barScript: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-layout")
    readonly property string fontScript: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-font")
    readonly property string mediaScript: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-bar-library")
    readonly property string tasksScript: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-tasks")
    readonly property string configScript: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-config")
    readonly property string weatherScript: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-bar-weather")
    readonly property string fontStatePath: Util.configPath(home, "font.json")
    readonly property string themeNamePath: Quickshell.env("HOME") + "/.themes/current/.theme-name"
    readonly property string themeListScript: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-menu-list")
    readonly property string home: Quickshell.env("HOME")
    readonly property string wallpaperStatePath: Util.statePath(home, "wallpaper")

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
    property string barOutput: ""
    property string barPosition: "bottom"
    property string notificationsOutput: ""
    property string notificationsPosition: "bottom"
    property bool fieldsetRoundingOn: true
    property string fontFamily: "CaskaydiaMono Nerd Font"
    property int fontScalePercent: 100
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
    property string panelSide: "left"
    property bool panelSideReady: false
    property var startupOpenIds: []
    property bool dashboardsReady: false
    property string weatherLocation: ""
    property string personalWallpaperDir: ""
    property bool weatherReady: false
    property bool personalWallpaperReady: false
    property bool weatherLocationPickerOpen: false
    property string weatherSearchQuery: ""
    property var weatherSearchResults: []
    property bool weatherSearchBusy: false
    property int weatherLocationPopupX: 0
    property int weatherLocationPopupY: 0
    property int weatherLocationPopupWidth: 0
    property var secretsStatus: ({})
    property bool secretsReady: false
    property string haLightAreas: ""
    property string haClimateEntities: ""
    property var haEnabledLightAreas: []
    property var haEnabledClimateEntities: []
    property bool haReady: false
    property var haAreaOptions: []
    property var haClimateOptions: []
    property string haDiscoveryError: ""
    property bool haDiscoveryReady: false
    property int idleLockMin: 15
    property bool idleReady: false
    property var trayWidgets: ({})
    property var trayWidgetOrderIds: []
    property bool trayReady: false
    readonly property bool ready: hyprReady && barReady && fontReady
    readonly property bool fontBusy: fontSetProc.running
    readonly property bool mediaBusy: mediaTvSetProc.running || mediaFilmsSetProc.running
        || mediaTvPickProc.running || mediaFilmsPickProc.running
    readonly property bool tasksBusy: taskVaultSetProc.running || taskVaultPickProc.running
    readonly property bool settingsBusy: fontBusy || mediaBusy || tasksBusy || hyprToggleProc.running || hyprSetProc.running
        || barSetProc.running || notificationsSetProc.running || uiToggleProc.running
        || panelSetProc.running || dashboardToggleProc.running || weatherSetProc.running
        || wallpaperPersonalDirSetProc.running
        || haSaveProc.running || idleSetProc.running
        || trayToggleProc.running || trayOrderSetProc.running
    readonly property bool active: host && host.opened && host.activeModule === "settings"

    Keys.onEscapePressed: {
        if (root.weatherLocationPickerOpen) {
            root.weatherLocationPickerOpen = false
            return
        }
        if (host)
            host.dismiss()
    }
    Keys.onPressed: function(event) {
        if (event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab)
            return
        if (!(event.modifiers & Qt.ControlModifier) && focusInTextInput())
            return
        if (event.modifiers & Qt.ShiftModifier || event.key === Qt.Key_Backtab)
            settingsTabs.currentIndex = (settingsTabs.currentIndex + settingsTabModel.length - 1) % settingsTabModel.length
        else
            settingsTabs.currentIndex = (settingsTabs.currentIndex + 1) % settingsTabModel.length
        event.accepted = true
    }

    function focusInTextInput() {
        var item = root.activeFocusItem
        while (item) {
            if (item instanceof TextInput || item instanceof TextField)
                return true
            item = item.parent
        }
        return false
    }

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
        if (!loadPanelProc.running) loadPanelProc.running = true
        if (!loadDashboardsProc.running) loadDashboardsProc.running = true
        if (!loadWeatherProc.running) loadWeatherProc.running = true
        if (!loadWallpaperConfigProc.running) loadWallpaperConfigProc.running = true
        if (!loadSecretsProc.running) loadSecretsProc.running = true
        if (!loadHaProc.running) loadHaProc.running = true
        if (!loadIdleProc.running) loadIdleProc.running = true
        if (!loadTrayProc.running) loadTrayProc.running = true
        loadHaDiscovery()
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

    function setBar(output, position) {
        if (!barReady || settingsBusy)
            return
        var out = String(output || "")
        var pos = String(position || "")
        if (!out || (pos !== "top" && pos !== "bottom"))
            return
        barSetProc.output = out
        barSetProc.position = pos
        barSetProc.running = true
    }

    function setNotifications(output, position) {
        if (!notificationsReady || settingsBusy)
            return
        var out = String(output || "")
        var pos = String(position || "")
        if (!out || (pos !== "top" && pos !== "bottom"))
            return
        notificationsSetProc.output = out
        notificationsSetProc.position = pos
        notificationsSetProc.running = true
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
        shell.toggle("evo.sys.themes")
    }

    function openWallpaperPicker() {
        if (!shell)
            return
        shell.toggle("evo.sys.wallpaper")
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
            root.barOutput = String(data.output || "")
            root.barPosition = String(data.position || "bottom")
            root.barReady = true
        } catch (e) {
            root.barReady = false
        }
    }

    function parseNotificationsState(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.notificationsOutput = String(data.output || "")
            root.notificationsPosition = String(data.position || "bottom")
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

    function togglePanelSide() {
        if (!panelSideReady || settingsBusy)
            return
        panelSetProc.side = root.panelSide === "right" ? "left" : "right"
        panelSetProc.running = true
    }

    function toggleStartupDashboard(id, enabled) {
        if (!dashboardsReady || settingsBusy)
            return
        dashboardToggleProc.id = id
        dashboardToggleProc.enabled = enabled
        dashboardToggleProc.running = true
    }

    function startupDashboardEnabled(id) {
        return root.startupOpenIds.indexOf(String(id || "")) >= 0
    }

    function setWeatherLocation(query) {
        if (!weatherReady || settingsBusy)
            return
        weatherSetProc.query = String(query || "")
        weatherSetProc.running = true
    }

    function setPersonalWallpaperDir(path) {
        if (!personalWallpaperReady || settingsBusy)
            return
        var next = String(path || "").trim()
        if (next === personalWallpaperDir)
            return
        wallpaperPersonalDirSetProc.path = next
        wallpaperPersonalDirSetProc.running = true
    }

    function trayWidgetLabel(name) {
        return PluginManifest.trayWidgetSettingsLabel(name, shell ? shell.pluginOverlay : ({}))
    }

    function trayWidgetIcon(name) {
        return PluginManifest.trayWidgetSettingsIcon(name, shell ? shell.pluginOverlay : ({}))
    }

    function trayWidgetShowSecret(name) {
        return PluginManifest.trayWidgetHasSecret(name)
    }

    function openWeatherLocationPicker() {
        if (!weatherReady || settingsBusy)
            return
        weatherLocationPickerOpen = true
        weatherSearchQuery = weatherLocation
        weatherSearchResults = []
        repositionWeatherLocationPopup()
        Qt.callLater(function() {
            repositionWeatherLocationPopup()
            weatherLocationSearchInput.forceActiveFocus()
            weatherSearchDebounce.restart()
        })
    }

    function repositionWeatherLocationPopup() {
        if (!weatherLocationPickerOpen || !weatherLocationRow)
            return
        var pos = weatherLocationRow.mapToItem(root, 0, weatherLocationRow.height + 4)
        weatherLocationPopupX = pos.x
        weatherLocationPopupY = pos.y
        weatherLocationPopupWidth = weatherLocationRow.width
    }

    function closeWeatherLocationPicker() {
        weatherLocationPickerOpen = false
    }

    function pickWeatherLocation(result) {
        if (!result)
            return
        var query = String(result.query || result.name || "")
        closeWeatherLocationPicker()
        setWeatherLocation(query)
    }

    function queueWeatherSearch() {
        if (!weatherLocationPickerOpen)
            return
        weatherSearchDebounce.restart()
    }

    function runWeatherSearch() {
        if (!weatherLocationPickerOpen || settingsBusy)
            return
        weatherSearchBusy = true
        weatherSearchProc.query = String(weatherSearchQuery || "")
        weatherSearchProc.running = true
    }

    function parseWeatherSearch(raw) {
        weatherSearchBusy = false
        try {
            var data = JSON.parse(String(raw || "{}"))
            weatherSearchResults = Array.isArray(data.results) ? data.results : []
        } catch (e) {
            weatherSearchResults = []
        }
    }

    function saveHomeAssistantConfig() {
        if (settingsBusy || !haDiscoveryReady)
            return
        var areas = []
        var climates = []
        var i
        for (i = 0; i < haAreaOptions.length; i++) {
            if (haAreaOptions[i].enabled)
                areas.push(String(haAreaOptions[i].name || ""))
        }
        for (i = 0; i < haClimateOptions.length; i++) {
            if (haClimateOptions[i].enabled)
                climates.push(String(haClimateOptions[i].entityId || ""))
        }
        haSaveProc.areasJson = JSON.stringify(areas)
        haSaveProc.climatesJson = JSON.stringify(climates)
        haSaveProc.running = true
    }

    function syncHaToggleStateFromConfig() {
        if (haAreaOptions.length > 0) {
            var enabledAreas = {}
            var i
            for (i = 0; i < haEnabledLightAreas.length; i++)
                enabledAreas[String(haEnabledLightAreas[i])] = true
            haAreaOptions = haAreaOptions.map(function(row) {
                return { name: row.name, enabled: enabledAreas[row.name] === true }
            })
        }
        if (haClimateOptions.length > 0) {
            var enabledClimates = {}
            var j
            for (j = 0; j < haEnabledClimateEntities.length; j++)
                enabledClimates[String(haEnabledClimateEntities[j])] = true
            haClimateOptions = haClimateOptions.map(function(row) {
                return {
                    entityId: row.entityId,
                    name: row.name,
                    enabled: enabledClimates[row.entityId] === true
                }
            })
        }
    }

    function refreshHomeAssistantService() {
        if (!shell)
            return
        var ha = shell.serviceFor("evo.panels.homeassistant")
        if (ha && typeof ha.refresh === "function")
            ha.refresh(true)
    }

    function loadHaDiscovery() {
        if (settingsBusy)
            return
        loadHaAreasProc.running = true
    }

    function setHaAreaEnabled(index, enabled) {
        if (index < 0 || index >= haAreaOptions.length)
            return
        var next = haAreaOptions.slice()
        next[index] = { name: next[index].name, enabled: enabled === true }
        haAreaOptions = next
        saveHomeAssistantConfig()
    }

    function setHaClimateEnabled(index, enabled) {
        if (index < 0 || index >= haClimateOptions.length)
            return
        var next = haClimateOptions.slice()
        next[index] = {
            entityId: next[index].entityId,
            name: next[index].name,
            enabled: enabled === true
        }
        haClimateOptions = next
        saveHomeAssistantConfig()
    }

    function setIdleLockMin(lockMin) {
        if (!idleReady || settingsBusy)
            return
        idleSetProc.lockMin = lockMin
        idleSetProc.running = true
    }

    function trayWidgetEnabled(name) {
        var key = PluginManifest.normalizeTrayWidgetId(name)
        if (key === "volume" || key === "media") {
            var audio = root.trayWidgets.audio
            if (audio && audio.enabled === false)
                return false
        }
        var w = root.trayWidgets[key]
        return !w || w.enabled !== false
    }

    function moveTrayWidget(from, to) {
        if (settingsBusy || from === to)
            return
        if (from < 0 || to < 0 || from >= trayWidgetOrderIds.length || to >= trayWidgetOrderIds.length)
            return
        var next = trayWidgetOrderIds.slice()
        var item = next.splice(from, 1)[0]
        next.splice(to, 0, item)
        trayWidgetOrderIds = next
        trayOrderSetProc.orderJson = JSON.stringify(next)
        trayOrderSetProc.running = true
    }

    function syncTrayWidgetOrderFallback() {
        if (trayWidgetOrderIds.length > 0)
            return
        if (shell && shell.trayWidgetOrder)
            trayWidgetOrderIds = shell.trayWidgetOrder.slice()
    }

    function toggleTrayWidget(name, enabled) {
        if (!trayReady || settingsBusy)
            return
        trayToggleProc.widget = PluginManifest.normalizeTrayWidgetId(name)
        trayToggleProc.enabled = enabled
        trayToggleProc.running = true
    }

    function parsePanelSideState(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.panelSide = String(data.side || "left") === "right" ? "right" : "left"
            root.panelSideReady = true
        } catch (e) {
            root.panelSideReady = false
        }
    }

    function parseDashboardsState(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            var ids = Array.isArray(data.openOnStart) ? data.openOnStart : []
            root.startupOpenIds = ids.slice()
            root.dashboardsReady = true
        } catch (e) {
            root.startupOpenIds = []
            root.dashboardsReady = false
        }
    }

    function parseWeatherSettings(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.weatherLocation = data.ok === true ? String(data.name || "") : ""
            root.weatherReady = true
        } catch (e) {
            root.weatherLocation = ""
            root.weatherReady = false
        }
    }

    function parseWallpaperConfig(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.personalWallpaperDir = String(data.personalDir || "")
            root.personalWallpaperReady = true
        } catch (e) {
            root.personalWallpaperDir = ""
            root.personalWallpaperReady = false
        }
    }

    function secretEntryDetail(entry) {
        if (!secretsReady || !entry)
            return ""
        return entry.configured ? "Configured" : "Missing"
    }

    function secretDetail(name) {
        if (!secretsReady)
            return ""
        var data = secretsStatus
        if (name === "github")
            return secretEntryDetail(data.github)
        if (name === "cursor")
            return secretEntryDetail(data.cursor)
        if (name === "cloudflare")
            return secretEntryDetail(data.cloudflare)
        if (name === "homeAssistant") {
            var ha = data.homeAssistant
            if (!ha)
                return ""
            var urlOk = ha.url && ha.url.configured
            var tokenOk = ha.token && ha.token.configured
            if (urlOk && tokenOk)
                return "Configured"
            return "Missing"
        }
        return ""
    }

    function parseSecretsStatus(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.secretsStatus = data && typeof data === "object" ? data : ({})
            root.secretsReady = true
        } catch (e) {
            root.secretsStatus = ({})
            root.secretsReady = false
        }
    }

    function parseHaConfig(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            var areas = Array.isArray(data.lightAreas) ? data.lightAreas : []
            var climates = Array.isArray(data.climateEntities) ? data.climateEntities : []
            root.haEnabledLightAreas = areas.slice()
            root.haEnabledClimateEntities = climates.slice()
            root.haLightAreas = areas.join(", ")
            root.haClimateEntities = climates.join(", ")
            root.syncHaToggleStateFromConfig()
            root.haReady = true
        } catch (e) {
            root.haReady = false
        }
    }

    function parseHaDiscovery(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            if (data.ok !== true) {
                haDiscoveryError = String(data.error || "Home Assistant unavailable")
                haAreaOptions = []
                haClimateOptions = []
                haDiscoveryReady = false
                return
            }
            haDiscoveryError = ""
            var enabledAreas = {}
            var enabledClimates = {}
            var enabledAreaList = Array.isArray(data.enabledLightAreas) ? data.enabledLightAreas : []
            var enabledClimateList = Array.isArray(data.enabledClimateEntities) ? data.enabledClimateEntities : []
            var i
            for (i = 0; i < enabledAreaList.length; i++)
                enabledAreas[String(enabledAreaList[i])] = true
            for (i = 0; i < enabledClimateList.length; i++)
                enabledClimates[String(enabledClimateList[i])] = true
            haAreaOptions = (Array.isArray(data.areas) ? data.areas : []).map(function(name) {
                var key = String(name || "")
                return { name: key, enabled: enabledAreas[key] === true }
            })
            haClimateOptions = (Array.isArray(data.climates) ? data.climates : []).map(function(row) {
                var entityId = String(row.entityId || "")
                return {
                    entityId: entityId,
                    name: String(row.name || entityId),
                    enabled: enabledClimates[entityId] === true
                }
            })
            haDiscoveryReady = true
        } catch (e) {
            haDiscoveryError = "Could not load Home Assistant areas"
            haAreaOptions = []
            haClimateOptions = []
            haDiscoveryReady = false
        }
    }

    function parseIdleState(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            var lock = parseInt(data.lock, 10)
            root.idleLockMin = isNaN(lock) ? 15 : Math.max(0, Math.round(lock / 60))
            root.idleReady = true
        } catch (e) {
            root.idleReady = false
        }
    }

    function parseTrayState(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            if (!data || typeof data !== "object")
                throw new Error("invalid tray state")
            if (Array.isArray(data.order))
                root.trayWidgetOrderIds = data.order.slice()
            var widgets = data.widgets && typeof data.widgets === "object" ? data.widgets : data
            var keys = Object.keys(widgets)
            var looksLikeSingleWidget = keys.length > 0
                && keys.indexOf("enabled") >= 0
                && keys.indexOf("weather") < 0
                && keys.indexOf("github") < 0
                && keys.indexOf("order") < 0
            if (looksLikeSingleWidget && trayToggleProc.widget) {
                var next = {}
                var existingKey
                for (existingKey in root.trayWidgets)
                    next[existingKey] = root.trayWidgets[existingKey]
                next[trayToggleProc.widget] = widgets
                root.trayWidgets = next
            } else {
                root.trayWidgets = widgets
            }
            root.syncTrayWidgetOrderFallback()
            root.trayReady = true
        } catch (e) {
            root.trayWidgets = ({})
            root.trayWidgetOrderIds = []
            root.trayReady = false
        }
    }

    function splitCsv(text) {
        return String(text || "").split(",").map(function(s) { return s.trim() }).filter(function(s) { return s !== "" })
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
        id: barSetProc
        property string output: ""
        property string position: ""
        command: ["bash", root.barScript, "bar", "set", barSetProc.output, barSetProc.position]
        stdout: StdioCollector {
            onStreamFinished: root.parseBarState(text)
        }
    }

    Process {
        id: notificationsSetProc
        property string output: ""
        property string position: ""
        command: ["bash", root.barScript, "notifications", "set", notificationsSetProc.output, notificationsSetProc.position]
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
        id: loadPanelProc
        command: ["bash", root.configScript, "panel", "get"]
        stdout: StdioCollector {
            onStreamFinished: root.parsePanelSideState(text)
        }
    }

    Process {
        id: panelSetProc
        property string side: "left"
        command: ["bash", root.configScript, "panel", "set", panelSetProc.side]
        stdout: StdioCollector {
            onStreamFinished: root.parsePanelSideState(text)
        }
    }

    Process {
        id: loadDashboardsProc
        command: ["bash", root.configScript, "dashboards", "get"]
        stdout: StdioCollector {
            onStreamFinished: root.parseDashboardsState(text)
        }
    }

    Process {
        id: dashboardToggleProc
        property string id: ""
        property bool enabled: true
        command: ["bash", root.configScript, "dashboards", "set", dashboardToggleProc.id, dashboardToggleProc.enabled ? "on" : "off"]
        stdout: StdioCollector {
            onStreamFinished: root.parseDashboardsState(text)
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
        property string query: ""
        command: ["bash", root.weatherScript, "settings", "set", weatherSetProc.query]
        stdout: StdioCollector {
            onStreamFinished: root.parseWeatherSettings(text)
        }
    }

    Process {
        id: loadWallpaperConfigProc
        command: ["bash", root.configScript, "wallpaper", "get"]
        stdout: StdioCollector {
            onStreamFinished: root.parseWallpaperConfig(text)
        }
    }

    Process {
        id: wallpaperPersonalDirSetProc
        property string path: ""
        command: ["bash", root.configScript, "wallpaper", "set-personal-dir", wallpaperPersonalDirSetProc.path]
        stdout: StdioCollector {
            onStreamFinished: {
                root.parseWallpaperConfig(text)
                if (!loadWallpaperListProc.running)
                    loadWallpaperListProc.running = true
            }
        }
    }

    Process {
        id: weatherSearchProc
        property string query: ""
        command: ["bash", root.weatherScript, "settings", "search", weatherSearchProc.query]
        stdout: StdioCollector {
            onStreamFinished: root.parseWeatherSearch(text)
        }
    }

    Timer {
        id: weatherSearchDebounce
        interval: 300
        repeat: false
        onTriggered: root.runWeatherSearch()
    }

    Process {
        id: loadSecretsProc
        command: ["bash", root.configScript, "secrets", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: root.parseSecretsStatus(text)
        }
    }

    Process {
        id: loadHaProc
        command: ["bash", root.configScript, "homeassistant", "get"]
        stdout: StdioCollector {
            onStreamFinished: root.parseHaConfig(text)
        }
    }

    Process {
        id: haSaveProc
        property string areasJson: "[]"
        property string climatesJson: "[]"
        command: ["bash", root.configScript, "homeassistant", "set-fields", haSaveProc.areasJson, haSaveProc.climatesJson]
        stdout: StdioCollector {
            onStreamFinished: {
                root.parseHaConfig(text)
                root.refreshHomeAssistantService()
            }
        }
    }

    Process {
        id: loadHaAreasProc
        command: ["bash", root.configScript, "homeassistant", "areas"]
        stdout: StdioCollector {
            onStreamFinished: root.parseHaDiscovery(text)
        }
    }

    Process {
        id: loadIdleProc
        command: ["bash", root.configScript, "idle", "get"]
        stdout: StdioCollector {
            onStreamFinished: root.parseIdleState(text)
        }
    }

    Process {
        id: idleSetProc
        property int lockMin: root.idleLockMin
        command: ["bash", root.configScript, "idle", "set-fields", String(idleSetProc.lockMin)]
        stdout: StdioCollector {
            onStreamFinished: root.parseIdleState(text)
        }
    }

    Process {
        id: loadTrayProc
        command: ["bash", root.configScript, "tray", "get"]
        stdout: StdioCollector {
            onStreamFinished: root.parseTrayState(text)
        }
    }

    Process {
        id: trayToggleProc
        property string widget: ""
        property bool enabled: true
        command: ["bash", root.configScript, "tray", "set", trayToggleProc.widget, "enabled", trayToggleProc.enabled ? "on" : "off"]
        stdout: StdioCollector {
            onStreamFinished: root.parseTrayState(text)
        }
    }

    Process {
        id: trayOrderSetProc
        property string orderJson: JSON.stringify(root.trayWidgetOrderIds)
        command: ["bash", root.configScript, "tray", "order", "set", trayOrderSetProc.orderJson]
        stdout: StdioCollector {
            onStreamFinished: root.parseTrayState(text)
        }
    }

    readonly property var settingsTabModel: [
        { label: "Settings", icon: "󰒠" },
        { label: "Integrations", icon: "󰒓" },
        { label: "Home Assistant", icon: "󰠵" }
    ]

    implicitHeight: parent && parent.height > 0 ? parent.height : settingsLayout.implicitHeight
    implicitWidth: Theme.settingsPanelWidth

    ColumnLayout {
        id: settingsLayout
        anchors.fill: parent
        spacing: Theme.hoverPanelSectionSpacing

        SettingsTabBar {
            id: settingsTabs
            Layout.fillWidth: true
            tabs: root.settingsTabModel
        }

        Connections {
            target: settingsTabs
            function onCurrentIndexChanged() {
                if (settingsTabs.currentIndex !== 1)
                    root.closeWeatherLocationPicker()
                if (settingsTabs.currentIndex === 2)
                    root.loadHaDiscovery()
            }
        }

        StackLayout {
            id: settingsStack
            Layout.fillWidth: true
            Layout.fillHeight: parent.height > 0
            currentIndex: settingsTabs.currentIndex

            Flickable {
                id: settingsScroll
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                width: parent.width
                height: parent.height > 0 ? parent.height : contentHeight
                contentWidth: width
                contentHeight: settingsColumn.implicitHeight

                Item {
                    id: settingsColumn
                    width: parent.width
                    implicitHeight: settingsRow.implicitHeight
                    clip: true

                    readonly property int columnSpacing: Theme.hoverPanelSectionSpacing
                    readonly property int leftColumnWidth: Math.max(1, Math.floor((width - columnSpacing) * 0.66))
                    readonly property int rightColumnWidth: Math.max(1, width - columnSpacing - leftColumnWidth)

                    RowLayout {
                        id: settingsRow
                        width: parent.width
                        spacing: settingsColumn.columnSpacing

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: settingsColumn.leftColumnWidth
                            Layout.maximumWidth: settingsColumn.leftColumnWidth
                            Layout.alignment: Qt.AlignTop
                            spacing: settingsColumn.columnSpacing

                            SectionPanel {
                                Layout.fillWidth: true
                                Layout.preferredWidth: settingsColumn.leftColumnWidth
                                Layout.maximumWidth: settingsColumn.leftColumnWidth
                                Layout.alignment: Qt.AlignTop
                                width: settingsColumn.leftColumnWidth
                                legendBackground: Theme.background
                                label: ""

                                HoverPanelLabelPill {
                                    text: "Shell"
                                    icon: "󰍳"
                                    fontSize: Theme.fontSizeS
                                }

                                                MonitorLayoutPicker {
                                                    Layout.fillWidth: true
                                                    barOutput: root.barOutput
                                                    barPosition: root.barPosition
                                                    notificationsOutput: root.notificationsOutput
                                                    notificationsPosition: root.notificationsPosition
                                                    enabled: root.barReady && root.notificationsReady && !settingsBusy
                                                    onBarChosen: function(output, position) {
                                                        root.setBar(output, position)
                                                    }
                                                    onNotificationsChosen: function(output, position) {
                                                        root.setNotifications(output, position)
                                                    }
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
                                                    label: "Fieldset radius"
                                                    checked: root.fieldsetRoundingOn
                                                    enabled: root.uiReady && !settingsBusy
                                                    onToggled: root.toggleFieldsetRounding()
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

                                                SliderSetting {
                                                    Layout.fillWidth: true
                                                    label: "Lock after"
                                                    value: root.idleLockMin
                                                    minimum: 0
                                                    maximum: 120
                                                    step: 5
                                                    valueSuffix: "m"
                                                    enabled: root.idleReady && !settingsBusy
                                                    onValueCommitted: root.setIdleLockMin(value)
                                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: settingsColumn.rightColumnWidth
                            Layout.maximumWidth: settingsColumn.rightColumnWidth
                            Layout.alignment: Qt.AlignTop
                            spacing: settingsColumn.columnSpacing

                            SectionPanel {
                                Layout.fillWidth: true
                                Layout.preferredWidth: settingsColumn.rightColumnWidth
                                Layout.maximumWidth: settingsColumn.rightColumnWidth
                                Layout.alignment: Qt.AlignTop
                                width: settingsColumn.rightColumnWidth
                                legendBackground: Theme.background
                                label: ""

                                HoverPanelLabelPill {
                                    text: "Theme"
                                    icon: "󰸌"
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
                                                            Layout.preferredHeight: 80
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
                                                                font.pixelSize: Theme.fontSize5xl
                                                            }
                                                        }

                                                        Text {
                                                            Layout.fillWidth: true
                                                            horizontalAlignment: Text.AlignHCenter
                                                            text: root.themeDisplayName
                                                            color: Theme.foreground
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: Theme.fontSizeS
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
                                                            Layout.preferredHeight: 80
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
                                                                font.pixelSize: Theme.fontSize5xl
                                                            }
                                                        }

                                                        Text {
                                                            Layout.fillWidth: true
                                                            horizontalAlignment: Text.AlignHCenter
                                                            text: root.wallpaperDisplayName
                                                            color: Theme.foreground
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: Theme.fontSizeS
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

                            SectionPanel {
                                Layout.fillWidth: true
                                Layout.preferredWidth: settingsColumn.rightColumnWidth
                                Layout.maximumWidth: settingsColumn.rightColumnWidth
                                Layout.alignment: Qt.AlignTop
                                width: settingsColumn.rightColumnWidth
                                legendBackground: Theme.background
                                label: ""

                                HoverPanelLabelPill {
                                    text: "Font"
                                    icon: "󰛖"
                                    fontSize: Theme.fontSizeS
                                }

                                                FontFamilyPicker {
                                                    Layout.fillWidth: true
                                                    label: "Family"
                                                    value: root.fontFamily
                                                    model: root.fontFamilies
                                                    enabled: root.fontReady && !settingsBusy
                                                    onActivated: function(family) {
                                                        root.fontFamily = family
                                                        root.setFont("family", family)
                                                    }
                                                }

                                                SliderSetting {
                                                    Layout.fillWidth: true
                                                    label: "UI scale"
                                                    value: root.fontScalePercent
                                                    valueSuffix: "%"
                                                    minimum: 50
                                                    maximum: 150
                                                    step: 10
                                                    enabled: false
                                                }
                            }
                        }
                    }
                }
            }

            Flickable {
                id: integrationsTabScroll
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                width: parent.width
                height: parent.height > 0 ? parent.height : contentHeight
                contentWidth: width
                contentHeight: integrationsTabContent.implicitHeight

                onContentYChanged: root.repositionWeatherLocationPopup()
                onWidthChanged: root.repositionWeatherLocationPopup()

                Item {
                    id: integrationsTabContent
                    width: parent.width
                    implicitHeight: integrationsRow.implicitHeight
                    clip: true

                    readonly property int columnSpacing: Theme.hoverPanelSectionSpacing
                    readonly property int leftColumnWidth: Math.max(1, Math.floor((width - columnSpacing) * 0.66))
                    readonly property int rightColumnWidth: Math.max(1, width - columnSpacing - leftColumnWidth)

                    RowLayout {
                        id: integrationsRow
                        width: parent.width
                        spacing: integrationsTabContent.columnSpacing

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: integrationsTabContent.leftColumnWidth
                            Layout.maximumWidth: integrationsTabContent.leftColumnWidth
                            Layout.alignment: Qt.AlignTop
                            spacing: integrationsTabContent.columnSpacing

                            SectionPanel {
                                Layout.fillWidth: true
                                Layout.preferredWidth: integrationsTabContent.leftColumnWidth
                                Layout.maximumWidth: integrationsTabContent.leftColumnWidth
                                Layout.alignment: Qt.AlignTop
                                width: integrationsTabContent.leftColumnWidth
                                notchLegend: true
                                legendText: "Bar widgets"
                                legendIcon: "󰝲"
                                legendBackground: Theme.background
                                label: ""

                                Text {
                                    Layout.fillWidth: true
                                    text: "Drag rows to reorder widgets in the bar"
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    opacity: Theme.opacityMuted
                                    wrapMode: Text.WordWrap
                                }

                                ListView {
                                    id: trayWidgetList
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: contentHeight
                                    clip: true
                                    spacing: Theme.spacing2
                                    boundsBehavior: Flickable.StopAtBounds
                                    interactive: dragIndex < 0
                                    model: root.trayWidgetOrderIds

                                    property int dragIndex: -1
                                    property int dropIndex: -1

                                    delegate: Item {
                                        id: trayWidgetRow
                                        required property int index
                                        required property string modelData

                                        readonly property string widgetId: String(modelData || "")
                                        readonly property bool rowEnabled: root.trayReady && !settingsBusy

                                        width: trayWidgetList.width
                                        height: Math.max(32, trayWidgetRowLayout.implicitHeight + 4)
                                        opacity: trayWidgetList.dragIndex === index ? 0.55 : 1

                                        Rectangle {
                                            anchors.top: parent.top
                                            width: parent.width
                                            height: 2
                                            color: Theme.accent
                                            visible: trayWidgetList.dragIndex >= 0
                                                && trayWidgetList.dropIndex === index
                                                && trayWidgetList.dropIndex !== trayWidgetList.dragIndex
                                        }

                                        RowLayout {
                                            id: trayWidgetRowLayout
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: Theme.spacingS

                                            Item {
                                                Layout.preferredWidth: 22
                                                Layout.preferredHeight: 28

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰇅"
                                                    color: Theme.foreground
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fontSizeL
                                                    opacity: trayDragMouse.enabled
                                                        ? (trayDragMouse.drag.active || trayDragMouse.pressed
                                                            ? 1 : (trayDragMouse.containsMouse ? 0.72 : 0.35))
                                                        : 0.2
                                                }

                                                MouseArea {
                                                    id: trayDragMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.SizeAllCursor
                                                    preventStealing: true
                                                    enabled: trayWidgetRow.rowEnabled
                                                    drag.target: trayDragLift
                                                    drag.axis: Drag.YAxis
                                                    drag.threshold: 6

                                                    Item {
                                                        id: trayDragLift
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        width: 1
                                                        height: parent.height
                                                    }

                                                    onPressed: function(mouse) {
                                                        trayWidgetList.dragIndex = trayWidgetRow.index
                                                        trayWidgetList.dropIndex = trayWidgetRow.index
                                                    }

                                                    onPositionChanged: function(mouse) {
                                                        if (!drag.active || trayWidgetList.dragIndex < 0)
                                                            return
                                                        var pos = mapToItem(trayWidgetList.contentItem, width / 2, mouse.y)
                                                        var target = trayWidgetList.indexAt(pos.x, pos.y)
                                                        if (target < 0)
                                                            return
                                                        trayWidgetList.dropIndex = target
                                                    }

                                                    onReleased: function(mouse) {
                                                        if (trayWidgetList.dragIndex >= 0
                                                                && trayWidgetList.dropIndex >= 0
                                                                && trayWidgetList.dropIndex !== trayWidgetList.dragIndex)
                                                            root.moveTrayWidget(
                                                                trayWidgetList.dragIndex,
                                                                trayWidgetList.dropIndex)
                                                        trayDragLift.y = 0
                                                        trayWidgetList.dragIndex = -1
                                                        trayWidgetList.dropIndex = -1
                                                    }

                                                    onCanceled: {
                                                        trayDragLift.y = 0
                                                        trayWidgetList.dragIndex = -1
                                                        trayWidgetList.dropIndex = -1
                                                    }
                                                }
                                            }

                                            ToggleRow {
                                                Layout.fillWidth: true
                                                icon: root.trayWidgetIcon(trayWidgetRow.widgetId)
                                                label: root.trayWidgetLabel(trayWidgetRow.widgetId)
                                                detail: root.trayWidgetShowSecret(trayWidgetRow.widgetId)
                                                    ? root.secretDetail(trayWidgetRow.widgetId) : ""
                                                detailInline: root.trayWidgetShowSecret(trayWidgetRow.widgetId)
                                                checked: root.trayWidgetEnabled(trayWidgetRow.widgetId)
                                                enabled: trayWidgetRow.rowEnabled
                                                onToggled: root.toggleTrayWidget(
                                                    trayWidgetRow.widgetId,
                                                    !root.trayWidgetEnabled(trayWidgetRow.widgetId))
                                            }
                                        }
                                    }
                                }
                            }

                            SectionPanel {
                                Layout.fillWidth: true
                                Layout.preferredWidth: integrationsTabContent.leftColumnWidth
                                Layout.maximumWidth: integrationsTabContent.leftColumnWidth
                                Layout.alignment: Qt.AlignTop
                                width: integrationsTabContent.leftColumnWidth
                                notchLegend: true
                                legendText: "Startup"
                                legendIcon: "󰄖"
                                legendBackground: Theme.background
                                label: ""

                                ToggleRow {
                                    Layout.fillWidth: true
                                    label: "Player"
                                    checked: root.startupDashboardEnabled("evo.panels.player")
                                    enabled: root.dashboardsReady && !settingsBusy
                                    onToggled: root.toggleStartupDashboard(
                                        "evo.panels.player",
                                        !root.startupDashboardEnabled("evo.panels.player"))
                                }

                                Repeater {
                                    model: root.shell ? root.shell.extensionStartupDashboards : []

                                    delegate: ToggleRow {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        label: modelData.label
                                        checked: root.startupDashboardEnabled(modelData.id)
                                        enabled: root.dashboardsReady && !settingsBusy
                                        onToggled: root.toggleStartupDashboard(
                                            modelData.id,
                                            !root.startupDashboardEnabled(modelData.id))
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: integrationsTabContent.rightColumnWidth
                            Layout.maximumWidth: integrationsTabContent.rightColumnWidth
                            Layout.alignment: Qt.AlignTop
                            spacing: integrationsTabContent.columnSpacing

                            SectionPanel {
                                Layout.fillWidth: true
                                Layout.preferredWidth: integrationsTabContent.rightColumnWidth
                                Layout.maximumWidth: integrationsTabContent.rightColumnWidth
                                Layout.alignment: Qt.AlignTop
                                width: integrationsTabContent.rightColumnWidth
                                notchLegend: true
                                legendText: "Locations"
                                legendIcon: "󰍎"
                                legendBackground: Theme.background
                                label: ""

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        text: "Weather location"
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeS
                                        opacity: Theme.opacityMuted
                                    }

                                    RowLayout {
                                        id: weatherLocationRow
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
                                                text: root.weatherLocation
                                                enabled: root.weatherReady && !settingsBusy
                                                onEditingFinished: root.setWeatherLocation(text)
                                            }
                                        }

                                        Item {
                                            Layout.preferredWidth: 34
                                            Layout.preferredHeight: 34

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 6
                                                color: root.weatherLocationPickerOpen || weatherLocationPickMouse.containsMouse
                                                    ? Theme.foregroundHoverWash
                                                    : Theme.foregroundWash
                                                border.color: root.weatherLocationPickerOpen
                                                    ? Theme.accent
                                                    : Theme.foregroundDivider
                                                border.width: 1
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰍎"
                                                color: Theme.foreground
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeXl
                                                opacity: weatherLocationPickMouse.enabled
                                                    ? (weatherLocationPickMouse.containsMouse || root.weatherLocationPickerOpen ? 1 : 0.72)
                                                    : 0.35
                                            }

                                            MouseArea {
                                                id: weatherLocationPickMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                preventStealing: true
                                                enabled: root.weatherReady && !settingsBusy
                                                onClicked: {
                                                    if (root.weatherLocationPickerOpen)
                                                        root.closeWeatherLocationPicker()
                                                    else
                                                        root.openWeatherLocationPicker()
                                                }
                                            }
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        text: "Personal wallpapers"
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
                                            text: root.personalWallpaperDir
                                            enabled: root.personalWallpaperReady && !settingsBusy
                                            onEditingFinished: root.setPersonalWallpaperDir(text)
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: "Images here appear in the wallpaper carousel."
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        opacity: Theme.opacityMuted
                                        wrapMode: Text.WordWrap
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
                        }
                    }
                }
            }

            Flickable {
                id: haTabScroll
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                width: parent.width
                height: parent.height > 0 ? parent.height : contentHeight
                contentWidth: width
                contentHeight: haTabContent.implicitHeight

                Item {
                    id: haTabContent
                    width: parent.width
                    implicitHeight: haTabRow.implicitHeight
                    clip: true

                    readonly property int columnSpacing: Theme.hoverPanelSectionSpacing
                    readonly property int leftColumnWidth: Math.max(1, Math.floor((width - columnSpacing) * 0.66))
                    readonly property int rightColumnWidth: Math.max(1, width - columnSpacing - leftColumnWidth)

                    RowLayout {
                        id: haTabRow
                        width: parent.width
                        spacing: haTabContent.columnSpacing

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: haTabContent.leftColumnWidth
                            Layout.maximumWidth: haTabContent.leftColumnWidth
                            Layout.alignment: Qt.AlignTop
                            spacing: haTabContent.columnSpacing

                            SectionPanel {
                                Layout.fillWidth: true
                                Layout.preferredWidth: haTabContent.leftColumnWidth
                                Layout.maximumWidth: haTabContent.leftColumnWidth
                                Layout.alignment: Qt.AlignTop
                                width: haTabContent.leftColumnWidth
                                notchLegend: true
                                legendText: "Areas"
                                legendIcon: "󰠵"
                                legendBackground: Theme.background
                                label: ""

                                Text {
                                    Layout.fillWidth: true
                                    text: root.haDiscoveryError !== ""
                                        ? root.haDiscoveryError
                                        : "Choose light areas from your Home Assistant instance."
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    opacity: Theme.opacityMuted
                                    wrapMode: Text.WordWrap
                                }

                                Repeater {
                                    model: root.haAreaOptions.length

                                    ToggleRow {
                                        Layout.fillWidth: true
                                        property int rowIndex: index
                                        property var rowData: root.haAreaOptions[rowIndex]
                                        label: rowData ? rowData.name : ""
                                        checked: rowData ? rowData.enabled === true : false
                                        enabled: root.haDiscoveryReady && !settingsBusy
                                        onToggled: root.setHaAreaEnabled(rowIndex, !checked)
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: haTabContent.rightColumnWidth
                            Layout.maximumWidth: haTabContent.rightColumnWidth
                            Layout.alignment: Qt.AlignTop
                            spacing: haTabContent.columnSpacing

                            SectionPanel {
                                Layout.fillWidth: true
                                Layout.preferredWidth: haTabContent.rightColumnWidth
                                Layout.maximumWidth: haTabContent.rightColumnWidth
                                Layout.alignment: Qt.AlignTop
                                width: haTabContent.rightColumnWidth
                                notchLegend: true
                                legendText: "Climate"
                                legendIcon: "󱤖"
                                legendBackground: Theme.background
                                label: ""

                                Repeater {
                                    model: root.haClimateOptions.length

                                    ToggleRow {
                                        Layout.fillWidth: true
                                        property int rowIndex: index
                                        property var rowData: root.haClimateOptions[rowIndex]
                                        label: rowData ? rowData.name : ""
                                        checked: rowData ? rowData.enabled === true : false
                                        enabled: root.haDiscoveryReady && !settingsBusy
                                        onToggled: root.setHaClimateEnabled(rowIndex, !checked)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        z: 500
        anchors.fill: parent
        visible: root.weatherLocationPickerOpen
        enabled: root.weatherLocationPickerOpen
        onClicked: root.closeWeatherLocationPicker()
    }

    Rectangle {
        id: weatherLocationPopup
        z: 501
        visible: root.weatherLocationPickerOpen
        x: root.weatherLocationPopupX
        y: root.weatherLocationPopupY
        width: Math.max(220, root.weatherLocationPopupWidth)
        radius: Theme.radiusL
        color: Theme.panelMantle
        border.color: Theme.foregroundPickerBorder
        border.width: 1
        implicitHeight: visible
            ? Math.min(220, weatherLocationSearchInput.implicitHeight + weatherLocationResults.contentHeight + 24)
            : 0
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: Theme.radiusL
                color: Theme.foregroundWash
                border.color: Theme.foregroundDivider
                border.width: 1

                TextField {
                    id: weatherLocationSearchInput
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.mantle
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    enabled: root.weatherReady
                    text: root.weatherSearchQuery
                    placeholderText: "Search city…"
                    background: Item {}
                    onTextChanged: {
                        root.weatherSearchQuery = text
                        root.queueWeatherSearch()
                    }
                    Keys.onEscapePressed: root.closeWeatherLocationPicker()
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.weatherSearchBusy
                text: "Searching…"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                opacity: Theme.opacityMuted
            }

            ListView {
                id: weatherLocationResults
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(160, Math.max(28, count * 28))
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.weatherSearchResults
                spacing: 2

                delegate: Item {
                    required property var modelData
                    required property int index
                    width: weatherLocationResults.width
                    height: 28

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusS
                        color: resultMouse.containsMouse ? Theme.foregroundHoverWash : "transparent"
                    }

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        verticalAlignment: Text.AlignVCenter
                        text: String(modelData.label || modelData.name || "")
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeS
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: resultMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pickWeatherLocation(modelData)
                    }
                }
            }
        }
    }
}
