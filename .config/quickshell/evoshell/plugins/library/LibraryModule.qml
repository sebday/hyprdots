import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null
    readonly property bool active: host && host.opened === true

    property string screen: "browse"
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
    property int selectedIndex: 0

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/evo-media.sh"
    readonly property string posterScript: Quickshell.env("HOME") + "/.local/bin/evo-media-fetch-posters.py"
    readonly property int gridColumns: {
        var w = gridView.width
        if (w <= 0)
            return 4
        return Math.max(4, Math.floor(w / 270))
    }
    readonly property int gridSpacing: 18
    readonly property color frameColor: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.32)
    readonly property int cellWidth: gridView.width > 0
        ? Math.floor(gridView.width / gridColumns)
        : 88
    readonly property int posterWidth: Math.max(56, cellWidth - gridSpacing)
    readonly property int posterHeight: Math.round(posterWidth * 1.5)
    readonly property bool showCaptions: screen === "episodes"
    readonly property int captionHeight: 52
    readonly property int tileHeight: posterHeight + (showCaptions ? captionHeight + 4 : 0)
    readonly property string currentSection: screen === "episodes" ? "episodes" : "catalog"
    readonly property var catalogItems: mergeCatalog(films, shows)
    readonly property var gridItems: screen === "episodes"
        ? filterItems(episodes, "episodes")
        : filterItems(catalogItems, "catalog")
    readonly property string emptyLabel: {
        if (normalizeQuery(searchQuery))
            return screen === "episodes" ? "No matching episodes" : "No matches"
        if (screen === "episodes")
            return "No episodes"
        return catalogItems.length === 0 ? "No media indexed" : "No matches"
    }
    readonly property string searchPlaceholder: screen === "episodes" ? "Episodes…" : "Search…"

    onGridItemsChanged: {
        if (selectedIndex >= gridItems.length)
            selectedIndex = Math.max(0, gridItems.length - 1)
    }

    function onActivated() {
        loading = true
        if (!statusProc.running)
            statusProc.running = true
    }

    function focusSearch(insertText) {
        searchField.forceActiveFocus()
        if (insertText)
            searchQuery += insertText
    }

    function moveSelection(dx, dy) {
        var n = gridItems.length
        if (n <= 0)
            return
        var cols = Math.max(1, gridColumns)
        var idx = selectedIndex
        if (idx < 0 || idx >= n)
            idx = 0
        if (dx !== 0)
            idx = Math.max(0, Math.min(n - 1, idx + dx))
        if (dy !== 0)
            idx = Math.max(0, Math.min(n - 1, idx + dy * cols))
        selectedIndex = idx
        gridView.positionViewAtIndex(idx, GridView.Contain)
    }

    function activateSelected() {
        if (selectedIndex < 0 || selectedIndex >= gridItems.length)
            return
        activateItem(gridItems[selectedIndex])
    }

    function handleNavKey(event) {
        if (event.key === Qt.Key_Left) {
            moveSelection(-1, 0)
            event.accepted = true
            return true
        }
        if (event.key === Qt.Key_Right) {
            moveSelection(1, 0)
            event.accepted = true
            return true
        }
        if (event.key === Qt.Key_Up) {
            moveSelection(0, -1)
            event.accepted = true
            return true
        }
        if (event.key === Qt.Key_Down) {
            moveSelection(0, 1)
            event.accepted = true
            return true
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            activateSelected()
            event.accepted = true
            return true
        }
        return false
    }

    Keys.enabled: root.active
    Keys.onPressed: function(event) {
        if (handleNavKey(event))
            return
        if (searchField.activeFocus)
            return
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            root.focusSearch()
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Backspace) {
            root.focusSearch()
            if (root.searchQuery.length)
                root.searchQuery = root.searchQuery.slice(0, -1)
            event.accepted = true
            return
        }
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return
        var ch = event.text || ""
        if (ch.length === 1 && ch >= " ") {
            root.focusSearch(ch)
            event.accepted = true
        }
    }

    function normalizeQuery(value) {
        return String(value || "").trim().toLowerCase()
    }

    function itemSearchText(item, section) {
        if (!item) return ""
        var kind = item.section || section
        if (kind === "catalog")
            kind = item.section
        if (kind === "films") {
            var title = String(item.title || "")
            if (item.year)
                return (title + " " + String(item.year)).toLowerCase()
            return title.toLowerCase()
        }
        if (kind === "shows")
            return String(item.name || "").toLowerCase()
        return String(item.label || item.title || item.name || "").toLowerCase()
    }

    function sortKey(item) {
        if (!item) return ""
        if (item.section === "shows" || item.name)
            return cleanTitle(item.name || item.title || "").toLowerCase()
        return cleanTitle(item.title || "").toLowerCase()
    }

    function mergeCatalog(filmList, showList) {
        var out = []
        var filmsSrc = Array.isArray(filmList) ? filmList : []
        var showsSrc = Array.isArray(showList) ? showList : []
        for (var i = 0; i < filmsSrc.length; i++) {
            var film = filmsSrc[i] || {}
            out.push({
                section: "films",
                title: film.title,
                name: film.title,
                year: film.year,
                path: film.path,
                poster_path: film.poster_path,
                poster: film.poster
            })
        }
        for (var j = 0; j < showsSrc.length; j++) {
            var show = showsSrc[j] || {}
            out.push({
                section: "shows",
                title: show.name,
                name: show.name,
                path: show.path,
                poster_path: show.poster_path,
                poster: show.poster
            })
        }
        out.sort(function(a, b) {
            var an = sortKey(a)
            var bn = sortKey(b)
            if (an < bn) return -1
            if (an > bn) return 1
            return 0
        })
        return out
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

    function captionFor(item) {
        if (!item) return ""
        var label = item.label || item.title || ""
        if (label.indexOf(" · ") >= 0) {
            var parts = label.split(" · ")
            return parts[0] + " · " + cleanTitle(parts.slice(1).join(" · "))
        }
        return cleanTitle(label)
    }

    function itemPoster(item) {
        if (!item) return ""
        var path = item.poster_path ? String(item.poster_path) : String(item.poster || "")
        if (path.startsWith("file://"))
            path = decodeURIComponent(path.substring(7))
        return path ? Util.fileUrl(path) : ""
    }

    function playPath(path) {
        if (!path) return
        Quickshell.execDetached(["mpv", "--fs", "--really-quiet", String(path)])
        if (host) host.dismiss()
    }

    function activateItem(item) {
        if (!item) return
        if (item.section === "shows")
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
        searchQuery = ""
        screen = "episodes"
        selectedIndex = 0
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
        selectedShowName = ""
        selectedShowTitle = ""
        selectedIndex = 0
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

    component PosterTile: Item {
        id: tile
        required property var modelData
        required property int index

        width: root.cellWidth
        height: root.tileHeight

        readonly property var item: modelData
        readonly property bool hovered: tileMouse.containsMouse || index === root.selectedIndex

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
                        text: (tile.item && tile.item.section === "shows") ? "󰖺" : "󰿯"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.popupTitleFontPixelSize
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
                visible: root.showCaptions
                text: root.captionFor(tile.item)
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.popupSmallFontPixelSize
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
            onEntered: root.selectedIndex = tile.index
            onClicked: root.activateItem(tile.item)
        }
    }

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
                font.pixelSize: Theme.popupSmallFontPixelSize
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
                font.pixelSize: Theme.popupBodyFontPixelSize
                font.bold: Theme.fontBold
                Layout.fillWidth: true
                elide: Text.ElideRight
                opacity: 0.85
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 24
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: Theme.panelCornerRadius
                color: Theme.panelMantle
                border.width: searchField.activeFocus ? 2 : 1
                border.color: searchField.activeFocus ? Theme.accent : root.frameColor

                MouseArea {
                    anchors.fill: parent
                    onPressed: searchField.forceActiveFocus()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Text {
                        text: "󰍉"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.popupSmallFontPixelSize
                        opacity: 0.55
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        TextInput {
                            id: searchField
                            anchors.fill: parent
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.popupSmallFontPixelSize
                            font.bold: Theme.fontBold
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            clip: true
                            text: root.searchQuery
                            onTextChanged: root.searchQuery = text
                            Keys.onTabPressed: function(event) { event.accepted = true }
                            Keys.onBacktabPressed: function(event) { event.accepted = true }
                            Keys.onPressed: function(event) {
                                root.handleNavKey(event)
                            }
                            Keys.onEscapePressed: {
                                if (root.searchQuery) {
                                    root.searchQuery = ""
                                    text = ""
                                } else if (root.screen === "episodes") {
                                    root.goBack()
                                } else if (host && typeof host.dismiss === "function") {
                                    host.dismiss()
                                }
                            }
                        }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: !searchField.text && !searchField.activeFocus
                            text: root.searchPlaceholder
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.popupSmallFontPixelSize
                            opacity: 0.35
                        }
                    }

                    Text {
                        visible: root.searchQuery.length > 0
                        text: "󰅖"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.popupSmallFontPixelSize
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
            }
        }

        Text {
            visible: root.dbMissing || root.statusText !== ""
            text: root.dbMissing ? "Run scan library to index media" : root.statusText
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.popupSmallFontPixelSize
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
            currentIndex: root.selectedIndex
            highlightFollowsCurrentItem: false
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: cellHeight * 8
            delegate: PosterTile {}

            Text {
                anchors.centerIn: parent
                visible: !root.loading && root.gridItems.length === 0
                text: root.emptyLabel
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.popupHintFontPixelSize
                opacity: 0.45
            }
        }
    }
}
