import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../../Commons"

Item {
    id: root

    property var host: null
    property var shell: null

    property var entries: []
    property int selectedIndex: 0
    property int previewTick: 0

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/evo-clipboard.sh"
    readonly property string previewDir: Quickshell.env("HOME") + "/.local/state/evo-shell/clipboard-previews"
    readonly property int listLimit: 30
    readonly property int historyFontSize: 13
    readonly property bool active: host && host.opened && host.activeModule === "clipboard"

    readonly property var selectedEntry: {
        if (selectedIndex < 0 || selectedIndex >= entries.length)
            return null
        return entries[selectedIndex]
    }

    function refresh() {
        if (!listProc.running) listProc.running = true
    }

    function parseImageMeta(text) {
        var m = String(text || "").match(/\[\[\s*binary data\s+[^\]]*\s+(png|jpe?g)\s+(\d+)x(\d+)\s*\]\]/i)
        if (!m) return null
        return {
            format: String(m[1]).toLowerCase(),
            width: parseInt(m[2], 10),
            height: parseInt(m[3], 10)
        }
    }

    function parseList(raw) {
        var out = []
        var lines = String(raw || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (!line.trim()) continue
            var tab = line.indexOf("\t")
            if (tab < 1) continue
            var id = line.substring(0, tab)
            if (!/^[0-9]+$/.test(id)) continue
            var text = line.substring(tab + 1)
            var image = parseImageMeta(text)
            out.push({
                id: id,
                text: text,
                image: image,
                label: image ? ("image " + image.width + "×" + image.height) : text
            })
        }
        return out
    }

    function previewExtension(image) {
        if (!image) return ""
        var fmt = String(image.format || "")
        if (fmt === "jpeg" || fmt === "jpg") return "jpg"
        if (fmt === "png") return "png"
        return ""
    }

    function previewPathFor(entry) {
        if (!entry || !entry.image) return ""
        var ext = previewExtension(entry.image)
        if (!ext) return ""
        return previewDir + "/" + entry.id + "." + ext
    }

    function previewUrlFor(entry) {
        var path = previewPathFor(entry)
        if (!path) return ""
        return Util.fileUrl(path) + "?t=" + previewTick
    }

    function copyId(id) {
        Quickshell.execDetached(["bash", root.script, "copy", String(id)])
        if (host) host.dismiss()
    }

    function cachePreviews() {
        if (!cacheProc.running) cacheProc.running = true
    }

    function clearHistory() {
        if (entries.length === 0 || clearProc.running) return
        clearProc.running = true
    }

    function onActivated() {
        selectedIndex = 0
        previewTick = 0
        refresh()
        Qt.callLater(function() {
            if (root.active)
                focusSink.forceActiveFocus()
        })
    }

    Process {
        id: clearProc
        command: ["bash", root.script, "clear"]
        onExited: {
            root.entries = []
            root.selectedIndex = 0
            root.previewTick++
            root.refresh()
        }
    }

    Process {
        id: listProc
        command: ["bash", root.script, "list", String(root.listLimit)]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = root.parseList(text)
                if (root.selectedIndex >= root.entries.length)
                    root.selectedIndex = Math.max(0, root.entries.length - 1)
                listView.currentIndex = root.selectedIndex
                root.cachePreviews()
            }
        }
    }

    Process {
        id: cacheProc
        command: ["bash", root.script, "cache-previews", String(root.listLimit)]
        onExited: root.previewTick++
    }

    Item {
        id: focusSink
        anchors.fill: parent
        focus: root.active
        Keys.enabled: root.active
        Keys.onEscapePressed: if (host) host.dismiss()
        Keys.onUpPressed: listView.decrementCurrentIndex()
        Keys.onDownPressed: listView.incrementCurrentIndex()
        Keys.onReturnPressed: {
            if (listView.currentIndex >= 0 && listView.currentIndex < root.entries.length)
                root.copyId(root.entries[listView.currentIndex].id)
        }
        Keys.onEnterPressed: {
            if (listView.currentIndex >= 0 && listView.currentIndex < root.entries.length)
                root.copyId(root.entries[listView.currentIndex].id)
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 10

            FramedPanel {
                label: "History"
                contentFill: true
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: listView
                    anchors.fill: parent
                    clip: true
                    model: root.entries
                    currentIndex: root.selectedIndex
                    highlightFollowsCurrentItem: true
                    boundsBehavior: Flickable.StopAtBounds
                    onCurrentIndexChanged: root.selectedIndex = currentIndex

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: modelData.image ? 44 : 30
                        color: ListView.isCurrentItem || mouseArea.containsMouse ? Theme.panelMantle : "transparent"
                        radius: 3

                        Row {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 8

                            Item {
                                width: 32
                                height: parent.height
                                visible: !!modelData.image

                                Image {
                                    anchors.centerIn: parent
                                    width: 32
                                    height: 32
                                    fillMode: Image.PreserveAspectFit
                                    source: root.previewUrlFor(modelData)
                                    sourceSize: Qt.size(64, 64)
                                    asynchronous: true
                                    cache: false
                                }
                            }

                            Text {
                                width: parent.width - (modelData.image ? 40 : 0)
                                height: parent.height
                                verticalAlignment: Text.AlignVCenter
                                text: modelData.label
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.historyFontSize
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                listView.currentIndex = index
                                root.copyId(modelData.id)
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: listView.count === 0
                    text: "No clipboard history"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.historyFontSize
                    opacity: 0.5
                }
            }

            FramedPanel {
                label: "Preview"
                contentFill: true
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                Layout.topMargin: 4

                Image {
                    id: previewImage
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    visible: root.selectedEntry && root.selectedEntry.image && status === Image.Ready
                    source: root.previewUrlFor(root.selectedEntry)
                    sourceSize: Qt.size(parent.width * 2, parent.height * 2)
                }

                Text {
                    anchors.fill: parent
                    visible: root.selectedEntry && !root.selectedEntry.image
                    text: root.selectedEntry ? root.selectedEntry.text : ""
                    wrapMode: Text.WordWrap
                    clip: true
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    verticalAlignment: Text.AlignTop
                }

                Text {
                    anchors.centerIn: parent
                    visible: !root.selectedEntry
                    text: "Select an entry"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    opacity: 0.5
                }

                Text {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    visible: {
                        var e = root.selectedEntry
                        return previewImage.visible && e && e.image
                    }
                    text: {
                        var e = root.selectedEntry
                        return (e && e.image) ? (e.image.width + "×" + e.image.height) : ""
                    }
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    opacity: 0.65
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                Layout.topMargin: 2
                opacity: root.entries.length === 0 || clearProc.running ? 0.35 : 1

                Text {
                    anchors.centerIn: parent
                    text: "Clear history"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: Theme.fontBold
                    opacity: clearMouse.containsMouse ? 1 : 0.72
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.entries.length > 0 && !clearProc.running
                    onClicked: root.clearHistory()
                }
            }
        }
    }
}
