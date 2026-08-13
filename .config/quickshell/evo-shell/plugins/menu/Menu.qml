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
    readonly property int tileWidth: 104
    readonly property int tileHeight: 100
    readonly property int tileSpacing: 10
    readonly property int tileIconSize: 32
    readonly property int appGridColumns: 6
    readonly property int appTileWidth: 96
    readonly property int appTileHeight: 108
    readonly property int appIconSize: 44
    readonly property int appIconTopPadding: 10
    readonly property int appLabelFontSize: Theme.panelSmallFontPixelSize
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
    readonly property int appsMenuPadding: 14
    readonly property int appsMenuRadius: Theme.panelCornerRadius

    readonly property int previewGridColumns: 5
    readonly property int previewColumnCount: gridColumnCount
    readonly property int activeTileWidth: previewTileMode ? previewTileWidth : (appsGridMode ? appTileWidth : tileWidth)
    readonly property int activeTileHeight: previewTileMode ? previewTileHeight : (appsGridMode ? appTileHeight : tileHeight)

    readonly property int gridColumnCount: {
        var n = filteredEntries().length
        if (n <= 0) return 1
        if (tileMode) return n
        if (appsGridMode)
            return Math.max(1, Math.min(n, appGridColumns))
        if (previewTileMode)
            return Math.max(1, Math.min(n, previewGridColumns))
        var maxW = panel.previewAreaMaxWidth
        var cols = Math.floor((maxW + tileSpacing) / (activeTileWidth + tileSpacing))
        return Math.max(1, Math.min(n, cols))
    }

    readonly property int gridRowCount: {
        var n = filteredEntries().length
        if (n <= 0) return 1
        if (tileMode) return 1
        return Math.ceil(n / gridColumnCount)
    }

    readonly property int gridWidth: {
        var cols = gridColumnCount
        if (cols <= 0) return activeTileWidth
        if (appsGridMode)
            return cols * (appTileWidth + tileSpacing)
        return cols * activeTileWidth + (cols - 1) * tileSpacing
    }

    readonly property int gridHeight: {
        var rows = gridRowCount
        if (rows <= 0) return activeTileHeight
        return rows * activeTileHeight + (rows - 1) * tileSpacing
    }

    readonly property int appsGridViewportHeight: Math.max(
        appTileHeight * 3,
        panel.previewAreaMaxHeight - listFilterHeight - previewMenuMargin
    )

    readonly property int previewRowCount: gridRowCount
    readonly property int previewGridWidth: gridWidth
    readonly property int previewGridHeight: gridHeight

    readonly property int tileRowWidth: {
        var n = filteredEntries().length
        if (n <= 0) return tileWidth
        return n * tileWidth + (n - 1) * tileSpacing
    }

    readonly property int previewRowWidth: {
        var n = filteredEntries().length
        if (n <= 0) return previewTileWidth
        return n * previewTileWidth + (n - 1) * tileSpacing
    }

    readonly property int boxRowWidth: previewTileMode ? gridWidth : tileRowWidth
    readonly property int boxRowHeight: previewTileMode ? gridHeight : tileHeight
    readonly property int appsHostWidth: gridWidth + appsMenuPadding * 2
    readonly property int appsHostHeight: listFilterHeight + 16 + Math.min(gridHeight, appsGridViewportHeight) + appsMenuPadding * 2 + 8

    readonly property string home: Quickshell.env("HOME")
    readonly property string placeholderText: {
        if (mode === "runner") return "run: command"
        if (mode === "power") return "Power…"
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
        UsageMemory.reload()
        refreshCommandEntries()
        if (submenu) loadDynamicEntries(submenu)
        else dynamicEntries = []
        hostScreen = resolveHostScreen()
        opened = true
        Qt.callLater(function() {
            root.previewAreaMaxWidth = panel.previewAreaMaxWidth
            root.previewAreaMaxHeight = panel.previewAreaMaxHeight
            if (root.boxTileMode)
                menuHost.forceActiveFocus()
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
        var count = filteredEntries().length
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
        var count = filteredEntries().length
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
        else if (tileMode) moveSelection(-1)
    }

    function handlePreviewRight() {
        if (previewTileMode || appsGridMode) moveGridSelection(1, 0)
        else if (tileMode) moveSelection(1)
    }

    function handlePreviewUp() {
        if (previewTileMode || appsGridMode) moveGridSelection(0, -1)
        else if (framedMode) moveSelection(-1)
    }

    function handlePreviewDown() {
        if (previewTileMode || appsGridMode) moveGridSelection(0, 1)
        else if (framedMode) moveSelection(1)
    }

    function activateSelection() {
        var list = filteredEntries()
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
        if (mode === "runner") {
            var cmd = filterText.trim()
            if (cmd.indexOf("run:") === 0) cmd = cmd.slice(4).trim()
            runCommand(cmd)
            return
        }
        activateSelection()
    }

    onFilterTextChanged: selectedIndex = 0
    onSubmenuChanged: selectedIndex = 0
    onModeChanged: selectedIndex = 0

    function refreshCommandEntries() {
        if (mode === "power") {
            commandEntries = MenuEntries.powerEntries(home)
            return
        }
        if (mode === "apps" || mode === "runner") {
            commandEntries = []
            return
        }
        commandEntries = []
    }

    function entryIconSource(entry) {
        if (!entry) return ""
        if (entry.kind === "app" && entry.entryRef && entry.entryRef.icon)
            return Quickshell.iconPath(String(entry.entryRef.icon), true) || ""
        return ""
    }

    function entryGlyphIcon(entry) {
        if (!entry) return "󰍉"
        if (entry.icon) return entry.icon
        return "󰍉"
    }

    function appEntries() {
        var list = []
        try {
            var values = DesktopEntries.applications.values || []
            for (var i = 0; i < values.length; i++) {
                var entry = values[i]
                if (!entry || !entry.id) continue
                list.push({
                    kind: "app",
                    name: String(entry.name || entry.id),
                    id: entry.id,
                    entryRef: entry
                })
            }
        } catch (e) {
            console.warn("evo.menu app list failed:", e)
        }
        list.sort(function(a, b) {
            var sa = UsageMemory.score("apps", a.id)
            var sb = UsageMemory.score("apps", b.id)
            if (sa !== sb) return sb - sa
            return a.name.localeCompare(b.name)
        })
        return list
    }

    function filteredEntries() {
        var q = filterText.trim()
        if (mode === "runner") return []
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
            for (var i = 0; i < apps.length; i++) {
                var app = apps[i]
                if (!q) out.push(app)
                else if (app.name.toLowerCase().indexOf(q.toLowerCase()) !== -1 || app.id.toLowerCase().indexOf(q.toLowerCase()) !== -1)
                    out.push(app)
            }
            return UsageMemory.sortByUsage(out, "apps", function(e) { return e.id }, function(e) { return e.name })
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

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.opened && root.hostScreen && modelData && modelData.name !== root.hostScreen.name
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            WlrLayershell.namespace: "evo-menu"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            Rectangle {
                anchors.fill: parent
                color: Theme.overlayScrim
            }
        }
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
                visible: root.appsGridMode
                color: Theme.overlaySurfaceInactive
                radius: root.appsMenuRadius
                border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.22)
                border.width: 1
            }

            Rectangle {
                anchors.fill: parent
                visible: root.framedMode
                color: Theme.overlaySurface
                border.color: Theme.accent
                border.width: 1
            }

            Column {
                anchors.fill: parent
                anchors.margins: root.boxTileMode ? 0 : (root.appsGridMode ? root.appsMenuPadding : 16)
                spacing: root.appsGridMode ? 10 : 12

                Item {
                    width: root.appsGridMode ? root.gridWidth : parent.width
                    anchors.horizontalCenter: root.appsGridMode ? parent.horizontalCenter : undefined
                    height: root.listFilterHeight
                    visible: root.framedMode || root.appsGridMode

                    Rectangle {
                        anchors.fill: parent
                        radius: root.appsGridMode ? root.appsMenuRadius : 0
                        color: root.appsGridMode ? Theme.panelMantle : Theme.overlaySurface
                        border.color: root.appsGridMode
                            ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.18)
                            : "transparent"
                        border.width: root.appsGridMode ? 1 : 0
                    }

                    Text {
                        visible: root.appsGridMode
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰍉"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.panelIconFontPixelSize
                        font.bold: Theme.fontBold
                        opacity: 0.85
                    }

                    Text {
                        visible: filterField.text.length === 0 && !filterField.activeFocus
                        anchors.left: parent.left
                        anchors.leftMargin: root.appsGridMode ? 36 : 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.placeholderText
                        color: Theme.foreground
                        opacity: 0.45
                        font.family: Theme.fontFamily
                        font.pixelSize: root.listFilterFontSize
                        font.bold: Theme.fontBold
                    }

                    Text {
                        visible: root.appsGridMode && root.filteredEntries().length > 0
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(root.filteredEntries().length)
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.panelHintFontPixelSize
                        font.bold: Theme.fontBold
                        opacity: 0.5
                    }

                    TextInput {
                        id: filterField
                        anchors.fill: parent
                        anchors.leftMargin: root.appsGridMode ? 36 : 12
                        anchors.rightMargin: root.appsGridMode ? 40 : 12
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
                        model: root.filteredEntries()

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
                    visible: root.appsGridMode && !root.dynamicLoading && root.filteredEntries().length === 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: filterField.text.trim() === "" ? "No applications" : "No matches"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.panelSmallFontPixelSize
                    font.bold: Theme.fontBold
                    opacity: 0.55
                }

                GridView {
                    id: appGrid
                    visible: root.appsGridMode && root.filteredEntries().length > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.gridWidth
                    height: parent.height - root.listFilterHeight - (root.appsGridMode ? 26 : 12)
                    clip: true
                    cellWidth: root.appTileWidth + root.tileSpacing
                    cellHeight: root.appTileHeight + root.tileSpacing
                    model: root.filteredEntries()
                    currentIndex: root.selectedIndex

                    onCountChanged: if (root.selectedIndex >= count) root.selectedIndex = Math.max(0, count - 1)

                    delegate: Rectangle {
                        id: appTile
                        required property var modelData
                        required property int index
                        width: root.appTileWidth
                        height: root.appTileHeight
                        radius: root.appsMenuRadius
                        color: index === root.selectedIndex || appMouse.containsMouse
                            ? Theme.panelMantle
                            : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.04)
                        border.color: index === root.selectedIndex
                            ? Theme.accent
                            : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.12)
                        border.width: 1
                        opacity: appMouse.containsMouse || index === root.selectedIndex ? 1 : 0.88

                        readonly property string appIconSource: root.entryIconSource(modelData)
                        readonly property string glyphIcon: root.entryGlyphIcon(modelData)

                        Column {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            anchors.bottomMargin: 8
                            anchors.topMargin: root.appIconTopPadding
                            spacing: 6

                            Item {
                                width: parent.width
                                height: root.appIconSize
                                anchors.horizontalCenter: parent.horizontalCenter

                                Image {
                                    anchors.centerIn: parent
                                    width: root.appIconSize
                                    height: root.appIconSize
                                    visible: appTile.appIconSource.length > 0
                                    source: appTile.appIconSource
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    asynchronous: true
                                    cache: true
                                    sourceSize: Qt.size(root.appIconSize * 2, root.appIconSize * 2)
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: appTile.appIconSource.length === 0
                                    text: appTile.glyphIcon
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.appIconSize * 0.5
                                    font.bold: Theme.fontBold
                                }
                            }

                            Text {
                                text: modelData.name
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.appLabelFontSize
                                font.bold: Theme.fontBold
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                opacity: appMouse.containsMouse || index === root.selectedIndex ? 1 : 0.78
                            }
                        }

                        MouseArea {
                            id: appMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedIndex = index
                                root.activateEntry(modelData)
                            }
                        }
                    }
                }

                Row {
                    id: tileRow
                    visible: root.tileMode
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: root.tileSpacing
                    height: root.tileHeight

                    Repeater {
                        model: root.filteredEntries()

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
                                spacing: 8
                                width: parent.width - 12

                                Text {
                                    text: modelData.icon || "󰍉"
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.tileIconSize
                                    font.bold: Theme.fontBold
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Text {
                                    text: modelData.name
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: Theme.fontBold
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: tileMouse
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

                ListView {
                    id: entryList
                    width: parent.width
                    height: parent.height - (root.mode === "runner" ? root.listFilterHeight + 12 : 0)
                    clip: true
                    visible: root.framedMode
                    model: root.filteredEntries()
                    currentIndex: root.selectedIndex

                    onCountChanged: if (root.selectedIndex >= count) root.selectedIndex = Math.max(0, count - 1)

                    delegate: Rectangle {
                        id: entryRow
                        required property var modelData
                        required property int index
                        width: entryList.width
                        height: root.listRowHeight
                        color: index === entryList.currentIndex || mouseArea.containsMouse ? Theme.panelMantle : "transparent"

                        readonly property string appIconSource: root.entryIconSource(modelData)
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
        refreshCommandEntries()
        Qt.callLater(warmPreviewCache)
    }
}
