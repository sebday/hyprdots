import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../../Commons"

Item {
    id: root

    property var shell: null
    property bool opened: false
    property var entries: []
    property int selectedIndex: 0
    property int previewTick: 0

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/evo-clipboard.sh"
    readonly property string previewDir: Quickshell.env("HOME") + "/.local/state/evo-shell/clipboard-previews"
    readonly property int listLimit: 30
    readonly property int panelWidth: 780
    readonly property int panelHeight: 420
    readonly property int previewPaneWidth: 320

    readonly property var selectedEntry: {
        if (selectedIndex < 0 || selectedIndex >= entries.length)
            return null
        return entries[selectedIndex]
    }

    function open(payloadJson) {
        selectedIndex = 0
        previewTick = 0
        refresh()
        opened = true
    }

    function dismiss() {
        if (shell) shell.hide("evo.clipboard")
        else close()
    }

    function close() {
        opened = false
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
        dismiss()
    }

    function cachePreviews() {
        if (!cacheProc.running) cacheProc.running = true
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

    PanelWindow {
        visible: root.opened
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.namespace: "evo-clipboard"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Item {
            anchors.fill: parent
            focus: root.opened
            Keys.onEscapePressed: root.dismiss()
            Keys.onUpPressed: listView.decrementCurrentIndex()
            Keys.onDownPressed: listView.incrementCurrentIndex()
            Keys.onReturnPressed: {
                if (listView.currentIndex >= 0 && listView.currentIndex < root.entries.length)
                    root.copyId(root.entries[listView.currentIndex].id)
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: root.panelWidth
            height: root.panelHeight
            color: Theme.background
            border.color: Theme.accent

            Row {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                ListView {
                    id: listView
                    width: parent.width - root.previewPaneWidth - parent.spacing
                    height: parent.height
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
                        height: modelData.image ? 48 : 32
                        color: ListView.isCurrentItem || mouseArea.containsMouse ? Theme.mantle : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 8

                            Item {
                                width: 36
                                height: parent.height
                                visible: modelData.image !== null && modelData.image !== undefined

                                Image {
                                    anchors.centerIn: parent
                                    width: 36
                                    height: 36
                                    fillMode: Image.PreserveAspectFit
                                    source: root.previewUrlFor(modelData)
                                    sourceSize: Qt.size(72, 72)
                                    asynchronous: true
                                    cache: false
                                }
                            }

                            Text {
                                width: parent.width - (modelData.image ? 44 : 0)
                                height: parent.height
                                verticalAlignment: Text.AlignVCenter
                                text: modelData.label
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.copyId(modelData.id)
                        }
                    }
                }

                Rectangle {
                    width: root.previewPaneWidth
                    height: parent.height
                    color: Theme.mantle
                    clip: true

                    Image {
                        id: previewImage
                        anchors.centerIn: parent
                        width: parent.width - 16
                        height: parent.height - 16
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                        visible: root.selectedEntry && root.selectedEntry.image && status === Image.Ready
                        source: root.previewUrlFor(root.selectedEntry)
                        sourceSize: Qt.size(root.previewPaneWidth * 2, root.panelHeight * 2)
                    }

                    Text {
                        anchors.fill: parent
                        anchors.margins: 12
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
                        text: "No clipboard history"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        opacity: 0.6
                    }

                    Text {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 8
                        visible: previewImage.visible && root.selectedEntry && root.selectedEntry.image
                        text: root.selectedEntry.image.width + "×" + root.selectedEntry.image.height
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        opacity: 0.65
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: root.dismiss()
        }
    }
}
