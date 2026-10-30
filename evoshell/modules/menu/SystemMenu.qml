import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.commons
import "../settings"
import "LauncherSources.js" as LauncherSources
import "views"

Item {
    id: root

    property var shell: null
    property bool opened: false
    property var openScreen: null
    // Keyboard zone. Everything is on screen; this is which part arrows act on.
    property string lastView: "themes"
    property string view: "themes"
    property string query: ""
    property int themeIndex: 0
    property int wallpaperIndex: 0
    property bool actionsOpen: false
    property int actionIndex: 0

    property var themeEntries: []
    property var wallpaperEntries: []
    property var themePreview: ({ valid: false })
    property string currentThemeName: ""
    property string currentWallpaperPath: ""

    readonly property string home: Quickshell.env("HOME")
    readonly property string hyprScript: Util.evoshellScript(home, shell, "evo-hyprland")
    readonly property var themeResults: LauncherSources.filterThemes(themeEntries, query, currentThemeName)
    readonly property string previewThemeName: {
        var list = themeResults
        if (!list || list.length === 0)
            return currentThemeName
        var index = themeIndex
        if (index < 0 || index >= list.length)
            index = 0
        var entry = list[index]
        return entry ? String(entry.name || "") : currentThemeName
    }
    // An empty search shows the highlighted theme's wallpapers. A query searches all of them.
    readonly property string wallpaperScope: String(query || "").trim() === "" ? "current" : "all"
    readonly property var wallpaperResults: LauncherSources.filterWallpapers(
        wallpaperEntries, query, wallpaperScope,
        wallpaperScope === "current" ? previewThemeName : "",
        currentWallpaperPath)
    readonly property var selectedEntry: {
        var list = view === "wallpapers" ? wallpaperResults : themeResults
        var index = view === "wallpapers" ? wallpaperIndex : themeIndex
        if (view === "looks" || !list || index < 0 || index >= list.length)
            return null
        return list[index]
    }
    readonly property var actionItems: {
        if (view === "looks")
            return [{ id: "toggle", label: "Toggle" }]
        return LauncherSources.actionsFor(selectedEntry)
    }
    readonly property bool mediaNav: view === "themes" || view === "wallpapers"
    readonly property int wallpaperColumns: Math.max(1, wallpaperGrid.columnCount)
    readonly property bool looksFilteredEmpty: String(query || "").trim() !== ""
        && embeddedSettings.settingsNavItems.length === 0
    readonly property string themeColorsPath: {
        if (view !== "themes" || !selectedEntry || selectedEntry.kind !== "theme")
            return ""
        var name = String(selectedEntry.name || "").trim()
        if (!name || name.indexOf("/") >= 0 || name.indexOf("..") >= 0)
            return ""
        return home + "/.themes/" + name + "/colors.toml"
    }

    function parsePayload(payloadJson) {
        var viewName = ""
        var nextQuery = ""
        try {
            var payload = JSON.parse(payloadJson || "{}")
            if (payload.view)
                viewName = String(payload.view)
            else if (String(payload.submenu || "") === "themes")
                viewName = "themes"
            else if (String(payload.submenu || "") === "wallpaper" || String(payload.submenu || "") === "wallpapers")
                viewName = "wallpapers"
            else {
                var tab = String(payload.tab || payload.panel || "").toLowerCase()
                if (tab === "looks" || tab === "settings" || tab === "1")
                    viewName = "looks"
            }
            if (payload.query)
                nextQuery = String(payload.query)
        } catch (e) {
            viewName = ""
        }
        if (viewName === "clipboard" || viewName === "emoji")
            return { forward: JSON.stringify({ view: viewName, query: nextQuery }) }
        if (viewName !== "looks" && viewName !== "themes" && viewName !== "wallpapers")
            viewName = "themes"
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
        lastView = nextView
        query = String(nextQuery || "")
        themeIndex = 0
        wallpaperIndex = 0
        actionsOpen = false
        if (searchField.text !== query)
            searchField.text = query
        if (String(query).trim() === "")
            Qt.callLater(root.focusCurrentTheme)
        if (nextView === "looks") {
            Qt.callLater(function() {
                embeddedSettings.onActivated()
            })
        }
        Qt.callLater(root.syncBackdrop)
    }

    function focusZone(zone) {
        var next = String(zone || "looks")
        if (view === next)
            return
        view = next
        lastView = next
        actionsOpen = false
        if (next === "looks")
            Qt.callLater(function() { embeddedSettings.rebuildSettingsNav() })
        Qt.callLater(root.syncBackdrop)
        Qt.callLater(function() { searchField.forceActiveFocus() })
    }

    function cycleSection(direction) {
        var zones = ["themes", "wallpapers", "looks"]
        var index = zones.indexOf(view)
        if (index < 0)
            index = 0
        focusZone(zones[(index + direction + zones.length) % zones.length])
    }

    function focusCurrentTheme() {
        if (String(query).trim() !== "")
            return
        var name = String(currentThemeName || "")
        var list = themeResults
        for (var i = 0; i < list.length; i++) {
            if (list[i] && String(list[i].name || "") === name) {
                themeIndex = i
                return
            }
        }
    }

    function focusCurrentWallpaper() {
        if (String(query).trim() !== "")
            return
        var list = wallpaperResults
        var next = 0
        for (var i = 0; i < list.length; i++) {
            if (list[i] && list[i].current) {
                next = i
                break
            }
        }
        if (wallpaperIndex !== next)
            wallpaperIndex = next
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
        shell.hide("evo.sys.clipboard")
        shell.hide("evo.sys.runner")
    }

    function open(payloadJson) {
        var next = parsePayload(payloadJson)
        if (next.forward) {
            if (shell) {
                shell.hide("evo.sys.menu")
                shell.summon("evo.sys.clipboard", next.forward)
            }
            return
        }
        hideSiblings()
        openScreen = focusedScreen()
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
        if (next.forward) {
            dismiss()
            if (shell)
                shell.summon("evo.sys.clipboard", next.forward)
            return true
        }
        if (next.view === view && next.query === query)
            return false
        applyView(next.view, next.query)
        Qt.callLater(function() {
            searchField.forceActiveFocus()
        })
        return true
    }

    function setQuery(text) {
        var next = String(text || "")
        if (query !== next)
            query = next
        themeIndex = 0
        wallpaperIndex = 0
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
        dismiss()
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
        if (view === "looks") {
            embeddedSettings.activateSettingsFocus()
            return
        }
        if (selectedEntry)
            runAction(selectedEntry, action.id)
    }

    function atLooksEdge(delta) {
        var count = embeddedSettings.settingsNavItems.length
        if (count <= 0)
            return true
        if (delta < 0)
            return embeddedSettings.settingsKeyIndex <= 0
        return embeddedSettings.settingsKeyIndex >= count - 1
    }

    function stepIndex(index, count, delta) {
        if (count <= 0)
            return 0
        var next = index + delta
        if (next < 0)
            return count - 1
        if (next >= count)
            return 0
        return next
    }

    function moveVertical(delta) {
        if (actionsOpen) {
            var count = actionItems.length
            if (count <= 0)
                return
            actionIndex = (actionIndex + delta + count) % count
            return
        }
        if (view === "looks") {
            if (embeddedSettings.focusInTextInput())
                return
            if (atLooksEdge(delta)) {
                focusZone(delta > 0 ? "themes" : "wallpapers")
                return
            }
            embeddedSettings.moveSettingsFocus(delta)
            return
        }
        if (view === "themes") {
            focusZone(delta > 0 ? "wallpapers" : "looks")
            return
        }
        var row = Math.floor(Math.max(0, wallpaperIndex) / wallpaperColumns)
        var rows = Math.max(1, Math.ceil(wallpaperResults.length / wallpaperColumns))
        if (delta < 0 && row === 0) {
            focusZone("themes")
            return
        }
        if (delta > 0 && row >= rows - 1) {
            focusZone("looks")
            return
        }
        moveWallpaper(0, delta)
    }

    function moveHorizontal(delta) {
        if (actionsOpen || delta === 0)
            return
        if (view === "themes") {
            themeIndex = stepIndex(themeIndex, themeResults.length, delta)
            return
        }
        if (view === "wallpapers")
            moveWallpaper(delta, 0)
    }

    function moveWallpaper(dx, dy) {
        var count = wallpaperResults.length
        if (count <= 0) {
            wallpaperIndex = 0
            return
        }
        var cols = Math.max(1, wallpaperColumns)
        var index = wallpaperIndex
        if (index < 0)
            index = 0
        if (dx !== 0) {
            wallpaperIndex = stepIndex(index, count, dx)
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
        wallpaperIndex = target
    }

    function activateSelection() {
        if (actionsOpen) {
            runVisibleAction(actionIndex)
            return
        }
        if (view === "looks") {
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
        if (entry.kind === "setting") {
            if (entry.action === "toggleHypr")
                embeddedSettings.toggleHypr(entry.arg)
            else if (entry.action === "toggleFieldsetRounding")
                embeddedSettings.toggleFieldsetRounding()
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

    onThemeResultsChanged: {
        if (themeIndex >= themeResults.length)
            themeIndex = Math.max(0, themeResults.length - 1)
    }
    onWallpaperResultsChanged: {
        if (wallpaperIndex >= wallpaperResults.length)
            wallpaperIndex = Math.max(0, wallpaperResults.length - 1)
    }
    onThemeEntriesChanged: {
        if (String(query).trim() === "")
            Qt.callLater(root.focusCurrentTheme)
    }
    onPreviewThemeNameChanged: Qt.callLater(root.focusCurrentWallpaper)
    onSelectedEntryChanged: syncBackdrop()
    onViewChanged: syncBackdrop()

    Process { id: menuSpecialProc }

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
        readonly property bool live: root.view === "themes" && root.themePreview.valid
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

    Component.onCompleted: refreshCatalogs()

    PanelWindow {
        id: panel
        visible: root.opened
        screen: root.openScreen
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
            width: Theme.launcherWidth + Theme.space(200) + Theme.hoverPanelContentPad * 2
            height: Theme.launcherHeight + Theme.space(120) + Theme.hoverPanelContentPad * 2

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

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.minimumWidth: Theme.space(160)
                        Layout.preferredHeight: Theme.launcherSearchHeight
                        radius: Theme.cornerRadius
                        color: panelPalette.panelMantle

                        TextInput {
                            id: searchField
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            color: panelPalette.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeS
                            font.bold: Theme.fontBold
                            clip: true
                            selectByMouse: true
                            focus: root.opened
                            onTextEdited: function() { root.setQuery(searchField.text) }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                elide: Text.ElideRight
                                visible: searchField.text.length === 0
                                text: "Search appearance…"
                                color: panelPalette.foreground
                                opacity: Theme.opacityMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeS
                                font.bold: Theme.fontBold
                            }

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
                                if (root.view === "looks" && !embeddedSettings.focusInTextInput()) {
                                    embeddedSettings.adjustSettingsNavHorizontal(-1)
                                    event.accepted = true
                                    return
                                }
                                if (!root.mediaNav || cursorPosition !== 0) {
                                    event.accepted = false
                                    return
                                }
                                root.moveHorizontal(-1)
                                event.accepted = true
                            }
                            Keys.onRightPressed: function(event) {
                                if (root.view === "looks" && !embeddedSettings.focusInTextInput()) {
                                    embeddedSettings.adjustSettingsNavHorizontal(1)
                                    event.accepted = true
                                    return
                                }
                                if (!root.mediaNav || cursorPosition !== text.length) {
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

                RowLayout {
                    id: bodyRow
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Theme.spacingM

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Theme.spacingM

                        SectionPanel {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Theme.space(148)
                            fillHeight: false
                            filled: true
                            fillColor: panelPalette.background
                            legendBackground: panelPalette.background
                            frameBorder: root.view === "themes"
                                ? panelPalette.accent
                                : panelPalette.foregroundBorder
                            label: ""
                            contentPad: Theme.launcherPad
                            sectionSpacing: Theme.spacingS

                            HoverPanelLabelPill {
                                text: "Themes"
                                fontSize: Theme.font.caption
                                textColor: panelPalette.foreground
                                fieldsetFill: panelPalette.background
                            }

                            Item {
                                Layout.fillWidth: true
                                implicitHeight: themeStrip.tileHeight + Theme.fontSizeS + Theme.space(8)
                                Layout.preferredHeight: implicitHeight

                                PreviewStrip {
                                    id: themeStrip
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    height: parent.implicitHeight
                                    entries: root.themeResults
                                    selectedIndex: root.themeIndex
                                    ink: panelPalette.foreground
                                    accentColor: panelPalette.accent
                                    surface: panelPalette.surface
                                    divider: panelPalette.foregroundDivider
                                    onIndexMoved: function(index) {
                                        if (root.view === "themes")
                                            root.themeIndex = index
                                    }
                                    onActivated: function(entry) { root.runAction(entry, "") }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: root.themeResults.length === 0
                                    text: root.query.trim() === "" ? "No themes" : "No matches"
                                    color: panelPalette.foreground
                                    opacity: Theme.opacityMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeS
                                    font.bold: Theme.fontBold
                                }
                            }
                        }

                        SectionPanel {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            fillHeight: true
                            filled: true
                            fillColor: panelPalette.background
                            legendBackground: panelPalette.background
                            frameBorder: root.view === "wallpapers"
                                ? panelPalette.accent
                                : panelPalette.foregroundBorder
                            label: ""
                            contentPad: Theme.launcherPad
                            sectionSpacing: Theme.spacingS

                            HoverPanelLabelPill {
                                text: "Wallpapers"
                                fontSize: Theme.font.caption
                                textColor: panelPalette.foreground
                                fieldsetFill: panelPalette.background
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                PreviewGrid {
                                    id: wallpaperGrid
                                    anchors.fill: parent
                                    entries: root.wallpaperResults
                                    selectedIndex: root.wallpaperIndex
                                    showDetail: false
                                    ink: panelPalette.foreground
                                    paper: panelPalette.background
                                    accentColor: panelPalette.accent
                                    surface: panelPalette.surface
                                    divider: panelPalette.foregroundDivider
                                    onIndexMoved: function(index) {
                                        if (root.view === "wallpapers")
                                            root.wallpaperIndex = index
                                    }
                                    onActivated: function(entry) { root.runAction(entry, "") }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: root.wallpaperResults.length === 0
                                    text: root.query.trim() === "" ? "No wallpapers" : "No matches"
                                    color: panelPalette.foreground
                                    opacity: Theme.opacityMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeS
                                    font.bold: Theme.fontBold
                                }
                            }
                        }
                    }

                    SectionPanel {
                        id: looksFrame
                        Layout.preferredWidth: Theme.space(300)
                        Layout.fillHeight: true
                        fillHeight: true
                        filled: true
                        fillColor: panelPalette.background
                        legendBackground: panelPalette.background
                        frameBorder: root.view === "looks"
                            ? panelPalette.accent
                            : panelPalette.foregroundBorder
                        label: ""
                        contentPad: Theme.launcherPad
                        sectionSpacing: Theme.spacingS

                        HoverPanelLabelPill {
                            text: "Looks"
                            fontSize: Theme.font.caption
                            textColor: panelPalette.foreground
                            fieldsetFill: panelPalette.background
                        }

                        Item {
                            id: looksHost
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            SettingsModule {
                                id: embeddedSettings
                                anchors.fill: parent
                                showTabBar: false
                                tabIndex: 0
                                menuFilterText: root.query
                                host: settingsHost
                                shell: root.shell
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: root.looksFilteredEmpty
                                text: "No matches"
                                color: panelPalette.foreground
                                opacity: Theme.opacityMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeS
                                font.bold: Theme.fontBold
                            }
                        }
                    }
                }
            }

            Item {
                id: actionHints
                z: 4
                x: bodyRow.mapToItem(launcherPanel, 0, 0).x
                y: bodyRow.mapToItem(launcherPanel, 0, bodyRow.height).y - height / 2
                width: bodyRow.width
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
        property bool opened: root.opened
        property string activeModule: "settings"
        property bool settingsEmbedded: true
        property bool keepSearchFocus: true
        property int width: looksHost.width
        function dismiss() {
            root.dismiss()
        }
        function openView(name) {
            root.applyView(name, "")
        }
        function focusSearch() {
            searchField.forceActiveFocus()
        }
    }
}
