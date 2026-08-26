import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../commons"
import "../../pluginManifest.js" as PluginManifest
import "../../vendor/evoplayer/qml/panel/settings"
import "."

Item {
    id: root

    property var host: null
    property var shell: null
    property bool showTabBar: true
    readonly property bool compactLayout: !showTabBar
    property alias tabIndex: settingsTabs.currentIndex
    property string menuFilterText: ""
    property int settingsKeyIndex: 0
    property var settingsNavItems: []

    readonly property string hyprScript: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-hyprland")
    readonly property string barScript: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-layout")
    readonly property string fontScript: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-font")
    readonly property string mediaScript: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-bar-library")
    readonly property string tasksScript: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-tasks")
    readonly property string configScript: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-config")
    readonly property string weatherScript: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-bar-weather")
    readonly property string packagesScript: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-system-packages")
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
    property string tasksFile: ""
    property bool tasksReady: false
    property string panelSide: "left"
    property bool panelSideReady: false
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
    property bool packagesLoading: false
    property bool packagesReady: false
    property string packagesError: ""
    property var packagesSummary: ({})
    property var packagesCategories: []
    property var packagesOrphans: []
    property int idleLockMin: 15
    property bool idleReady: false
    property var trayWidgets: ({})
    property var trayWidgetOrderIds: []
    property var barChromeWidgets: ({})
    property var barChromeOrderIds: []
    property var barWidgetOrderIds: []
    property bool trayReady: false
    readonly property bool ready: hyprReady && barReady && fontReady
    readonly property bool fontBusy: fontSetProc.running
    readonly property bool mediaBusy: mediaTvSetProc.running || mediaFilmsSetProc.running
        || mediaTvPickProc.running || mediaFilmsPickProc.running
    readonly property bool settingsBusy: fontBusy || mediaBusy || hyprToggleProc.running || hyprSetProc.running
        || barSetProc.running || notificationsSetProc.running || uiToggleProc.running
        || panelSetProc.running || weatherSetProc.running
        || wallpaperPersonalDirSetProc.running || wallpaperPersonalDirPickProc.running
        || haSaveProc.running || idleSetProc.running
        || trayToggleProc.running || trayOrderSetProc.running
    readonly property bool active: host && host.opened
        && (host.activeModule === "settings" || host.settingsEmbedded === true)

    Keys.onEscapePressed: {
        if (root.weatherLocationPickerOpen) {
            root.weatherLocationPickerOpen = false
            return
        }
        if (host)
            host.dismiss()
    }
    Keys.onPressed: function(event) {
        if (!root.showTabBar)
            return
        if (event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab)
            return
        if (!(event.modifiers & Qt.ControlModifier) && focusInTextInput())
            return
        if (event.modifiers & Qt.ShiftModifier || event.key === Qt.Key_Backtab)
            settingsTabs.currentIndex = (settingsTabs.currentIndex + looksTabModel.length - 1) % looksTabModel.length
        else
            settingsTabs.currentIndex = (settingsTabs.currentIndex + 1) % looksTabModel.length
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

    function isEffectivelyVisible(item) {
        var node = item
        while (node) {
            if (node.visible === false || node.opacity === 0)
                return false
            node = node.parent
        }
        return true
    }

    function collectSettingsNavItems(item, out) {
        if (!item)
            return
        if (item.enabled !== false && root.isEffectivelyVisible(item)) {
            if (item.settingsNavInput !== undefined)
                out.push({ kind: "input", target: item, input: item.settingsNavInput })
            else if (typeof item.toggled === "function" && item.keyboardSelected !== undefined)
                out.push({ kind: "toggle", target: item })
            else if (typeof item.valueCommitted === "function" && item.maximum !== undefined)
                out.push({ kind: "slider", target: item })
        }
        var kids = item.children
        if (!kids)
            return
        for (var i = 0; i < kids.length; i++)
            root.collectSettingsNavItems(kids[i], out)
    }

    function currentSettingsNavEntry() {
        var list = root.settingsNavItems
        if (!list || list.length === 0)
            return null
        var idx = Math.max(0, Math.min(root.settingsKeyIndex, list.length - 1))
        return list[idx]
    }

    function clearSettingsNavHighlights() {
        var list = root.settingsNavItems
        for (var i = 0; i < list.length; i++) {
            var target = list[i].target
            if (target && target.keyboardSelected !== undefined)
                target.keyboardSelected = false
        }
    }

    function releaseTextFocus() {
        if (!root.focusInTextInput())
            return
        var item = root.activeFocusItem
        if (item && item.focus !== undefined)
            item.focus = false
        root.forceActiveFocus()
    }

    function activeTabContent() {
        switch (settingsTabs.currentIndex) {
        case 0: return looksTab
        case 1: return displaysTab
        case 2: return integrationsColumn
        case 3: return wallpapersTab
        case 4: return weatherTab
        case 5: return mediaTab
        case 6: return homeAssistantTab
        case 7: return packagesTabColumn
        case 8: return playerSettingsHost
        default: return null
        }
    }

    function activeTabFlickable() {
        switch (settingsTabs.currentIndex) {
        case 0: return looksTabScroll
        case 1: return displaysTabScroll
        case 2: return integrationsTabScroll
        case 3: return wallpapersTabScroll
        case 4: return weatherTabScroll
        case 5: return mediaTabScroll
        case 6: return homeAssistantTabScroll
        case 7: return packagesTabScroll
        case 8: return playerTabScroll
        default: return null
        }
    }

    function rebuildSettingsNav() {
        if (!root.compactLayout)
            return
        var out = []
        root.collectSettingsNavItems(root.activeTabContent(), out)
        root.clearSettingsNavHighlights()
        root.settingsNavItems = out
        if (root.settingsKeyIndex >= out.length)
            root.settingsKeyIndex = Math.max(0, out.length - 1)
        root.applySettingsKeyFocus()
    }

    function applySettingsKeyFocus() {
        root.clearSettingsNavHighlights()
        var entry = root.currentSettingsNavEntry()
        if (!entry)
            return
        if (entry.target && entry.target.keyboardSelected !== undefined)
            entry.target.keyboardSelected = true
        root.ensureSettingsNavVisible(entry.target)
    }

    function ensureSettingsNavVisible(target) {
        var flick = root.activeTabFlickable()
        if (!flick || !target)
            return
        var pos = target.mapToItem(flick.contentItem, 0, 0)
        var y = pos.y
        var bottom = y + target.height
        if (y < flick.contentY)
            flick.contentY = Math.max(0, y)
        else if (bottom > flick.contentY + flick.height)
            flick.contentY = Math.max(0, bottom - flick.height)
    }

    function moveSettingsFocus(delta) {
        if (!root.compactLayout)
            return
        root.releaseTextFocus()
        root.rebuildSettingsNav()
        var count = root.settingsNavItems.length
        if (count <= 0)
            return
        root.settingsKeyIndex = (root.settingsKeyIndex + delta + count) % count
        root.applySettingsKeyFocus()
    }

    function adjustSettingsNavHorizontal(delta) {
        if (!root.compactLayout || root.focusInTextInput())
            return false
        root.rebuildSettingsNav()
        var entry = root.currentSettingsNavEntry()
        if (!entry || entry.kind !== "slider" || !entry.target || entry.target.enabled === false)
            return false
        var slider = entry.target
        var next = Math.max(slider.minimum, Math.min(slider.maximum, slider.value + delta * slider.step))
        if (next === slider.value)
            return true
        slider.dragValue = next
        slider.value = next
        slider.valueEdited(next)
        slider.valueCommitted(next)
        return true
    }

    function activateSettingsFocus() {
        if (!root.compactLayout)
            return
        root.rebuildSettingsNav()
        var entry = root.currentSettingsNavEntry()
        if (!entry || !entry.target || entry.target.enabled === false)
            return
        if (entry.kind === "toggle")
            entry.target.toggled()
        else if (entry.kind === "input" && entry.input)
            entry.input.forceActiveFocus()
    }

    onMenuFilterTextChanged: Qt.callLater(root.rebuildSettingsNav)

    function sectionFilterVisible(label) {
        var q = String(menuFilterText || "").trim().toLowerCase()
        if (!q)
            return true
        return String(label || "").toLowerCase().indexOf(q) >= 0
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

    function dismissHostForExternalDialog() {
        if (host && typeof host.dismiss === "function")
            host.dismiss()
        else if (shell)
            shell.hide("evo.sys.menu")
    }

    function startExternalPicker(pickProc) {
        if (!pickProc)
            return
        dismissHostForExternalDialog()
        Qt.callLater(function() {
            pickProc.running = true
        })
    }

    function pickMediaTv() {
        if (!mediaReady || settingsBusy)
            return
        suppressMediaPathCommit = true
        startExternalPicker(mediaTvPickProc)
    }

    function pickMediaFilms() {
        if (!mediaReady || settingsBusy)
            return
        suppressMediaPathCommit = true
        startExternalPicker(mediaFilmsPickProc)
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
        Qt.callLater(function() {
            root.forceActiveFocus()
            root.rebuildSettingsNav()
        })
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
            root.tasksFile = String(data.tasksFile || "")
            root.tasksReady = data.ok === true
        } catch (e) {
            root.tasksFile = ""
            root.tasksReady = false
        }
    }

    function togglePanelSide() {
        if (!panelSideReady || settingsBusy)
            return
        panelSetProc.side = root.panelSide === "right" ? "left" : "right"
        panelSetProc.running = true
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

    function pickPersonalWallpaperDir() {
        if (!personalWallpaperReady || settingsBusy)
            return
        startExternalPicker(wallpaperPersonalDirPickProc)
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

    function isBarChromeWidget(name) {
        return PluginManifest.isBarChromeWidgetId(name)
    }

    function barWidgetLabel(name) {
        if (isBarChromeWidget(name))
            return PluginManifest.barChromeWidgetSettingsLabel(name)
        return trayWidgetLabel(name)
    }

    function barWidgetIcon(name) {
        if (isBarChromeWidget(name))
            return PluginManifest.barChromeWidgetSettingsIcon(name)
        return trayWidgetIcon(name)
    }

    function barWidgetEnabled(name) {
        if (isBarChromeWidget(name)) {
            var chrome = root.barChromeWidgets[name]
            return !chrome || chrome.enabled !== false
        }
        return trayWidgetEnabled(name)
    }

    function toggleBarWidget(name, enabled) {
        if (!trayReady || settingsBusy)
            return
        trayToggleProc.widget = isBarChromeWidget(name)
            ? String(name)
            : PluginManifest.normalizeTrayWidgetId(name)
        trayToggleProc.enabled = enabled
        trayToggleProc.running = true
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

    function loadPackagesBreakdown() {
        if (packagesLoading)
            return
        packagesLoading = true
        packagesReady = false
        packagesError = ""
        loadPackagesProc.running = true
    }

    function parsePackagesBreakdown(raw) {
        packagesLoading = false
        try {
            var data = JSON.parse(String(raw || "{}"))
            if (data.ok !== true) {
                packagesError = String(data.error || "Could not load packages")
                packagesSummary = ({})
                packagesCategories = []
                packagesOrphans = []
                packagesReady = false
                return
            }
            packagesError = ""
            packagesSummary = data.summary && typeof data.summary === "object" ? data.summary : ({})
            packagesCategories = Array.isArray(data.categories) ? data.categories : []
            packagesOrphans = Array.isArray(data.orphans) ? data.orphans : []
            packagesReady = true
        } catch (e) {
            packagesError = "Could not load packages"
            packagesSummary = ({})
            packagesCategories = []
            packagesOrphans = []
            packagesReady = false
        }
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

    function moveBarWidget(from, to) {
        if (settingsBusy || from === to)
            return
        if (from < 0 || to < 0 || from >= barWidgetOrderIds.length || to >= barWidgetOrderIds.length)
            return
        var next = barWidgetOrderIds.slice()
        var item = next.splice(from, 1)[0]
        next.splice(to, 0, item)
        barWidgetOrderIds = next
        trayOrderSetProc.orderJson = JSON.stringify(next)
        trayOrderSetProc.running = true
    }

    function syncTrayWidgetOrderFallback() {
        if (trayWidgetOrderIds.length > 0)
            return
        if (shell && shell.trayWidgetOrder)
            trayWidgetOrderIds = shell.trayWidgetOrder.slice()
    }

    function syncBarChromeOrderFallback() {
        if (barChromeOrderIds.length > 0)
            return
        barChromeOrderIds = PluginManifest.defaultBarChromeWidgetOrder()
    }

    function syncBarWidgetOrderFallback() {
        if (barWidgetOrderIds.length > 0)
            return
        if (trayWidgetOrderIds.length > 0) {
            barWidgetOrderIds = trayWidgetOrderIds.slice()
            return
        }
        if (shell && shell.trayWidgetOrder && shell.trayWidgetOrder.length > 0) {
            barWidgetOrderIds = shell.trayWidgetOrder.slice()
            return
        }
        barWidgetOrderIds = PluginManifest.defaultTrayWidgetOrder(
            shell ? shell.pluginOverlay : ({}))
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
        if (root.compactLayout)
            Qt.callLater(root.rebuildSettingsNav)
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
            if (data.barChrome && typeof data.barChrome === "object")
                root.barChromeWidgets = data.barChrome
            if (Array.isArray(data.barChromeOrder))
                root.barChromeOrderIds = data.barChromeOrder.slice()
            if (Array.isArray(data.barWidgetOrder))
                root.barWidgetOrderIds = data.barWidgetOrder.slice()
            else if (Array.isArray(data.order))
                root.barWidgetOrderIds = data.order.slice()
            else
                root.barWidgetOrderIds = []
            var widgets = data.widgets && typeof data.widgets === "object" ? data.widgets : data
            var keys = Object.keys(widgets)
            var looksLikeSingleWidget = keys.length > 0
                && keys.indexOf("enabled") >= 0
                && keys.indexOf("weather") < 0
                && keys.indexOf("github") < 0
                && keys.indexOf("order") < 0
            if (looksLikeSingleWidget && trayToggleProc.widget) {
                if (root.isBarChromeWidget(trayToggleProc.widget)) {
                    var chromeNext = {}
                    var chromeKey
                    for (chromeKey in root.barChromeWidgets)
                        chromeNext[chromeKey] = root.barChromeWidgets[chromeKey]
                    chromeNext[trayToggleProc.widget] = widgets
                    root.barChromeWidgets = chromeNext
                } else {
                    var next = {}
                    var existingKey
                    for (existingKey in root.trayWidgets)
                        next[existingKey] = root.trayWidgets[existingKey]
                    next[trayToggleProc.widget] = widgets
                    root.trayWidgets = next
                }
            } else {
                root.trayWidgets = widgets
            }
            root.syncTrayWidgetOrderFallback()
            root.syncBarChromeOrderFallback()
            root.syncBarWidgetOrderFallback()
            root.trayReady = true
        } catch (e) {
            root.trayWidgets = ({})
            root.trayWidgetOrderIds = []
            root.barChromeWidgets = ({})
            root.barChromeOrderIds = []
            root.barWidgetOrderIds = []
            root.trayReady = false
        }
        if (root.compactLayout)
            Qt.callLater(root.rebuildSettingsNav)
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
        id: wallpaperPersonalDirPickProc
        command: ["bash", root.configScript, "wallpaper", "pick-personal-dir"]
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
        id: loadPackagesProc
        command: ["bash", root.packagesScript, "breakdown"]
        stdout: StdioCollector {
            onStreamFinished: root.parsePackagesBreakdown(text)
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
        property string orderJson: JSON.stringify(root.barWidgetOrderIds)
        command: ["bash", root.configScript, "tray", "order", "set", trayOrderSetProc.orderJson]
        stdout: StdioCollector {
            onStreamFinished: root.parseTrayState(text)
        }
    }

    readonly property var looksTabModel: PluginManifest.extensionSettingsTabs([
        { label: "Looks", icon: "󰒠" },
        { label: "Displays", icon: "󰍹" },
        { label: "Widgets", icon: "󰒓" },
        { label: "Wallpapers", icon: "󰏘" },
        { label: "Weather", icon: "󰖕" },
        { label: "Media", icon: "󰿯" },
        { label: "Home Assistant", icon: "󰠵" },
        { label: "Packages", icon: "󰏖" },
        { label: "Player", icon: "󰎆" }
    ], shell ? shell.pluginOverlay : null)

    property alias weatherLocationRow: weatherTab.weatherLocationRow

    implicitHeight: parent && parent.height > 0 ? parent.height : settingsLayout.implicitHeight
    implicitWidth: root.compactLayout
        ? (host && host.width > 0
            ? host.width
            : Theme.menuPanelWidth(Quickshell.screens.length > 0 ? Quickshell.screens[0].width : 1920))
        : Theme.settingsPanelWidth
    readonly property int looksTabContentHeight: looksTab.implicitHeight

    RowLayout {
        id: settingsLayout
        anchors.fill: parent
        spacing: root.showTabBar ? Theme.spacingM : 0

        SettingsTabBar {
            id: settingsTabs
            visible: root.showTabBar
            vertical: true
            Layout.preferredWidth: root.showTabBar ? Theme.settingsSideTabWidth : 0
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            tabs: root.looksTabModel
            onTabActivated: function(index) {
                settingsTabs.currentIndex = index
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

        Connections {
            target: settingsTabs
            function onCurrentIndexChanged() {
                if (settingsTabs.currentIndex !== 4)
                    root.closeWeatherLocationPicker()
                root.settingsKeyIndex = 0
                Qt.callLater(root.rebuildSettingsNav)
                if (settingsTabs.currentIndex === 1) {
                    if (!loadBarProc.running)
                        loadBarProc.running = true
                    if (!loadNotificationsProc.running)
                        loadNotificationsProc.running = true
                }
                if (settingsTabs.currentIndex === 6)
                    root.loadHaDiscovery()
                if (settingsTabs.currentIndex === 7)
                    root.loadPackagesBreakdown()
                if (settingsTabs.currentIndex === 8)
                    playerSettingsHost.loadPlayerSettings()
            }
        }

        StackLayout {
            id: settingsStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            currentIndex: settingsTabs.currentIndex

            Flickable {
                id: looksTabScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: looksTab.implicitHeight

                LooksTab {
                    id: looksTab
                    width: parent.width
                    module: root
                }
            }

            Flickable {
                id: displaysTabScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: displaysTab.implicitHeight

                DisplaysTab {
                    id: displaysTab
                    width: parent.width
                    module: root
                }
            }

            Flickable {
                id: integrationsTabScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: integrationsColumn.implicitHeight

                ColumnLayout {
                    id: integrationsColumn
                    width: parent.width
                    spacing: Theme.hoverPanelSectionSpacing

                    SectionPanel {
                        visible: root.sectionFilterVisible("Bar widgets")
                        Layout.fillWidth: true
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
                                    model: root.barWidgetOrderIds

                                    property int dragIndex: -1
                                    property int dropIndex: -1

                                    delegate: Item {
                                        id: trayWidgetRow
                                        required property int index
                                        required property string modelData

                                        readonly property string widgetId: String(modelData || "")
                                        readonly property bool isChromeWidget: root.isBarChromeWidget(trayWidgetRow.widgetId)
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
                                                            root.moveBarWidget(
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
                                                icon: root.barWidgetIcon(trayWidgetRow.widgetId)
                                                label: root.barWidgetLabel(trayWidgetRow.widgetId)
                                                detail: !trayWidgetRow.isChromeWidget && root.trayWidgetShowSecret(trayWidgetRow.widgetId)
                                                    ? root.secretDetail(trayWidgetRow.widgetId) : ""
                                                detailInline: !trayWidgetRow.isChromeWidget && root.trayWidgetShowSecret(trayWidgetRow.widgetId)
                                                checked: root.barWidgetEnabled(trayWidgetRow.widgetId)
                                                enabled: trayWidgetRow.rowEnabled
                                                onToggled: root.toggleBarWidget(
                                                    trayWidgetRow.widgetId,
                                                    !root.barWidgetEnabled(trayWidgetRow.widgetId))
                                            }
                                        }
                                    }
                                }
                    }
                }
            }

            Flickable {
                id: wallpapersTabScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: wallpapersTab.implicitHeight

                WallpapersTab {
                    id: wallpapersTab
                    width: parent.width
                    module: root
                }
            }

            Flickable {
                id: weatherTabScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: weatherTab.implicitHeight

                onContentYChanged: root.repositionWeatherLocationPopup()
                onWidthChanged: root.repositionWeatherLocationPopup()

                WeatherTab {
                    id: weatherTab
                    width: parent.width
                    module: root
                }
            }

            Flickable {
                id: mediaTabScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: mediaTab.implicitHeight

                MediaTab {
                    id: mediaTab
                    width: parent.width
                    module: root
                }
            }

            Flickable {
                id: homeAssistantTabScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: homeAssistantTab.implicitHeight

                HomeAssistantTab {
                    id: homeAssistantTab
                    width: parent.width
                    module: root
                }
            }

            Flickable {
                id: packagesTabScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: packagesTabContent.implicitHeight

                Item {
                    id: packagesTabContent
                    width: parent.width
                    implicitHeight: packagesTabColumn.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: packagesTabColumn
                        width: parent.width
                        spacing: Theme.hoverPanelSectionSpacing

                        Text {
                            Layout.fillWidth: true
                            visible: root.packagesLoading
                            text: "Loading packages…"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeS
                            opacity: Theme.opacityMuted
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: !root.packagesLoading && root.packagesError !== ""
                            text: root.packagesError
                            color: Theme.urgent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeS
                            wrapMode: Text.WordWrap
                        }

                        SectionPanel {
                            visible: !root.packagesLoading && root.packagesReady
                                && root.sectionFilterVisible("Summary")
                            Layout.fillWidth: true
                            notchLegend: true
                            legendText: "Summary"
                            legendIcon: "󰋼"
                            legendBackground: Theme.background
                            label: ""

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingS

                                Repeater {
                                    model: [
                                        { label: "total", text: String(root.packagesSummary.total || 0) + " total" },
                                        { label: "explicit", text: String(root.packagesSummary.explicit || 0) + " explicit" },
                                        { label: "foreign", text: String(root.packagesSummary.foreign || 0) + " AUR" },
                                        { label: "orphans", text: String(root.packagesSummary.orphans || 0) + " orphans" },
                                        { label: "mise", text: String(root.packagesSummary.mise || 0) + " mise" }
                                    ]

                                    HoverPanelLabelPill {
                                        required property var modelData
                                        text: modelData.text
                                        fontSize: Theme.fontSizeS
                                        fieldsetLegend: false
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }
                        }

                        Repeater {
                            model: root.packagesCategories

                            SectionPanel {
                                required property var modelData
                                visible: !root.packagesLoading && root.packagesReady
                                    && root.sectionFilterVisible(modelData.name)
                                Layout.fillWidth: true
                                notchLegend: true
                                legendText: modelData.name + " (" + (modelData.packages ? modelData.packages.length : 0) + ")"
                                legendIcon: "󰏖"
                                legendBackground: Theme.background
                                label: ""

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Repeater {
                                        model: modelData.packages || []

                                        RowLayout {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            spacing: Theme.spacingM

                                            Text {
                                                Layout.fillWidth: true
                                                text: String(modelData.name || "")
                                                color: Theme.foreground
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeS
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                visible: modelData.source === "aur"
                                                text: "AUR"
                                                color: Theme.accent
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeXs
                                                font.bold: Theme.fontBold
                                            }

                                            Text {
                                                Layout.preferredWidth: Math.min(180, implicitWidth)
                                                text: String(modelData.version || "")
                                                color: Theme.foreground
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeXs
                                                opacity: Theme.opacityMuted
                                                horizontalAlignment: Text.AlignRight
                                                elide: Text.ElideLeft
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        SectionPanel {
                            visible: !root.packagesLoading && root.packagesReady && root.packagesOrphans.length > 0
                                && root.sectionFilterVisible("Orphans")
                            Layout.fillWidth: true
                            notchLegend: true
                            legendText: "Orphans"
                            legendIcon: "󰀨"
                            legendBackground: Theme.background
                            label: ""

                            Text {
                                Layout.fillWidth: true
                                text: "Unused dependencies (pacman -Qdt)"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                                opacity: Theme.opacityMuted
                                wrapMode: Text.WordWrap
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: Theme.spacingS

                                Repeater {
                                    model: root.packagesOrphans

                                    HoverPanelLabelPill {
                                        required property string modelData
                                        text: modelData
                                        fontSize: Theme.fontSizeXs
                                        fieldsetLegend: false
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Flickable {
                id: playerTabScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: Math.max(height, playerSettingsHost.implicitHeight)

                PlayerSettingsModule {
                    id: playerSettingsHost
                    width: parent.width
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
