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

    signal activated(var entry)

    readonly property string listScript: Quickshell.env("HOME") + "/.local/bin/evo-menu-list-previews.sh"
    readonly property string fallbackIcon: kind === "wallpapers" ? "󰏘" : "󰸌"
    readonly property int tileIconSize: 22
    readonly property int rowCount: entries.length > 0
        ? Math.ceil(entries.length / Math.max(1, columns))
        : 0
    readonly property int gridWidth: columns * tileWidth + Math.max(0, columns - 1) * spacing
    readonly property int gridHeight: rowCount > 0
        ? rowCount * tileHeight + Math.max(0, rowCount - 1) * spacing
        : 0

    implicitWidth: gridWidth
    implicitHeight: statusText.visible
        ? statusText.implicitHeight
        : gridHeight
    opacity: enabled ? 1 : 0.45

    function reload() {
        if (!enabled || loading) return
        loading = true
        entries = []
        if (kind !== "themes" && kind !== "wallpapers") {
            loading = false
            return
        }
        listProc.running = true
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
        loading = false
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
        command: ["bash", "-lc",
            "test -x " + Util.shellQuote(root.listScript) + " && " +
            Util.shellQuote(root.listScript) + " " + (root.kind === "wallpapers" ? "wallpapers" : "themes")
        ]
        stdout: StdioCollector {
            onStreamFinished: root.parseLines(text)
        }
        onExited: root.loading = false
    }

    Text {
        id: statusText
        visible: loading || entries.length === 0
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: loading ? "Loading…" : "No previews"
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.panelSmallFontPixelSize
        font.bold: Theme.fontBold
        opacity: 0.72
    }

    Flow {
        id: previewFlow
        visible: !statusText.visible
        width: root.gridWidth
        spacing: root.spacing
        flow: Flow.LeftToRight

        Repeater {
            model: root.entries

            Rectangle {
                required property var modelData
                required property int index
                width: root.tileWidth
                height: root.tileHeight
                color: Theme.overlaySurface
                border.color: root.isSelected(modelData)
                    ? Theme.accent
                    : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                border.width: root.isSelected(modelData) ? 2 : 1

                Item {
                    anchors.fill: parent
                    anchors.margins: 4
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
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.enabled
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.runEntry(modelData)
                }
            }
        }
    }
}
