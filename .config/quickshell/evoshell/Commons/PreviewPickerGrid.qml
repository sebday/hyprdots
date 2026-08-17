import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    property string kind: "themes"
    property string selectedKey: ""
    property int tileWidth: 96
    property int tileHeight: 62
    property int columns: 3
    property int spacing: 8
    property bool enabled: true
    property real previewDpr: 2

    property var entries: []
    property bool loading: false
    property bool pendingReload: false
    property int cursorIndex: 0
    property bool keyboardFocus: false

    signal activated(var entry)
    signal focused()

    readonly property string listScript: Quickshell.env("HOME") + "/.local/bin/evo-menu-list"
    readonly property string fallbackIcon: kind === "wallpapers" ? "󰏘" : "󰸌"
    readonly property int tileIconSize: 22
    readonly property int rowCount: entries.length > 0
        ? Math.ceil(entries.length / Math.max(1, columns))
        : 0
    readonly property int gridWidth: columns * tileWidth + Math.max(0, columns - 1) * spacing
    readonly property int gridHeight: rowCount > 0
        ? rowCount * tileHeight + Math.max(0, rowCount - 1) * spacing
        : 0

    readonly property int tileInset: 0
    implicitWidth: gridWidth
    implicitHeight: statusText.visible
        ? statusText.implicitHeight
        : gridHeight
    opacity: enabled ? 1 : 0.45

    function reload() {
        if (!enabled) return
        if (loading) {
            pendingReload = true
            return
        }
        pendingReload = false
        loading = true
        if (kind !== "themes" && kind !== "wallpapers") {
            loading = false
            return
        }
        listProc.running = true
    }

    function finishReload() {
        loading = false
        if (!pendingReload)
            return
        pendingReload = false
        Qt.callLater(reload)
    }

    function parseLines(raw) {
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
        entries = out
        syncCursorToSelected()
        finishReload()
    }

    function indexOfSelected() {
        for (var i = 0; i < entries.length; i++) {
            if (isSelected(entries[i]))
                return i
        }
        return -1
    }

    function syncCursorToSelected() {
        var idx = indexOfSelected()
        if (idx >= 0)
            cursorIndex = idx
        else if (cursorIndex >= entries.length)
            cursorIndex = Math.max(0, entries.length - 1)
    }

    function moveCursor(dx, dy) {
        var n = entries.length
        if (n <= 0) return false
        var cols = Math.max(1, columns)
        var rows = Math.ceil(n / cols)
        var idx = Math.max(0, Math.min(cursorIndex, n - 1))
        var row = Math.floor(idx / cols)
        var col = idx % cols

        if (dx !== 0) {
            var next = idx + dx
            if (next < 0 || next >= n)
                return false
            cursorIndex = next
            focused()
            return true
        }

        if (dy === 0) return false
        var targetRow = row + dy
        if (targetRow < 0 || targetRow >= rows)
            return false
        var targetIdx = targetRow * cols + col
        if (targetIdx >= n) targetIdx = n - 1
        cursorIndex = targetIdx
        focused()
        return true
    }

    function activateCursor() {
        if (cursorIndex < 0 || cursorIndex >= entries.length)
            return
        runEntry(entries[cursorIndex])
    }

    function cursorRowY() {
        var cols = Math.max(1, columns)
        var row = Math.floor(Math.max(0, cursorIndex) / cols)
        return row * (tileHeight + spacing)
    }

    function isSelected(entry) {
        if (!entry || !selectedKey) return false
        var key = String(selectedKey).trim()
        if (!key) return false
        if (kind === "themes")
            return String(entry.name) === key
        if (entry.preview && key === String(entry.preview))
            return true
        var cmd = String(entry.command || "")
        if (cmd.indexOf(key) >= 0)
            return true
        var name = String(entry.name || "")
        return key.endsWith("/" + name) || key === name
    }

    function runEntry(entry) {
        if (!enabled || !entry) return
        var command = String(entry.command || "").trim()
        if (!command) return
        Quickshell.execDetached(["bash", "-lc", command])
        activated(entry)
    }

    Component.onCompleted: reload()

    Process {
        id: listProc
        command: [root.listScript, root.kind === "wallpapers" ? "wallpapers" : "themes"]
        stdout: StdioCollector {
            onStreamFinished: root.parseLines(text)
        }
        onExited: root.finishReload()
    }

    Text {
        id: statusText
        visible: root.entries.length === 0
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: loading ? "Loading…" : "No previews"
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeS
        font.bold: Theme.fontBold
        opacity: 0.72
    }

    Flow {
        id: previewFlow
        visible: !statusText.visible
        x: root.tileInset
        y: root.tileInset
        width: root.gridWidth
        spacing: root.spacing
        flow: Flow.LeftToRight

        Repeater {
            model: root.entries

            Item {
                required property var modelData
                required property int index
                width: root.tileWidth
                height: root.tileHeight
                clip: true

                Image {
                    id: previewImage
                    anchors.fill: parent
                    source: Util.fileUrl(modelData.preview)
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                    cache: true
                    mipmap: true
                    sourceSize: Qt.size(
                        Math.ceil(root.tileWidth * root.previewDpr),
                        Math.ceil(root.tileHeight * root.previewDpr)
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
                    text: root.fallbackIcon
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: root.tileIconSize
                    font.bold: Theme.fontBold
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: Theme.accent
                    border.width: 2
                    visible: (root.keyboardFocus && index === root.cursorIndex) || root.isSelected(modelData)
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.enabled
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        root.cursorIndex = index
                        root.focused()
                    }
                    onClicked: {
                        root.cursorIndex = index
                        root.runEntry(modelData)
                    }
                }
            }
        }
    }
}
