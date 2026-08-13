import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
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
    property var visibleEntries: []
    property var cachedApps: []
    property var iconPathCache: ({})
    property int iconWarmIndex: 0
    property bool dynamicLoading: false
    property int selectedIndex: 0
    property real previewAreaMaxWidth: 1600
    property real previewAreaMaxHeight: 900
    property var hostScreen: null

    function resolveHostScreen() {
        return Util.screenForOverlay()
    }

    readonly property bool tileMode: mode === "power" && !submenu
    readonly property bool previewTileMode: submenu === "themes" || submenu === "wallpaper"
    readonly property bool appsGridMode: mode === "apps"
    readonly property bool boxTileMode: tileMode || previewTileMode
    readonly property bool framedMode: !boxTileMode && !appsGridMode
    readonly property string previewFallbackIcon: submenu === "wallpaper" ? "󰏘" : "󰸌"
    readonly property int tileWidth: 160
    readonly property int tileHeight: 160
    readonly property int tileSpacing: 24
    readonly property int tileIconSize: 64
    readonly property int systemActionCount: 6
    readonly property int appGridColumns: 6
    readonly property int appIconSize: 110
    readonly property int appIconSourceSize: 128
    readonly property int appTileWidth: 160
    readonly property int appTileHeight: 160
    readonly property int appTileSpacing: 24
    readonly property int previewTileWidth: 296
    readonly property int previewTileHeight: 204
    readonly property int previewImageHeight: 192
    readonly property real previewDpr: 2
    readonly property int listIconSize: 40
    readonly property int listFontSize: 24
    readonly property int listRowHeight: 72
    readonly property int listFilterHeight: 38
    readonly property int listFilterFontSize: Theme.panelTitleFontPixelSize
    readonly property int previewMenuMargin: 48
    readonly property int appsMenuPadding: 0
    readonly property int appsMenuRadius: Theme.panelCornerRadius

    readonly property int previewGridColumns: 5
    readonly property int previewColumnCount: gridColumnCount
    readonly property int activeTileWidth: previewTileMode ? previewTileWidth : (appsGridMode ? appTileWidth : tileWidth)
    readonly property int activeTileHeight: previewTileMode ? previewTileHeight : (appsGridMode ? appTileHeight : tileHeight)

    readonly property int gridColumnCount: {
        var n = visibleEntries.length
        if (tileMode) return Math.max(1, n)
        if (appsGridMode)
            return appGridColumns
        if (n <= 0) return 1
        if (previewTileMode)
            return Math.max(1, Math.min(n, previewGridColumns))
        var maxW = panel.previewAreaMaxWidth
        var cols = Math.floor((maxW + tileSpacing) / (activeTileWidth + tileSpacing))
        return Math.max(1, Math.min(n, cols))
    }

    readonly property int gridRowCount: {
        var n = visibleEntries.length
        if (n <= 0) return 1
        if (tileMode) return 2
        return Math.ceil(n / gridColumnCount)
    }

    readonly property int gridWidth: {
        var cols = gridColumnCount
        if (cols <= 0) return activeTileWidth
        if (appsGridMode)
            return cols * (appTileWidth + appTileSpacing)
        return cols * activeTileWidth + (cols - 1) * tileSpacing
    }

    readonly property int gridHeight: {
        var rows = gridRowCount
        if (rows <= 0) return activeTileHeight
        if (appsGridMode)
            return rows * (appTileHeight + appTileSpacing)
        return rows * activeTileHeight + (rows - 1) * tileSpacing
    }

    readonly property int appsGridViewportHeight: {
        var chrome = appsMenuPadding * 2
        var available = Math.max(appTileHeight + appTileSpacing,
            panel.previewAreaMaxHeight - chrome)
        return Math.min(gridHeight, available)
    }

    readonly property int previewRowCount: gridRowCount
    readonly property int previewGridWidth: gridWidth
    readonly property int previewGridHeight: gridHeight

    readonly property int tileRowWidth: {
        var n = visibleEntries.length
        if (n <= 0) return tileWidth
        if (tileMode) {
            var actionN = Math.min(systemActionCount, n)
            var powerN = Math.max(0, n - systemActionCount)
            var cols = Math.max(actionN, powerN, 1)
            return cols * tileWidth + (cols - 1) * tileSpacing
        }
        return n * tileWidth + (n - 1) * tileSpacing
    }

    readonly property int previewRowWidth: {
        var n = visibleEntries.length
        if (n <= 0) return previewTileWidth
        return n * previewTileWidth + (n - 1) * tileSpacing
    }

    readonly property int boxRowWidth: previewTileMode ? gridWidth : tileRowWidth
    readonly property int boxRowHeight: previewTileMode
        ? gridHeight
        : (tileMode ? tileHeight * 2 + tileSpacing : tileHeight)
    readonly property var systemActionTiles: {
        var list = visibleEntries
        var out = []
        var n = Math.min(systemActionCount, list.length)
        for (var i = 0; i < n; i++)
            out.push(list[i])
        return out
    }
    readonly property var systemPowerTiles: {
        var list = visibleEntries
        var out = []
        for (var i = systemActionCount; i < list.length; i++)
            out.push(list[i])
        return out
    }
    readonly property int appsHostWidth: gridWidth + appsMenuPadding * 2
    readonly property int appsHostHeight: appsMenuPadding * 2 + appsGridViewportHeight

    readonly property string home: Quickshell.env("HOME")
    readonly property string placeholderText: {
        if (mode === "power") return "System…"
        if (mode === "apps") return "Applications…"
        return "Search…"
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
        hostScreen = resolveHostScreen()
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
            if (root.boxTileMode)
                menuHost.forceActiveFocus()
            else if (root.appsGridMode)
                appsFilterField.forceActiveFocus()
            else
                filterField.forceActiveFocus()
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
        if (appsGridMode)
            appGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
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
        if (previewTileMode || appsGridMode) moveGridSelection(-1, 0)
        else if (tileMode) moveTileSelection(-1, 0)
    }

    function handlePreviewRight() {
        if (previewTileMode || appsGridMode) moveGridSelection(1, 0)
        else if (tileMode) moveTileSelection(1, 0)
    }

    function handlePreviewUp() {
        if (previewTileMode || appsGridMode) moveGridSelection(0, -1)
        else if (tileMode) moveTileSelection(0, -1)
        else if (framedMode) moveSelection(-1)
    }

    function handlePreviewDown() {
        if (previewTileMode || appsGridMode) moveGridSelection(0, 1)
        else if (tileMode) moveTileSelection(0, 1)
        else if (framedMode) moveSelection(1)
    }

    function moveTileSelection(dx, dy) {
        var n = visibleEntries.length
        if (n <= 0) return
        var row = selectedIndex < systemActionCount ? 0 : 1
        var start = row === 0 ? 0 : systemActionCount
        var len = row === 0 ? Math.min(systemActionCount, n) : Math.max(0, n - start)
        if (len <= 0) return
        var col = selectedIndex - start

        if (dx !== 0) {
            selectedIndex = start + ((col + dx) % len + len) % len
            return
        }
        if (dy === 0) return
        var nextRow = row + dy
        if (nextRow < 0 || nextRow > 1) return
        var nextStart = nextRow === 0 ? 0 : systemActionCount
        var nextLen = nextRow === 0 ? Math.min(systemActionCount, n) : Math.max(0, n - nextStart)
        if (nextLen <= 0) return
        selectedIndex = nextStart + Math.min(col, nextLen - 1)
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
            filterText = ""
            selectedIndex = 0
        } else dismiss()
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

    function refreshCommandEntries() {
        if (mode === "power") {
            commandEntries = MenuEntries.systemEntries(home)
            return
        }
        commandEntries = []
    }

    function steamThemedIconName(name) {
        if (name === "steam_icon_220" || name === "half-life2") return "half-life2"
        if (name === "steam_icon_2536520" || name === "diablo-2") return "diablo-2"
        return ""
    }

    function cachedIconPath(name) {
        var key = String(name || "") + "|" + String(Theme.iconThemeName || "")
        if (iconPathCache[key] !== undefined)
            return iconPathCache[key]
        var path = Quickshell.iconPath(name, true) || ""
        iconPathCache[key] = path
        return path
    }

    function entryIconSource(entry) {
        if (!entry) return ""
        if (entry.iconSource)
            return entry.iconSource
        if (entry.kind !== "app" || !entry.entryRef || !entry.entryRef.icon)
            return ""
        var name = String(entry.entryRef.icon)
        if (name.indexOf("/") !== -1)
            return name.indexOf("file://") === 0 ? name : ("file://" + name)
        var themed = steamThemedIconName(name)
        var src = ""
        if (themed) {
            var home = Quickshell.env("HOME") || ""
            var theme = Theme.iconThemeName
            if (home && theme)
                src = "file://" + home + "/.local/share/icons/" + theme + "/apps/64/" + themed + ".svg"
            else
                src = cachedIconPath(themed)
        } else {
            src = cachedIconPath(name)
        }
        entry.iconSource = src
        return src
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
                    entryRef: entry
                }
                list.push(item)
            }
        } catch (e) {
            console.warn("evo.menu app list failed:", e)
        }
        cachedApps = UsageMemory.sortByUsage(list, "apps", function(e) { return e.id }, function(e) { return e.name })
        iconWarmIndex = 0
        iconWarmTimer.running = cachedApps.length > 0
    }

    function resortCachedApps() {
        if (cachedApps.length === 0)
            return
        cachedApps = UsageMemory.sortByUsage(cachedApps, "apps", function(e) { return e.id }, function(e) { return e.name })
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
            return MenuEntries.filterEntries(dynamicEntries, q).map(function(e) {
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
                if (app.name.toLowerCase().indexOf(needle) !== -1 || app.id.toLowerCase().indexOf(needle) !== -1)
                    out.push(app)
            }
            return out
        }
        if (mode === "power") {
            return MenuEntries.filterEntries(commandEntries, q, 16).map(MenuEntries.mapEntry)
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
            UsageMemory.bump("apps", entry.id)
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
                    filterField.forceActiveFocus()
            })
            return
        }
        if (entry.command) runCommand(entry.command)
    }

    function warmPreviewCache() {
        var warmScript = home + "/.local/bin/evo-menu-preview-warm.sh"
        previewWarmProc.command = ["bash", "-lc", "test -x " + Util.shellQuote(warmScript) + " && " + Util.shellQuote(warmScript)]
        previewWarmProc.running = true
    }

    function loadDynamicEntries(kind) {
        dynamicLoading = true
        dynamicEntries = []
        var listScript = home + "/.local/bin/evo-menu-list-previews.sh"
        if (kind !== "themes" && kind !== "wallpaper") {
            dynamicLoading = false
            return
        }
        dynamicProc.command = ["bash", "-lc",
            "test -x " + Util.shellQuote(listScript) + " && " +
            Util.shellQuote(listScript) + " " + (kind === "wallpaper" ? "wallpapers" : "themes")
        ]
        dynamicProc.running = true
    }

    function parseDynamicLines(raw) {
        var lines = String(raw || "").split("\n")
        var out = []
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line) continue
            var tab = line.indexOf("\t")
            if (tab === -1) {
                out.push({ name: line, command: line, preview: "" })
            } else {
                var parts = line.split("\t")
                out.push({
                    name: parts[0] || "",
                    command: parts[1] || "",
                    preview: parts[2] || ""
                })
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

    PanelWindow {
        id: panel
        screen: root.hostScreen
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

        Rectangle {
            anchors.fill: parent
            color: Theme.overlayScrim
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismiss()
        }

        Item {
            id: menuHost
            z: 1
            anchors.centerIn: parent
            width: root.appsGridMode
                ? root.appsHostWidth
                : root.boxTileMode
                    ? root.boxRowWidth
                    : 720
            height: root.appsGridMode
                ? root.appsHostHeight
                : root.boxTileMode ? root.boxRowHeight : 640
            focus: root.opened

            Keys.onEscapePressed: root.handleEscapeKey()
            Keys.onLeftPressed: root.handlePreviewLeft()
            Keys.onRightPressed: root.handlePreviewRight()
            Keys.onUpPressed: root.handlePreviewUp()
            Keys.onDownPressed: root.handlePreviewDown()
            Keys.onReturnPressed: root.handleActivateKey()

            Rectangle {
                anchors.fill: parent
                visible: root.framedMode
                color: Theme.overlaySurface
                border.color: Theme.accent
                border.width: 1
            }

            TextInput {
                id: appsFilterField
                x: 0
                y: 0
                width: 1
                height: 1
                opacity: 0
                visible: root.appsGridMode
                enabled: root.appsGridMode
                color: "transparent"
                cursorVisible: false
                text: root.filterText
                onTextEdited: root.filterText = text
                Keys.onEscapePressed: root.handleEscapeKey()
                Keys.onLeftPressed: root.handlePreviewLeft()
                Keys.onRightPressed: root.handlePreviewRight()
                Keys.onUpPressed: root.handlePreviewUp()
                Keys.onDownPressed: root.handlePreviewDown()
                Keys.onReturnPressed: root.handleActivateKey()
                onActiveFocusChanged: {
                    if (activeFocus || !root.opened || !root.appsGridMode)
                        return
                    Qt.callLater(function() {
                        if (root.opened && root.appsGridMode)
                            appsFilterField.forceActiveFocus()
                    })
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: root.boxTileMode ? 0 : (root.appsGridMode ? root.appsMenuPadding : 16)
                spacing: 12

                Item {
                    width: parent.width
                    height: root.listFilterHeight
                    visible: root.framedMode

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.overlaySurface
                    }

                    Text {
                        visible: filterField.text.length === 0 && !filterField.activeFocus
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.placeholderText
                        color: Theme.foreground
                        opacity: 0.45
                        font.family: Theme.fontFamily
                        font.pixelSize: root.listFilterFontSize
                        font.bold: Theme.fontBold
                    }

                    TextInput {
                        id: filterField
                        anchors.fill: parent
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

                Text {
                    visible: root.appsGridMode && !root.dynamicLoading && root.visibleEntries.length === 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.filterText.trim() === "" ? "No applications" : "No matches"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.panelSmallFontPixelSize
                    font.bold: Theme.fontBold
                    opacity: 0.55
                }

                GridView {
                    id: appGrid
                    visible: root.appsGridMode && root.visibleEntries.length > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.gridWidth
                    height: root.appsGridViewportHeight
                    clip: true
                    reuseItems: true
                    highlightFollowsCurrentItem: false
                    cacheBuffer: root.appTileHeight + root.appTileSpacing
                    cellWidth: root.appTileWidth + root.appTileSpacing
                    cellHeight: root.appTileHeight + root.appTileSpacing
                    model: root.visibleEntries
                    currentIndex: root.selectedIndex

                    onCountChanged: if (root.selectedIndex >= count) root.selectedIndex = Math.max(0, count - 1)

                    delegate: Item {
                        id: appTile
                        required property var modelData
                        required property int index
                        width: root.appTileWidth + root.appTileSpacing
                        height: root.appTileHeight + root.appTileSpacing
                        opacity: appMouse.containsMouse || index === root.selectedIndex ? 1 : 0.88

                        readonly property string appIconSource: modelData.iconSource || root.entryIconSource(modelData)
                        readonly property string glyphIcon: root.entryGlyphIcon(modelData)
                        readonly property bool appSelected: index === root.selectedIndex

                        Item {
                            id: tileFrame
                            anchors.centerIn: parent
                            width: root.appTileWidth
                            height: root.appTileHeight

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.overlaySurface
                                border.width: appTile.appSelected ? 2 : 0
                                border.color: Theme.accent
                                radius: Theme.panelCornerRadius
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 4

                                Item {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: root.appIconSize
                                    height: root.appIconSize

                                    Image {
                                        id: appIcon
                                        anchors.fill: parent
                                        visible: appTile.appIconSource.length > 0 && status !== Image.Error
                                        source: appTile.appIconSource
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        asynchronous: true
                                        cache: true
                                        sourceSize: Qt.size(root.appIconSourceSize, root.appIconSourceSize)
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: appTile.appIconSource.length === 0 || appIcon.status === Image.Error
                                        text: appTile.glyphIcon
                                        color: Theme.accent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.appIconSize * 0.5
                                        font.bold: Theme.fontBold
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: Math.min(implicitWidth, root.appTileWidth - 12)
                                    text: modelData.name || ""
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.panelHintFontPixelSize
                                    font.bold: Theme.fontBold
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    opacity: 0.8
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

                Column {
                    id: tileRow
                    visible: root.tileMode
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: root.tileSpacing
                    width: root.tileRowWidth
                    height: root.tileHeight * 2 + root.tileSpacing

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: root.tileSpacing
                        height: root.tileHeight

                        Repeater {
                            model: root.systemActionTiles

                            Rectangle {
                                required property var modelData
                                required property int index
                                width: root.tileWidth
                                height: root.tileHeight
                                color: Theme.overlaySurface
                                border.color: index === root.selectedIndex ? Theme.accent : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                                border.width: index === root.selectedIndex ? 2 : 1

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        text: modelData.icon || "󰍉"
                                        color: Theme.accent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.tileIconSize
                                        font.bold: Theme.fontBold
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.name
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.panelHintFontPixelSize
                                        font.bold: Theme.fontBold
                                        width: Math.min(implicitWidth, root.tileWidth - 12)
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: root.selectedIndex = index
                                    onClicked: {
                                        root.selectedIndex = index
                                        root.activateEntry(modelData)
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: root.tileSpacing
                        height: root.tileHeight

                        Repeater {
                            model: root.systemPowerTiles

                            Rectangle {
                                required property var modelData
                                required property int index
                                readonly property int tileIndex: index + root.systemActionCount
                                width: root.tileWidth
                                height: root.tileHeight
                                color: Theme.overlaySurface
                                border.color: tileIndex === root.selectedIndex ? Theme.accent : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                                border.width: tileIndex === root.selectedIndex ? 2 : 1

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        text: modelData.icon || "󰍉"
                                        color: Theme.accent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.tileIconSize
                                        font.bold: Theme.fontBold
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.name
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.panelHintFontPixelSize
                                        font.bold: Theme.fontBold
                                        width: Math.min(implicitWidth, root.tileWidth - 12)
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: root.selectedIndex = tileIndex
                                    onClicked: {
                                        root.selectedIndex = tileIndex
                                        root.activateEntry(modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                ListView {
                    id: entryList
                    width: parent.width
                    height: parent.height
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
                        height: root.listRowHeight
                        color: index === entryList.currentIndex || mouseArea.containsMouse ? Theme.panelMantle : "transparent"

                        readonly property string appIconSource: {
                            var _theme = Theme.iconThemeName
                            return root.entryIconSource(modelData)
                        }
                        readonly property string glyphIcon: root.entryGlyphIcon(modelData)

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 20
                            width: parent.width - 16

                            Item {
                                width: root.listIconSize
                                height: root.listIconSize

                                Image {
                                    anchors.fill: parent
                                    visible: entryRow.appIconSource.length > 0
                                    source: entryRow.appIconSource
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
                                text: modelData.name
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.listFontSize
                                font.bold: Theme.fontBold
                                elide: Text.ElideRight
                                width: parent.width - root.listIconSize - 20
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
        hostScreen = resolveHostScreen()
        refreshCommandEntries()
        Qt.callLater(rebuildAppCache)
        Qt.callLater(warmPreviewCache)
    }

    Timer {
        id: iconWarmTimer
        interval: 16
        repeat: true
        running: false
        onTriggered: {
            var n = root.cachedApps.length
            if (root.iconWarmIndex >= n) {
                running = false
                return
            }
            var end = Math.min(n, root.iconWarmIndex + 6)
            for (var i = root.iconWarmIndex; i < end; i++)
                root.entryIconSource(root.cachedApps[i])
            root.iconWarmIndex = end
            if (root.iconWarmIndex >= n)
                running = false
        }
    }
}
