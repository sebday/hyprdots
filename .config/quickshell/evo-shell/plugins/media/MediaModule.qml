import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null
    property var shell: null
    property bool active: false

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

    property int focusIndex: 0
    property string searchQuery: ""
    property bool librarySyncing: false

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/evo-media.sh"
    readonly property string posterScript: Quickshell.env("HOME") + "/.local/bin/evo-media-fetch-posters.py"
    readonly property int gridColumns: 10
    readonly property int gridSpacing: 14
    readonly property int captionHeight: 40
    readonly property int flowWidth: screen === "episodes" ? episodeFlickable.width : browseFlickable.width
    readonly property int computedCellWidth: flowWidth > 0
        ? Math.floor((flowWidth - (gridColumns - 1) * gridSpacing) / gridColumns)
        : 120
    readonly property int computedPosterWidth: Math.max(72, computedCellWidth)
    readonly property int computedPosterHeight: Math.round(computedPosterWidth * 1.5)
    readonly property int computedTileHeight: computedPosterHeight + captionHeight + 8
    readonly property int captionFontSize: 10

    readonly property var filteredFilms: filterItems(films, "films")
    readonly property var filteredShows: filterItems(shows, "shows")
    readonly property var filteredEpisodes: filterItems(episodes, "episodes")

    readonly property var browseEntries: {
        var out = []
        var i
        for (i = 0; i < filteredFilms.length; i++)
            out.push({ section: "films", item: filteredFilms[i] })
        for (i = 0; i < filteredShows.length; i++)
            out.push({ section: "shows", item: filteredShows[i] })
        return out
    }

    function resetView() {
        screen = "browse"
        selectedShowName = ""
        selectedShowTitle = ""
        episodes = []
        searchQuery = ""
        focusIndex = 0
    }

    function onActivated() {
        resetView()
        loading = true
        if (!statusProc.running)
            statusProc.running = true
        Qt.callLater(function() {
            if (root.active)
                focusSink.forceActiveFocus()
        })
    }

    function focusGrid() {
        focusSink.forceActiveFocus()
        clampFocus()
    }

    function handleArrowKey(dx, dy, event) {
        if (root.entryCount() === 0)
            return
        if (dx !== 0 || dy !== 0)
            focusGrid()
        root.moveSelection(dx, dy)
        if (event)
            event.accepted = true
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

    onSearchQueryChanged: {
        focusIndex = 0
        clampFocus()
    }

    function stripExtension(text) {
        return String(text || "").replace(/\.(mkv|mp4|m4v|avi|mov|wmv|flv|webm|ts|m2ts)$/i, "")
    }

    function cleanTitle(text) {
        var value = stripExtension(String(text || ""))
        value = value.replace(/[._]+/g, " ").replace(/\s+/g, " ").trim()
        return value
    }

    function gridColumnsFor(flow) {
        return gridColumns
    }

    function currentGridColumns() {
        return gridColumns
    }

    function entryCount() {
        if (screen === "episodes")
            return filteredEpisodes.length
        return browseEntries.length
    }

    function browseEntryAt(index) {
        if (index < 0 || index >= browseEntries.length)
            return null
        return browseEntries[index]
    }

    function episodeEntryAt(index) {
        if (index < 0 || index >= filteredEpisodes.length)
            return null
        return { section: "episodes", item: filteredEpisodes[index] }
    }

    function entryAt(index) {
        if (screen === "episodes")
            return episodeEntryAt(index)
        return browseEntryAt(index)
    }

    function posterPath(item) {
        if (!item) return ""
        if (item.poster_path)
            return String(item.poster_path)
        var uri = String(item.poster || "")
        if (uri.startsWith("file://"))
            return decodeURIComponent(uri.substring(7))
        return uri
    }

    function itemPoster(item) {
        var path = posterPath(item)
        if (!path) return ""
        return Util.fileUrl(path)
    }

    function filmCaption(item) {
        if (!item) return ""
        var title = cleanTitle(item.title)
        if (item.year)
            return title + " (" + item.year + ")"
        return title
    }

    function showCaption(item) {
        if (!item) return ""
        var name = cleanTitle(item.name)
        if (item.episodes)
            return name + " · " + String(item.episodes) + " eps"
        return name
    }

    function episodeCaption(item) {
        if (!item) return ""
        var label = item.label || item.title || ""
        if (label.indexOf(" · ") >= 0) {
            var parts = label.split(" · ")
            return parts[0] + " · " + cleanTitle(parts.slice(1).join(" · "))
        }
        return cleanTitle(label)
    }

    function clampFocus() {
        var count = entryCount()
        if (count === 0) {
            focusIndex = 0
            return
        }
        focusIndex = Math.max(0, Math.min(focusIndex, count - 1))
        syncScrollPosition()
    }

    function syncScrollPosition() {
        var flickable = screen === "episodes" ? episodeFlickable : browseFlickable
        var flow = screen === "episodes" ? episodeFlow : browseFlow
        if (!flickable || !flow || flow.children.length === 0)
            return

        var child = flow.children[Math.min(focusIndex, flow.children.length - 1)]
        if (!child)
            return

        var top = child.y
        var bottom = child.y + child.height
        if (top < flickable.contentY)
            flickable.contentY = top
        else if (bottom > flickable.contentY + flickable.height)
            flickable.contentY = bottom - flickable.height
    }

    function playPath(path) {
        if (!path) return
        Quickshell.execDetached(["mpv", "--fs", "--really-quiet", String(path)])
        if (host) host.dismiss()
    }

    function activateEntry(entry) {
        if (!entry || !entry.item) return
        if (entry.section === "films")
            playPath(entry.item.path)
        else if (entry.section === "shows")
            openShow(entry.item)
        else
            playPath(entry.item.path)
    }

    function activateAt(index) {
        var entry = entryAt(index)
        if (!entry) return
        focusIndex = index
        activateEntry(entry)
    }

    function openShow(show) {
        if (!show) return
        selectedShowName = show.name
        selectedShowTitle = show.name
        focusIndex = 0
        screen = "episodes"
        episodesProc.showName = show.name
        episodesProc.running = true
    }

    function handleBack() {
        if (screen === "episodes") {
            var showIndex = -1
            for (var i = 0; i < filteredShows.length; i++) {
                if (filteredShows[i] && filteredShows[i].name === selectedShowName) {
                    showIndex = i
                    break
                }
            }
            screen = "browse"
            episodes = []
            searchQuery = ""
            focusIndex = showIndex >= 0 ? filteredFilms.length + showIndex : 0
            clampFocus()
            Qt.callLater(function() {
                if (root.active)
                    focusSink.forceActiveFocus()
            })
            return
        }
        if (host) host.dismiss()
    }

    function handleActivate() {
        if (dbMissing) return
        activateEntry(entryAt(focusIndex))
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
        librarySyncing = true
        statusText = "Scanning library…"
        scanProc.running = true
    }

    function finishLibrarySync(message) {
        librarySyncing = false
        statusText = message || ""
    }

    function moveSelection(dx, dy) {
        var count = entryCount()
        if (count <= 0) return

        if (dx !== 0) {
            var next = focusIndex + dx
            if (next >= 0 && next < count) {
                focusIndex = next
                syncScrollPosition()
            }
            return
        }

        if (dy === 0) return

        var cols = currentGridColumns()
        var nextRow = focusIndex + dy * cols
        if (dy < 0 && focusIndex < cols && screen === "browse") {
            searchField.forceActiveFocus()
            return
        }
        if (nextRow >= 0 && nextRow < count) {
            focusIndex = nextRow
            syncScrollPosition()
        } else if (dy > 0 && nextRow >= count && count > 0) {
            focusIndex = count - 1
            syncScrollPosition()
        }
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
                root.clampFocus()
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
                root.clampFocus()
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
                    root.focusIndex = 0
                    root.clampFocus()
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
                    Quickshell.execDetached(["python3", "-u", root.posterScript])
                    root.reloadLibrary()
                    root.refreshCurrentShowEpisodes()
                    root.finishLibrarySync("Scan complete — fetching covers in background")
                } catch (e) {
                    root.finishLibrarySync("Library scan failed")
                }
            }
        }
    }

    component PosterTile: Item {
        id: tile
        required property int tileIndex
        required property string section
        required property var item

        width: root.computedCellWidth
        height: root.computedTileHeight
        visible: item !== null

        readonly property bool selected: root.focusIndex === tileIndex

        Column {
            spacing: 8
            width: root.computedPosterWidth

            Item {
                width: root.computedPosterWidth
                height: root.computedPosterHeight

                Rectangle {
                    anchors.fill: parent
                    color: Theme.panelMantle
                    clip: true

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
                        text: tile.section === "shows" ? "󰖺" : "󰿯"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 36
                        opacity: 0.35
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: tile.selected ? 4 : 1
                    border.color: tile.selected ? Theme.accent : "#33343a"
                }
            }

            Text {
                width: parent.width
                text: {
                    if (tile.section === "films") return root.filmCaption(tile.item)
                    if (tile.section === "shows") return root.showCaption(tile.item)
                    return root.episodeCaption(tile.item)
                }
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.captionFontSize
                font.bold: Theme.fontBold
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.focusIndex = tile.tileIndex
                root.focusGrid()
                root.activateAt(tile.tileIndex)
            }
            onEntered: {
                root.focusIndex = tile.tileIndex
                root.focusGrid()
            }
        }
    }

    Item {
        id: focusSink
        anchors.fill: parent
        focus: root.active
        activeFocusOnTab: true
        Keys.enabled: root.active
        Keys.onEscapePressed: root.handleBack()
        Keys.onLeftPressed: function(event) { root.handleArrowKey(-1, 0, event) }
        Keys.onRightPressed: function(event) { root.handleArrowKey(1, 0, event) }
        Keys.onUpPressed: function(event) { root.handleArrowKey(0, -1, event) }
        Keys.onDownPressed: function(event) { root.handleArrowKey(0, 1, event) }
        Keys.onReturnPressed: root.handleActivate()
        Keys.onEnterPressed: root.handleActivate()
        Keys.onTabPressed: function(event) {
            searchField.forceActiveFocus()
            event.accepted = true
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: root.screen === "episodes"

                Text {
                    text: "󰁍 Back"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: Theme.fontBold
                    opacity: backMouse.containsMouse ? 1 : 0.75

                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.handleBack()
                    }
                }

                Text {
                    text: root.selectedShowTitle
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 20
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
                    Layout.preferredHeight: 44
                    radius: 8
                    color: Theme.panelMantle
                    border.width: searchField.activeFocus ? 2 : 1
                    border.color: searchField.activeFocus ? Theme.accent : "#33343a"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        Text {
                            text: "󰍉"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 18
                            opacity: 0.55
                        }

                        TextInput {
                            id: searchField
                            Layout.fillWidth: true
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
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
                                    root.handleBack()
                                }
                            }
                            Keys.onLeftPressed: function(event) {
                                if (root.entryCount() === 0)
                                    return
                                if (cursorPosition > 0 || selectionStart !== selectionEnd)
                                    return
                                root.handleArrowKey(-1, 0, event)
                            }
                            Keys.onRightPressed: function(event) {
                                if (root.entryCount() === 0)
                                    return
                                if (cursorPosition < text.length || selectionStart !== selectionEnd)
                                    return
                                root.handleArrowKey(1, 0, event)
                            }
                            Keys.onUpPressed: function(event) {
                                root.handleArrowKey(0, -1, event)
                            }
                            Keys.onDownPressed: function(event) {
                                root.handleArrowKey(0, 1, event)
                            }
                            Keys.onReturnPressed: event.accepted = true
                            Keys.onEnterPressed: event.accepted = true
                            Keys.onTabPressed: function(event) {
                                root.focusGrid()
                                event.accepted = true
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
                        anchors.leftMargin: 42
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !searchField.text && !searchField.activeFocus
                        text: root.screen === "episodes" ? "Search episodes…" : "Search films and TV…"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        opacity: 0.35
                    }
                }

                Text {
                    text: scanProc.running ? "Scanning…" : "Scan library"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: Theme.fontBold
                    opacity: scanProc.running ? 0.5 : (scanLinkMouse.containsMouse ? 1 : 0.8)

                    MouseArea {
                        id: scanLinkMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !scanProc.running
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.startLibraryScan()
                    }
                }
            }

            Text {
                visible: root.dbMissing || root.statusText !== ""
                text: root.dbMissing ? "Run scan library to index media" : root.statusText
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 14
                opacity: 0.7
            }

            Flickable {
                id: browseFlickable
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !root.dbMissing && root.screen === "browse"
                clip: true
                contentWidth: width
                contentHeight: browseFlow.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Flow {
                    id: browseFlow
                    width: parent.width
                    spacing: root.gridSpacing

                    Repeater {
                        model: root.browseEntries

                        delegate: Item {
                            required property var modelData
                            required property int index

                            width: tile.width
                            height: tile.height

                            PosterTile {
                                id: tile
                                tileIndex: parent.index
                                section: parent.modelData.section
                                item: parent.modelData.item
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: !root.loading && root.browseEntries.length === 0
                    text: {
                        if (root.normalizeQuery(root.searchQuery))
                            return "No matches"
                        if (root.films.length === 0 && root.shows.length === 0)
                            return "Nothing indexed"
                        return "No matches"
                    }
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    opacity: 0.45
                }
            }

            Flickable {
                id: episodeFlickable
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !root.dbMissing && root.screen === "episodes"
                clip: true
                contentWidth: width
                contentHeight: episodeFlow.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Flow {
                    id: episodeFlow
                    width: parent.width
                    spacing: root.gridSpacing

                    Repeater {
                        model: root.filteredEpisodes

                        delegate: Item {
                            required property var modelData
                            required property int index

                            width: tile.width
                            height: tile.height

                            PosterTile {
                                id: tile
                                tileIndex: parent.index
                                section: "episodes"
                                item: parent.modelData
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: !root.loading && root.filteredEpisodes.length === 0
                    text: root.normalizeQuery(root.searchQuery) ? "No matching episodes" : "No episodes"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    opacity: 0.45
                }
            }
        }
    }
}
