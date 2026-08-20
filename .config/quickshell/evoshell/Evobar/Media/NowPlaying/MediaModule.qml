import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../../Commons"

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
    readonly property string mediaScript: (Quickshell.env("HOME") || "") + "/.local/bin/evo-bar-library"
    readonly property string cacheKey: "evo.bar.media.now-playing"

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

    property real positionTick: 0

    readonly property var allPlayers: {
        var values = Mpris.players.values
        return values ? values : []
    }

    function mprisPlayerActive(candidate) {
        if (!candidate)
            return false
        if (candidate.playbackState === MprisPlaybackState.Stopped)
            return false
        if (String(candidate.trackTitle || "").trim() !== "")
            return true
        if (candidate.isPlaying)
            return true
        return candidate.playbackState === MprisPlaybackState.Paused
    }

    function mprisCanStop(player) {
        if (!player)
            return false
        return player.canControl || player.canPause || player.canTogglePlaying
    }

    function mprisPlaybackLabel(player) {
        if (!player)
            return ""
        if (player.isPlaying)
            return "Playing"
        if (player.playbackState === MprisPlaybackState.Paused)
            return "Paused"
        return "Stopped"
    }

    readonly property var activeMediaFeeds: {
        var _ = root.positionTick
        var feeds = []
        var list = allPlayers
        var i
        for (i = 0; i < list.length; i++) {
            var player = list[i]
            if (root.mprisPlayerActive(player))
                feeds.push({ kind: "mpris", player: player })
        }
        feeds.sort(function(a, b) {
            var aPlaying = a.player.isPlaying ? 0 : 1
            var bPlaying = b.player.isPlaying ? 0 : 1
            if (aPlaying !== bPlaying)
                return aPlaying - bPlaying
            return String(a.player.identity || "").localeCompare(String(b.player.identity || ""))
        })
        if (root.evoPlayerHasTrack)
            feeds.push({ kind: "evo" })
        return feeds
    }

    readonly property bool anyFeedPlaying: {
        var list = allPlayers
        var i
        for (i = 0; i < list.length; i++) {
            if (list[i] && list[i].isPlaying)
                return true
        }
        return root.evoPlayerPlaying
    }

    readonly property string evoPlayerScript: (Quickshell.env("HOME") || "") + "/.local/bin/evo-player"
    readonly property var evoPlayerMonitor: shell ? shell.serviceFor("evo.panel.player.monitor") : null
    readonly property var evoPlayerStatus: evoPlayerMonitor && evoPlayerMonitor.player
        ? evoPlayerMonitor.player
        : ({})
    readonly property bool evoPlayerHasTrack: String(evoPlayerStatus.path || "") !== ""
    readonly property bool evoPlayerPlaying: String(evoPlayerStatus.state || "") === "playing"
    readonly property bool evoPlayerPaused: String(evoPlayerStatus.state || "") === "paused"

    readonly property real evoTrackProgress: {
        var dur = Number(evoPlayerStatus.duration) || 0
        if (dur <= 0)
            return 0
        return Math.max(0, Math.min(1, Number(evoPlayerStatus.position) || 0) / dur)
    }
    readonly property string evoArtUrl: {
        var art = String(evoPlayerStatus.art || "")
        return art ? Util.fileUrl(art) : ""
    }

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

    function onActivated() {
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
        shell.summon("evo.bar.media.library", JSON.stringify(payload))
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

    function toggleMprisPlayback(mprisPlayer) {
        if (mprisPlayer && mprisPlayer.canTogglePlaying)
            mprisPlayer.togglePlaying()
    }

    function toggleEvoPlayback() {
        Quickshell.execDetached(["bash", evoPlayerScript, "toggle"])
    }

    function evoPlayerPrevious() {
        Quickshell.execDetached(["bash", evoPlayerScript, "prev"])
    }

    function evoPlayerNext() {
        Quickshell.execDetached(["bash", evoPlayerScript, "next"])
    }

    function openEvoPlayerDashboard() {
        if (!shell)
            return
        shell.summon("evo.panel.player", "")
    }

    function stopEvoPlayerPlayback() {
        Quickshell.execDetached(["bash", evoPlayerScript, "stop"])
    }

    function stopMprisPlayback(mprisPlayer) {
        if (!mprisPlayer)
            return
        if (mprisPlayer.canControl) {
            mprisPlayer.stop()
            return
        }
        if (mprisPlayer.canPause && mprisPlayer.isPlaying) {
            mprisPlayer.pause()
            return
        }
        if (mprisPlayer.canTogglePlaying && mprisPlayer.isPlaying)
            mprisPlayer.togglePlaying()
    }

    function raiseMprisPlayer(mprisPlayer) {
        if (mprisPlayer && mprisPlayer.canRaise)
            mprisPlayer.raise()
    }

    Timer {
        interval: 250
        running: root.active && root.anyFeedPlaying
        repeat: true
        onTriggered: {
            var list = root.allPlayers
            for (var i = 0; i < list.length; i++) {
                if (list[i] && list[i].isPlaying)
                    list[i].positionChanged()
            }
            root.positionTick = Date.now()
        }
    }

    ColumnLayout {
        id: column
        width: root.hoverPopupWidth
        spacing: Theme.hoverPopupSectionSpacing

        Repeater {
            model: root.activeMediaFeeds

            PlayingFeedPanel {
                required property var modelData
                feed: modelData
            }
        }

        SectionPanel {
            label: ""

            HoverPopupLabelPill {
                text: "TV/Film"
                icon: "󰿯"
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

        component PlayingFeedPanel: SectionPanel {
            id: feedPanel
            property var feed: ({})
            readonly property bool isMpris: feed && feed.kind === "mpris"
            readonly property bool isEvo: feed && feed.kind === "evo"
            readonly property var mprisPlayer: isMpris ? feed.player : null
            readonly property bool feedPlaying: isMpris
                ? (mprisPlayer && mprisPlayer.isPlaying)
                : root.evoPlayerPlaying
            readonly property real feedProgress: {
                if (isMpris && mprisPlayer) {
                    var _ = root.positionTick
                    var len = mprisPlayer.lengthSupported ? mprisPlayer.length : 0
                    if (len <= 0)
                        return 0
                    return Math.max(0, Math.min(1, mprisPlayer.position / len))
                }
                if (isEvo)
                    return root.evoTrackProgress
                return 0
            }
            readonly property string feedArtUrl: isMpris
                ? String(mprisPlayer ? mprisPlayer.trackArtUrl || "" : "")
                : root.evoArtUrl
            readonly property string feedTitle: isMpris
                ? String(mprisPlayer ? mprisPlayer.trackTitle || "Unknown track" : "")
                : String(root.evoPlayerStatus.title || "Unknown track")
            readonly property string feedArtist: isMpris
                ? String(mprisPlayer
                    ? mprisPlayer.trackArtist || mprisPlayer.trackAlbumArtist || ""
                    : "")
                : String(root.evoPlayerStatus.artist || "")
            readonly property string feedAlbum: isMpris
                ? String(mprisPlayer ? mprisPlayer.trackAlbum || "" : "")
                : ""
            readonly property string feedSourceLine: {
                if (isMpris && mprisPlayer)
                    return String(mprisPlayer.identity || "Media player")
                        + " · "
                        + root.mprisPlaybackLabel(mprisPlayer)
                if (isEvo)
                    return "EvoPlayer · "
                        + (root.evoPlayerPlaying
                            ? "Playing"
                            : (root.evoPlayerPaused ? "Paused" : "Stopped"))
                return ""
            }
            readonly property string feedTimeLine: isEvo
                ? String(root.evoPlayerStatus.position_label || "0:00")
                    + " / "
                    + String(root.evoPlayerStatus.duration_label || "0:00")
                : ""
            readonly property bool feedCanStop: isMpris
                ? root.mprisCanStop(mprisPlayer)
                : true

            label: ""

            HoverPopupLabelPill {
                text: "Playing"
                icon: "󰎈"
                fontSize: Theme.fontSizeS
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: feedRow.implicitHeight

                RowLayout {
                    id: feedRow
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
                            visible: feedPanel.feedArtUrl === ""
                        }

                        Image {
                            anchors.fill: parent
                            visible: feedPanel.feedArtUrl !== ""
                            source: feedPanel.feedArtUrl
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: true
                            layer.enabled: true
                            layer.smooth: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: feedPanel.feedArtUrl === ""
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
                            text: feedPanel.feedTitle
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
                            visible: feedPanel.feedArtist !== ""
                            text: feedPanel.feedArtist
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: 0.82
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: feedPanel.feedAlbum !== ""
                            text: feedPanel.feedAlbum
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: Theme.opacityMuted
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: feedPanel.isMpris
                            text: feedPanel.feedSourceLine
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: Theme.opacitySecondary
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: feedPanel.isEvo
                            text: feedPanel.feedTimeLine
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: feedPanel.isMpris
                        ? (feedPanel.mprisPlayer && feedPanel.mprisPlayer.canTogglePlaying)
                        : true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (feedPanel.isMpris)
                            root.toggleMprisPlayback(feedPanel.mprisPlayer)
                        else
                            root.toggleEvoPlayback()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 4
                radius: Theme.radiusS
                color: Theme.foregroundDivider

                Rectangle {
                    width: parent.width * feedPanel.feedProgress
                    height: parent.height
                    radius: Theme.radiusS
                    color: Theme.accent
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: feedPanel.isMpris
                        ? (feedPanel.mprisPlayer && feedPanel.mprisPlayer.canTogglePlaying)
                        : false
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.toggleMprisPlayback(feedPanel.mprisPlayer)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingM

                Text {
                    text: "󰒮"
                    color: Theme.foreground
                    opacity: 0.85
                    font.family: Theme.fontFamily
                    font.pixelSize: root.iconFont
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (feedPanel.isMpris && feedPanel.mprisPlayer)
                                feedPanel.mprisPlayer.previous()
                            else
                                root.evoPlayerPrevious()
                        }
                    }
                }

                Text {
                    text: feedPanel.feedPlaying ? "󰏤" : "󰐊"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize6xl
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (feedPanel.isMpris)
                                root.toggleMprisPlayback(feedPanel.mprisPlayer)
                            else
                                root.toggleEvoPlayback()
                        }
                    }
                }

                Text {
                    text: "󰒭"
                    color: Theme.foreground
                    opacity: 0.85
                    font.family: Theme.fontFamily
                    font.pixelSize: root.iconFont
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (feedPanel.isMpris && feedPanel.mprisPlayer)
                                feedPanel.mprisPlayer.next()
                            else
                                root.evoPlayerNext()
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "󰍉"
                    color: Theme.foreground
                    opacity: 0.75
                    font.family: Theme.fontFamily
                    font.pixelSize: root.iconFont
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (feedPanel.isMpris)
                                root.raiseMprisPlayer(feedPanel.mprisPlayer)
                            else
                                root.openEvoPlayerDashboard()
                        }
                    }
                }

                Text {
                    text: "󰓛"
                    color: Theme.urgent
                    opacity: feedPanel.feedCanStop ? 0.85 : 0.35
                    font.family: Theme.fontFamily
                    font.pixelSize: root.iconFont
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        enabled: feedPanel.feedCanStop
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (feedPanel.isMpris)
                                root.stopMprisPlayback(feedPanel.mprisPlayer)
                            else
                                root.stopEvoPlayerPlayback()
                        }
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

                        readonly property bool hovered: posterMouse.containsMouse

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

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.fieldsetCornerRadius
                                    color: Theme.accent
                                    opacity: hovered ? 0.12 : 0
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.fieldsetCornerRadius
                                    color: "transparent"
                                    border.width: hovered ? 2 : 1
                                    border.color: hovered ? Theme.accent : Theme.foregroundDivider
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: posterGrid.showLabels
                                text: root.itemLabel(modelData)
                                color: hovered ? Theme.accent : Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.hintFont
                                font.bold: Theme.fontBold
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        MouseArea {
                            id: posterMouse
                            anchors.fill: parent
                            hoverEnabled: true
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
