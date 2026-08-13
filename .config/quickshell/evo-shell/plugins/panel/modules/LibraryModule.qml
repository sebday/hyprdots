import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../../Commons"

Item {
    id: root

    property var host: null
    readonly property bool active: host && host.opened && host.activeModule === "library"

    property string screen: "browse"
    property string browseKind: "shows"
    property var films: []
    property var shows: []
    property var episodes: []
    property string selectedShowName: ""
    property string selectedShowTitle: ""
    property bool dbMissing: false
    property bool loading: false
    property string statusText: ""
    property int pendingLoads: 0
    property string searchQuery: ""
    property var episodeCache: ({})

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/evo-media.sh"
    readonly property string posterScript: Quickshell.env("HOME") + "/.local/bin/evo-media-fetch-posters.py"
    readonly property int gridColumns: 3
    readonly property int gridSpacing: 8
    readonly property int captionHeight: 28
    readonly property color frameColor: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.32)
    readonly property int cellWidth: gridView.width > 0
        ? Math.floor(gridView.width / gridColumns)
        : 88
    readonly property int posterWidth: Math.max(56, cellWidth - gridSpacing)
    readonly property int posterHeight: Math.round(posterWidth * 1.5)
    readonly property int tileHeight: posterHeight + captionHeight + 4
    readonly property string currentSection: screen === "episodes" ? "episodes" : browseKind
    readonly property var gridItems: filterItems(
        screen === "episodes" ? episodes : (browseKind === "shows" ? shows : films),
        currentSection
    )
    readonly property string emptyLabel: {
        if (normalizeQuery(searchQuery))
            return screen === "episodes" ? "No matching episodes" : "No matches"
        if (screen === "episodes")
            return "No episodes"
        if (browseKind === "shows")
            return shows.length === 0 ? "No TV indexed" : "No matches"
        return films.length === 0 ? "No films indexed" : "No matches"
    }
    readonly property string searchPlaceholder: screen === "episodes"
        ? "Episodes…"
        : (browseKind === "shows" ? "TV…" : "Films…")

    function onActivated() {
        loading = true
        if (!statusProc.running)
            statusProc.running = true
    }

    function normalizeQuery(value) {
        return String(value || "").trim().toLowerCase()
    }

    function itemSearchText(item, section) {
        if (!item) return ""
        if (section === "films") {
            var title = String(item.title || "")
            if (item.year)
                return (title + " " + String(item.year)).toLowerCase()
            return title.toLowerCase()
        }
        if (section === "shows")
            return String(item.name || "").toLowerCase()
        return String(item.label || item.title || "").toLowerCase()
    }

    function filterItems(items, section) {
        var query = normalizeQuery(searchQuery)
        if (!query)
            return items
        var out = []
        for (var i = 0; i < items.length; i++) {
            if (itemSearchText(items[i], section).indexOf(query) >= 0)
                out.push(items[i])
        }
        return out
    }

    function stripExtension(text) {
        return String(text || "").replace(/\.(mkv|mp4|m4v|avi|mov|wmv|flv|webm|ts|m2ts)$/i, "")
    }

    function cleanTitle(text) {
        var value = stripExtension(String(text || ""))
        return value.replace(/[._]+/g, " ").replace(/\s+/g, " ").trim()
    }

    function itemPoster(item) {
        if (!item) return ""
        var path = item.poster_path ? String(item.poster_path) : String(item.poster || "")
        if (path.startsWith("file://"))
            path = decodeURIComponent(path.substring(7))
        return path ? Util.fileUrl(path) : ""
    }

    function captionFor(section, item) {
        if (!item) return ""
        if (section === "films") {
            var title = cleanTitle(item.title)
            return item.year ? (title + " (" + item.year + ")") : title
        }
        if (section === "shows")
            return cleanTitle(item.name)
        var label = item.label || item.title || ""
        if (label.indexOf(" · ") >= 0) {
            var parts = label.split(" · ")
            return parts[0] + " · " + cleanTitle(parts.slice(1).join(" · "))
        }
        return cleanTitle(label)
    }

    function setBrowseKind(kind) {
        if (kind !== "films" && kind !== "shows") return
        browseKind = kind
        if (screen === "episodes") {
            screen = "browse"
            episodes = []
            selectedShowName = ""
            selectedShowTitle = ""
        }
    }

    function playPath(path) {
        if (!path) return
        Quickshell.execDetached(["mpv", "--fs", "--really-quiet", String(path)])
        if (host) host.dismiss()
    }

    function activateItem(item) {
        if (!item) return
        if (currentSection === "shows")
            openShow(item)
        else
            playPath(item.path)
    }

    function rememberEpisodes(name, items) {
        if (!name) return
        var next = {}
        for (var key in episodeCache)
            next[key] = episodeCache[key]
        next[name] = items
        episodeCache = next
    }

    function openShow(show) {
        if (!show) return
        selectedShowName = show.name
        selectedShowTitle = show.name
        browseKind = "shows"
        searchQuery = ""
        screen = "episodes"
        var cached = episodeCache[show.name]
        if (cached) {
            episodes = cached
            loading = false
            return
        }
        episodes = []
        episodesProc.showName = show.name
        episodesProc.running = true
    }

    function goBack() {
        if (screen !== "episodes") return
        screen = "browse"
        episodes = []
        searchQuery = ""
        browseKind = "shows"
        selectedShowName = ""
        selectedShowTitle = ""
    }

    function reloadLibrary() {
        dbMissing = false
        loading = true
        pendingLoads = 2
        filmsProc.running = true
        showsProc.running = true
    }

    function refreshCurrentShowEpisodes() {
        if (screen !== "episodes" || !selectedShowName)
            return
        loading = true
        episodesProc.showName = selectedShowName
        episodesProc.running = true
    }

    function startLibraryScan() {
        if (scanProc.running)
            return
        statusText = "Scanning library…"
        scanProc.running = true
    }

    Process {
        id: statusProc
        command: ["bash", root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(String(text || "{}"))
                    root.dbMissing = data.exists !== true
                    if (root.dbMissing) {
                        root.loading = false
                        root.statusText = "Run scan library to index media"
                        return
                    }
                    root.reloadLibrary()
                } catch (e) {
                    root.dbMissing = true
                    root.loading = false
                    root.statusText = "Library unavailable"
                }
            }
        }
    }

    Process {
        id: filmsProc
        command: ["bash", root.script, "list", "films"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.films = JSON.parse(String(text || "[]"))
                } catch (e) {
                    root.films = []
                }
                root.pendingLoads = Math.max(0, root.pendingLoads - 1)
                if (root.pendingLoads === 0)
                    root.loading = false
            }
        }
    }

    Process {
        id: showsProc
        command: ["bash", root.script, "list", "shows"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.shows = JSON.parse(String(text || "[]"))
                } catch (e) {
                    root.shows = []
                }
                root.pendingLoads = Math.max(0, root.pendingLoads - 1)
                if (root.pendingLoads === 0)
                    root.loading = false
            }
        }
    }

    Process {
        id: episodesProc
        property string showName: ""
        command: ["bash", root.script, "list", "episodes", episodesProc.showName]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                try {
                    var data = JSON.parse(String(text || "{}"))
                    root.episodes = data.episodes || []
                    root.rememberEpisodes(root.selectedShowName, root.episodes)
                } catch (e) {
                    root.episodes = []
                }
            }
        }
        onRunningChanged: if (episodesProc.running) root.loading = true
    }

    Process {
        id: scanProc
        command: ["bash", root.script, "scan"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(String(text || "{}"))
                    if (data.ok !== true)
                        throw new Error("scan failed")
                    root.episodeCache = ({})
                    Quickshell.execDetached(["python3", "-u", root.posterScript])
                    root.reloadLibrary()
                    root.refreshCurrentShowEpisodes()
                    root.statusText = "Scan complete — fetching covers in background"
                } catch (e) {
                    root.statusText = "Library scan failed"
                }
            }
        }
    }

    component KindLink: Text {
        id: kindLink
        property string kind: ""
        property bool current: false

        color: current ? Theme.accent : Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.panelHintFontPixelSize
        font.bold: Theme.fontBold
        opacity: kindMouse.containsMouse || current ? 1 : 0.65

        MouseArea {
            id: kindMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setBrowseKind(kindLink.kind)
        }
    }

    component PosterTile: Item {
        id: tile
        required property var modelData
        required property int index

        width: root.cellWidth
        height: root.tileHeight

        readonly property var item: modelData
        readonly property bool hovered: tileMouse.containsMouse

        Column {
            spacing: 4
            width: root.posterWidth
            anchors.horizontalCenter: parent.horizontalCenter

            Item {
                width: root.posterWidth
                height: root.posterHeight

                Rectangle {
                    anchors.fill: parent
                    color: Theme.panelMantle
                    clip: true
                    radius: Theme.panelCornerRadius

                    Image {
                        id: posterImage
                        anchors.fill: parent
                        source: root.itemPoster(tile.item)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        mipmap: true
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: posterImage.status !== Image.Ready
                        text: root.currentSection === "shows" ? "󰖺" : "󰿯"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                        opacity: 0.35
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    radius: Theme.panelCornerRadius
                    border.width: tile.hovered ? 2 : 1
                    border.color: tile.hovered ? Theme.accent : root.frameColor
                }
            }

            Text {
                width: parent.width
                text: root.captionFor(root.currentSection, tile.item)
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.panelHintFontPixelSize
                font.bold: Theme.fontBold
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activateItem(tile.item)
        }
    }

    FramedPanel {
        anchors.fill: parent
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        label: "Library"
        contentFill: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            visible: root.screen === "episodes"

            Text {
                text: "󰁍 Back"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.panelHintFontPixelSize
                font.bold: Theme.fontBold
                opacity: backMouse.containsMouse ? 1 : 0.75

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.goBack()
                }
            }

            Text {
                text: root.selectedShowTitle
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.panelSmallFontPixelSize
                font.bold: Theme.fontBold
                Layout.fillWidth: true
                elide: Text.ElideRight
                opacity: 0.85
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                radius: Theme.panelCornerRadius
                color: Theme.panelMantle
                border.width: searchField.activeFocus ? 2 : 1
                border.color: searchField.activeFocus ? Theme.accent : root.frameColor

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    Text {
                        text: "󰍉"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        opacity: 0.55
                    }

                    TextInput {
                        id: searchField
                        Layout.fillWidth: true
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.panelSmallFontPixelSize
                        font.bold: Theme.fontBold
                        selectByMouse: true
                        clip: true
                        text: root.searchQuery
                        onTextChanged: root.searchQuery = text
                        Keys.onEscapePressed: {
                            if (root.searchQuery) {
                                root.searchQuery = ""
                                text = ""
                            } else {
                                root.goBack()
                            }
                        }
                    }

                    Text {
                        visible: root.searchQuery.length > 0
                        text: "󰅖"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        opacity: clearSearchMouse.containsMouse ? 1 : 0.55

                        MouseArea {
                            id: clearSearchMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.searchQuery = ""
                                searchField.text = ""
                                searchField.forceActiveFocus()
                            }
                        }
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 32
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !searchField.text && !searchField.activeFocus
                    text: root.searchPlaceholder
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.panelHintFontPixelSize
                    opacity: 0.35
                }
            }

            KindLink {
                text: "Films"
                kind: "films"
                current: root.browseKind === "films" && root.screen !== "episodes"
            }

            KindLink {
                text: "TV"
                kind: "shows"
                current: root.browseKind === "shows" || root.screen === "episodes"
            }
        }

        Text {
            visible: root.dbMissing || root.statusText !== ""
            text: root.dbMissing ? "Run scan library to index media" : root.statusText
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelHintFontPixelSize
            opacity: scanStatusMouse.containsMouse && root.dbMissing ? 1 : 0.7

            MouseArea {
                id: scanStatusMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: (root.dbMissing || root.statusText !== "") && !scanProc.running
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.startLibraryScan()
            }
        }

        GridView {
            id: gridView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.dbMissing
            clip: true
            cellWidth: root.cellWidth
            cellHeight: root.tileHeight + root.gridSpacing
            model: root.gridItems
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: cellHeight * 8
            delegate: PosterTile {}

            Text {
                anchors.centerIn: parent
                visible: !root.loading && root.gridItems.length === 0
                text: root.emptyLabel
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 13
                opacity: 0.45
            }
        }
        }
    }
}
