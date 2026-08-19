import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPopupWidth: 0

    readonly property bool active: host && host.opened === true
    readonly property int bodyFont: Theme.fontSize3xl
    readonly property int nowPlayingTitleFont: Theme.fontSize2xl
    readonly property int hintFont: Theme.fontSizeL
    readonly property int iconFont: Theme.fontSize4xl
    readonly property string mediaScript: (Quickshell.env("HOME") || "") + "/.local/bin/evo-media"
    readonly property string cacheKey: "evo.media"

    property var mediaFilms: []
    property var mediaShows: []
    property bool mediaLoading: false
    readonly property bool contentReady: !mediaLoading

    readonly property int libraryGridCols: 4
    readonly property int popularLimit: 4
    readonly property int libraryTileSpacing: Theme.hoverPopupSectionSpacing

    readonly property var mostPopularItems: {
        var combined = []
        var i
        for (i = 0; i < mediaFilms.length; i++) {
            var film = mediaFilms[i]
            combined.push({
                id: film.id,
                name: film.name,
                poster_path: film.poster_path,
                play_count: Number(film.play_count) || 0,
                kind: "film"
            })
        }
        for (i = 0; i < mediaShows.length; i++) {
            var show = mediaShows[i]
            combined.push({
                id: show.id,
                name: show.name,
                poster_path: show.poster_path,
                play_count: Number(show.play_count) || 0,
                kind: "show"
            })
        }
        combined.sort(function(a, b) {
            var diff = (Number(b.play_count) || 0) - (Number(a.play_count) || 0)
            if (diff !== 0)
                return diff
            return String(a.name || "").localeCompare(String(b.name || ""))
        })
        return combined.slice(0, popularLimit)
    }

    property MprisPlayer trackedPlayer: null
    property real positionTick: 0

    readonly property var allPlayers: {
        var values = Mpris.players.values
        return values ? values : []
    }

    readonly property MprisPlayer player: trackedPlayer
    readonly property bool hasPlayer: player !== null
    readonly property bool playerPlaying: hasPlayer && player.isPlaying
    readonly property real trackPosition: {
        var _ = positionTick
        return hasPlayer ? player.position : 0
    }
    readonly property real trackLength: hasPlayer && player.lengthSupported ? player.length : 0
    readonly property real trackProgress: trackLength > 0
        ? Math.max(0, Math.min(1, trackPosition / trackLength))
        : 0
    readonly property string trackTitle: hasPlayer ? String(player.trackTitle || "Unknown track") : ""
    readonly property string trackArtist: hasPlayer ? String(player.trackArtist || player.trackAlbumArtist || "") : ""
    readonly property string trackAlbum: hasPlayer ? String(player.trackAlbum || "") : ""
    readonly property string trackArtUrl: hasPlayer ? String(player.trackArtUrl || "") : ""
    readonly property string playerName: hasPlayer ? String(player.identity || "Media player") : ""
    readonly property string playbackLabel: {
        if (!hasPlayer) return ""
        if (player.isPlaying) return "Playing"
        if (player.playbackState === MprisPlaybackState.Paused) return "Paused"
        return "Stopped"
    }
    readonly property string loopLabel: {
        if (!hasPlayer || !player.loopSupported) return ""
        if (player.loopState === MprisLoopState.Track) return "󰑖"
        if (player.loopState === MprisLoopState.Playlist) return "󰑐"
        return ""
    }
    readonly property bool shuffleOn: hasPlayer && player.shuffleSupported && player.shuffle

    readonly property int artSize: 64
    readonly property int posterWidth: Math.round(artSize * 36 / 54)

    readonly property int posterGridWidth: Math.max(0, hoverPopupWidth - Theme.hoverPopupContentPad * 2)

    readonly property int posterCellWidth: {
        if (posterGridWidth <= 0)
            return 72
        var gaps = (libraryGridCols - 1) * libraryTileSpacing
        return Math.floor((posterGridWidth - gaps) / libraryGridCols)
    }
    readonly property int posterHeight: Math.round(posterCellWidth * 3 / 2)

    readonly property int libraryNameHeight: hintFont + 6
    readonly property int libraryPlaceholderHeight: hintFont + 24

    implicitHeight: column.implicitHeight

    function playerInList(candidate, list) {
        if (!candidate || !list) return false
        for (var i = 0; i < list.length; i++) {
            if (list[i] === candidate) return true
        }
        return false
    }

    function onActivated() {
        refreshTrackedPlayer()
        loadMediaPreview()
    }

    function onDeactivated() {}

    function bootstrapFromCache() {
        if (!shell)
            return
        var cached = Util.hoverPopupCacheRead(shell, cacheKey)
        if (!cached || typeof cached !== "object")
            return
        if (Array.isArray(cached.films))
            mediaFilms = cached.films.slice()
        if (Array.isArray(cached.shows))
            mediaShows = cached.shows.slice()
    }

    function publishCache() {
        if (!shell)
            return
        Util.hoverPopupCacheWrite(shell, cacheKey, {
            films: mediaFilms,
            shows: mediaShows
        })
    }

    function openMediaLibrary(showName, tab) {
        if (!shell) return
        if (host && typeof host.close === "function")
            host.close()
        var payload = {}
        if (showName)
            payload.show = String(showName)
        if (tab)
            payload.tab = String(tab)
        shell.summon("evo.library", JSON.stringify(payload))
    }

    function openMediaShow(item) {
        if (!item || !item.name) return
        openMediaLibrary(item.name, "shows")
    }

    function openMediaFilm(item) {
        if (!item || item.id === undefined)
            return
        Quickshell.execDetached(["bash", root.mediaScript, "play", "film", String(item.id)])
    }

    function openPopularItem(item) {
        if (!item)
            return
        if (item.kind === "film")
            openMediaFilm(item)
        else
            openMediaShow(item)
    }

    function popularFallbackIcon(item) {
        if (item && item.kind === "show")
            return "󰖺"
        return "󰿯"
    }

    function loadMediaPreview() {
        if (mediaPopupProc.running)
            return
        mediaLoading = mediaFilms.length === 0 && mediaShows.length === 0
        mediaPopupProc.running = true
    }

    function itemLabel(item) {
        if (!item) return ""
        return String(item.name || item.title || "")
    }

    function showPoster(item) {
        if (!item) return ""
        var path = item.poster_path ? String(item.poster_path) : ""
        if (path.startsWith("file://"))
            path = decodeURIComponent(path.substring(7))
        path = path.replace("/.local/state/evo-shell/", "/.local/state/evoshell/")
        return path ? Util.fileUrl(path) : ""
    }

    function refreshTrackedPlayer() {
        var list = allPlayers
        if (!list || list.length === 0) {
            trackedPlayer = null
            return
        }
        for (var i = 0; i < list.length; i++) {
            if (list[i] && list[i].isPlaying) {
                trackedPlayer = list[i]
                return
            }
        }
        if (!trackedPlayer || !playerInList(trackedPlayer, list))
            trackedPlayer = list[0]
    }

    function formatTime(seconds) {
        var totalSec = Math.max(0, Math.floor(Number(seconds) || 0))
        var min = Math.floor(totalSec / 60)
        var sec = totalSec % 60
        return min + ":" + (sec < 10 ? "0" : "") + sec
    }

    function togglePlayback() {
        if (player && player.canTogglePlaying)
            player.togglePlaying()
    }

    Timer {
        interval: 250
        running: root.active && root.hasPlayer && root.playerPlaying
        repeat: true
        onTriggered: {
            if (root.player)
                root.player.positionChanged()
            root.positionTick = Date.now()
        }
    }

    Instantiator {
        model: Mpris.players

        Connections {
            required property MprisPlayer modelData
            target: modelData

            function onIsPlayingChanged() {
                if (modelData.isPlaying)
                    root.trackedPlayer = modelData
            }

            function onTrackTitleChanged() {
                if (modelData.isPlaying)
                    root.trackedPlayer = modelData
            }
        }
    }

    onActiveChanged: {
        if (active)
            refreshTrackedPlayer()
    }

    ColumnLayout {
        id: column
        width: root.hoverPopupWidth
        spacing: Theme.hoverPopupSectionSpacing

        SectionPanel {
            label: ""
            visible: root.hasPlayer

            HoverPopupLabelPill {
                text: "Now playing"
                icon: "󰎈"
                fontSize: Theme.fontSizeS
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: nowPlayingRow.implicitHeight

                RowLayout {
                    id: nowPlayingRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 12

                    Item {
                        Layout.preferredWidth: root.artSize
                        Layout.preferredHeight: root.artSize

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.fieldsetCornerRadius
                            color: Theme.foregroundFaint
                            visible: root.trackArtUrl === ""
                        }

                        Image {
                            anchors.fill: parent
                            visible: root.trackArtUrl !== ""
                            source: root.trackArtUrl
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: true
                            layer.enabled: true
                            layer.smooth: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: root.trackArtUrl === ""
                            text: "󰎈"
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: root.iconFont
                            opacity: 0.75
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacing2

                        Text {
                            Layout.fillWidth: true
                            text: root.trackTitle
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.nowPlayingTitleFont
                            font.bold: Theme.fontBold
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.trackArtist !== ""
                            text: root.trackArtist
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: 0.82
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.trackAlbum !== ""
                            text: root.trackAlbum
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: Theme.opacityMuted
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.playerName + " · " + root.playbackLabel
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: Theme.opacitySecondary
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.player && root.player.canTogglePlaying
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.togglePlayback()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingS
                visible: root.trackLength > 0 || root.playerPlaying

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusS
                        color: Theme.foregroundDivider
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        height: parent.height
                        width: parent.width * root.trackProgress
                        radius: Theme.radiusS
                        color: Theme.accent
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.player && root.player.canTogglePlaying
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.togglePlayback()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: root.formatTime(root.trackPosition)
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                        opacity: Theme.opacityHover
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        visible: root.loopLabel !== "" || root.shuffleOn
                        text: (root.shuffleOn ? "󰒟 " : "") + root.loopLabel
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                        opacity: Theme.opacityMuted
                    }

                    Text {
                        text: root.trackLength > 0 ? root.formatTime(root.trackLength) : ""
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                        opacity: Theme.opacityHover
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingM
                visible: root.hasPlayer && (root.player.canGoPrevious || root.player.canTogglePlaying || root.player.canGoNext)

                Item { Layout.fillWidth: true }

                Text {
                    text: "󰒮"
                    color: Theme.foreground
                    opacity: root.player && root.player.canGoPrevious ? 0.85 : 0.25
                    font.family: Theme.fontFamily
                    font.pixelSize: root.iconFont

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        enabled: root.player && root.player.canGoPrevious
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.player.previous()
                    }
                }

                Text {
                    text: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize6xl

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        enabled: root.player && root.player.canTogglePlaying
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.player.togglePlaying()
                    }
                }

                Text {
                    text: "󰒭"
                    color: Theme.foreground
                    opacity: root.player && root.player.canGoNext ? 0.85 : 0.25
                    font.family: Theme.fontFamily
                    font.pixelSize: root.iconFont

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        enabled: root.player && root.player.canGoNext
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.player.next()
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: !root.hasPlayer
            text: "Nothing playing"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: root.bodyFont
            opacity: Theme.opacityMuted
        }

        SectionPanel {
            label: ""
            visible: root.allPlayers.length > 1

            HoverPopupLabelPill {
                text: "Players"
                icon: "󰝚"
                fontSize: Theme.fontSizeS
            }

            Repeater {
                model: root.allPlayers

                Item {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: playerRow.implicitHeight

                    RowLayout {
                        id: playerRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: Theme.spacingM

                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 120
                            text: String(modelData.identity || "Player")
                            color: root.trackedPlayer === modelData ? Theme.accent : Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            font.bold: root.trackedPlayer === modelData
                            elide: Text.ElideRight
                            opacity: modelData.isPlaying ? 1 : 0.55
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                            text: modelData.isPlaying ? "Playing" : "Idle"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: Theme.opacityDisabled
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.trackedPlayer = modelData
                    }
                }
            }
        }

        component MediaPosterGrid: Item {
            id: posterGrid
            property var items: []
            property string emptyLabel: ""
            property string fallbackIcon: "󰿯"
            property bool showLabels: true
            property var iconForItem: function(item) { return posterGrid.fallbackIcon }
            property var itemActivated: null

            Layout.fillWidth: true
            implicitHeight: grid.visible
                ? grid.implicitHeight
                : root.libraryPlaceholderHeight

            Text {
                anchors.centerIn: parent
                width: parent.width
                visible: root.mediaLoading && posterGrid.items.length === 0
                text: "Loading…"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFont
                opacity: Theme.opacityMuted
            }

            Text {
                anchors.centerIn: parent
                width: parent.width
                visible: !root.mediaLoading && posterGrid.items.length === 0
                text: posterGrid.emptyLabel
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFont
                opacity: Theme.opacityMuted
            }

            GridLayout {
                id: grid
                width: root.posterCellWidth * root.libraryGridCols
                    + root.libraryTileSpacing * (root.libraryGridCols - 1)
                visible: posterGrid.items.length > 0
                columns: root.libraryGridCols
                columnSpacing: root.libraryTileSpacing
                rowSpacing: root.libraryTileSpacing

                Repeater {
                    model: posterGrid.items

                    Item {
                        required property var modelData
                        Layout.preferredWidth: root.posterCellWidth
                        Layout.maximumWidth: root.posterCellWidth
                        implicitHeight: posterCol.implicitHeight

                        ColumnLayout {
                            id: posterCol
                            width: root.posterCellWidth
                            spacing: 4

                            Item {
                                id: posterFrame
                                Layout.preferredWidth: root.posterCellWidth
                                Layout.preferredHeight: root.posterHeight

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.fieldsetCornerRadius
                                    color: Theme.foregroundFaint
                                    visible: showPosterImage.status !== Image.Ready
                                }

                                Image {
                                    id: showPosterImage
                                    anchors.fill: parent
                                    source: root.showPoster(modelData)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    asynchronous: true
                                    visible: status === Image.Ready
                                    layer.enabled: true
                                    layer.smooth: true
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: showPosterImage.status !== Image.Ready
                                    text: posterGrid.iconForItem(modelData)
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.hintFont
                                    opacity: 0.75
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: posterGrid.showLabels
                                text: root.itemLabel(modelData)
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.hintFont
                                font.bold: Theme.fontBold
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (posterGrid.itemActivated)
                                    posterGrid.itemActivated(modelData)
                            }
                        }
                    }
                }
            }
        }

        SectionPanel {
            label: ""
            visible: !root.mediaLoading

            HoverPopupLabelPill {
                text: "Most popular"
                icon: "󰕶"
                fontSize: Theme.fontSizeS
            }

            MediaPosterGrid {
                items: root.mostPopularItems
                emptyLabel: "No play history"
                fallbackIcon: "󰿯"
                showLabels: false
                iconForItem: root.popularFallbackIcon
                itemActivated: function(item) { root.openPopularItem(item) }
            }
        }
    }

    Process {
        id: mediaPopupProc
        command: ["bash", root.mediaScript, "popup", "preview"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.mediaLoading = false
                try {
                    var data = JSON.parse(String(text || "{}"))
                    root.mediaFilms = Array.isArray(data.films) ? data.films : []
                    root.mediaShows = Array.isArray(data.shows) ? data.shows : []
                } catch (e) {
                    root.mediaFilms = []
                    root.mediaShows = []
                }
                root.publishCache()
            }
        }
    }

    Component.onCompleted: bootstrapFromCache()
}
