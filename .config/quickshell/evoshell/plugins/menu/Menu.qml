import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "MenuEntries.js" as MenuEntries

Item {
    id: root

    property var shell: null
    property bool opened: false
    property string filterText: ""
    property string mode: "apps"
    property string submenu: ""
    property var commandEntries: []
    property var dynamicEntries: []
    property string dynamicEntryKind: ""
    property var visibleEntries: []
    property var cachedApps: []
    property var appIconMap: ({})
    property int appIconEpoch: 0
    property bool dynamicLoading: false
    property bool shellUnusedOnly: false
    property int selectedIndex: 0
    property real previewAreaMaxWidth: 1600
    property real previewAreaMaxHeight: 900

    readonly property bool tileMode: mode === "power" && !submenu
    readonly property bool previewTileMode: submenu === "themes" || submenu === "wallpaper"
    readonly property bool appsGridMode: mode === "apps"
    readonly property bool styledMenuMode: tileMode || appsGridMode
    readonly property bool boxTileMode: tileMode || previewTileMode
    readonly property bool framedMode: !boxTileMode && !appsGridMode
    readonly property string previewFallbackIcon: submenu === "wallpaper" ? "󰏘" : "󰸌"
    readonly property int tileWidth: 160
    readonly property int tileHeight: 160
    readonly property int powerTileWidth: 136
    readonly property int powerTileHeight: 124
    readonly property int powerGridColumns: 5
    readonly property int powerMenuPadding: 28
    readonly property int powerHeaderHeight: 104
    readonly property int powerLogoFont: Theme.fontSize8xl * 2
    readonly property int powerTileIconSize: 52
    readonly property int tileSpacing: 24
    readonly property int tileIconSize: 64
    readonly property int previewTileWidth: 296
    readonly property int previewTileHeight: 204
    readonly property int previewImageHeight: 192
    readonly property real previewDpr: 2
    readonly property int listIconSize: 40
    readonly property int listFontSize: Theme.fontSize6xl
    readonly property int listRowHeight: 72
    readonly property int listFilterHeight: 38
    readonly property int listFilterFontSize: Theme.fontSizeL
    readonly property int previewMenuMargin: 48
    readonly property int appIconSourceSize: 128
    readonly property string menuHeaderIcon: appsGridMode ? "󰀻" : "󰣇"
    readonly property string menuHeaderTitle: appsGridMode ? "Apps" : "Evo shell"
    readonly property string menuHeaderSubtitle: appsGridMode ? "Desktop programs" : "Panels · overlays · session"

    readonly property int previewGridColumns: 5
    readonly property int previewColumnCount: gridColumnCount
    readonly property int activeTileWidth: previewTileMode ? previewTileWidth : (styledMenuMode ? powerTileWidth : tileWidth)
    readonly property int activeTileHeight: previewTileMode ? previewTileHeight : (styledMenuMode ? powerTileHeight : tileHeight)

    readonly property int sizingEntryCount: {
        var q = filterText.trim()
        if (q === "")
            return visibleEntries.length
        if (submenu)
            return dynamicEntries.length
        if (mode === "apps")
            return appEntries().length
        if (mode === "power")
            return commandEntries.length
        return visibleEntries.length
    }

    readonly property int gridColumnCount: {
        var n = sizingEntryCount
        if (styledMenuMode) return Math.max(1, Math.min(n, powerGridColumns))
        if (n <= 0) return 1
        if (previewTileMode)
            return Math.max(1, Math.min(n, previewGridColumns))
        var maxW = panel.previewAreaMaxWidth
        var cols = Math.floor((maxW + tileSpacing) / (activeTileWidth + tileSpacing))
        return Math.max(1, Math.min(n, cols))
    }

    readonly property int gridRowCount: {
        var n = sizingEntryCount
        if (n <= 0) return 1
        return Math.ceil(n / gridColumnCount)
    }

    readonly property int gridWidth: {
        var cols = gridColumnCount
        if (cols <= 0) return activeTileWidth
        return cols * activeTileWidth + (cols - 1) * tileSpacing
    }

    readonly property int gridHeight: {
        var rows = gridRowCount
        if (rows <= 0) return activeTileHeight
        return rows * activeTileHeight + (rows - 1) * tileSpacing
    }

    readonly property int styledMenuViewportHeight: {
        var chrome = powerHeaderHeight + powerMenuPadding * 2 + 28
        var available = Math.max(powerTileHeight + tileSpacing,
            panel.previewAreaMaxHeight - chrome)
        return Math.min(gridHeight, available)
    }

    readonly property int previewRowCount: gridRowCount
    readonly property int previewGridWidth: gridWidth
    readonly property int previewGridHeight: gridHeight

    readonly property int tileRowWidth: {
        var n = sizingEntryCount
        if (n <= 0) return tileWidth
        return n * tileWidth + (n - 1) * tileSpacing
    }

    readonly property int previewRowWidth: {
        var n = sizingEntryCount
        if (n <= 0) return previewTileWidth
        return n * previewTileWidth + (n - 1) * tileSpacing
    }

    readonly property int boxRowWidth: previewTileMode ? gridWidth : (tileMode ? gridWidth : tileRowWidth)
    readonly property int boxRowHeight: previewTileMode
        ? gridHeight
        : (tileMode ? gridHeight + powerHeaderHeight + 12 : tileHeight)
    readonly property int styledMenuHostHeight: styledMenuViewportHeight + powerHeaderHeight + powerMenuPadding * 2 + 28

    readonly property string home: Quickshell.env("HOME")
    readonly property string placeholderText: {
        if (submenu === "bindings") return "Search bindings…"
        if (submenu === "shell") return "Search shell commands…"
        if (mode === "power") return "Search system…"
        if (mode === "apps") return "Applications…"
        return "Search…"
    }

    readonly property bool infoListMode: submenu === "bindings" || submenu === "shell"
    readonly property int framedMenuWidth: infoListMode ? 1040 : 720
    readonly property int infoListFontSize: Theme.fontSizeM
    readonly property int infoListRowHeight: 48
    readonly property int framedMenuHeight: 640
    readonly property int framedPadding: 16
    readonly property int framedFilterChromeHeight: listFilterHeight
    readonly property int framedListHeight: Math.max(120, framedMenuHeight - framedPadding * 2 - framedFilterChromeHeight - 12)

    function focusSearchField() {
        if (root.styledMenuMode)
            silentFilterField.forceActiveFocus()
        else if (root.framedMode)
            filterField.forceActiveFocus()
        else if (root.previewTileMode)
            menuHost.forceActiveFocus()
    }

    function appendFilterText(text) {
        if (!text)
            return
        root.filterText = root.filterText + text
        if (root.styledMenuMode) {
            silentFilterField.text = root.filterText
            silentFilterField.forceActiveFocus()
        } else if (root.framedMode) {
            filterField.text = root.filterText
            filterField.forceActiveFocus()
        }
    }

    function open(payloadJson) {
        try {
            var payload = JSON.parse(payloadJson || "{}")
            mode = String(payload.mode || "apps")
            submenu = String(payload.submenu || "")
        } catch (e) {
            mode = "apps"
            submenu = ""
        }
        filterText = ""
        selectedIndex = 0
        refreshCommandEntries()
        if (submenu) loadDynamicEntries(submenu)
        else dynamicEntries = []
        opened = true
        if (mode === "apps" && cachedApps.length === 0) {
            rebuildAppCache()
            refreshVisibleEntries()
        } else {
            refreshVisibleEntries()
        }
        Qt.callLater(function() {
            root.previewAreaMaxWidth = panel.previewAreaMaxWidth
            root.previewAreaMaxHeight = panel.previewAreaMaxHeight
            root.focusSearchField()
        })
    }

    function dismiss() {
        if (shell) shell.hide("evo.menu")
        else close()
    }

    function close() {
        if (!opened) return
        opened = false
        filterText = ""
        submenu = ""
        dynamicEntries = []
        dynamicEntryKind = ""
        shellUnusedOnly = false
        selectedIndex = 0
    }

    function moveSelection(delta) {
        var count = visibleEntries.length
        if (count <= 0) {
            selectedIndex = 0
            return
        }
        var next = selectedIndex + delta
        if (next < 0) next = count - 1
        else if (next >= count) next = 0
        selectedIndex = next
        if (framedMode)
            entryList.positionViewAtIndex(selectedIndex, ListView.Contain)
        else if (appsGridMode || previewTileMode)
            ensureGridSelectionVisible()
    }

    function ensureGridSelectionVisible() {
        if (!appsGridMode)
            return
        var cols = gridColumnCount
        if (cols <= 0)
            return
        var row = Math.floor(selectedIndex / cols)
        var rowHeight = powerTileHeight + tileSpacing
        var itemTop = row * rowHeight
        var itemBottom = itemTop + powerTileHeight
        if (itemTop < appFlickable.contentY)
            appFlickable.contentY = itemTop
        else if (itemBottom > appFlickable.contentY + appFlickable.height)
            appFlickable.contentY = Math.max(0, itemBottom - appFlickable.height)
    }

    function moveGridSelection(dx, dy) {
        var count = visibleEntries.length
        if (count <= 0) {
            selectedIndex = 0
            return
        }
        var cols = gridColumnCount
        var rows = gridRowCount
        var row = Math.floor(selectedIndex / cols)
        var col = selectedIndex % cols

        if (dx !== 0) {
            if (dx > 0) {
                if (col < cols - 1 && selectedIndex + 1 < count)
                    selectedIndex++
                else
                    selectedIndex = (selectedIndex + 1) % count
            } else {
                if (col > 0)
                    selectedIndex--
                else
                    selectedIndex = (selectedIndex - 1 + count) % count
            }
            return
        }

        if (dy === 0) return
        var targetRow = row + dy
        if (targetRow < 0) targetRow = rows - 1
        else if (targetRow >= rows) targetRow = 0
        var targetIdx = targetRow * cols + col
        if (targetIdx >= count) targetIdx = count - 1
        selectedIndex = targetIdx
        ensureGridSelectionVisible()
    }

    function handlePreviewLeft() {
        if (previewTileMode || appsGridMode || tileMode) moveGridSelection(-1, 0)
    }

    function handlePreviewRight() {
        if (previewTileMode || appsGridMode || tileMode) moveGridSelection(1, 0)
    }

    function handlePreviewUp() {
        if (previewTileMode || appsGridMode || tileMode) moveGridSelection(0, -1)
        else if (framedMode) moveSelection(-1)
    }

    function handlePreviewDown() {
        if (previewTileMode || appsGridMode || tileMode) moveGridSelection(0, 1)
        else if (framedMode) moveSelection(1)
    }

    function moveTileSelection(dx, dy) {
        var n = visibleEntries.length
        if (n <= 0) return
        if (dy !== 0) return
        if (dx !== 0)
            selectedIndex = (selectedIndex + dx % n + n) % n
    }

    function activateSelection() {
        var list = visibleEntries
        if (list.length === 0) return
        var idx = Math.max(0, Math.min(selectedIndex, list.length - 1))
        activateEntry(list[idx])
    }

    function handleEscapeKey() {
        if (submenu) {
            submenu = ""
            dynamicEntries = []
            dynamicEntryKind = ""
            shellUnusedOnly = false
            filterText = ""
            selectedIndex = 0
        } else if (styledMenuMode && filterText.trim() !== "") {
            filterText = ""
            selectedIndex = 0
        } else {
            dismiss()
        }
    }

    function handleActivateKey() {
        activateSelection()
    }

    onFilterTextChanged: {
        selectedIndex = 0
        refreshVisibleEntries()
    }
    onSubmenuChanged: {
        selectedIndex = 0
        refreshVisibleEntries()
    }
    onModeChanged: {
        selectedIndex = 0
        refreshVisibleEntries()
    }
    onCommandEntriesChanged: refreshVisibleEntries()
    onDynamicEntriesChanged: refreshVisibleEntries()
    onShellUnusedOnlyChanged: {
        selectedIndex = 0
        refreshVisibleEntries()
    }

    function refreshCommandEntries() {
        if (mode === "power") {
            commandEntries = MenuEntries.systemEntries(home)
            return
        }
        commandEntries = []
    }

    function entryIconSource(entry) {
        if (!entry) return ""
        if (entry.iconSource)
            return entry.iconSource
        if (entry.id && root.appIconMap[entry.id])
            return root.appIconMap[entry.id]
        var iconName = ""
        if (entry.entryRef && entry.entryRef.icon)
            iconName = String(entry.entryRef.icon)
        if (iconName && root.appIconMap[iconName])
            return root.appIconMap[iconName]
        return Util.iconSourceForName(iconName)
    }

    function applyAppIconMap(raw) {
        var map = {}
        var lines = String(raw || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line) continue
            var tab = line.indexOf("\t")
            if (tab === -1) continue
            map[line.slice(0, tab)] = line.slice(tab + 1)
        }
        root.appIconMap = map
        var rebuilt = []
        for (var j = 0; j < root.cachedApps.length; j++) {
            var app = root.cachedApps[j]
            rebuilt.push({
                kind: app.kind,
                name: app.name,
                id: app.id,
                entryRef: app.entryRef,
                iconSource: (app.id && map[app.id]) ? map[app.id] : (app.iconSource || "")
            })
        }
        root.cachedApps = rebuilt
        root.appIconEpoch++
        root.visibleEntries = root.filteredEntries()
    }

    function entryGlyphIcon(entry) {
        if (!entry) return "󰍉"
        if (entry.icon) return entry.icon
        return "󰍉"
    }

    function rebuildAppCache() {
        var list = []
        try {
            var values = DesktopEntries.applications.values || []
            for (var i = 0; i < values.length; i++) {
                var entry = values[i]
                if (!entry || !entry.id) continue
                var item = {
                    kind: "app",
                    name: String(entry.name || entry.id),
                    id: entry.id,
                    entryRef: entry,
                    iconSource: root.appIconMap[entry.id] || ""
                }
                list.push(item)
            }
        } catch (e) {
            console.warn("evo.menu app list failed:", e)
        }
        cachedApps = list
        loadAppIcons()
    }

    function loadAppIcons() {
        var listScript = home + "/.local/bin/evo-menu-list"
        loadAppIconsProc.command = ["bash", "-lc",
            "test -x " + Util.shellQuote(listScript) + " && " +
            Util.shellQuote(listScript) + " icons"
        ]
        if (!loadAppIconsProc.running)
            loadAppIconsProc.running = true
    }

    function appEntries() {
        if (cachedApps.length === 0)
            rebuildAppCache()
        return cachedApps
    }

    function entryListsEqual(a, b) {
        if (!a || !b || a.length !== b.length) return false
        for (var i = 0; i < a.length; i++) {
            if ((a[i].id || a[i].name) !== (b[i].id || b[i].name))
                return false
        }
        return true
    }

    function refreshVisibleEntries() {
        var next = filteredEntries()
        if (entryListsEqual(visibleEntries, next))
            return
        visibleEntries = next
    }

    function filteredEntries() {
        var q = filterText.trim()
        if (submenu) {
            if (dynamicEntries.length === 0) return []
            var shellEntries = MenuEntries.filterEntries(dynamicEntries, q)
            if (submenu === "shell" && shellUnusedOnly) {
                shellEntries = shellEntries.filter(function(e) {
                    return !e.internal
                })
            }
            return shellEntries.map(function(e) {
                if (root.infoListMode) {
                    return {
                        kind: "info",
                        name: e.name,
                        keys: e.keys || e.command || "",
                        icon: root.submenu === "bindings" ? "󰌌" : "󰆍"
                    }
                }
                return {
                    kind: "command",
                    name: e.name,
                    command: e.command,
                    submenu: e.submenu,
                    preview: e.preview || "",
                    icon: e.icon || ""
                }
            })
        }
        var out = []
        if (mode === "apps") {
            var apps = appEntries()
            if (!q)
                return apps
            var needle = q.toLowerCase()
            for (var i = 0; i < apps.length; i++) {
                var app = apps[i]
                var name = String(app.name || "").toLowerCase()
                var id = String(app.id || "").toLowerCase()
                if (name.startsWith(needle) || id.startsWith(needle))
                    out.push(app)
            }
            return out
        }
        if (mode === "power") {
            return MenuEntries.filterEntries(commandEntries, q).map(MenuEntries.mapEntry)
        }
        return []
    }

    function runCommand(cmd) {
        var command = String(cmd || "").trim()
        if (!command) return
        Quickshell.execDetached(["bash", "-lc", command])
        dismiss()
    }

    function launchDesktopEntry(entryRef, id) {
        // Quickshell execute() ignores runInTerminal; gtk-launch respects Terminal=true.
        if (entryRef && entryRef.runInTerminal)
            Quickshell.execDetached(["gtk-launch", String(id)])
        else if (entryRef && typeof entryRef.execute === "function")
            entryRef.execute()
        else
            Quickshell.execDetached(["gtk-launch", String(id)])
    }

    function activateEntry(entry) {
        if (!entry) return
        if (entry.kind === "app") {
            launchDesktopEntry(entry.entryRef, entry.id)
            dismiss()
            return
        }
        if (entry.kind === "submenu" && entry.submenu) {
            submenu = entry.submenu
            filterText = ""
            selectedIndex = 0
            loadDynamicEntries(entry.submenu)
            Qt.callLater(function() {
                root.previewAreaMaxWidth = panel.previewAreaMaxWidth
                root.previewAreaMaxHeight = panel.previewAreaMaxHeight
                if (entry.submenu === "themes" || entry.submenu === "wallpaper")
                    menuHost.forceActiveFocus()
                else
                    root.focusSearchField()
            })
            return
        }
        if (entry.kind === "mode" && entry.mode) {
            mode = String(entry.mode)
            submenu = ""
            filterText = ""
            selectedIndex = 0
            refreshCommandEntries()
            dynamicEntries = []
            if (mode === "apps" && cachedApps.length === 0)
                rebuildAppCache()
            refreshVisibleEntries()
            Qt.callLater(function() {
                root.previewAreaMaxWidth = panel.previewAreaMaxWidth
                root.previewAreaMaxHeight = panel.previewAreaMaxHeight
                root.focusSearchField()
            })
            return
        }
        if (entry.kind === "info")
            return
        if (entry.command) runCommand(entry.command)
    }

    function warmPreviewCache() {
        var warmScript = home + "/.local/bin/evo-menu-warm"
        previewWarmProc.command = ["bash", "-lc", "test -x " + Util.shellQuote(warmScript) + " && " + Util.shellQuote(warmScript)]
        previewWarmProc.running = true
    }

    function loadDynamicEntries(kind) {
        dynamicLoading = true
        dynamicEntries = []
        dynamicEntryKind = kind
        var listScript = home + "/.local/bin/evo-menu-list"
        if (kind !== "themes" && kind !== "wallpaper" && kind !== "bindings" && kind !== "shell") {
            dynamicLoading = false
            dynamicEntryKind = ""
            return
        }
        dynamicProc.command = ["bash", "-lc",
            "test -x " + Util.shellQuote(listScript) + " && " +
            Util.shellQuote(listScript) + " " + kind
        ]
        dynamicProc.running = true
    }

    function parseDynamicLines(raw) {
        var lines = String(raw || "").split("\n")
        var out = []
        var infoMode = root.dynamicEntryKind === "bindings" || root.dynamicEntryKind === "shell"
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line) continue
            var tab = line.indexOf("\t")
            if (tab === -1) {
                out.push({ name: line, command: line, preview: "" })
            } else {
                var parts = line.split("\t")
                if (infoMode && parts.length >= 2) {
                    out.push({
                        name: parts[0] || "",
                        keys: parts[1] || "",
                        internal: root.dynamicEntryKind === "shell" && parts.length >= 3 && parts[2] === "1"
                    })
                } else if (parts.length === 2 && parts[1].indexOf("/") < 0 && parts[1].indexOf("evo-") !== 0) {
                    out.push({ name: parts[0] || "", keys: parts[1] || "" })
                } else {
                    out.push({
                        name: parts[0] || "",
                        command: parts[1] || "",
                        preview: parts[2] || ""
                    })
                }
            }
        }
        dynamicEntries = out
        dynamicLoading = false
        Qt.callLater(function() {
            root.previewAreaMaxWidth = panel.previewAreaMaxWidth
            root.previewAreaMaxHeight = panel.previewAreaMaxHeight
        })
    }

    Process {
        id: dynamicProc
        stdout: StdioCollector {
            onStreamFinished: root.parseDynamicLines(text)
        }
        onExited: root.dynamicLoading = false
    }

    Process {
        id: previewWarmProc
    }

    Process {
        id: loadAppIconsProc
        stdout: StdioCollector {
            onStreamFinished: root.applyAppIconMap(text)
        }
    }

    PanelWindow {
        id: panel
        visible: root.opened
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.namespace: "evo-menu"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore

        readonly property real previewAreaMaxWidth: {
            var screenW = width > 0 ? width : (Quickshell.screens.length > 0 ? Quickshell.screens[0].width : 1920)
            return Math.max(root.previewTileWidth * 3, screenW - root.previewMenuMargin * 2)
        }
        readonly property real previewAreaMaxHeight: {
            var screenH = height > 0 ? height : (Quickshell.screens.length > 0 ? Quickshell.screens[0].height : 1080)
            return Math.max(root.previewTileHeight * 2, screenH - root.previewMenuMargin * 2)
        }

        onWidthChanged: {
            root.previewAreaMaxWidth = previewAreaMaxWidth
        }
        onHeightChanged: {
            root.previewAreaMaxHeight = previewAreaMaxHeight
        }
        Component.onCompleted: {
            root.previewAreaMaxWidth = previewAreaMaxWidth
            root.previewAreaMaxHeight = previewAreaMaxHeight
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismiss()
        }

        Item {
            id: menuHost
            z: 1
            anchors.centerIn: parent
            width: root.styledMenuMode
                ? root.gridWidth + root.powerMenuPadding * 2
                : root.boxTileMode
                    ? root.boxRowWidth
                    : root.framedMenuWidth
            height: root.styledMenuMode
                ? (root.appsGridMode ? root.styledMenuHostHeight : root.gridHeight + root.powerHeaderHeight + root.powerMenuPadding * 2 + 28)
                : root.boxTileMode ? root.boxRowHeight : root.framedMenuHeight
            focus: root.opened && (root.previewTileMode || root.styledMenuMode)

            TextInput {
                id: silentFilterField
                visible: false
                width: 1
                height: 1
                opacity: 0
                text: root.filterText
                onTextEdited: root.filterText = text
                Keys.onEscapePressed: root.handleEscapeKey()
                Keys.onLeftPressed: root.handlePreviewLeft()
                Keys.onRightPressed: root.handlePreviewRight()
                Keys.onUpPressed: root.handlePreviewUp()
                Keys.onDownPressed: root.handlePreviewDown()
                Keys.onReturnPressed: root.handleActivateKey()
            }

            Keys.onEscapePressed: root.handleEscapeKey()
            Keys.onLeftPressed: root.handlePreviewLeft()
            Keys.onRightPressed: root.handlePreviewRight()
            Keys.onUpPressed: root.handlePreviewUp()
            Keys.onDownPressed: root.handlePreviewDown()
            Keys.onReturnPressed: root.handleActivateKey()
            Keys.onPressed: function(event) {
                if (!root.styledMenuMode && !root.framedMode)
                    return
                if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                    return
                var text = event.text
                if (!text || text.length === 0 || event.isAutoRepeat)
                    return
                root.appendFilterText(text)
                event.accepted = true
            }

            Rectangle {
                anchors.fill: parent
                visible: root.framedMode
                color: Theme.overlaySurface
                border.color: Theme.accent
                border.width: 1
            }

            Rectangle {
                anchors.fill: parent
                visible: root.styledMenuMode
                color: Theme.withOpacity(Theme.background, 0.94)
                border.color: Theme.withOpacity(Theme.accent, 0.5)
                border.width: 1
                radius: Theme.panelCornerRadius
            }

            Column {
                id: framedColumn
                anchors.fill: parent
                anchors.margins: root.styledMenuMode ? root.powerMenuPadding : (root.boxTileMode ? 0 : root.framedPadding)
                spacing: root.styledMenuMode ? 14 : 12
                clip: root.framedMode

                Item {
                    id: filterChrome
                    width: parent.width
                    height: root.framedFilterChromeHeight
                    visible: root.framedMode

                    Rectangle {
                        id: filterBg
                        anchors.fill: parent
                        color: Theme.overlaySurface
                    }

                    Text {
                        visible: filterField.text.length === 0 && !filterField.activeFocus
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: shellToggleRow.visible ? shellToggleRow.left : parent.right
                        anchors.rightMargin: shellToggleRow.visible ? 12 : 12
                        text: root.placeholderText
                        color: Theme.foreground
                        opacity: Theme.opacityDisabled
                        font.family: Theme.fontFamily
                        font.pixelSize: root.listFilterFontSize
                        font.bold: Theme.fontBold
                        elide: Text.ElideRight
                    }

                    TextInput {
                        id: filterField
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: shellToggleRow.visible ? shellToggleRow.left : parent.right
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.listFilterFontSize
                        font.bold: Theme.fontBold
                        text: root.filterText
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter
                        onTextEdited: root.filterText = text
                        Keys.onEscapePressed: root.handleEscapeKey()
                        Keys.onLeftPressed: root.handlePreviewLeft()
                        Keys.onRightPressed: root.handlePreviewRight()
                        Keys.onUpPressed: root.handlePreviewUp()
                        Keys.onDownPressed: root.handlePreviewDown()
                        Keys.onReturnPressed: root.handleActivateKey()
                    }

                    Row {
                        id: shellToggleRow
                        visible: root.submenu === "shell"
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        height: parent.height

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.shellUnusedOnly ? "󰄲" : "󰄱"
                            color: root.shellUnusedOnly ? Theme.accent : Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.listFilterFontSize
                            font.bold: Theme.fontBold
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Unused only"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.listFilterFontSize
                            font.bold: Theme.fontBold
                            opacity: root.shellUnusedOnly ? 1 : Theme.opacityMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shellUnusedOnly = !root.shellUnusedOnly
                        }
                    }
                }

                Text {
                    visible: root.dynamicLoading
                    text: "Loading…"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.listFontSize
                    font.bold: Theme.fontBold
                }

                Flow {
                    id: previewFlow
                    visible: root.previewTileMode
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.previewGridWidth
                    spacing: root.tileSpacing
                    flow: Flow.LeftToRight

                    Repeater {
                        model: root.visibleEntries

                        Rectangle {
                            required property var modelData
                            required property int index
                            width: root.previewTileWidth
                            height: root.previewTileHeight
                            color: Theme.overlaySurface
                            border.color: index === root.selectedIndex ? Theme.accent : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                            border.width: index === root.selectedIndex ? 2 : 1

                            Item {
                                anchors.fill: parent
                                anchors.margins: 6
                                clip: true

                                Image {
                                    id: previewImage
                                    anchors.fill: parent
                                    source: Util.fileUrl(modelData.preview)
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    asynchronous: true
                                    cache: false
                                    mipmap: true
                                    sourceSize: Qt.size(
                                        Math.ceil(root.previewTileWidth * root.previewDpr),
                                        Math.ceil(root.previewImageHeight * root.previewDpr)
                                    )
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.overlaySurface
                                    visible: !modelData.preview || previewImage.status === Image.Error
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !modelData.preview || previewImage.status === Image.Error
                                    text: root.previewFallbackIcon
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.tileIconSize
                                    font.bold: Theme.fontBold
                                }
                            }

                            MouseArea {
                                id: previewMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.selectedIndex = index
                                    root.activateEntry(modelData)
                                }
                            }
                        }
                    }
                }

                Column {
                    visible: root.styledMenuMode
                    width: parent.width
                    spacing: 14

                    Item {
                        width: parent.width
                        height: root.powerHeaderHeight

                        Row {
                            id: menuHeaderRow
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.menuHeaderIcon
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: root.powerLogoFont
                                font.bold: Theme.fontBold
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacing2

                                Text {
                                    text: root.menuHeaderTitle
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize6xl
                                    font.bold: Theme.fontBold
                                }

                                Text {
                                    text: root.menuHeaderSubtitle
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeS
                                    font.bold: Theme.fontBold
                                    opacity: 0.5
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.appsGridMode && !root.dynamicLoading && root.visibleEntries.length === 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.filterText.trim() === "" ? "No applications" : "No matches"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeS
                        font.bold: Theme.fontBold
                        opacity: Theme.opacityMuted
                    }

                    Flickable {
                        id: appFlickable
                        visible: root.appsGridMode && root.visibleEntries.length > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.gridWidth
                        height: root.styledMenuViewportHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        contentWidth: width
                        contentHeight: appFlow.height

                        Flow {
                            id: appFlow
                            width: parent.width
                            spacing: root.tileSpacing
                            flow: Flow.LeftToRight

                            Repeater {
                                model: root.visibleEntries

                                Item {
                                    id: appTile
                                    required property var modelData
                                    required property int index
                                    width: root.powerTileWidth
                                    height: root.powerTileHeight

                                    readonly property string appIconSource: {
                                        var _epoch = root.appIconEpoch
                                        if (!modelData)
                                            return ""
                                        if (modelData.iconSource)
                                            return modelData.iconSource
                                        if (modelData.id && root.appIconMap[modelData.id])
                                            return root.appIconMap[modelData.id]
                                        return root.entryIconSource(modelData)
                                    }
                                    readonly property string glyphIcon: root.entryGlyphIcon(modelData)
                                    readonly property bool appSelected: index === root.selectedIndex

                                    scale: appMouse.pressed ? 0.96 : (appMouse.containsMouse ? 1.02 : 1)
                                    transformOrigin: Item.Center

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 120
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    Rectangle {
                                        id: tileBg
                                        anchors.fill: parent
                                        radius: Theme.panelCornerRadius
                                        color: appTile.appSelected
                                            ? Theme.withOpacity(Theme.accent, 0.14)
                                            : Theme.withOpacity(Theme.panelMantle, appMouse.containsMouse ? 0.95 : 0.72)
                                        border.color: appTile.appSelected
                                            ? Theme.accent
                                            : Theme.withOpacity(Theme.accent, appMouse.containsMouse ? 0.45 : 0.22)
                                        border.width: appTile.appSelected ? 2 : 1

                                        Column {
                                            anchors.centerIn: parent
                                            width: parent.width - 16
                                            spacing: Theme.spacingM

                                            Item {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: root.powerTileIconSize
                                                height: root.powerTileIconSize

                                                Image {
                                                    id: appIcon
                                                    anchors.fill: parent
                                                    visible: appTile.appIconSource.length > 0 && status !== Image.Error
                                                    source: Util.normalizeIconSource(appTile.appIconSource)
                                                    fillMode: Image.PreserveAspectFit
                                                    smooth: true
                                                    asynchronous: true
                                                    cache: true
                                                    mipmap: true
                                                    sourceSize: Qt.size(root.appIconSourceSize, root.appIconSourceSize)
                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    visible: appTile.appIconSource.length === 0 || appIcon.status === Image.Error
                                                    text: appTile.glyphIcon
                                                    color: appTile.appSelected ? Theme.accent : Theme.foreground
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: root.powerTileIconSize
                                                    font.bold: Theme.fontBold
                                                }
                                            }

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: parent.width
                                                text: modelData.name || ""
                                                color: Theme.foreground
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeXs
                                                font.bold: Theme.fontBold
                                                horizontalAlignment: Text.AlignHCenter
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                                opacity: appTile.appSelected ? 1 : 0.82
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: appMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: root.selectedIndex = index
                                        onClicked: {
                                            root.selectedIndex = index
                                            root.activateEntry(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        visible: root.tileMode
                        width: parent.width
                        implicitHeight: powerFlow.implicitHeight

                        Flow {
                            id: powerFlow
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root.gridWidth
                            spacing: root.tileSpacing
                            flow: Flow.LeftToRight

                            Repeater {
                                model: root.visibleEntries

                                Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: root.powerTileWidth
                                    height: root.powerTileHeight
                                    radius: Theme.panelCornerRadius
                                    color: index === root.selectedIndex
                                        ? Theme.withOpacity(Theme.accent, 0.14)
                                        : Theme.withOpacity(Theme.panelMantle, powerMouse.containsMouse ? 0.95 : 0.72)
                                    border.color: index === root.selectedIndex
                                        ? Theme.accent
                                        : Theme.withOpacity(Theme.accent, powerMouse.containsMouse ? 0.45 : 0.22)
                                    border.width: index === root.selectedIndex ? 2 : 1

                                    scale: powerMouse.pressed ? 0.96 : (powerMouse.containsMouse ? 1.02 : 1)
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 120
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    Column {
                                        anchors.centerIn: parent
                                        width: parent.width - 16
                                        spacing: Theme.spacingM

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.icon || "󰍉"
                                            color: index === root.selectedIndex ? Theme.accent : Theme.foreground
                                            font.family: Theme.fontFamily
                                            font.pixelSize: root.powerTileIconSize
                                            font.bold: Theme.fontBold
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: parent.width
                                            text: modelData.name
                                            color: Theme.foreground
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            font.bold: Theme.fontBold
                                            horizontalAlignment: Text.AlignHCenter
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                            opacity: index === root.selectedIndex ? 1 : 0.82
                                        }
                                    }

                                    MouseArea {
                                        id: powerMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: root.selectedIndex = index
                                        onClicked: {
                                            root.selectedIndex = index
                                            root.activateEntry(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ListView {
                    id: entryList
                    width: parent.width
                    height: root.framedMode ? root.framedListHeight : parent.height - y
                    clip: true
                    visible: root.framedMode
                    model: root.visibleEntries
                    currentIndex: root.selectedIndex

                    onCountChanged: if (root.selectedIndex >= count) root.selectedIndex = Math.max(0, count - 1)

                    delegate: Rectangle {
                        id: entryRow
                        required property var modelData
                        required property int index
                        width: entryList.width
                        height: entryRow.infoRow ? root.infoListRowHeight : root.listRowHeight
                        clip: false
                        color: index === entryList.currentIndex || mouseArea.containsMouse ? Theme.panelMantle : "transparent"

                        readonly property string appIconSource: {
                            var _epoch = root.appIconEpoch
                            return root.entryIconSource(modelData)
                        }
                        readonly property string glyphIcon: root.entryGlyphIcon(modelData)
                        readonly property bool infoRow: modelData.kind === "info"
                        readonly property string keysLabel: String(modelData.keys || "")
                        readonly property int rowFontSize: entryRow.infoRow
                            ? root.infoListFontSize
                            : root.listFontSize

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: entryRow.infoRow ? 16 : 12

                            Item {
                                visible: !entryRow.infoRow
                                Layout.preferredWidth: root.listIconSize
                                Layout.preferredHeight: root.listIconSize
                                Layout.alignment: Qt.AlignVCenter

                                Image {
                                    anchors.fill: parent
                                    visible: entryRow.appIconSource.length > 0
                                    source: Util.normalizeIconSource(entryRow.appIconSource)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    asynchronous: true
                                    cache: true
                                    sourceSize: Qt.size(root.listIconSize * 2, root.listIconSize * 2)
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: entryRow.appIconSource.length === 0
                                    text: entryRow.glyphIcon
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.listIconSize
                                    font.bold: Theme.fontBold
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.preferredWidth: entryRow.infoRow ? 1 : 0
                                Layout.alignment: Qt.AlignVCenter
                                text: modelData.name
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: entryRow.rowFontSize
                                font.bold: Theme.fontBold
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Text {
                                visible: entryRow.infoRow && entryRow.keysLabel !== ""
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.alignment: Qt.AlignVCenter
                                horizontalAlignment: Text.AlignRight
                                text: entryRow.keysLabel
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: entryRow.rowFontSize
                                font.bold: Theme.fontBold
                                opacity: Theme.opacitySecondary
                                elide: Text.ElideMiddle
                                maximumLineCount: 1
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.selectedIndex = index
                                root.activateEntry(modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        refreshCommandEntries()
        Qt.callLater(rebuildAppCache)
        Qt.callLater(warmPreviewCache)
    }
}
