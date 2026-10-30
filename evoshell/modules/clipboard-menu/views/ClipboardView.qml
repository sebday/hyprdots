import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.commons

Item {
    id: root

    property var shell: null
    property string query: ""
    property int selectedIndex: 0
    property var entries: []

    signal activated(var entry)
    signal indexMoved(int index)

    readonly property string script: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-clipboard")
    readonly property string previewDir: Util.statePath(Quickshell.env("HOME"), "clipboard-previews")
    readonly property int listLimit: 30
    property int previewTick: 0

    readonly property var visibleEntries: {
        var q = String(query || "").trim().toLowerCase()
        if (!q)
            return entries
        var out = []
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i]
            if (!entry)
                continue
            var hay = String(entry.name || "").toLowerCase()
            if (hay.indexOf(q) >= 0)
                out.push(entry)
        }
        return out
    }

    readonly property var selectedEntry: {
        if (selectedIndex < 0 || selectedIndex >= visibleEntries.length)
            return null
        return visibleEntries[selectedIndex]
    }

    function refresh() {
        if (!listProc.running)
            listProc.running = true
    }

    function parseImageMeta(text) {
        var match = String(text || "").match(/\[\[\s*binary data\s+[^\]]*\s+(png|jpe?g)\s+(\d+)x(\d+)\s*\]\]/i)
        if (!match)
            return null
        return {
            format: String(match[1]).toLowerCase(),
            width: parseInt(match[2], 10),
            height: parseInt(match[3], 10)
        }
    }

    function parseList(raw) {
        var out = []
        var lines = String(raw || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (!line.trim())
                continue
            var tab = line.indexOf("\t")
            if (tab < 1)
                continue
            var id = line.substring(0, tab)
            if (!/^[0-9]+$/.test(id))
                continue
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
            var label = image ? ("Image " + image.width + "×" + image.height) : text
            out.push({
                kind: "clipboard",
                id: id,
                name: label,
                text: text,
                image: image,
                pinned: pinned,
                icon: pinned ? "󰐃" : (image ? "󰋩" : "󰅍"),
                accessory: "",
                section: ""
            })
        }
        return out
    }

    function previewPathFor(entry) {
        if (!entry || !entry.image)
            return ""
        var fmt = String(entry.image.format || "")
        var ext = ""
        if (fmt === "jpeg" || fmt === "jpg")
            ext = "jpg"
        else if (fmt === "png")
            ext = "png"
        if (!ext)
            return ""
        return previewDir + "/" + entry.id + "." + ext
    }

    function copyEntry(entry) {
        if (!entry)
            return
        Quickshell.execDetached(["bash", script, "copy", String(entry.id)])
    }

    function togglePin(entry) {
        if (!entry || pinProc.running)
            return
        pinProc.entryId = String(entry.id)
        pinProc.running = true
    }

    function deleteEntry(entry) {
        if (!entry || deleteProc.running)
            return
        deleteProc.entryId = String(entry.id)
        deleteProc.running = true
    }

    Process {
        id: listProc
        command: ["bash", root.script, "list", String(root.listLimit)]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = root.parseList(text)
                if (!cacheProc.running)
                    cacheProc.running = true
            }
        }
    }

    Process {
        id: cacheProc
        command: ["bash", root.script, "cache-previews", String(root.listLimit)]
        onExited: root.previewTick++
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

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacingM

        ListView {
            id: clipList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: 2
            model: root.visibleEntries
            currentIndex: root.selectedIndex

            onCurrentIndexChanged: {
                if (currentIndex >= 0)
                    positionViewAtIndex(currentIndex, ListView.Contain)
            }

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                width: clipList.width
                height: Theme.launcherRowHeight
                radius: Theme.cornerRadius
                color: index === root.selectedIndex || rowMouse.containsMouse
                    ? Theme.panelMantle
                    : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        Layout.preferredWidth: Theme.launcherIconSize
                        Layout.alignment: Qt.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: row.modelData && row.modelData.icon ? row.modelData.icon : "󰅍"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.launcherIconSize
                        font.bold: Theme.fontBold
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: row.modelData ? row.modelData.name : ""
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeS
                        font.bold: Theme.fontBold
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.indexMoved(index)
                    onClicked: {
                        root.indexMoved(index)
                        root.activated(row.modelData)
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: Theme.launcherDetailWidth
            Layout.fillHeight: true
            radius: Theme.cornerRadius
            color: Theme.overlaySurface
            clip: true

            Image {
                anchors.fill: parent
                anchors.margins: 8
                visible: root.selectedEntry && root.selectedEntry.image
                source: {
                    var path = root.previewPathFor(root.selectedEntry)
                    if (!path)
                        return ""
                    return Util.fileUrl(path) + "?t=" + root.previewTick
                }
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
            }

            Flickable {
                anchors.fill: parent
                anchors.margins: 12
                visible: root.selectedEntry && !root.selectedEntry.image
                contentWidth: width
                contentHeight: previewText.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    id: previewText
                    width: parent.width
                    text: root.selectedEntry ? root.selectedEntry.text : ""
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    wrapMode: Text.Wrap
                }
            }

            Text {
                anchors.centerIn: parent
                visible: !root.selectedEntry
                text: String(root.query || "").trim() === "" ? "Clipboard is empty" : "No matches"
                color: Theme.foreground
                opacity: Theme.opacityMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                font.bold: Theme.fontBold
            }
        }
    }
}
