import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var shell: null
    property var host: null

    readonly property bool active: host && host.opened === true
    readonly property string musicScript: (Quickshell.env("HOME") || "") + "/.local/bin/evo-music"
    readonly property int pad: Theme.hoverPopupMargin
    readonly property int bodyFont: Theme.hoverPopupBodyFontPixelSize
    readonly property int hintFont: Theme.hoverPopupHintFontPixelSize
    readonly property int titleFont: bodyFont + 6
    readonly property int nowPlayingArtSize: 384
    readonly property int iconFont: Theme.hoverPopupIconFontPixelSize
    readonly property int transportIconFont: iconFont * 2
    readonly property int libraryFont: Math.max(9, hintFont - 3)
    readonly property int pathFont: Math.max(8, libraryFont - 1)
    readonly property int sidebarWidth: Math.round(Math.max(168, Math.min(width * 0.28, 300)))
    readonly property real progress: player.duration > 0
        ? Math.max(0, Math.min(1, player.position / player.duration))
        : 0

    property var genres: []
    property var tracks: []
    property string selectedGenre: ""
    property int selectedTrackIndex: -1
    property var player: ({})
    property var libraryStats: ({ tracks: 0, genres: 0 })
    property bool jobBusy: false
    property string jobLabel: ""
    property bool genrePickerOpen: false
    property bool retagBusy: false
    property bool tracksLoading: false
    property string tracksForGenre: ""
    property string resumeGenre: ""

    function artUrl(path) {
        if (!path) return ""
        if (path.startsWith("file://")) return path
        return Util.fileUrl(path)
    }

    function notify(body, durationMs) {
        if (!shell) return
        var notif = shell.serviceFor("evo.notifications")
        if (notif && typeof notif.showBrief === "function")
            notif.showBrief("evo.music", String(body || ""), durationMs || 3000)
    }

    function runJob(args, label) {
        if (jobBusy) {
            notify("busy — " + jobLabel, 2000)
            return
        }
        jobBusy = true
        jobLabel = label
        jobProc.command = ["bash", musicScript].concat(args || [])
        notify(label + "…", 2000)
        jobProc.running = true
    }

    function onJobFinished(exitCode) {
        var label = jobLabel
        jobBusy = false
        jobLabel = ""
        if (exitCode === 0) {
            notify(label + " complete", 4000)
            loadGenres()
            loadLibraryStats()
            if (selectedGenre)
                loadTracks(selectedGenre)
        } else {
            var err = jobErr.text ? String(jobErr.text).trim() : ""
            if (err)
                err = err.split("\n").pop()
            notify(label + " failed" + (err ? " — " + err : ""), 5000)
        }
    }

    function loadLibraryStats() {
        runQuery(["status", "--json"], function(text) {
            try {
                libraryStats = JSON.parse(String(text || "{}"))
            } catch (e) {
                libraryStats = { tracks: 0, genres: 0 }
            }
        })
    }

    function runMusic(args, onDone, proc) {
        var runner = proc || cmdProc
        if (runner.running) return false
        runner.command = ["bash", musicScript].concat(args || [])
        runner._onDone = onDone || null
        runner.running = true
        return true
    }

    function runQuery(args, onDone) {
        if (queryProc.running) return false
        queryProc.command = ["bash", musicScript].concat(args || [])
        queryProc._onDone = onDone || null
        queryProc.running = true
        return true
    }

    function onActivated() {
        runMusic(["player", "start"], null, cmdProc)
        if (!runQuery(["player", "resume", "--json"], function(text) {
            try {
                var saved = JSON.parse(String(text || "{}"))
                resumeGenre = String(saved.genre || "")
            } catch (e) {
                resumeGenre = ""
            }
            loadGenres()
            refreshStatus()
        }))
            Qt.callLater(onActivated)
        statusTimer.start()
        saveStateTimer.start()
    }

    function onDeactivated() {
        statusTimer.stop()
        saveStateTimer.stop()
        runMusic(["player", "save"], null, cmdProc)
    }

    function loadGenres() {
        if (!runQuery(["genres", "--json"], function(text) {
            try {
                genres = JSON.parse(String(text || "[]"))
            } catch (e) {
                genres = []
            }
            loadLibraryStats()
            if (genres.length > 0 && !selectedGenre)
                selectGenre(genres[0].name)
        }))
            Qt.callLater(loadGenres)
    }

    function selectGenre(name) {
        selectedGenre = String(name || "")
        selectedTrackIndex = -1
        loadTracks(selectedGenre)
        runMusic(["player", "play", selectedGenre], refreshStatus, cmdProc)
    }

    function loadTracks(genre) {
        if (!genre) {
            tracks = []
            tracksLoading = false
            tracksForGenre = ""
            return
        }
        var requested = String(genre)
        tracksForGenre = requested
        tracksLoading = true
        if (!runQuery(["tracks", genre, "--json"], function(text) {
            if (root.tracksForGenre !== requested)
                return
            tracksLoading = false
            try {
                tracks = JSON.parse(String(text || "[]"))
            } catch (e) {
                tracks = []
            }
        }))
            Qt.callLater(function() { loadTracks(genre) })
    }

    function refreshStatus() {
        if (!active || statusProc.running) return
        statusProc.running = true
    }

    function applyStatus(text) {
        try {
            player = JSON.parse(String(text || "{}"))
        } catch (e) {
            player = {}
        }
    }

    function seekFromX(x, width) {
        if (!player.duration || width <= 0) return
        var ratio = Math.max(0, Math.min(1, x / width))
        runMusic(["player", "seek", String(ratio * player.duration)], refreshStatus, cmdProc)
    }

    function adjustVolume(delta) {
        if (!delta) return
        runMusic(["player", "volume", String(delta)], refreshStatus, cmdProc)
    }

    function setVolume(percent) {
        var v = Math.max(0, Math.min(100, Math.round(percent)))
        runMusic(["player", "volume", "set", String(v)], refreshStatus, cmdProc)
    }

    function volumeIcon(level) {
        var v = Number(level || 0)
        if (v <= 0) return "󰝟"
        if (v < 34) return "󰕿"
        if (v < 67) return "󰖀"
        return "󰕾"
    }

    function playTrackAt(index) {
        if (index < 0 || index >= tracks.length) return
        var path = tracks[index].path
        if (!path) return
        selectedTrackIndex = index
        runMusic(["player", "load", path], refreshStatus, cmdProc)
    }

    function toggleFavorite() {
        if (!player.path) return
        runMusic(["favorite", "toggle", player.path, "--json"], function(text) {
            try {
                var result = JSON.parse(String(text || "{}"))
                var next = Object.assign({}, player)
                next.liked = !!result.liked
                player = next
            } catch (e) {
            }
            refreshStatus()
        }, cmdProc)
    }

    function pathGenreFolder() {
        if (!player.path) return ""
        var p = String(player.path)
        var slash = p.lastIndexOf("/")
        if (slash <= 0) return ""
        var parent = p.substring(0, slash)
        var prev = parent.lastIndexOf("/")
        return prev >= 0 ? parent.substring(prev + 1) : parent
    }

    function retagToGenre(genre) {
        if (!player.path || retagBusy || !genre) return
        if (genre === pathGenreFolder()) {
            genrePickerOpen = false
            return
        }
        genrePickerOpen = false
        retagBusy = true
        retagProc.command = ["bash", musicScript, "retag", player.path, genre, "--json"]
        retagProc.running = true
    }

    function onRetagFinished(exitCode, stdout) {
        retagBusy = false
        if (exitCode !== 0) {
            var err = retagErr.text ? String(retagErr.text).trim() : ""
            if (err)
                err = err.split("\n").pop()
            notify("retag failed" + (err ? " — " + err : ""), 5000)
            return
        }
        try {
            var result = JSON.parse(String(stdout || "{}"))
            notify("moved to " + result.genre, 3000)
            loadGenres()
            loadLibraryStats()
            if (selectedGenre)
                loadTracks(selectedGenre)
            if (result.path)
                runMusic(["player", "load", result.path], refreshStatus, cmdProc)
        } catch (e) {
            notify("retag failed", 5000)
        }
    }

    Process {
        id: retagProc
        property string _stdout: ""
        stderr: StdioCollector { id: retagErr }
        stdout: StdioCollector {
            onStreamFinished: retagProc._stdout = String(text || "").trim()
        }
        onExited: function(exitCode) {
            root.onRetagFinished(exitCode, retagProc._stdout)
        }
    }

    Process {
        id: jobProc
        stderr: StdioCollector { id: jobErr }
        onExited: function(exitCode) {
            root.onJobFinished(exitCode)
        }
    }

    Process {
        id: cmdProc
        property var _onDone: null
        stdout: StdioCollector {
            onStreamFinished: {
                if (cmdProc._onDone)
                    cmdProc._onDone(text)
            }
        }
    }

    Process {
        id: queryProc
        property var _onDone: null
        stdout: StdioCollector {
            onStreamFinished: {
                if (queryProc._onDone)
                    queryProc._onDone(text)
            }
        }
    }

    Process {
        id: statusProc
        command: ["bash", root.musicScript, "player", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: root.applyStatus(text)
        }
    }

    Timer {
        id: statusTimer
        interval: 500
        repeat: true
        onTriggered: root.refreshStatus()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: pad
        spacing: pad

        // Now playing — full width
        SectionPanel {
            label: "Now playing"
            Layout.fillWidth: true

            Item {
                Layout.fillWidth: true
                implicitHeight: nowPlayingRow.implicitHeight

                RowLayout {
                    id: nowPlayingRow
                    anchors.fill: parent
                    spacing: 14

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        text: root.player.title || "No track"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.titleFont
                        font.bold: Theme.fontBold
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.player.artist || "—"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.bodyFont
                        opacity: 0.8
                        elide: Text.ElideRight
                    }

                    Item {
                        Layout.fillWidth: true
                        visible: (root.player.path || "") !== ""
                        implicitHeight: genreBlock.height

                        Column {
                            id: genreBlock
                            width: parent.width
                            spacing: 4

                            Text {
                                id: genreTag
                                width: parent.width
                                text: "# " + (root.player.genre || "—")
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: root.hintFont
                                opacity: root.retagBusy ? 0.5 : (genreTagMouse.containsMouse ? 1 : 0.9)

                                MouseArea {
                                    id: genreTagMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !root.retagBusy
                                    onClicked: root.genrePickerOpen = !root.genrePickerOpen
                                }
                            }

                            Flow {
                                width: parent.width
                                spacing: 4
                                visible: root.genrePickerOpen && !root.retagBusy

                                Repeater {
                                    model: root.genres

                                    delegate: Rectangle {
                                        required property var modelData
                                        height: 20
                                        width: genrePickLabel.width + 12
                                        radius: 3
                                        color: root.pathGenreFolder() === modelData.name
                                            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                                            : (genrePickMouse.containsMouse
                                                ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)
                                                : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.04))

                                        Text {
                                            id: genrePickLabel
                                            anchors.centerIn: parent
                                            text: modelData.name
                                            color: Theme.foreground
                                            font.family: Theme.fontFamily
                                            font.pixelSize: root.libraryFont
                                            opacity: 0.9
                                        }

                                        MouseArea {
                                            id: genrePickMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.retagToGenre(modelData.name)
                                        }
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                text: root.player.path || ""
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.pathFont
                                opacity: 0.4
                                elide: Text.ElideMiddle
                            }
                        }
                    }
                }

                Item {
                    Layout.preferredWidth: root.nowPlayingArtSize
                    Layout.preferredHeight: root.nowPlayingArtSize
                    Layout.alignment: Qt.AlignTop | Qt.AlignRight

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)
                        visible: !coverImage.visible
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !coverImage.visible
                        text: "󰎈"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(root.nowPlayingArtSize * 0.28)
                        opacity: 0.5
                    }

                    Image {
                        id: coverImage
                        anchors.fill: parent
                        visible: (root.player.art || "") !== "" && status === Image.Ready
                        source: root.artUrl(root.player.art)
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                        layer.enabled: true
                        layer.smooth: true
                    }
                }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: pad

                // Track list
                SectionPanel {
                    label: root.selectedGenre ? root.selectedGenre : "Tracks"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    fillHeight: true

                    ListView {
                        id: trackList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 1
                        model: root.tracks

                        Text {
                            anchors.centerIn: parent
                            visible: root.tracksLoading && root.tracks.length === 0
                            text: "loading…"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: 0.45
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !root.tracksLoading && root.tracks.length === 0 && root.selectedGenre !== ""
                            text: "no tracks"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: 0.45
                        }

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: trackList.width
                            height: 28
                            color: root.selectedTrackIndex === index
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
                                : (trackMouse.containsMouse
                                    ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.05)
                                    : "transparent")

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                text: (modelData.artist ? modelData.artist + " — " : "") + (modelData.title || "")
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.hintFont
                                elide: Text.ElideRight
                                opacity: root.selectedTrackIndex === index ? 1 : 0.85
                            }

                            MouseArea {
                                id: trackMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.playTrackAt(index)
                            }
                        }
                    }
                }

            // Sidebar: genres + library (right)
            ColumnLayout {
                Layout.preferredWidth: root.sidebarWidth
                Layout.minimumWidth: 148
                Layout.maximumWidth: Math.round(root.width * 0.4)
                Layout.fillHeight: true
                spacing: pad

                SectionPanel {
                    label: "Genres"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    fillHeight: true

                    ListView {
                        id: genreList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: root.genres

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: genreList.width
                            height: 30
                            radius: 4
                            color: root.selectedGenre === modelData.name
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
                                : (genreMouse.containsMouse
                                    ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.06)
                                    : "transparent")

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.hintFont
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: String(modelData.count || 0)
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.hintFont - 1
                                    opacity: 0.45
                                }
                            }

                            MouseArea {
                                id: genreMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectGenre(modelData.name)
                            }
                        }
                    }
                }

                SectionPanel {
                    label: "Library"
                    Layout.fillWidth: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: root.jobBusy
                                ? root.jobLabel + "…"
                                : (root.libraryStats.tracks || 0) + " tracks · " + (root.libraryStats.genres || 0) + " genres"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.libraryFont
                            opacity: root.jobBusy ? 0.9 : 0.55
                            elide: Text.ElideRight
                        }

                        SyncBtn {
                            icon: "󰕧"
                            label: "sync likes"
                            enabled: !root.jobBusy
                            onActivated: root.runJob(["sync"], "sync likes")
                        }

                        SyncBtn {
                            icon: "󰋋"
                            label: "import incoming"
                            enabled: !root.jobBusy
                            onActivated: root.runJob(["import"], "import")
                        }

                        SyncBtn {
                            icon: "󰲹"
                            label: "rebuild playlists"
                            enabled: !root.jobBusy
                            onActivated: root.runJob(["playlists"], "rebuild playlists")
                        }

                        SyncBtn {
                            icon: "󰝚"
                            label: "enrich art"
                            enabled: !root.jobBusy
                            onActivated: root.runJob(["enrich"], "enrich")
                        }

                        SyncBtn {
                            icon: "󰑐"
                            label: "refresh all"
                            accent: true
                            enabled: !root.jobBusy
                            onActivated: root.runJob(["refresh"], "refresh")
                        }
                    }
                }
            }
        }

        // Bottom control bar — full width
        SectionPanel {
            label: ""
            Layout.fillWidth: true

            Item {
                Layout.fillWidth: true
                implicitHeight: transportRow.implicitHeight

                RowLayout {
                    id: transportRow
                    anchors.fill: parent
                    spacing: 10

                    Text {
                        text: root.player.position_label || "0:00"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                        opacity: 0.65
                    }

                    Item { Layout.fillWidth: true; Layout.minimumWidth: 4 }

                    RowLayout {
                        spacing: 24

                    TransportBtn { icon: "󰒮"; onActivated: root.runMusic(["player", "prev"], root.refreshStatus, cmdProc) }
                    TransportBtn {
                        icon: root.player.state === "playing" ? "󰏤" : "󰐊"
                        accent: true
                        onActivated: root.runMusic(["player", "toggle"], root.refreshStatus, cmdProc)
                    }
                    TransportBtn { icon: "󰒭"; onActivated: root.runMusic(["player", "next"], root.refreshStatus, cmdProc) }
                    TransportBtn {
                        icon: "󰒟"
                        dimmed: !root.player.shuffle
                        onActivated: root.runMusic(["player", "shuffle", "toggle"], root.refreshStatus, cmdProc)
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 72
                        Layout.maximumWidth: 320
                        Layout.preferredHeight: 6
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: 3
                            color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.12)
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            height: parent.height
                            width: parent.width * root.progress
                            radius: 3
                            color: Theme.accent
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                root.seekFromX(mouse.x, width)
                            }
                        }
                    }

                    TransportBtn {
                        icon: "󰋑"
                        compact: true
                        liked: !!root.player.liked
                        onActivated: root.toggleFavorite()
                    }
                    VolumeTransportBtn {}
                    }

                    Item { Layout.fillWidth: true; Layout.minimumWidth: 4 }

                    Text {
                        text: root.player.duration_label || "0:00"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                        opacity: 0.65
                    }
                }

                VolumeWheel {
                    anchors.fill: parent
                }
            }
        }
    }

    component VolumeTransportBtn: Item {
        id: volBtn
        readonly property int level: Math.round(root.player.volume !== undefined ? root.player.volume : 100)
        readonly property bool popupVisible: volHover.containsMouse || sliderArea.pressed

        implicitWidth: volIcon.implicitWidth
        implicitHeight: volIcon.implicitHeight

        Item {
            visible: popupVisible
            z: 10
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: 10
            width: 40
            height: 132

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: Theme.mantle
                border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.18)
                border.width: 1
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: volBtn.level + "%"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: root.hintFont - 1
                    font.bold: Theme.fontBold
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Rectangle {
                        id: volTrack
                        anchors.centerIn: parent
                        width: 4
                        height: parent.height
                        radius: 2
                        color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.14)
                    }

                    Rectangle {
                        anchors.horizontalCenter: volTrack.horizontalCenter
                        anchors.bottom: volTrack.bottom
                        width: volTrack.width
                        height: volTrack.height * (volBtn.level / 100)
                        radius: 2
                        color: Theme.accent
                    }

                    Rectangle {
                        anchors.horizontalCenter: volTrack.horizontalCenter
                        anchors.verticalCenter: volTrack.top
                        anchors.verticalCenterOffset: volTrack.height * (1 - volBtn.level / 100)
                        width: 12
                        height: 12
                        radius: 6
                        color: Theme.accent
                        border.color: Theme.panelBackground
                        border.width: 2
                    }

                    MouseArea {
                        id: sliderArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.SizeVerCursor

                        function volumeAt(mouseY) {
                            var ratio = 1 - Math.max(0, Math.min(1, mouseY / height))
                            return Math.round(ratio * 100)
                        }

                        onPressed: function(mouse) {
                            root.setVolume(volumeAt(mouse.y))
                        }

                        onPositionChanged: function(mouse) {
                            if (pressed)
                                root.setVolume(volumeAt(mouse.y))
                        }
                    }
                }
            }
        }

        Text {
            id: volIcon
            anchors.centerIn: parent
            text: root.volumeIcon(volBtn.level)
            color: volBtn.level <= 0 ? Theme.foreground : Theme.accent
            opacity: volBtn.level <= 0 ? 0.45 : 0.9
            font.family: Theme.fontFamily
            font.pixelSize: root.transportIconFont
        }

        MouseArea {
            id: volHover
            anchors.fill: parent
            anchors.margins: -12
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setVolume(volBtn.level > 0 ? 0 : 100)
        }

        WheelHandler {
            onWheel: function(event) {
                if (!event.angleDelta.y)
                    return
                root.adjustVolume(event.angleDelta.y > 0 ? 5 : -5)
                event.accepted = true
            }
        }
    }

    component VolumeWheel: Item {
        property int step: 5

        WheelHandler {
            onWheel: function(event) {
                if (!event.angleDelta.y)
                    return
                root.adjustVolume(event.angleDelta.y > 0 ? parent.step : -parent.step)
                event.accepted = true
            }
        }
    }

    component TransportBtn: Text {
        id: btn
        property string icon: ""
        property bool accent: false
        property bool dimmed: false
        property bool compact: false
        property bool liked: false
        signal activated()
        text: icon
        color: liked ? Theme.urgent : (accent ? Theme.accent : Theme.foreground)
        opacity: dimmed ? 0.35 : (liked ? 1 : 0.9)
        font.family: Theme.fontFamily
        font.pixelSize: compact
            ? Math.round(root.transportIconFont * 0.72)
            : (root.transportIconFont + (accent ? 4 : 0))

        MouseArea {
            anchors.fill: parent
            anchors.margins: -12
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.activated()
        }
    }

    component SyncBtn: Item {
        id: syncBtn
        property string icon: ""
        property string label: ""
        property bool accent: false
        property bool enabled: true
        signal activated()
        Layout.fillWidth: true
        Layout.preferredHeight: root.libraryFont + 10

        RowLayout {
            anchors.fill: parent
            spacing: 6

            Text {
                text: syncBtn.icon
                color: accent ? Theme.accent : Theme.foreground
                opacity: enabled ? 0.9 : 0.35
                font.family: Theme.fontFamily
                font.pixelSize: root.libraryFont + 1
            }

            Text {
                Layout.fillWidth: true
                text: syncBtn.label
                color: accent ? Theme.accent : Theme.foreground
                opacity: enabled ? (syncMouse.containsMouse ? 1 : 0.78) : 0.35
                font.family: Theme.fontFamily
                font.pixelSize: root.libraryFont
                font.bold: accent && Theme.fontBold
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: syncMouse
            anchors.fill: parent
            anchors.margins: -2
            enabled: syncBtn.enabled
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: syncBtn.activated()
        }
    }
}
