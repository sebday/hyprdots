import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../../Commons"

Item {
    id: root

    property var shell: null
    property bool opened: false
    property string pluginId: "evo.theme"
    property string kind: "themes"
    property string layerNamespace: "evo-theme"

    readonly property bool isWallpaper: kind === "wallpapers"
    readonly property string listScript: Quickshell.env("HOME") + "/.local/bin/evo-menu-list"
    readonly property string themeNamePath: Quickshell.env("HOME") + "/.themes/current/.theme-name"
    readonly property string wallpaperStatePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/evoshell/wallpaper"
    readonly property string warmScript: Quickshell.env("HOME") + "/.local/bin/evo-menu-warm"
    readonly property string emptyLabel: isWallpaper ? "No wallpapers" : "No themes"
    readonly property real previewDpr: 1.5
    readonly property int decodeWidth: Math.ceil(expandedWidth * previewDpr)
    readonly property int decodeHeight: Math.ceil(expandedHeight * previewDpr)

    property var entries: []
    property bool loading: false
    property bool pendingListReload: false
    property bool layoutReady: false
    property string currentThemeName: ""
    property string currentWallpaperPath: ""
    property int selectedIndex: 0

    readonly property int expandedWidth: 768
    readonly property int expandedHeight: 475
    readonly property int sliceWidth: 108
    readonly property int sliceHeight: 432
    readonly property int sliceSpacing: -30
    readonly property int skewOffset: 28
    readonly property int bottomChromeHeight: 44
    readonly property color dimColor: Theme.background
    readonly property color selectedBorder: Theme.accent
    readonly property color unselectedBorder: Theme.inactiveBorder

    function open(payloadJson) {
        opened = true
        layoutReady = false
        warmPreviewCache()
        if (isWallpaper)
            wallpaperStateFile.reload()
        else
            themeNameFile.reload()
        if (entries.length === 0)
            reloadEntries()
        else
            syncSelectedIndex()
        revealWhenReady()
    }

    function warmPreviewCache() {
        if (warmProc.running) return
        warmProc.running = true
    }

    function close() {
        opened = false
        layoutReady = false
    }

    function dismiss() {
        if (shell)
            shell.hide(pluginId)
        else
            close()
    }

    function revealWhenReady() {
        Qt.callLater(function() {
            if (root.opened && !root.loading && root.entries.length > 0) {
                root.layoutReady = true
                carousel.forceActiveFocus()
            }
        })
    }

    function reloadEntries(silent) {
        if (listProc.running) {
            pendingListReload = true
            return
        }
        pendingListReload = false
        if (!silent)
            loading = true
        listProc.running = true
    }

    function parseLines(raw) {
        var lines = String(raw || "").split("\n")
        var out = []
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line) continue
            var parts = line.split("\t")
            out.push({
                name: parts[0] || "",
                command: parts[1] || "",
                preview: parts[2] || ""
            })
        }
        entries = out
        syncSelectedIndex()
        loading = false
        revealWhenReady()
    }

    function isSelected(entry) {
        if (!entry) return false
        if (isWallpaper) {
            var key = String(currentWallpaperPath || "").trim()
            if (!key) return false
            if (entry.preview && key === String(entry.preview))
                return true
            var cmd = String(entry.command || "")
            if (cmd.indexOf(key) >= 0)
                return true
            var name = String(entry.name || "")
            return key.endsWith("/" + name) || key === name
        }
        var theme = String(currentThemeName || "").trim()
        return theme && String(entry.name) === theme
    }

    function indexOfSelected() {
        for (var i = 0; i < entries.length; i++) {
            if (isSelected(entries[i]))
                return i
        }
        return -1
    }

    function syncSelectedIndex() {
        var idx = indexOfSelected()
        if (idx >= 0)
            selectedIndex = idx
        else if (selectedIndex >= entries.length)
            selectedIndex = Math.max(0, entries.length - 1)
    }

    function select(index) {
        if (entries.length === 0) return
        if (index < 0) index = 0
        else if (index >= entries.length) index = entries.length - 1
        if (index === selectedIndex) return
        selectedIndex = index
    }

    function selectAdjacent(direction) {
        var count = entries.length
        if (count === 0) return
        select((selectedIndex + direction + count) % count)
    }

    function currentEntry() {
        if (selectedIndex < 0 || selectedIndex >= entries.length)
            return null
        return entries[selectedIndex]
    }

    function entryPreview(entry) {
        return entry ? String(entry.preview || "") : ""
    }

    function currentPreview() {
        return entryPreview(currentEntry())
    }

    function applySelected() {
        var entry = currentEntry()
        if (!entry) {
            dismiss()
            return
        }
        var command = String(entry.command || "").trim()
        if (!command) {
            dismiss()
            return
        }
        Quickshell.execDetached(["bash", "-lc", command])
        dismiss()
    }

    FileView {
        id: themeNameFile
        path: root.themeNamePath
        watchChanges: true
        printErrors: false
        onLoaded: root.currentThemeName = String(themeNameFile.text() || "").trim()
        onFileChanged: reload()
    }

    FileView {
        id: wallpaperStateFile
        path: root.wallpaperStatePath
        watchChanges: true
        printErrors: false
        onLoaded: root.currentWallpaperPath = String(wallpaperStateFile.text() || "").trim()
        onFileChanged: reload()
    }

    Process {
        id: warmProc
        command: ["bash", "-lc", "test -x " + Util.shellQuote(root.warmScript) + " && " + Util.shellQuote(root.warmScript)]
        onExited: {
            if (root.opened)
                root.reloadEntries(true)
        }
    }

    Process {
        id: listProc
        command: [root.listScript, root.isWallpaper ? "wallpapers" : "themes"]
        stdout: StdioCollector {
            onStreamFinished: root.parseLines(text)
        }
        onExited: {
            root.loading = false
            if (root.pendingListReload)
                root.reloadEntries(true)
        }
    }

    PanelWindow {
        visible: root.opened
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.namespace: root.layerNamespace
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.opened && root.layoutReady ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        Item {
            id: backdrop
            anchors.fill: parent
            visible: root.opened

            Image {
                id: backdropImage
                anchors.fill: parent
                source: Util.fileUrl(root.currentPreview())
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                mipmap: true
                visible: status === Image.Ready
            }

            layer.enabled: backdropImage.visible
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 48
                blur: 0.9
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: root.opened
            color: Theme.overlayScrim
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.opened
            onClicked: root.dismiss()
        }

        Text {
            anchors.centerIn: parent
            visible: root.opened && root.loading
            text: "Loading…"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelTitleFontPixelSize
            font.bold: Theme.fontBold
            opacity: 0.72
        }

        Text {
            anchors.centerIn: parent
            visible: root.opened && !root.loading && root.entries.length === 0
            text: root.emptyLabel
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelTitleFontPixelSize
            font.bold: Theme.fontBold
            opacity: 0.72
        }

        Item {
            id: card
            visible: root.opened && root.layoutReady && root.entries.length > 0
            width: Math.min(parent.width - 80, root.expandedWidth + 13 * (root.sliceWidth + root.sliceSpacing) + 40)
            height: root.expandedHeight + 24 + root.bottomChromeHeight
            anchors.centerIn: parent

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            Item {
                id: carousel
                anchors.top: parent.top
                anchors.topMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.bottomChromeHeight
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.expandedWidth + 13 * (root.sliceWidth + root.sliceSpacing)
                clip: false
                focus: true

                readonly property real itemStep: root.sliceWidth + root.sliceSpacing
                readonly property real previewX: (width - root.expandedWidth) / 2

                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                        root.dismiss()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.applySelected()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab
                               || (event.key === Qt.Key_Tab && event.modifiers & Qt.ShiftModifier)) {
                        root.selectAdjacent(-1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                        root.selectAdjacent(1)
                        event.accepted = true
                    }
                }

                Component.onCompleted: forceActiveFocus()

                Repeater {
                    model: root.entries.length

                    delegate: Item {
                        id: item
                        required property int index

                        readonly property var entry: root.entries[index]
                        readonly property int relativeIndex: index - root.selectedIndex
                        readonly property bool selected: index === root.selectedIndex
                        readonly property bool nearby: Math.abs(relativeIndex) <= 16
                        readonly property bool preload: Math.abs(relativeIndex) <= 2
                        readonly property string imageSource: root.entryPreview(entry)
                        property bool sourceActivated: nearby || preload

                        onNearbyChanged: if (nearby) sourceActivated = true
                        onPreloadChanged: if (preload) sourceActivated = true

                        visible: nearby
                        z: selected ? 100 : 50 - Math.min(Math.abs(relativeIndex), 40)
                        width: selected ? root.expandedWidth : root.sliceWidth
                        height: selected ? root.expandedHeight : root.sliceHeight
                        y: selected ? 0 : (root.expandedHeight - root.sliceHeight) / 2
                        x: selected
                            ? carousel.previewX
                            : (relativeIndex < 0
                                ? carousel.previewX + relativeIndex * carousel.itemStep
                                : carousel.previewX + root.expandedWidth + root.sliceSpacing + (relativeIndex - 1) * carousel.itemStep)

                        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                        readonly property real skAbs: Math.abs(root.skewOffset)
                        readonly property real topLeft: root.skewOffset >= 0 ? skAbs : 0
                        readonly property real topRight: root.skewOffset >= 0 ? width : width - skAbs
                        readonly property real bottomRight: root.skewOffset >= 0 ? width - skAbs : width
                        readonly property real bottomLeft: root.skewOffset >= 0 ? 0 : skAbs

                        Item {
                            id: maskShape
                            anchors.fill: parent
                            visible: false
                            layer.enabled: true

                            Shape {
                                anchors.fill: parent
                                antialiasing: true
                                preferredRendererType: Shape.CurveRenderer
                                ShapePath {
                                    fillColor: "white"
                                    strokeColor: "transparent"
                                    startX: item.topLeft; startY: 0
                                    PathLine { x: item.topRight; y: 0 }
                                    PathLine { x: item.bottomRight; y: item.height }
                                    PathLine { x: item.bottomLeft; y: item.height }
                                    PathLine { x: item.topLeft; y: 0 }
                                }
                            }
                        }

                        Item {
                            anchors.fill: parent
                            layer.enabled: true
                            layer.smooth: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: maskShape
                                maskThresholdMin: 0.3
                                maskSpreadAtMin: 0.3
                            }

                            Image {
                                anchors.fill: parent
                                source: item.sourceActivated && imageSource ? Util.fileUrl(imageSource) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: !item.selected
                                cache: true
                                smooth: true
                                mipmap: true
                                sourceSize: Qt.size(root.decodeWidth, root.decodeHeight)
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.withOpacity(root.dimColor, item.selected ? 0 : 0.42)
                            }
                        }

                        Shape {
                            anchors.fill: parent
                            antialiasing: true
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: item.selected ? root.selectedBorder : root.unselectedBorder
                                strokeWidth: item.selected ? 3 : 1
                                startX: item.topLeft; startY: 0
                                PathLine { x: item.topRight; y: 0 }
                                PathLine { x: item.bottomRight; y: item.height }
                                PathLine { x: item.bottomLeft; y: item.height }
                                PathLine { x: item.topLeft; y: 0 }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: item.selected ? root.applySelected() : root.select(index)
                        }
                    }
                }
            }

            Row {
                id: pager
                anchors.top: carousel.bottom
                anchors.topMargin: 18
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                visible: root.entries.length > 0 && root.entries.length <= 21

                Repeater {
                    model: root.entries.length
                    delegate: Rectangle {
                        required property int index
                        width: index === root.selectedIndex ? 18 : 6
                        height: 6
                        radius: 3
                        color: index === root.selectedIndex ? Theme.accent : Theme.withOpacity(Theme.foreground, 0.35)
                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }
                }
            }

            Text {
                anchors.top: carousel.bottom
                anchors.topMargin: 18
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.entries.length > 21
                text: (root.selectedIndex + 1) + " / " + root.entries.length
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.panelSmallFontPixelSize
                font.bold: Theme.fontBold
                opacity: 0.8
            }
        }
    }
}
