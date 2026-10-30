import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.commons
import "../menu/MenuEntries.js" as MenuEntries
import "../menu/LauncherSources.js" as LauncherSources
import "../menu/views"

Item {
    id: root

    property var shell: null
    property bool opened: false
    property string query: ""
    property int selectedIndex: 0
    property bool actionsOpen: false
    property int actionIndex: 0
    property var openScreen: null

    property var cachedApps: []
    property var appIconMap: ({})
    property var programRunCounts: ({})
    property var themeEntries: []
    property var wallpaperEntries: []
    property var binEntries: []

    property bool gapsOn: false
    property bool animationsOn: false
    property bool roundingOn: false
    property bool fieldsetRoundingOn: true

    readonly property string home: Quickshell.env("HOME")
    readonly property string terminal: Quickshell.env("EVOSHELL_TERMINAL") || "ghostty"
    readonly property string hyprScript: Util.evoshellScript(home, shell, "evo-hyprland")
    readonly property string barScript: Util.evoshellScript(home, shell, "evo-layout")
    readonly property string programRunsPath: Util.statePath(home, "menu-program-runs.json")
    readonly property var extensionPanels: shell && shell.extensionSystemMenuPanels
        ? shell.extensionSystemMenuPanels
        : []
    readonly property var commandList: MenuEntries.commandEntries(home, extensionPanels)
    readonly property var settingsState: ({
        gapsOn: gapsOn,
        animationsOn: animationsOn,
        roundingOn: roundingOn,
        fieldsetRoundingOn: fieldsetRoundingOn
    })
    readonly property var results: LauncherSources.buildRoot(
        query, cachedApps, programRunCounts, commandList, settingsState,
        themeEntries, wallpaperEntries, DockPins.resolvedIds, binEntries, home)
    readonly property var selectedEntry: {
        var list = results
        if (!list || selectedIndex < 0 || selectedIndex >= list.length)
            return null
        return list[selectedIndex]
    }
    readonly property var actionItems: LauncherSources.actionsFor(selectedEntry)
    readonly property int listHeight: {
        var count = results.length
        if (count <= 0)
            return 0
        return count * Theme.launcherRowHeight + (count - 1) * 2
    }

    function focusedScreen() {
        var screens = Quickshell.screens
        var monitor = Hyprland.focusedMonitor
        if (!monitor)
            return screens.length > 0 ? screens[0] : null
        var name = String(monitor.name || "")
        for (var i = 0; i < screens.length; i++) {
            if (screens[i] && String(screens[i].name || "") === name)
                return screens[i]
        }
        for (var j = 0; j < screens.length; j++) {
            var screen = screens[j]
            if (screen && screen.x === monitor.x && screen.y === monitor.y)
                return screen
        }
        return screens.length > 0 ? screens[0] : null
    }

    function hideSiblings() {
        if (!shell)
            return
        shell.hide("evo.dock")
        shell.hide("evo.power")
        shell.hide("evo.sys.menu")
        shell.hide("evo.sys.clipboard")
    }

    function open(payloadJson) {
        hideSiblings()
        openScreen = focusedScreen()
        var nextQuery = ""
        try {
            var payload = JSON.parse(payloadJson || "{}")
            if (payload.query)
                nextQuery = String(payload.query)
        } catch (e) {
            nextQuery = ""
        }
        opened = true
        actionsOpen = false
        selectedIndex = 0
        query = nextQuery
        if (searchField.text !== nextQuery)
            searchField.text = nextQuery
        refreshCatalogs()
        Qt.callLater(function() {
            searchField.forceActiveFocus()
        })
    }

    function close() {
        if (!opened)
            return
        opened = false
        actionsOpen = false
        query = ""
        selectedIndex = 0
        if (searchField.text !== "")
            searchField.text = ""
    }

    function dismiss() {
        if (shell)
            shell.hide("evo.sys.runner")
        else
            close()
    }

    function reopen(payloadJson) {
        if (!opened)
            return false
        var nextQuery = ""
        try {
            var payload = JSON.parse(payloadJson || "{}")
            if (payload.query)
                nextQuery = String(payload.query)
        } catch (e) {
            nextQuery = ""
        }
        if (!nextQuery)
            return false
        setQuery(nextQuery)
        if (searchField.text !== query)
            searchField.text = query
        searchField.forceActiveFocus()
        return true
    }

    function setQuery(text) {
        var next = String(text || "")
        if (query !== next)
            query = next
        selectedIndex = 0
        actionsOpen = false
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
                if (alt || (empty && !items[i].alt))
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
        if (selectedEntry)
            runAction(selectedEntry, action.id)
    }

    function moveSelection(delta) {
        if (actionsOpen) {
            var count = actionItems.length
            if (count <= 0)
                return
            actionIndex = (actionIndex + delta + count) % count
            return
        }
        var count = results.length
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

    function activateSelection() {
        if (actionsOpen) {
            runVisibleAction(actionIndex)
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
        if (entry.kind === "setting") {
            if (entry.view) {
                var viewName = String(entry.view)
                dismiss()
                if (shell)
                    shell.summon("evo.sys.menu", JSON.stringify({ view: viewName }))
                return
            }
            if (entry.action === "toggleHypr")
                toggleHypr(entry.arg)
            else if (entry.action === "toggleFieldsetRounding")
                toggleFieldsetRounding()
            dismiss()
            return
        }
        if (entry.kind === "calc") {
            copyText(entry.result)
            recordCalc(entry.expr, entry.result)
            dismiss()
            return
        }
        if (entry.kind === "app") {
            if (action === "pin") {
                DockPins.toggle(entry.id)
                selectApp(entry.id)
                return
            }
            recordProgramRun(entry.id)
            launchDesktopEntry(entry)
            dismiss()
            return
        }
        if (entry.kind === "bin" || entry.kind === "run") {
            var cmd = String(entry.command || "")
            dismiss()
            if (action === "detach")
                runDetached(cmd)
            else
                runInTerminal(cmd)
            return
        }
        if (entry.command) {
            dismiss()
            runCommand(entry.command)
            return
        }
        dismiss()
    }

    function selectApp(appId) {
        var list = results
        for (var i = 0; i < list.length; i++) {
            if (list[i] && list[i].kind === "app" && list[i].id === appId) {
                selectedIndex = i
                return
            }
        }
    }

    function runCommand(cmd) {
        var command = String(cmd || "").trim()
        if (!command)
            return
        Quickshell.execDetached(["bash", "-lc", command])
    }

    function runInTerminal(cmd) {
        var command = String(cmd || "").trim()
        if (!command)
            return
        Quickshell.execDetached([terminal, "-e", "bash", "-lc", command])
    }

    function runDetached(cmd) {
        var command = String(cmd || "").trim()
        if (!command)
            return
        Quickshell.execDetached(["bash", "-lc", command])
    }

    function copyText(text) {
        Quickshell.execDetached(["bash", "-lc", "printf %s " + Util.shellQuote(String(text || "")) + " | wl-copy"])
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
            console.warn("runner app list failed:", e)
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
                iconSource: (app.id && map[app.id]) ? map[app.id] : (app.iconSource || ""),
                pinned: app.pinned
            })
        }
        cachedApps = rebuilt
    }

    function refreshCatalogs() {
        if (!themesProc.running)
            themesProc.running = true
        if (!wallpapersProc.running)
            wallpapersProc.running = true
        if (!binsProc.running)
            binsProc.running = true
        if (!hyprGetProc.running)
            hyprGetProc.running = true
        if (!uiGetProc.running)
            uiGetProc.running = true
    }

    function parseHyprState(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            gapsOn = data.gapsOn === true
            animationsOn = data.animationsOn === true
            roundingOn = data.roundingOn === true
        } catch (e) {
        }
    }

    function parseUiState(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            fieldsetRoundingOn = data.fieldsetRounding !== false
        } catch (e) {
        }
    }

    function toggleHypr(key) {
        hyprToggleProc.command = ["bash", hyprScript, "toggle", String(key || "")]
        if (!hyprToggleProc.running)
            hyprToggleProc.running = true
    }

    function toggleFieldsetRounding() {
        if (!uiToggleProc.running)
            uiToggleProc.running = true
    }

    onResultsChanged: {
        if (selectedIndex >= results.length)
            selectedIndex = Math.max(0, results.length - 1)
    }

    Process { id: saveProgramRunsProc }

    FileView {
        id: programRunsFile
        path: root.programRunsPath
        watchChanges: false
        printErrors: false
        onLoaded: root.loadProgramRuns()
        onLoadFailed: root.programRunCounts = {}
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
        id: binsProc
        command: [Util.evoshellScript(root.home, root.shell, "evo-menu-list"), "bins"]
        stdout: StdioCollector {
            onStreamFinished: root.binEntries = LauncherSources.parseBins(text)
        }
    }

    Process {
        id: loadAppIconsProc
        stdout: StdioCollector {
            onStreamFinished: root.applyAppIconMap(text)
        }
    }

    Process {
        id: hyprGetProc
        command: ["bash", root.hyprScript, "get"]
        stdout: StdioCollector {
            onStreamFinished: root.parseHyprState(text)
        }
    }

    Process {
        id: uiGetProc
        command: ["bash", root.barScript, "ui", "get"]
        stdout: StdioCollector {
            onStreamFinished: root.parseUiState(text)
        }
    }

    Process {
        id: hyprToggleProc
        stdout: StdioCollector {
            onStreamFinished: root.parseHyprState(text)
        }
    }

    Process {
        id: uiToggleProc
        command: ["bash", root.barScript, "ui", "toggle", "fieldsetRounding"]
        stdout: StdioCollector {
            onStreamFinished: root.parseUiState(text)
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
    }

    PanelWindow {
        id: panel
        visible: root.opened
        screen: root.openScreen
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.namespace: "evo-sys-runner"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismiss()
        }

        Rectangle {
            id: card
            z: 1
            width: Theme.hoverPanelWidthWide
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(Theme.space(48), Math.round(parent.height * 0.22) - height / 2)
            height: cardColumn.implicitHeight + Theme.launcherPad * 2
            radius: Theme.fieldsetCornerRadius
            color: Theme.background

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: {}
            }

            Column {
                id: cardColumn
                x: Theme.launcherPad
                y: Theme.launcherPad
                width: parent.width - Theme.launcherPad * 2
                spacing: Theme.spacingS

                Rectangle {
                    width: cardColumn.width
                    height: Theme.launcherSearchHeight
                    radius: Theme.cornerRadius
                    color: Theme.panelMantle

                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            elide: Text.ElideRight
                            visible: searchField.text.length === 0
                            text: "Run…"
                            color: Theme.foreground
                            opacity: Theme.opacityMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeS
                            font.bold: Theme.fontBold
                        }

                        TextInput {
                            id: searchField
                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeS
                            font.bold: Theme.fontBold
                            clip: true
                            selectByMouse: true
                            focus: root.opened
                            onTextEdited: function() { root.setQuery(searchField.text) }

                            Keys.onEscapePressed: function(event) {
                                if (root.actionsOpen) {
                                    root.actionsOpen = false
                                    event.accepted = true
                                    return
                                }
                                root.dismiss()
                                event.accepted = true
                            }
                            Keys.onUpPressed: function(event) {
                                root.moveSelection(-1)
                                event.accepted = true
                            }
                            Keys.onDownPressed: function(event) {
                                root.moveSelection(1)
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
                                if (event.key === Qt.Key_Backspace && text.length === 0 && !root.actionsOpen) {
                                    root.dismiss()
                                    event.accepted = true
                                    return
                                }
                                event.accepted = false
                            }
                        }
                    }
                }

                ResultList {
                    id: resultList
                    width: cardColumn.width
                    height: root.listHeight
                    visible: root.results.length > 0
                    entries: root.results
                    selectedIndex: root.selectedIndex
                    onIndexMoved: function(index) { root.selectedIndex = index }
                    onActivated: function(entry) { root.runAction(entry, "") }
                }

                Item {
                    width: cardColumn.width
                    height: hintRow.implicitHeight
                    visible: root.results.length > 0 && root.actionItems.length > 0

                    Row {
                        id: hintRow
                        anchors.right: parent.right
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
                                    if (key && modelData.alt)
                                        return "alt+" + key
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
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeS
                                    font.bold: Theme.fontBold
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: actionChip.modelData
                                        ? String(actionChip.modelData.label || "").toLowerCase()
                                        : ""
                                    color: Theme.foreground
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
}
}
