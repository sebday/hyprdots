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

    property MprisPlayer trackedPlayer: null
    property real positionTick: 0

    readonly property var allPlayers: {
        var values = Mpris.players.values
        return values ? values : []
    }

    readonly property string evoPlayerScript: (Quickshell.env("HOME") || "") + "/.local/bin/evo-player"
    readonly property var evoPlayerMonitor: shell ? shell.serviceFor("evo.panel.player.monitor") : null
    readonly property var evoPlayerStatus: evoPlayerMonitor && evoPlayerMonitor.player
        ? evoPlayerMonitor.player
        : ({})
    readonly property bool evoPlayerHasTrack: String(evoPlayerStatus.path || "") !== ""
    readonly property bool evoPlayerPlaying: String(evoPlayerStatus.state || "") === "playing"
    readonly property bool evoPlayerPaused: String(evoPlayerStatus.state || "") === "paused"

    readonly property MprisPlayer player: trackedPlayer
    readonly property bool hasMprisPlayer: player !== null
    readonly property bool mprisPlaying: hasMprisPlayer && player.isPlaying
    readonly property real mprisPosition: {
        if (!hasMprisPlayer)
            return 0
        var _ = positionTick
        return player.position
    }
    readonly property real mprisLength: hasMprisPlayer && player.lengthSupported ? player.length : 0
    readonly property real mprisProgress: mprisLength > 0
        ? Math.max(0, Math.min(1, mprisPosition / mprisLength))
        : 0
    readonly property string mprisTitle: hasMprisPlayer
        ? String(player.trackTitle || "Unknown track")
        : ""
    readonly property string mprisArtist: hasMprisPlayer
        ? String(player.trackArtist || player.trackAlbumArtist || "")
        : ""
    readonly property string mprisAlbum: hasMprisPlayer
        ? String(player.trackAlbum || "")
        : ""
    readonly property string mprisArtUrl: hasMprisPlayer ? String(player.trackArtUrl || "") : ""
    readonly property string mprisPlayerName: hasMprisPlayer
        ? String(player.identity || "Media player")
        : ""
    readonly property string mprisPlaybackLabel: {
        if (!hasMprisPlayer)
            return ""
        if (player.isPlaying)
            return "Playing"
        if (player.playbackState === MprisPlaybackState.Paused)
            return "Paused"
        return "Stopped"
    }
    readonly property bool mprisCanToggle: hasMprisPlayer && player.canTogglePlaying
    readonly property bool mprisCanPrevious: hasMprisPlayer && player.canGoPrevious
    readonly property bool mprisCanNext: hasMprisPlayer && player.canGoNext

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

    function toggleMprisPlayback() {
        if (player && player.canTogglePlaying)
            player.togglePlaying()
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

    function openEvoplayerDashboard() {
        if (!shell)
            return
        shell.summon("evo.panel.player", "")
    }

    function stopEvoplayerPlayback() {
        Quickshell.execDetached(["bash", evoPlayerScript, "stop"])
    }

    function stopMprisPlayback() {
        if (player && player.canQuit)
            player.quit()
        else if (player && player.canTogglePlaying && player.isPlaying)
            player.togglePlaying()
    }

    function raiseMprisPlayer() {
        if (player && player.canRaise)
            player.raise()
    }

    Timer {
        interval: 250
        running: root.active && (root.mprisPlaying || root.evoPlayerPlaying)
        repeat: true
        onTriggered: {
            if (root.hasMprisPlayer && root.player)
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

            HoverPopupLabelPill {
                text: "Now playing"
                icon: "󰎈"
                fontSize: Theme.fontSizeS
            }

            Item {
                Layout.fillWidth: true
                visible: root.hasMprisPlayer
                implicitHeight: mprisRow.implicitHeight

                RowLayout {
                    id: mprisRow
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
                            visible: root.mprisArtUrl === ""
                        }

                        Image {
                            anchors.fill: parent
                            visible: root.mprisArtUrl !== ""
                            source: root.mprisArtUrl
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: true
                            layer.enabled: true
                            layer.smooth: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: root.mprisArtUrl === ""
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
                            text: root.mprisTitle
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
                            visible: root.mprisArtist !== ""
                            text: root.mprisArtist
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: 0.82
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.mprisAlbum !== ""
                            text: root.mprisAlbum
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: Theme.opacityMuted
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.mprisPlayerName + " · " + root.mprisPlaybackLabel
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
                    enabled: root.mprisCanToggle
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.toggleMprisPlayback()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 4
                radius: Theme.radiusS
                color: Theme.foregroundDivider
                visible: root.hasMprisPlayer

                Rectangle {
                    width: parent.width * root.mprisProgress
                    height: parent.height
                    radius: Theme.radiusS
                    color: Theme.accent
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.mprisCanToggle
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.toggleMprisPlayback()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingM
                visible: root.hasMprisPlayer

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
                        onClicked: { if (root.player) root.player.previous() }
                    }
                }

                Text {
                    text: root.mprisPlaying ? "󰏤" : "󰐊"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize6xl
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMprisPlayback()
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
                        onClicked: { if (root.player) root.player.next() }
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
                        onClicked: root.raiseMprisPlayer()
                    }
                }

                Text {
                    text: "󰓛"
                    color: Theme.urgent
                    opacity: 0.85
                    font.family: Theme.fontFamily
                    font.pixelSize: root.iconFont
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stopMprisPlayback()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !root.hasMprisPlayer
                text: "Nothing playing"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.bodyFont
                opacity: Theme.opacityMuted
            }

            Repeater {
                model: root.allPlayers.length > 1 ? root.allPlayers : []

                Item {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: mprisPlayerRow.implicitHeight

                    RowLayout {
                        id: mprisPlayerRow
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

        SectionPanel {
            label: ""

            HoverPopupLabelPill {
                text: "Evoplayer"
                icon: "󰎈"
                fontSize: Theme.fontSizeS
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: root.evoPlayerHasTrack

                Item {
                    Layout.preferredWidth: root.artSize
                    Layout.preferredHeight: root.artSize

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.fieldsetCornerRadius
                        color: Theme.foregroundFaint
                        visible: root.evoArtUrl === ""
                    }

                    Image {
                        anchors.fill: parent
                        visible: root.evoArtUrl !== ""
                        source: root.evoArtUrl
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing2

                    Text {
                        Layout.fillWidth: true
                        text: String(evoPlayerStatus.title || "Unknown track")
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.nowPlayingTitleFont
                        font.bold: Theme.fontBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: String(evoPlayerStatus.artist || "") !== ""
                        text: String(evoPlayerStatus.artist || "")
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                        opacity: 0.82
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: String(evoPlayerStatus.position_label || "0:00")
                            + " / "
                            + String(evoPlayerStatus.duration_label || "0:00")
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 4
                radius: Theme.radiusS
                color: Theme.foregroundDivider
                visible: root.evoPlayerHasTrack

                Rectangle {
                    width: parent.width * root.evoTrackProgress
                    height: parent.height
                    radius: Theme.radiusS
                    color: Theme.accent
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingM
                visible: root.evoPlayerHasTrack

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
                        onClicked: root.evoPlayerPrevious()
                    }
                }

                Text {
                    text: root.evoPlayerPlaying ? "󰏤" : "󰐊"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize6xl
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleEvoPlayback()
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
                        onClicked: root.evoPlayerNext()
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
                        onClicked: root.openEvoplayerDashboard()
                    }
                }

                Text {
                    text: "󰓛"
                    color: Theme.urgent
                    opacity: 0.85
                    font.family: Theme.fontFamily
                    font.pixelSize: root.iconFont
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stopEvoplayerPlayback()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !root.evoPlayerHasTrack
                text: "No track playing"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFont
                opacity: Theme.opacityMuted
            }

            Text {
                visible: !root.evoPlayerHasTrack
                text: "Open Evoplayer"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFont

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openEvoplayerDashboard()
                }
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
