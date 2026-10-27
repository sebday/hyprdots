import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.commons
import "../settings"
import "MenuEntries.js" as MenuEntries
import "LauncherSources.js" as LauncherSources
import "views"

Item {
    id: root

    property var shell: null
    property bool opened: false
    property string view: "root"
    property string query: ""
    property int selectedIndex: 0
    property bool actionsOpen: false
    property int actionIndex: 0
    property string wallpaperFilter: "current"

    property var cachedApps: []
    property var appIconMap: ({})
    property var programRunCounts: ({})
    property var themeEntries: []
    property var wallpaperEntries: []
    property var emojiAll: []
    property var themePreview: ({ valid: false })
    property var emojiRecents: []
    property string currentThemeName: ""
    property string currentWallpaperPath: ""

    readonly property string home: Quickshell.env("HOME")
    readonly property string hyprScript: Util.evoshellScript(home, shell, "evo-hyprland")
    readonly property string programRunsPath: Util.statePath(home, "menu-program-runs.json")
    readonly property string emojiRecentsPath: Util.statePath(home, "launcher-emoji-recents.json")
    readonly property string emojiPath: {
        var dir = shell && shell.shellDir ? String(shell.shellDir) : String(Quickshell.shellDir)
        return dir + "/modules/menu/emoji.json"
    }
    readonly property var extensionPanels: shell && shell.extensionSystemMenuPanels
        ? shell.extensionSystemMenuPanels
        : []
    readonly property var settingsState: ({
        gapsOn: embeddedSettings.gapsOn,
        animationsOn: embeddedSettings.animationsOn,
        roundingOn: embeddedSettings.roundingOn,
        fieldsetRoundingOn: embeddedSettings.fieldsetRoundingOn
    })
    readonly property var commandList: MenuEntries.commandEntries(home, extensionPanels)
    readonly property var rootResults: LauncherSources.buildRoot(
        query, cachedApps, programRunCounts, commandList, settingsState, themeEntries, wallpaperEntries)
    readonly property var sessionResults: LauncherSources.filterEntries(
        MenuEntries.sessionEntries(home), query)
    readonly property var themeResults: LauncherSources.filterThemes(themeEntries, query, currentThemeName)
    readonly property var wallpaperResults: LauncherSources.filterWallpapers(
        wallpaperEntries, query, wallpaperFilter, currentThemeName, currentWallpaperPath)
    readonly property var emojiResults: view === "emoji"
        ? LauncherSources.filterEmoji(emojiAll, "", emojiRecents)
        : []
    readonly property bool searching: String(query).trim() !== ""
    readonly property string themeColorsPath: {
        if (view !== "themes" || searching || !selectedEntry || selectedEntry.kind !== "theme")
            return ""
        var name = String(selectedEntry.name || "").trim()
        if (!name || name.indexOf("/") >= 0 || name.indexOf("..") >= 0)
            return ""
        return home + "/.themes/" + name + "/colors.toml"
    }
    readonly property var currentEntries: {
        if (searching)
            return rootResults
        if (view === "session")
            return sessionResults
        if (view === "themes")
            return themeResults
        if (view === "wallpapers")
            return wallpaperResults
        if (view === "clipboard")
            return clipboardView.visibleEntries
        if (view === "emoji")
            return emojiResults
        if (view === "looks")
            return []
        return rootResults
    }
    readonly property var selectedEntry: {
        var list = currentEntries
        if (!list || selectedIndex < 0 || selectedIndex >= list.length)
            return null
        return list[selectedIndex]
    }
    readonly property var actionItems: {
        if (!searching && view === "calc")
            return [
                { id: "copy", label: "Copy result" },
                { id: "clear", label: "Clear history", key: "backspace" }
            ]
        if (!searching && view === "looks")
            return [{ id: "toggle", label: "Toggle" }]
        return LauncherSources.actionsFor(selectedEntry)
    }
    readonly property bool gridNav: !searching && (view === "themes" || view === "wallpapers" || view === "emoji")
    readonly property int gridColumns: {
        if (view === "emoji")
            return emojiGrid.columnCount
        if (view === "themes" || view === "wallpapers")
            return previewGrid.columnCount
        return 1
    }
    readonly property var sectionPills: [
        { id: "root", label: "Apps" },
        { id: "clipboard", label: "Clipboard" },
        { id: "calc", label: "Calculator" },
        { id: "emoji", label: "Emoji" },
        { id: "looks", label: "Looks" },
        { id: "themes", label: "Themes" },
        { id: "wallpapers", label: "Wallpapers" },
        { id: "session", label: "Power" }
    ]
    readonly property string sectionLabel: {
        for (var i = 0; i < sectionPills.length; i++) {
            if (sectionPills[i].id === view)
                return sectionPills[i].label
        }
        return "Apps"
    }
    readonly property string placeholder: "Search apps, commands, themes…"
    readonly property string primaryLabel: {
        if (!searching && view === "looks")
            return "Toggle"
        if (!searching && view === "calc")
            return "Copy"
        return LauncherSources.primaryHint(selectedEntry)
    }
    readonly property bool showEmpty: searching
        ? rootResults.length === 0
        : view !== "looks" && view !== "clipboard" && view !== "calc" && currentEntries.length === 0

    function parsePayload(payloadJson) {
        var viewName = "root"
        var nextQuery = ""
        try {
            var payload = JSON.parse(payloadJson || "{}")
            if (payload.view)
                viewName = String(payload.view)
            else if (String(payload.submenu || "") === "session")
                viewName = "session"
            else if (String(payload.submenu || "") === "themes")
                viewName = "themes"
            else if (String(payload.submenu || "") === "wallpaper" || String(payload.submenu || "") === "wallpapers")
                viewName = "wallpapers"
            else {
                var tab = String(payload.tab || payload.panel || "").toLowerCase()
                if (tab === "looks" || tab === "settings" || tab === "1")
                    viewName = "looks"
            }
            if (String(payload.mode || "") === "runner")
                viewName = "root"
            if (payload.query)
                nextQuery = String(payload.query)
        } catch (e) {
            viewName = "root"
        }
        var allowed = {
            root: true,
            themes: true,
            wallpapers: true,
            clipboard: true,
            emoji: true,
            looks: true,
            session: true,
            calc: true
        }
        if (!allowed[viewName])
            viewName = "root"
        return { view: viewName, query: nextQuery }
    }

    function applyThemeColors(raw) {
        var found = {}
        var lines = String(raw || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line || line.charAt(0) === "#")
                continue
            var eq = line.indexOf("=")
            if (eq < 0)
                continue
            var key = line.slice(0, eq).trim()
            if (key !== "foreground" && key !== "background" && key !== "accent" && key !== "mantle")
                continue
            var value = line.slice(eq + 1).trim()
            if (value.length >= 2 && value.charAt(0) === "\"" && value.charAt(value.length - 1) === "\"")
                value = value.slice(1, -1)
            found[key] = value
        }
        if (!found.background || !found.foreground) {
            themePreview = { valid: false }
            return
        }
        themePreview = {
            valid: true,
            foreground: found.foreground,
            background: found.background,
            accent: found.accent || found.foreground,
            mantle: found.mantle || found.background
        }
    }

    function applyView(nextView, nextQuery) {
        view = nextView
        query = String(nextQuery || "")
        selectedIndex = 0
        actionsOpen = false
        if (searchField.text !== query)
            searchField.text = query
        if (nextView === "looks") {
            Qt.callLater(function() {
                embeddedSettings.onActivated()
            })
        } else if (nextView === "clipboard") {
            clipboardView.refresh()
        } else if (nextView === "calc") {
            calcView.refresh()
        }
        Qt.callLater(root.syncBackdrop)
    }

    function selectSection(sectionId) {
        var next = String(sectionId || "root")
        if (view === next && query === "")
            return
        applyView(next, "")
        Qt.callLater(function() { searchField.forceActiveFocus() })
    }

    function cycleSection(direction) {
        var pills = sectionPills
        if (!pills || pills.length === 0)
            return
        var index = -1
        for (var i = 0; i < pills.length; i++) {
            if (pills[i].id === view) {
                index = i
                break
            }
        }
        var next = 0
        if (index < 0)
            next = direction < 0 ? pills.length - 1 : 0
        else
            next = (index + direction + pills.length) % pills.length
        selectSection(pills[next].id)
    }

    function open(payloadJson) {
        if (shell)
            shell.hide("evo.dock")
        var next = parsePayload(payloadJson)
        opened = true
        syncMenuSpecial(true)
        applyView(next.view, next.query)
        refreshCatalogs()
        embeddedSettings.refresh()
        Qt.callLater(function() {
            searchField.forceActiveFocus()
        })
    }

    function close() {
        if (!opened)
            return
        opened = false
        syncMenuSpecial(false)
        actionsOpen = false
        query = ""
        view = "root"
        selectedIndex = 0
        if (searchField.text !== "")
            searchField.text = ""
        backdrop.clear()
    }

    function dismiss() {
        if (shell)
            shell.hide("evo.sys.menu")
        else
            close()
    }

    function reopen(payloadJson) {
        if (!opened)
            return false
        var next = parsePayload(payloadJson)
        if (next.view === view && next.query === query)
            return false
        applyView(next.view, next.query)
        Qt.callLater(function() {
            searchField.forceActiveFocus()
        })
        return true
    }

    function goBack() {
        if (view !== "root") {
            applyView("root", "")
            return
        }
        dismiss()
    }

    function setQuery(text) {
        var next = String(text || "")
        if (query !== next)
            query = next
        selectedIndex = 0
        actionsOpen = false
    }

    function handleEscape() {
        if (actionsOpen) {
            actionsOpen = false
            return
        }
        if (view === "looks" && embeddedSettings.focusInTextInput()) {
            embeddedSettings.releaseTextFocus()
            return
        }
        goBack()
    }

    function toggleActions() {
        var count = actionItems.length
        if (count <= 0)
            return
        if (!actionsOpen) {
            actionIndex = count > 1 ? 1 : 0
            actionsOpen = true
            return
        }
        actionIndex = (actionIndex + 1) % count
    }

    function actionIndexForEvent(event, fieldText) {
        var items = actionItems
        var empty = String(fieldText || "").length === 0
        var alt = (event.modifiers & Qt.AltModifier) !== 0
        var shift = (event.modifiers & Qt.ShiftModifier) !== 0
        var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        if (!items || ctrl)
            return -1
        for (var i = 0; i < items.length; i++) {
            var key = items[i] && items[i].key ? String(items[i].key) : ""
            if (!key)
                continue
            if (key === "backspace" && event.key === Qt.Key_Backspace)
                return empty ? i : -1
            if (key.length === 1 && !shift && event.text && String(event.text).toLowerCase() === key) {
                if (empty || alt)
                    return i
            }
        }
        return -1
    }

    function runVisibleAction(index) {
        var action = actionItems[index]
        if (!action)
            return
        actionsOpen = false
        if (!searching && view === "calc") {
            runCalcAction(action.id)
            return
        }
        if (!searching && view === "looks") {
            embeddedSettings.activateSettingsFocus()
            return
        }
        if (selectedEntry)
            runAction(selectedEntry, action.id)
    }

    function moveVertical(delta) {
        if (actionsOpen) {
            var count = actionItems.length
            if (count <= 0)
                return
            actionIndex = (actionIndex + delta + count) % count
            return
        }
        if (searching) {
            moveSelection(delta)
            return
        }
        if (view === "looks") {
            if (embeddedSettings.focusInTextInput())
                return
            embeddedSettings.moveSettingsFocus(delta)
            return
        }
        if (view === "calc") {
            calcView.recall(delta)
            return
        }
        if (gridNav) {
            moveGrid(0, delta)
            return
        }
        moveSelection(delta)
    }

    function moveHorizontal(delta) {
        if (actionsOpen || !gridNav)
            return
        moveGrid(delta, 0)
    }

    function moveSelection(delta) {
        var count = currentEntries.length
        if (count <= 0) {
            selectedIndex = 0
            return
        }
        var next = selectedIndex + delta
        if (next < 0)
            next = count - 1
        else if (next >= count)
            next = 0
        selectedIndex = next
    }

    function moveGrid(dx, dy) {
        var count = currentEntries.length
        if (count <= 0) {
            selectedIndex = 0
            return
        }
        var cols = Math.max(1, gridColumns)
        var index = selectedIndex
        if (index < 0)
            index = 0
        if (dx !== 0) {
            var stepped = index + dx
            if (stepped < 0)
                stepped = count - 1
            else if (stepped >= count)
                stepped = 0
            selectedIndex = stepped
            return
        }
        var col = index % cols
        var row = Math.floor(index / cols)
        var rows = Math.max(1, Math.ceil(count / cols))
        var targetRow = row + dy
        if (targetRow < 0)
            targetRow = rows - 1
        else if (targetRow >= rows)
            targetRow = 0
        var target = targetRow * cols + col
        if (target >= count)
            target = count - 1
        selectedIndex = target
    }

    function applyCalcRecall(text) {
        var next = String(text || "")
        if (searchField.text !== next)
            searchField.text = next
        query = next
        searchField.cursorPosition = searchField.text.length
        actionsOpen = false
    }

    function submitCalc() {
        var live = LauncherSources.calculatorEntry(query)
        if (!live)
            return
        copyText(live.result)
        var notif = shell ? shell.serviceFor("evo.sys.notifications") : null
        if (notif && typeof notif.showBrief === "function")
            notif.showBrief("Calculator", "Copied " + live.result)
        calcView.remember(live.expr, live.result)
        if (searchField.text !== live.result)
            searchField.text = live.result
        query = live.result
        searchField.cursorPosition = searchField.text.length
    }

    function runCalcAction(actionId) {
        if (actionId === "clear") {
            calcView.clearHistory()
            return
        }
        submitCalc()
    }

    function activateSelection() {
        if (actionsOpen) {
            runVisibleAction(actionIndex)
            return
        }
        if (!searching && view === "calc") {
            submitCalc()
            return
        }
        if (!searching && view === "looks") {
            embeddedSettings.activateSettingsFocus()
            return
        }
        if (selectedEntry)
            runAction(selectedEntry, "")
    }

    function runAction(entry, actionId) {
        if (!entry)
            return
        var action = String(actionId || "")
        if (!action) {
            var actions = LauncherSources.actionsFor(entry)
            action = actions.length > 0 ? actions[0].id : "run"
        }
        if (entry.kind === "view" || action === "open") {
            applyView(entry.view, "")
            return
        }
        if (entry.kind === "setting") {
            if (entry.view) {
                applyView(entry.view, "")
                return
            }
            if (entry.action === "toggleHypr")
                embeddedSettings.toggleHypr(entry.arg)
            else if (entry.action === "toggleFieldsetRounding")
                embeddedSettings.toggleFieldsetRounding()
            return
        }
        if (entry.kind === "calc") {
            copyText(entry.result)
            recordCalc(entry.expr, entry.result)
            dismiss()
            return
        }
        if (entry.kind === "app") {
            recordProgramRun(entry.id)
            launchDesktopEntry(entry)
            dismiss()
            return
        }
        if (entry.kind === "clipboard") {
            if (action === "pin") {
                clipboardView.togglePin(entry)
                return
            }
            if (action === "delete") {
                clipboardView.deleteEntry(entry)
                return
            }
            clipboardView.copyEntry(entry)
            dismiss()
            return
        }
        if (entry.kind === "emoji") {
            rememberEmoji(entry.emoji)
            if (action === "type") {
                dismiss()
                typeText(entry.emoji)
                return
            }
            copyText(entry.emoji)
            dismiss()
            return
        }
        if (entry.command)
            runCommand(entry.command)
        dismiss()
    }

    function runCommand(cmd) {
        var command = String(cmd || "").trim()
        if (!command)
            return
        Quickshell.execDetached(["bash", "-lc", command])
    }

    function copyText(text) {
        Quickshell.execDetached(["bash", "-lc", "printf %s " + Util.shellQuote(String(text || "")) + " | wl-copy"])
    }

    function typeText(text) {
        Quickshell.execDetached(["bash", "-lc",
            "sleep 0.2; command -v wtype >/dev/null && wtype -- " + Util.shellQuote(String(text || ""))])
    }

    function recordCalc(expr, result) {
        var script = Util.evoshellScript(home, shell, "evo-calculator")
        Quickshell.execDetached(["bash", script, "add", String(expr || ""), String(result || "")])
    }

    function launchDesktopEntry(entry) {
        var entryRef = entry.entryRef
        if (entryRef && entryRef.runInTerminal)
            Quickshell.execDetached(["gtk-launch", String(entry.id)])
        else if (entryRef && typeof entryRef.execute === "function")
            entryRef.execute()
        else
            Quickshell.execDetached(["gtk-launch", String(entry.id)])
    }

    function programRunCount(id) {
        var n = programRunCounts[String(id || "")]
        if (typeof n === "number")
            return n
        return parseInt(n, 10) || 0
    }

    function loadProgramRuns() {
        try {
            var raw = String(programRunsFile.text() || "").trim()
            if (!raw) {
                programRunCounts = {}
                return
            }
            var data = JSON.parse(raw)
            programRunCounts = data && data.counts && typeof data.counts === "object" ? data.counts : {}
        } catch (e) {
            programRunCounts = {}
        }
    }

    function saveProgramRuns() {
        var payload = JSON.stringify({ counts: programRunCounts })
        saveProgramRunsProc.command = ["bash", "-lc",
            "mkdir -p $(dirname " + Util.shellQuote(programRunsPath) + ") && printf '%s' "
                + Util.shellQuote(payload) + " > " + Util.shellQuote(programRunsPath)]
        if (!saveProgramRunsProc.running)
            saveProgramRunsProc.running = true
    }

    function recordProgramRun(id) {
        var key = String(id || "").trim()
        if (!key)
            return
        var next = {}
        for (var k in programRunCounts)
            next[k] = programRunCounts[k]
        next[key] = programRunCount(key) + 1
        programRunCounts = next
        saveProgramRuns()
    }

    function loadEmojiRecents() {
        try {
            var raw = String(emojiRecentsFile.text() || "").trim()
            var data = raw ? JSON.parse(raw) : []
            emojiRecents = Array.isArray(data) ? data : []
        } catch (e) {
            emojiRecents = []
        }
    }

    function saveEmojiRecents() {
        var payload = JSON.stringify(emojiRecents)
        saveEmojiRecentsProc.command = ["bash", "-lc",
            "mkdir -p $(dirname " + Util.shellQuote(emojiRecentsPath) + ") && printf '%s' "
                + Util.shellQuote(payload) + " > " + Util.shellQuote(emojiRecentsPath)]
        if (!saveEmojiRecentsProc.running)
            saveEmojiRecentsProc.running = true
    }

    function rememberEmoji(ch) {
        var key = String(ch || "")
        if (!key)
            return
        var next = [key]
        for (var i = 0; i < emojiRecents.length; i++) {
            if (emojiRecents[i] !== key)
                next.push(emojiRecents[i])
            if (next.length >= 32)
                break
        }
        emojiRecents = next
        saveEmojiRecents()
    }

    function rebuildAppCache() {
        var list = []
        var indexByName = {}
        try {
            var values = DesktopEntries.applications.values || []
            for (var i = 0; i < values.length; i++) {
                var entry = values[i]
                if (!entry || !entry.id || entry.noDisplay)
                    continue
                var words = []
                if (entry.genericName)
                    words.push(String(entry.genericName))
                if (entry.comment)
                    words.push(String(entry.comment))
                var keywords = entry.keywords || []
                for (var k = 0; k < keywords.length; k++)
                    words.push(String(keywords[k]))
                var item = {
                    kind: "app",
                    name: String(entry.name || entry.id),
                    id: entry.id,
                    entryRef: entry,
                    keywords: words,
                    iconName: String(entry.icon || ""),
                    iconSource: appIconMap[entry.id] || Util.iconSourceForName(String(entry.icon || "")) || ""
                }
                var key = item.name.trim().toLowerCase()
                var existing = indexByName[key]
                if (existing === undefined) {
                    indexByName[key] = list.length
                    list.push(item)
                } else if (!list[existing].iconName && item.iconName) {
                    list[existing] = item
                }
            }
        } catch (e) {
            console.warn("launcher app list failed:", e)
        }
        cachedApps = list
        loadAppIcons()
    }

    function loadAppIcons() {
        var listScript = Util.evoshellScript(home, shell, "evo-menu-list")
        loadAppIconsProc.command = ["bash", "-lc",
            "test -x " + Util.shellQuote(listScript) + " && " + Util.shellQuote(listScript) + " icons"]
        if (!loadAppIconsProc.running)
            loadAppIconsProc.running = true
    }

    function applyAppIconMap(raw) {
        var map = {}
        var lines = String(raw || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line)
                continue
            var tab = line.indexOf("\t")
            if (tab === -1)
                continue
            map[line.slice(0, tab)] = line.slice(tab + 1)
        }
        appIconMap = map
        var rebuilt = []
        for (var j = 0; j < cachedApps.length; j++) {
            var app = cachedApps[j]
            rebuilt.push({
                kind: app.kind,
                name: app.name,
                id: app.id,
                entryRef: app.entryRef,
                keywords: app.keywords,
                iconSource: (app.id && map[app.id]) ? map[app.id] : (app.iconSource || "")
            })
        }
        cachedApps = rebuilt
    }

    function refreshCatalogs() {
        if (!themesProc.running)
            themesProc.running = true
        if (!wallpapersProc.running)
            wallpapersProc.running = true
    }

    function syncMenuSpecial(show) {
        if (!hyprScript)
            return
        menuSpecialProc.command = ["bash", hyprScript, "menu-special", show ? "open" : "close"]
        menuSpecialProc.running = true
    }

    function syncBackdrop() {
        if (!opened || (view !== "themes" && view !== "wallpapers")) {
            backdrop.clear()
            return
        }
        var entry = selectedEntry
        var path = entry && entry.preview ? String(entry.preview) : ""
        if (!path) {
            backdrop.clear()
            return
        }
        backdrop.show(path, backdrop.basePath === "")
    }

    onCurrentEntriesChanged: {
        if (selectedIndex >= currentEntries.length)
            selectedIndex = Math.max(0, currentEntries.length - 1)
    }
    onSelectedEntryChanged: syncBackdrop()
    onViewChanged: syncBackdrop()

    Process { id: menuSpecialProc }
    Process { id: saveProgramRunsProc }
    Process { id: saveEmojiRecentsProc }
    Process { id: previewWarmProc }

    FileView {
        id: programRunsFile
        path: root.programRunsPath
        watchChanges: false
        printErrors: false
        onLoaded: root.loadProgramRuns()
        onLoadFailed: root.programRunCounts = {}
    }

    FileView {
        id: emojiRecentsFile
        path: root.emojiRecentsPath
        watchChanges: false
        printErrors: false
        onLoaded: root.loadEmojiRecents()
        onLoadFailed: root.emojiRecents = []
    }

    FileView {
        id: emojiFile
        path: root.emojiPath
        watchChanges: false
        printErrors: false
        onLoaded: {
            try {
                var data = JSON.parse(String(emojiFile.text() || "[]"))
                root.emojiAll = Array.isArray(data) ? data : []
            } catch (e) {
                console.warn("launcher emoji load failed:", e)
                root.emojiAll = []
            }
        }
    }

    FileView {
        id: themeColorsFile
        path: root.themeColorsPath
        watchChanges: false
        printErrors: false
        onLoaded: root.applyThemeColors(text())
        onLoadFailed: root.themePreview = ({ valid: false })
    }

    QtObject {
        id: panelPalette
        readonly property bool live: root.view === "themes" && !root.searching && root.themePreview.valid
        readonly property color foreground: live ? root.themePreview.foreground : Theme.foreground
        readonly property color background: live ? root.themePreview.background : Theme.background
        readonly property color accent: live ? root.themePreview.accent : Theme.accent
        readonly property color mantle: live ? root.themePreview.mantle : Theme.mantle
        readonly property color panelMantle: live
            ? Theme.mixColors(mantle, foreground, Theme.panelMantleLift)
            : Theme.panelMantle
        readonly property color surface: live
            ? Theme.withOpacity(mantle, Theme.surfaceOpacity)
            : Theme.overlaySurface
        readonly property color foregroundWash: Theme.withOpacity(foreground, 0.06)
        readonly property color foregroundHoverWash: Theme.withOpacity(foreground, 0.1)
        readonly property color foregroundDivider: Theme.withOpacity(foreground, 0.14)
        readonly property color foregroundBorder: Theme.withOpacity(foreground, 0.32)
    }

    FileView {
        id: themeNameFile
        path: root.home + "/.themes/current/.theme-name"
        watchChanges: true
        printErrors: false
        onLoaded: root.currentThemeName = String(themeNameFile.text() || "").trim()
        onFileChanged: reload()
    }

    FileView {
        id: wallpaperStateFile
        path: Util.statePath(root.home, "wallpaper")
        watchChanges: true
        printErrors: false
        onLoaded: root.currentWallpaperPath = String(wallpaperStateFile.text() || "").trim()
        onFileChanged: reload()
    }

    Process {
        id: themesProc
        command: [Util.evoshellScript(root.home, root.shell, "evo-menu-list"), "themes"]
        stdout: StdioCollector {
            onStreamFinished: root.themeEntries = LauncherSources.parseCatalog(text, "theme")
        }
    }

    Process {
        id: wallpapersProc
        command: [Util.evoshellScript(root.home, root.shell, "evo-menu-list"), "wallpapers"]
        stdout: StdioCollector {
            onStreamFinished: root.wallpaperEntries = LauncherSources.parseCatalog(text, "wallpaper")
        }
    }

    Process {
        id: loadAppIconsProc
        stdout: StdioCollector {
            onStreamFinished: root.applyAppIconMap(text)
        }
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.rebuildAppCache()
        }
    }

    Component.onCompleted: {
        rebuildAppCache()
        refreshCatalogs()
        var warmScript = Util.evoshellScript(home, shell, "evo-menu-warm")
        previewWarmProc.command = ["bash", "-lc", "test -x " + Util.shellQuote(warmScript) + " && " + Util.shellQuote(warmScript)]
        previewWarmProc.running = true
    }

    PanelWindow {
        id: panel
        visible: root.opened
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.namespace: "evo-sys-menu"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore

        Item {
            id: backdrop
            anchors.fill: parent

            property string basePath: ""
            property string overlayPath: ""
            property bool crossfading: false

            function show(path, instant) {
                path = String(path || "").trim()
                if (!path)
                    return
                if (!basePath || instant) {
                    crossfade.stop()
                    crossfading = false
                    overlayImage.opacity = 0
                    overlayPath = ""
                    basePath = path
                    return
                }
                if (path === basePath && !crossfading)
                    return
                if (path === overlayPath && crossfading)
                    return
                overlayPath = path
                crossfading = true
                overlayImage.opacity = 0
                if (overlayImage.status === Image.Ready)
                    crossfade.start()
            }

            function clear() {
                crossfade.stop()
                crossfading = false
                overlayImage.opacity = 0
                overlayPath = ""
                basePath = ""
            }

            Image {
                id: baseImage
                anchors.fill: parent
                visible: backdrop.basePath !== ""
                source: backdrop.basePath ? Util.fileUrl(backdrop.basePath) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
            }

            Image {
                id: overlayImage
                anchors.fill: parent
                opacity: 0
                visible: opacity > 0 || backdrop.crossfading
                source: backdrop.overlayPath ? Util.fileUrl(backdrop.overlayPath) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                onStatusChanged: {
                    if (backdrop.crossfading && status === Image.Ready && !crossfade.running)
                        crossfade.start()
                }
            }

            NumberAnimation {
                id: crossfade
                target: overlayImage
                property: "opacity"
                from: 0
                to: 1
                duration: 220
                easing.type: Easing.InOutQuad
                onFinished: {
                    backdrop.basePath = backdrop.overlayPath
                    overlayImage.opacity = 0
                    backdrop.overlayPath = ""
                    backdrop.crossfading = false
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: backdrop.basePath !== ""
                color: Theme.background
                opacity: 0.55
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismiss()
        }

        Item {
            id: launcherPanel
            z: 1
            anchors.centerIn: parent
            width: Theme.launcherWidth + Theme.hoverPanelContentPad * 2
            height: Theme.launcherHeight + Theme.hoverPanelContentPad * 2

            Rectangle {
                anchors.fill: parent
                radius: Theme.fieldsetCornerRadius
                color: panelPalette.background
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: {}
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.hoverPanelContentPad
                spacing: Theme.hoverPanelContentPad

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.launcherSearchHeight
                    radius: Theme.cornerRadius
                    color: panelPalette.panelMantle

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 12
                        spacing: Theme.spacingS

                        Text {
                            visible: root.view !== "root"
                            text: "󰅁"
                            color: panelPalette.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeL
                            font.bold: Theme.fontBold

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.goBack()
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: searchField.text.length === 0
                                text: root.placeholder
                                color: panelPalette.foreground
                                opacity: Theme.opacityMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeS
                                font.bold: Theme.fontBold
                            }

                            TextInput {
                                id: searchField
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                color: panelPalette.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeS
                                font.bold: Theme.fontBold
                                clip: true
                                selectByMouse: true
                                focus: root.opened
                                onTextEdited: function() { root.setQuery(searchField.text) }

                                Keys.onEscapePressed: function(event) {
                                    root.handleEscape()
                                    event.accepted = true
                                }
                                Keys.onUpPressed: function(event) {
                                    root.moveVertical(-1)
                                    event.accepted = true
                                }
                                Keys.onDownPressed: function(event) {
                                    root.moveVertical(1)
                                    event.accepted = true
                                }
                                Keys.onLeftPressed: function(event) {
                                    if (!root.searching && root.view === "looks" && !embeddedSettings.focusInTextInput()) {
                                        embeddedSettings.adjustSettingsNavHorizontal(-1)
                                        event.accepted = true
                                        return
                                    }
                                    if (!root.gridNav || cursorPosition !== 0) {
                                        event.accepted = false
                                        return
                                    }
                                    root.moveHorizontal(-1)
                                    event.accepted = true
                                }
                                Keys.onRightPressed: function(event) {
                                    if (!root.searching && root.view === "looks" && !embeddedSettings.focusInTextInput()) {
                                        embeddedSettings.adjustSettingsNavHorizontal(1)
                                        event.accepted = true
                                        return
                                    }
                                    if (!root.gridNav || cursorPosition !== text.length) {
                                        event.accepted = false
                                        return
                                    }
                                    root.moveHorizontal(1)
                                    event.accepted = true
                                }
                                Keys.onReturnPressed: function(event) {
                                    root.activateSelection()
                                    event.accepted = true
                                }
                                Keys.onEnterPressed: function(event) {
                                    root.activateSelection()
                                    event.accepted = true
                                }
                                Keys.onTabPressed: function(event) {
                                    root.cycleSection(1)
                                    event.accepted = true
                                }
                                Keys.onBacktabPressed: function(event) {
                                    root.cycleSection(-1)
                                    event.accepted = true
                                }
                                Keys.onPressed: function(event) {
                                    if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_K) {
                                        root.toggleActions()
                                        event.accepted = true
                                        return
                                    }
                                    var shortcut = root.actionIndexForEvent(event, text)
                                    if (shortcut >= 0) {
                                        root.runVisibleAction(shortcut)
                                        event.accepted = true
                                        return
                                    }
                                    if (event.key === Qt.Key_Backspace && text.length === 0
                                            && root.view !== "root" && !root.actionsOpen) {
                                        root.goBack()
                                        event.accepted = true
                                        return
                                    }
                                    event.accepted = false
                                }
                            }
                        }
                    }
                }

                Row {
                    id: sectionPillRow
                    Layout.fillWidth: true
                    spacing: Theme.spacingS

                    Repeater {
                        model: root.sectionPills

                        delegate: Item {
                            id: sectionPill
                            required property var modelData
                            required property int index
                            readonly property bool selected: !root.searching && root.view === String(modelData.id || "")
                            width: sectionPillBox.implicitWidth
                            height: sectionPillBox.implicitHeight

                            Rectangle {
                                id: sectionPillBox
                                radius: height / 2
                                color: sectionPill.selected
                                    ? panelPalette.accent
                                    : (sectionPillMouse.containsMouse
                                        ? panelPalette.foregroundHoverWash
                                        : panelPalette.foregroundWash)
                                implicitWidth: sectionPillLabel.implicitWidth + 16
                                implicitHeight: sectionPillLabel.implicitHeight + 8

                                Text {
                                    id: sectionPillLabel
                                    anchors.centerIn: parent
                                    text: sectionPill.modelData ? String(sectionPill.modelData.label || "") : ""
                                    color: sectionPill.selected ? panelPalette.mantle : panelPalette.foreground
                                    opacity: sectionPill.selected ? 1 : Theme.opacitySecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeS
                                    font.bold: Theme.fontBold
                                }
                            }

                            MouseArea {
                                id: sectionPillMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectSection(sectionPill.modelData ? sectionPill.modelData.id : "root")
                            }
                        }
                    }
                }

            SectionPanel {
                id: mainFrame
                Layout.fillWidth: true
                Layout.fillHeight: true
                fillHeight: true
                filled: true
                fillColor: panelPalette.background
                legendBackground: panelPalette.background
                frameBorder: panelPalette.foregroundBorder
                label: ""
                contentPad: Theme.launcherPad
                sectionSpacing: Theme.spacingS

                HoverPanelLabelPill {
                    text: root.searching ? "" : root.sectionLabel
                    fontSize: Theme.font.caption
                    textColor: panelPalette.foreground
                    fieldsetFill: panelPalette.background
                }

                Item {
                    id: contentHost
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ResultList {
                        id: resultList
                        anchors.fill: parent
                        visible: root.searching || root.view === "root" || root.view === "session"
                        entries: root.searching || root.view === "root" ? root.rootResults : root.sessionResults
                        selectedIndex: root.selectedIndex
                        onIndexMoved: function(index) { root.selectedIndex = index }
                        onActivated: function(entry) { root.runAction(entry, "") }
                    }

                    PreviewGrid {
                        id: previewGrid
                        anchors.fill: parent
                        visible: !root.searching && (root.view === "themes" || root.view === "wallpapers")
                        entries: root.view === "wallpapers" ? root.wallpaperResults : root.themeResults
                        selectedIndex: root.selectedIndex
                        showDetail: true
                        ink: panelPalette.foreground
                        paper: panelPalette.background
                        accentColor: panelPalette.accent
                        surface: panelPalette.surface
                        divider: panelPalette.foregroundDivider
                        onStepped: function(delta) { root.moveGrid(delta, 0) }
                        onIndexMoved: function(index) { root.selectedIndex = index }
                        onActivated: function(entry) { root.runAction(entry, "") }
                    }

                    ClipboardView {
                        id: clipboardView
                        anchors.fill: parent
                        visible: !root.searching && root.view === "clipboard"
                        shell: root.shell
                        query: ""
                        selectedIndex: root.selectedIndex
                        onIndexMoved: function(index) { root.selectedIndex = index }
                        onActivated: function(entry) { root.runAction(entry, "copy") }
                    }

                    EmojiGrid {
                        id: emojiGrid
                        anchors.fill: parent
                        visible: !root.searching && root.view === "emoji"
                        model: root.emojiResults
                        selectedIndex: root.selectedIndex
                        onIndexMoved: function(index) { root.selectedIndex = index }
                        onActivated: function(entry) { root.runAction(entry, "copy") }
                    }

                    CalcView {
                        id: calcView
                        anchors.fill: parent
                        visible: !root.searching && root.view === "calc"
                        shell: root.shell
                        expression: ""
                        onRecalled: function(text) { root.applyCalcRecall(text) }
                    }

                    SettingsModule {
                        id: embeddedSettings
                        anchors.fill: parent
                        visible: !root.searching && root.view === "looks"
                        showTabBar: false
                        tabIndex: 0
                        menuFilterText: ""
                        host: settingsHost
                        shell: root.shell
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.showEmpty
                        text: root.query.trim() === "" ? "Nothing here" : "No matches"
                        color: panelPalette.foreground
                        opacity: Theme.opacityMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeS
                        font.bold: Theme.fontBold
                    }
                }

            }
            }

            Item {
                id: actionHints
                z: 4
                x: mainFrame.mapToItem(launcherPanel, 0, 0).x
                y: mainFrame.mapToItem(launcherPanel, 0, mainFrame.height).y - height / 2
                width: mainFrame.width
                height: hintRow.implicitHeight

                Rectangle {
                    visible: hintRow.visible
                    x: hintRow.x - 4
                    y: hintRow.y - 2
                    width: hintRow.width + 8
                    height: hintRow.height + 4
                    color: panelPalette.background
                }

                Row {
                    id: hintRow
                    visible: root.actionItems.length > 0
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Repeater {
                        model: root.actionItems

                        delegate: Item {
                            id: actionChip
                            required property var modelData
                            required property int index
                            readonly property bool armed: root.actionsOpen
                                ? index === root.actionIndex
                                : index === 0
                            readonly property string keyText: {
                                if (index === 0)
                                    return "⏎"
                                var key = modelData && modelData.key ? String(modelData.key) : ""
                                if (key === "backspace")
                                    return "⌫"
                                return key
                            }
                            width: chipRow.implicitWidth
                            height: chipRow.implicitHeight

                            Row {
                                id: chipRow
                                spacing: 4

                                Text {
                                    visible: actionChip.keyText !== ""
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: actionChip.keyText
                                    color: panelPalette.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeS
                                    font.bold: Theme.fontBold
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: actionChip.modelData
                                        ? String(actionChip.modelData.label || "").toLowerCase()
                                        : ""
                                    color: panelPalette.foreground
                                    opacity: actionChip.armed ? Theme.opacitySecondary : Theme.opacityMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeS
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.runVisibleAction(actionChip.index)
                            }
                        }
                    }
                }
            }
        }
    }

    QtObject {
        id: settingsHost
        property bool opened: root.opened && root.view === "looks"
        property string activeModule: "settings"
        property bool settingsEmbedded: root.view === "looks"
        property bool keepSearchFocus: true
        property int width: contentHost.width
        function dismiss() {
            root.goBack()
        }
        function openView(name) {
            root.applyView(name, "")
        }
        function focusSearch() {
            searchField.forceActiveFocus()
        }
    }
}
