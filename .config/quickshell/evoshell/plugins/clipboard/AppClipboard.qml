import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null
    property var shell: null

    property var entries: []
    property int selectedIndex: 0
    property int previewTick: 0
    property string entryFilter: "all"

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/evo-clipboard"
    readonly property string previewDir: Quickshell.env("HOME") + "/.local/state/evoshell/clipboard-previews"
    readonly property int listLimit: 30
    readonly property int historyFontSize: Theme.fontSizeM
    readonly property int rowHeight: 44
    readonly property bool active: host && host.opened

    readonly property var visibleEntries: {
        if (entryFilter === "all")
            return entries
        var out = []
        for (var i = 0; i < entries.length; i++) {
            if (!entries[i])
                continue
            if (entryFilter === "images" && entries[i].image)
                out.push(entries[i])
            else if (entryFilter === "text" && !entries[i].image)
                out.push(entries[i])
        }
        return out
    }

    readonly property var selectedEntry: {
        if (selectedIndex < 0 || selectedIndex >= visibleEntries.length)
            return null
        return visibleEntries[selectedIndex]
    }

    function clampSelectedIndex() {
        if (visibleEntries.length === 0) {
            selectedIndex = 0
            listView.currentIndex = -1
            return
        }
        if (selectedIndex >= visibleEntries.length)
            selectedIndex = visibleEntries.length - 1
        if (selectedIndex < 0)
            selectedIndex = 0
        listView.currentIndex = selectedIndex
    }

    function dismissHost() {
        if (host && typeof host.dismiss === "function")
            host.dismiss()
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
            var rest = line.substring(tab + 1)
            var pinned = false
            var text = rest
            var flagSep = rest.lastIndexOf("\t")
            if (flagSep >= 0) {
                var flag = rest.substring(flagSep + 1)
                if (flag === "0" || flag === "1") {
                    pinned = flag === "1"
                    text = rest.substring(0, flagSep)
                }
            }
            var image = parseImageMeta(text)
            out.push({
                id: id,
                text: text,
                image: image,
                pinned: pinned,
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

    function togglePin(id) {
        if (pinProc.running) return
        pinProc.entryId = String(id)
        pinProc.running = true
    }

    function copyId(id) {
        Quickshell.execDetached(["bash", root.script, "copy", String(id)])
        dismissHost()
    }

    function cachePreviews() {
        if (!cacheProc.running) cacheProc.running = true
    }

    function deleteSelected() {
        if (deleteProc.running) return
        var entry = selectedEntry
        if (!entry) return
        deleteProc.entryId = String(entry.id)
        deleteProc.running = true
    }

    function clearHistory() {
        if (clearProc.running || entries.length === 0)
            return
        clearProc.running = true
    }

    function onActivated() {
        selectedIndex = 0
        entryFilter = "all"
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
            root.previewTick++
            root.refresh()
        }
    }

    Process {
        id: pinProc
        property string entryId: ""
        command: ["bash", root.script, "toggle-pin", pinProc.entryId]
        onExited: root.refresh()
    }

    Process {
        id: deleteProc
        property string entryId: ""
        command: ["bash", root.script, "delete", deleteProc.entryId]
        onExited: {
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
                root.clampSelectedIndex()
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
        Keys.onEscapePressed: root.dismissHost()
        Keys.onUpPressed: listView.decrementCurrentIndex()
        Keys.onDownPressed: listView.incrementCurrentIndex()
        Keys.onReturnPressed: {
            if (listView.currentIndex >= 0 && listView.currentIndex < root.visibleEntries.length)
                root.copyId(root.visibleEntries[listView.currentIndex].id)
        }
        Keys.onEnterPressed: {
            if (listView.currentIndex >= 0 && listView.currentIndex < root.visibleEntries.length)
                root.copyId(root.visibleEntries[listView.currentIndex].id)
        }
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) {
                event.accepted = true
                root.deleteSelected()
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.hoverPopupSectionSpacing

            SectionPanel {
                fillHeight: true
                legendBackground: Theme.background
                label: ""
                sectionSpacing: 0
                Layout.fillWidth: true
                Layout.fillHeight: true

                HoverPopupLabelPill {
                    text: "History"
                    fontSize: Theme.fontSizeS
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: listView
                        anchors.fill: parent
                    clip: true
                    model: root.visibleEntries
                    currentIndex: root.selectedIndex
                    highlightFollowsCurrentItem: true
                    boundsBehavior: Flickable.StopAtBounds
                    onCurrentIndexChanged: root.selectedIndex = currentIndex

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: root.rowHeight
                        color: listView.currentIndex === index || rowMouse.containsMouse
                            ? Theme.panelMantle
                            : "transparent"
                        radius: Theme.radiusM

                        Row {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: Theme.spacingM

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
                                width: parent.width - (modelData.image ? 40 : 0) - 32
                                height: parent.height
                                verticalAlignment: Text.AlignVCenter
                                text: modelData.label
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.historyFontSize
                                elide: Text.ElideRight
                            }
                        }

                        Item {
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 28
                            z: 2

                            Text {
                                anchors.centerIn: parent
                                text: modelData.pinned ? "󰐃" : "󰤱"
                                color: modelData.pinned ? Theme.accent : Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize2xl
                                font.bold: Theme.fontBold
                                opacity: pinMouse.containsMouse || modelData.pinned ? 1 : 0.45
                            }

                            MouseArea {
                                id: pinMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.togglePin(modelData.id)
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: listView.currentIndex = index
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
                        text: root.entryFilter === "images"
                            ? "No images in clipboard history"
                            : (root.entryFilter === "text"
                                ? "No text in clipboard history"
                                : "No clipboard history")
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.historyFontSize
                        opacity: 0.5
                    }
                }
            }

            SectionPanel {
                legendBackground: Theme.background
                label: ""
                sectionSpacing: 0
                Layout.fillWidth: true
                Layout.preferredHeight: 166

                HoverPopupLabelPill {
                    text: "Preview"
                    fontSize: Theme.fontSizeS
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120

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
                        font.pixelSize: Theme.fontSizeS
                        verticalAlignment: Text.AlignTop
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !root.selectedEntry
                        text: "Select an entry"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeS
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
                        font.pixelSize: Theme.fontSizeXxs
                        opacity: Theme.opacityHover
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                Layout.topMargin: 2
                spacing: Theme.spacingS

                HoverPopupLabelPill {
                    clickable: root.entries.length > 0
                    text: "Images"
                    icon: "󰋩"
                    fontSize: Theme.fontSizeXs
                    textColor: root.entryFilter === "images" ? Theme.accent : Theme.foreground
                    fill: root.entryFilter === "images"
                        ? Theme.withOpacity(Theme.accent, 0.14)
                        : Theme.withOpacity(Theme.foreground, 0.08)
                    textOpacity: root.entries.length === 0
                        ? 0.35
                        : (root.entryFilter === "images" ? 1 : 0.72)
                    onClicked: {
                        root.entryFilter = root.entryFilter === "images" ? "all" : "images"
                        root.clampSelectedIndex()
                    }
                }

                HoverPopupLabelPill {
                    clickable: root.entries.length > 0
                    text: "Text"
                    icon: "󰈙"
                    fontSize: Theme.fontSizeXs
                    textColor: root.entryFilter === "text" ? Theme.accent : Theme.foreground
                    fill: root.entryFilter === "text"
                        ? Theme.withOpacity(Theme.accent, 0.14)
                        : Theme.withOpacity(Theme.foreground, 0.08)
                    textOpacity: root.entries.length === 0
                        ? 0.35
                        : (root.entryFilter === "text" ? 1 : 0.72)
                    onClicked: {
                        root.entryFilter = root.entryFilter === "text" ? "all" : "text"
                        root.clampSelectedIndex()
                    }
                }

                Item { Layout.fillWidth: true }

                HoverPopupLabelPill {
                    clickable: root.entries.length > 0
                    text: "Clear"
                    icon: "󰩺"
                    fontSize: Theme.fontSizeXs
                    textColor: Theme.foreground
                    fill: Theme.withOpacity(Theme.foreground, 0.08)
                    textOpacity: root.entries.length === 0 ? 0.35 : 0.72
                    onClicked: root.clearHistory()
                }
            }
        }
    }
}
