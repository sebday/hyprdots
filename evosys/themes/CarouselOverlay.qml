import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../../commons"

Item {
    id: root

    property var shell: null
    property bool opened: false
    property string pluginId: "evo.sys.themes"
    property string kind: "themes"
    property string layerNamespace: "evo-sys-themes"

    readonly property string pickerOutput: {
        if (shell && shell.shellConfig && shell.shellConfig.notifications
                && shell.shellConfig.notifications.output)
            return String(shell.shellConfig.notifications.output).trim()
        if (shell && shell.shellConfig && shell.shellConfig.bar
                && shell.shellConfig.bar.output)
            return String(shell.shellConfig.bar.output).trim()
        var screens = Quickshell.screens
        if (screens && screens.length > 0 && screens[0])
            return String(screens[0].name)
        return ""
    }

    readonly property var hostScreen: {
        var screens = Quickshell.screens
        if (!screens || screens.length === 0)
            return null
        var wanted = pickerOutput
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i]
            if (s && String(s.name) === wanted)
                return s
        }
        return screens[0]
    }

    readonly property var otherScreens: {
        if (!opened)
            return []
        var screens = Quickshell.screens
        if (!screens || screens.length === 0)
            return []
        var hostName = hostScreen ? String(hostScreen.name) : ""
        var out = []
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i]
            if (!s || (hostName && String(s.name) === hostName))
                continue
            out.push(s)
        }
        return out
    }

    readonly property bool isWallpaper: kind === "wallpapers"
    readonly property string listScript: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-menu-list")
    readonly property string themeNamePath: Quickshell.env("HOME") + "/.themes/current/.theme-name"
    readonly property string wallpaperStatePath: Util.statePath(Quickshell.env("HOME"), "wallpaper")
    readonly property string warmScript: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-menu-warm")
    readonly property string emptyLabel: isWallpaper ? "No wallpapers" : "No themes"
    readonly property real previewDpr: 1.5
    readonly property int decodeWidth: Math.ceil(expandedWidth * previewDpr)
    readonly property int decodeHeight: Math.ceil(expandedHeight * previewDpr)

    property var entries: []
    property bool loading: false
    property bool pendingListReload: false
    property bool pendingListSilent: false
    property bool layoutReady: false
    property bool selectionTouched: false
    property string currentThemeName: ""
    property string currentWallpaperPath: ""
    property int selectedIndex: 0

    readonly property int expandedWidth: 768
    readonly property int expandedHeight: 475
    readonly property int sliceWidth: 108
    readonly property int sliceHeight: 432
    readonly property int sliceSpacing: -30
    readonly property int skewOffset: 28
    readonly property int bottomChromeHeight: 72
    readonly property color dimColor: Theme.background
    readonly property color selectedBorder: Theme.accent
    readonly property color unselectedBorder: Theme.inactiveBorder

    function open(payloadJson) {
        opened = true
        layoutReady = false
        selectionTouched = false
        if (isWallpaper)
            wallpaperStateFile.reload()
        else
            themeNameFile.reload()
        if (entries.length === 0) {
            warmPreviewCache()
            reloadEntries()
        } else {
            syncSelectedIndex()
            backdrop.show(previewAt(selectedIndex), true)
        }
        revealWhenReady()
    }

    function warmPreviewCache() {
        if (warmProc.running)
            return
        warmProc.running = true
    }

    function close() {
        opened = false
        layoutReady = false
        selectionTouched = false
    }

    function dismiss() {
        if (shell)
            shell.hide(pluginId)
        else
            close()
    }

    function revealWhenReady() {
        Qt.callLater(function() {
            if (root.opened && root.hostScreen && !root.loading && root.entries.length > 0) {
                root.layoutReady = true
                carousel.forceActiveFocus()
            }
        })
    }

    function reloadEntries(silent) {
        if (listProc.running) {
            pendingListReload = true
            pendingListSilent = pendingListSilent && !!silent
            return
        }
        pendingListReload = false
        pendingListSilent = !!silent
        if (!silent)
            loading = true
        listProc.running = true
    }

    function parseLines(raw) {
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
        var silent = pendingListSilent
        pendingListSilent = false
        entries = out
        loading = false
        if (!silent)
            syncSelectedIndex()
        if (opened)
            backdrop.show(previewAt(selectedIndex), true)
        revealWhenReady()
    }

    function activeKey() {
        if (isWallpaper)
            return String(currentWallpaperPath || "").trim()
        return String(currentThemeName || "").trim()
    }

    function entryKey(entry) {
        if (!entry)
            return ""
        if (isWallpaper) {
            var cmd = String(entry.command || "")
            var marker = "evo-wallpaper set "
            var pos = cmd.indexOf(marker)
            if (pos >= 0) {
                var tail = cmd.slice(pos + marker.length).trim()
                if (tail.length >= 2 && tail.charAt(0) === "'" && tail.charAt(tail.length - 1) === "'")
                    tail = tail.slice(1, -1)
                return tail
            }
            return String(entry.name || "")
        }
        return String(entry.name || "")
    }

    function isSelected(entry) {
        var key = activeKey()
        if (!key || !entry)
            return false
        var entryKeyValue = entryKey(entry)
        if (!entryKeyValue)
            return false
        if (isWallpaper)
            return key === entryKeyValue || key.endsWith("/" + entry.name)
        return key === entryKeyValue
    }

    function indexOfSelected() {
        for (var i = 0; i < entries.length; i++) {
            if (isSelected(entries[i]))
                return i
        }
        return -1
    }

    function syncSelectedIndex() {
        if (selectionTouched)
            return
        var idx = indexOfSelected()
        if (idx >= 0)
            selectedIndex = idx
        else if (selectedIndex >= entries.length)
            selectedIndex = Math.max(0, entries.length - 1)
    }

    function select(index) {
        if (entries.length === 0)
            return
        if (index < 0)
            index = 0
        else if (index >= entries.length)
            index = entries.length - 1
        if (index === selectedIndex)
            return
        selectionTouched = true
        selectedIndex = index
        backdrop.show(previewAt(index), false)
    }

    function selectAdjacent(direction) {
        var count = entries.length
        if (count === 0)
            return
        select((selectedIndex + direction + count) % count)
    }

    function handleWheel(wheel) {
        if (!opened || !layoutReady || entries.length === 0)
            return
        var delta = wheel.angleDelta.y
        if (delta === 0)
            delta = wheel.pixelDelta.y
        if (delta === 0)
            delta = wheel.angleDelta.x
        if (delta === 0)
            delta = wheel.pixelDelta.x
        if (delta === 0)
            return
        selectAdjacent(delta < 0 ? 1 : -1)
        wheel.accepted = true
    }

    function previewAt(index) {
        if (index < 0 || index >= entries.length)
            return ""
        var entry = entries[index]
        return entry ? String(entry.preview || "") : ""
    }

    function currentEntry() {
        if (selectedIndex < 0 || selectedIndex >= entries.length)
            return null
        return entries[selectedIndex]
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
        onLoaded: {
            root.currentThemeName = String(themeNameFile.text() || "").trim()
            if (root.opened && !root.selectionTouched)
                root.syncSelectedIndex()
        }
    }

    FileView {
        id: wallpaperStateFile
        path: root.wallpaperStatePath
        watchChanges: true
        printErrors: false
        onLoaded: {
            root.currentWallpaperPath = String(wallpaperStateFile.text() || "").trim()
            if (root.opened && !root.selectionTouched)
                root.syncSelectedIndex()
        }
    }

    Process {
        id: warmProc
        command: ["bash", "-lc", "test -x " + Util.shellQuote(root.warmScript) + " && " + Util.shellQuote(root.warmScript)]
        onExited: {
            if (root.opened && root.entries.length === 0)
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

    Variants {
        model: root.otherScreens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.opened
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            WlrLayershell.namespace: root.layerNamespace + "-scrim"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            Rectangle {
                anchors.fill: parent
                color: Theme.withOpacity(root.dimColor, 0.72)
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.dismiss()
            }
        }
    }

    PanelWindow {
        screen: root.hostScreen
        visible: root.opened && root.hostScreen
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.namespace: root.layerNamespace
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.opened && root.layoutReady ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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

            Image {
                id: baseImage
                anchors.fill: parent
                source: backdrop.basePath ? Util.fileUrl(backdrop.basePath) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                mipmap: true
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
                mipmap: true
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
                color: root.dimColor
                opacity: Theme.opacityMuted
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.opened
            onClicked: root.dismiss()
            onWheel: function(wheel) { root.handleWheel(wheel) }
        }

        Text {
            anchors.centerIn: parent
            visible: root.opened && root.loading
            text: "Loading…"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeL
            font.bold: Theme.fontBold
            opacity: Theme.opacitySecondary
        }

        Text {
            anchors.centerIn: parent
            visible: root.opened && !root.loading && root.entries.length === 0
            text: root.emptyLabel
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeL
            font.bold: Theme.fontBold
            opacity: Theme.opacitySecondary
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
                onWheel: function(wheel) { root.handleWheel(wheel) }
            }

            Item {
                id: carousel
                anchors.top: parent.top
                anchors.topMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.bottomChromeHeight
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.expandedWidth + 13 * (root.sliceWidth + root.sliceSpacing)
                focus: true

                readonly property real itemStep: root.sliceWidth + root.sliceSpacing
                readonly property real previewX: (width - root.expandedWidth) / 2

                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                        root.dismiss()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.applySelected()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Left) {
                        root.selectAdjacent(-1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Right) {
                        root.selectAdjacent(1)
                        event.accepted = true
                    }
                }

                Component.onCompleted: forceActiveFocus()

                MouseArea {
                    anchors.fill: parent
                    z: 500
                    acceptedButtons: Qt.NoButton
                    onWheel: function(wheel) { root.handleWheel(wheel) }
                }

                Repeater {
                    model: root.entries.length

                    delegate: Item {
                        id: item
                        required property int index

                        readonly property var entry: root.entries[index]
                        readonly property int relativeIndex: index - root.selectedIndex
                        readonly property bool selected: index === root.selectedIndex
                        readonly property bool nearby: Math.abs(relativeIndex) <= 16
                        readonly property string imageSource: root.previewAt(index)
                        readonly property bool showImage: nearby || Math.abs(relativeIndex) <= 2

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

                        Behavior on x { NumberAnimation { duration: Theme.motionSlow; easing.type: Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: Theme.motionSlow; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: Theme.motionSlow; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: Theme.motionSlow; easing.type: Easing.OutCubic } }

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
                                source: item.showImage && imageSource ? Util.fileUrl(imageSource) : ""
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
                            onWheel: function(wheel) { root.handleWheel(wheel) }
                        }
                    }
                }
            }

            Column {
                anchors.top: carousel.bottom
                anchors.topMargin: 16
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingS
                width: Math.min(parent.width - 32, root.expandedWidth)

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    visible: !root.isWallpaper && root.entries.length > 0
                    text: {
                        var entry = root.currentEntry()
                        return entry ? String(entry.name || "") : ""
                    }
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeM
                    font.bold: Theme.fontBold
                    elide: Text.ElideMiddle
                    maximumLineCount: 1
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingM
                    visible: root.entries.length > 0 && root.entries.length <= 21

                    Repeater {
                        model: root.entries.length
                        delegate: Rectangle {
                            required property int index
                            width: index === root.selectedIndex ? 18 : 6
                            height: 6
                            radius: Theme.radiusM
                            color: index === root.selectedIndex ? Theme.accent : Theme.withOpacity(Theme.foreground, 0.35)
                            Behavior on width { NumberAnimation { duration: Theme.motionNormal; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.entries.length > 21
                    text: (root.selectedIndex + 1) + " / " + root.entries.length
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    font.bold: Theme.fontBold
                    opacity: 0.8
                }
            }
        }
    }
}
