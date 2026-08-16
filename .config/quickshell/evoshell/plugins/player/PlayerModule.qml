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

    Connections {
        target: root.host
        ignoreUnknownSignals: true
        function onOpenedChanged() {
            if (root.active)
                root.loadPlaylists()
        }
    }

    readonly property string musicScript: (Quickshell.env("HOME") || "") + "/.local/bin/evo-music"
    readonly property int pad: Theme.hoverPopupMargin
    readonly property int bodyFont: Theme.hoverPopupBodyFontPixelSize
    readonly property int hintFont: Theme.hoverPopupHintFontPixelSize
    readonly property int titleFont: bodyFont + 6
    readonly property int nowPlayingArtSize: nowPlayingPanel.height > 0
        ? Math.max(160, Math.min(
            nowPlayingPanel.height,
            Math.round(Math.max(0, nowPlayingPanel.width - 16) * 0.42)))
        : 320
    readonly property int nowPlayingTitleFont: bodyFont + 10
    property var waveformSamples: []
    readonly property int iconFont: Theme.hoverPopupIconFontPixelSize
    readonly property int transportIconFont: iconFont * 2
    readonly property int libraryFont: Math.max(9, hintFont - 3)
    readonly property int pathFont: Math.max(8, libraryFont - 1)
    readonly property int genreTabHeight: 34
    readonly property bool playerPlaying: String(player.state || "") === "playing"
    readonly property real progress: player.duration > 0
        ? Math.max(0, Math.min(1, player.position / player.duration))
        : 0

    property var genres: []
    property var tracks: []
    property int selectedTrackIndex: -1
    property var player: ({})
    property var libraryStats: ({ tracks: 0, genres: 0 })
    property bool jobBusy: false
    property string jobLabel: ""
    property string jobLog: ""
    property bool genrePickerOpen: false
    property bool retagBusy: false
    property bool tracksLoading: false
    property string browsePath: ""
    property string browseParent: ""
    property var browseEntries: []
    property bool browseLoading: false
    property string browseForPath: ""
    property var playlists: []
    property string selectedPlaylist: ""
    property bool playlistsLoading: false
    property string resumePlaylist: ""
    property string playerScreen: "nowPlaying"
    property int volumeApplyTarget: 100
    property bool volumeApplyPending: false
    property bool playbackStatePending: false
    property string playbackStateTarget: ""
    readonly property int screenStackIndex:
        playerScreen === "nowPlaying" ? 0
        : (playerScreen === "library" ? 1
        : (playerScreen === "browse" ? 2 : 3))
    readonly property int libraryPanelWidth: Math.round(Math.max(156, Math.min(width * 0.22, 220)))

    function artUrl(path) {
        if (!path) return ""
        if (path.startsWith("file://")) return path
        return Util.fileUrl(path)
    }

    function notify(body, durationMs) {
        if (!shell) return
        var notif = shell.serviceFor("evo.notifications")
        if (notif && typeof notif.showBrief === "function")
            notif.showBrief("evo.player", String(body || ""), durationMs || 3000)
    }

    function formatJobLog(text) {
        if (!text)
            return ""
        return String(text).replace(/\r\n/g, "\n").replace(/\r/g, "\n")
    }

    function syncJobLog() {
        var parts = []
        var err = jobErr.text ? formatJobLog(jobErr.text) : ""
        var out = jobOut.text ? formatJobLog(jobOut.text) : ""
        if (err)
            parts.push(err)
        if (out)
            parts.push(out)
        if (parts.length)
            jobLog = parts.join("\n")
    }

    function runJob(args, label) {
        if (jobBusy) {
            notify("busy — " + jobLabel, 2000)
            return
        }
        jobBusy = true
        jobLabel = label
        jobLog = label + "…\n"
        playerScreen = "library"
        jobProc.command = ["bash", musicScript].concat(args || [])
        notify(label + "…", 2000)
        jobProc.running = true
    }

    function onJobFinished(exitCode) {
        syncJobLog()
        var label = jobLabel
        jobBusy = false
        jobLabel = ""
        if (exitCode === 0) {
            notify(label + " complete", 4000)
            loadGenres()
            loadLibraryStats()
            loadPlaylists()
            if (playerScreen === "browse")
                loadBrowse(browsePath)
            if (playerScreen === "playlists" && selectedPlaylist)
                loadPlaylistTracks(selectedPlaylist)
            jobLog = jobLog + "\n\n" + label + " complete"
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

    function runPlaylistQuery(args, onDone) {
        if (playlistQueryProc.running) {
            Qt.callLater(function() { runPlaylistQuery(args, onDone) })
            return
        }
        playlistQueryProc.command = ["bash", musicScript].concat(args || [])
        playlistQueryProc._onDone = onDone || null
        playlistQueryProc.running = true
    }

    function applyPlaylists(list) {
        var filtered = []
        for (var j = 0; j < list.length; j++) {
            if (list[j].name !== "favorites")
                filtered.push(list[j])
        }
        playlists = filtered
        playlistTabModel.clear()
        for (var k = 0; k < filtered.length; k++) {
            playlistTabModel.append({
                name: filtered[k].name,
                count: filtered[k].count || 0
            })
        }
    }

    function onActivated() {
        if (!runQuery(["player", "open", "--json"], function(text) {
            try {
                var saved = JSON.parse(String(text || "{}"))
                resumePlaylist = root.normalizePlaylistName(saved.playlist || "")
                applyStatus(text)
            } catch (e) {
                resumePlaylist = ""
            }
            loadGenres()
            loadPlaylists()
        }))
            Qt.callLater(onActivated)
        statusTimer.start()
        saveStateTimer.start()
    }

    function onDeactivated() {
        statusTimer.stop()
        saveStateTimer.stop()
        if (volumeApplyPending) {
            volumeApplyTimer.stop()
            volumeSettleTimer.stop()
            flushVolumeApply()
        }
        if (playbackStatePending) {
            playbackToggleTimer.stop()
            playbackSettleTimer.stop()
            finishPlaybackSettle()
        }
        runMusic(["player", "stop"], null, cmdProc)
        playerScreen = "nowPlaying"
        player = {}
        waveformSamples = []
    }

    function loadGenres() {
        if (!runQuery(["genres", "--json"], function(text) {
            try {
                genres = JSON.parse(String(text || "[]"))
            } catch (e) {
                genres = []
            }
            loadLibraryStats()
        }))
            Qt.callLater(loadGenres)
    }

    function normalizePlaylistName(name) {
        var n = String(name || "")
        return n === "favorites" ? "all" : n
    }

    function loadPlaylists() {
        playlistsLoading = true
        runPlaylistQuery(["playlist", "--json"], function(text) {
            playlistsLoading = false
            try {
                applyPlaylists(JSON.parse(String(text || "[]")))
            } catch (e) {
                applyPlaylists([])
            }
            var preferred = normalizePlaylistName(resumePlaylist)
            resumePlaylist = ""
            if (preferred) {
                for (var i = 0; i < playlists.length; i++) {
                    if (playlists[i].name === preferred) {
                        selectPlaylist(preferred, false)
                        return
                    }
                }
            }
            syncPlaylistTabPosition()
        })
    }

    function syncPlaylistTabPosition() {
        if (!playlistTabBar || playlistTabModel.count === 0 || !selectedPlaylist)
            return
        for (var i = 0; i < playlistTabModel.count; i++) {
            if (playlistTabModel.get(i).name === selectedPlaylist) {
                playlistTabBar.positionViewAtIndex(i, ListView.Center)
                return
            }
        }
    }

    function openBrowse() {
        playerScreen = "browse"
        loadBrowse(browsePath)
    }

    function loadBrowse(relPath) {
        var requested = String(relPath || "")
        browseForPath = requested
        browseLoading = true
        if (!runQuery(["browse", requested, "--json"], function(text) {
            if (root.browseForPath !== requested)
                return
            browseLoading = false
            try {
                var data = JSON.parse(String(text || "{}"))
                browsePath = String(data.path || "")
                browseParent = data.parent === null || data.parent === undefined
                    ? ""
                    : String(data.parent || "")
                browseEntries = data.entries || []
                syncBrowseTracks()
            } catch (e) {
                browseEntries = []
                tracks = []
            }
        }))
            Qt.callLater(function() { loadBrowse(relPath) })
    }

    function syncBrowseTracks() {
        var audio = []
        for (var i = 0; i < browseEntries.length; i++) {
            if (browseEntries[i].type === "track")
                audio.push(browseEntries[i])
        }
        tracks = audio
        syncSelectedTrackIndex()
    }

    function browseEnter(entry) {
        if (!entry)
            return
        if (entry.type === "dir")
            loadBrowse(entry.path)
        else if (entry.type === "track")
            playBrowseTrack(entry)
    }

    function browseUp() {
        loadBrowse(browseParent)
    }

    function selectBrowseTrack(entry) {
        if (!entry || !entry.path)
            return
        for (var i = 0; i < tracks.length; i++) {
            if (tracks[i].path === entry.path) {
                selectedTrackIndex = i
                return
            }
        }
        selectedTrackIndex = -1
    }

    function playBrowseTrack(entry) {
        if (!entry || !entry.path)
            return
        selectBrowseTrack(entry)
        playPath(entry.path)
    }

    function browseTrackNumber(listIndex) {
        var n = 0
        for (var i = 0; i < browseEntries.length && i <= listIndex; i++) {
            if (browseEntries[i].type === "track")
                n++
        }
        return n
    }

    function isTrackPlaying(path) {
        return String(player.path || "") === String(path || "")
    }

    function isTrackSelected(path) {
        if (isTrackPlaying(path))
            return true
        if (selectedTrackIndex < 0 || selectedTrackIndex >= tracks.length)
            return false
        return tracks[selectedTrackIndex].path === path
    }

    function selectPlaylist(name, switchScreen) {
        selectedPlaylist = normalizePlaylistName(name)
        syncPlaylistTabPosition()
        if (switchScreen !== false)
            playerScreen = "playlists"
        loadPlaylistTracks(selectedPlaylist)
    }

    function loadPlaylistTracks(name) {
        if (!name) {
            tracks = []
            tracksLoading = false
            return
        }
        var requested = String(name)
        tracksLoading = true
        runPlaylistQuery(["playlist", requested, "--json"], function(text) {
            if (selectedPlaylist !== requested)
                return
            tracksLoading = false
            try {
                tracks = JSON.parse(String(text || "[]"))
            } catch (e) {
                tracks = []
            }
            syncSelectedTrackIndex()
            mergePlayerFromTrackList()
        })
    }

    function syncSelectedTrackIndex() {
        if (!player.path || !tracks.length)
            return
        var path = String(player.path)
        for (var i = 0; i < tracks.length; i++) {
            if (tracks[i].path === path) {
                selectedTrackIndex = i
                if (playerScreen !== "playlists")
                    return
                var idx = i
                Qt.callLater(function() {
                    if (playlistTrackList && playlistTrackList.count > idx)
                        playlistTrackList.positionViewAtIndex(idx, ListView.Center)
                })
                return
            }
        }
    }

    function browseLabel() {
        if (!browsePath)
            return "Library"
        return browsePath.split("/").join(" / ")
    }

    function refreshStatus() {
        if (!active)
            return
        pollStatus(applyStatus)
    }

    function pollStatus(onDone) {
        if (statusQueryProc.running)
            return false
        statusQueryProc.command = ["bash", musicScript, "player", "status", "--json"]
        statusQueryProc._onDone = onDone || applyStatus
        statusQueryProc.running = true
        return true
    }

    function trackMetaForPath(path) {
        var p = String(path || "")
        for (var i = 0; i < tracks.length; i++) {
            if (tracks[i].path === p)
                return tracks[i]
        }
        for (var j = 0; j < browseEntries.length; j++) {
            if (browseEntries[j].type === "track" && browseEntries[j].path === p)
                return browseEntries[j]
        }
        return null
    }

    function primePlayerForPath(path) {
        var t = trackMetaForPath(path)
        if (!t)
            return
        player = Object.assign({}, player, {
            path: String(path),
            title: t.title || "",
            artist: t.artist || "",
            genre: t.genre || "",
            state: "playing"
        })
    }

    function togglePlayback() {
        var target = playerPlaying ? "paused" : "playing"
        previewPlaybackState(target)
        queuePlaybackState(target)
        sendPlaybackToggle()
    }

    function previewPlaybackState(state) {
        var next = Object.assign({}, player)
        next.state = state
        player = next
    }

    function queuePlaybackState(target) {
        playbackStateTarget = target
        playbackStatePending = true
        playbackSettleTimer.restart()
    }

    function sendPlaybackToggle() {
        if (!playbackStatePending)
            return
        if (cmdProc.running) {
            playbackToggleTimer.restart()
            return
        }
        runMusic(["player", "toggle"], null, cmdProc)
    }

    function finishPlaybackSettle() {
        playbackStatePending = false
        playbackStateTarget = ""
    }

    function mergePlayerFromTrackList() {
        if (!player.path || !tracks.length)
            return
        var path = String(player.path)
        for (var i = 0; i < tracks.length; i++) {
            if (tracks[i].path !== path)
                continue
            var t = tracks[i]
            var next = Object.assign({}, player)
            if (t.title)
                next.title = t.title
            if (t.artist)
                next.artist = t.artist
            if (t.genre)
                next.genre = t.genre
            player = next
            return
        }
    }

    function applyStatus(text) {
        var prevPath = String(player.path || "")
        var parsed
        try {
            parsed = JSON.parse(String(text || "{}"))
        } catch (e) {
            parsed = {}
        }
        if (volumeApplyPending) {
            var reported = Number(parsed.volume !== undefined ? parsed.volume : volumeApplyTarget)
            if (Math.abs(reported - volumeApplyTarget) <= 1) {
                volumeApplyPending = false
                volumeSettleTimer.stop()
            } else {
                parsed = Object.assign({}, parsed, { volume: volumeApplyTarget })
            }
        }
        if (playbackStatePending && playbackStateTarget) {
            var reportedState = String(parsed.state || "")
            if (reportedState === playbackStateTarget) {
                playbackStatePending = false
                playbackStateTarget = ""
                playbackSettleTimer.stop()
            } else {
                parsed = Object.assign({}, parsed, { state: playbackStateTarget })
            }
        }
        player = parsed
        if (String(player.path || "") !== prevPath)
            waveformSamples = []
        mergePlayerFromTrackList()
    }

    function applyWaveform(text) {
        try {
            var wf = JSON.parse(String(text || "{}"))
            var raw = wf.data || []
            var ch = wf.channels || 1
            var out = []
            if (ch >= 2) {
                for (var i = 0; i < raw.length; i += 2)
                    out.push(Math.max(Number(raw[i]) || 0, Number(raw[i + 1]) || 0))
            } else {
                for (var j = 0; j < raw.length; j++)
                    out.push(Number(raw[j]) || 0)
            }
            waveformSamples = out
        } catch (e) {
            waveformSamples = []
        }
        if (waveCanvas)
            waveCanvas.requestPaint()
    }

    function seekFromX(x, width) {
        if (!player.duration || width <= 0) return
        var ratio = Math.max(0, Math.min(1, x / width))
        runMusic(["player", "seek", String(ratio * player.duration)], refreshStatus, cmdProc)
    }

    function previewVolume(percent) {
        var v = Math.max(0, Math.min(100, Math.round(percent)))
        var next = Object.assign({}, player)
        next.volume = v
        player = next
    }

    function queueVolumeApply(target) {
        volumeApplyTarget = Math.max(0, Math.min(100, Math.round(target)))
        volumeApplyPending = true
        volumeSettleTimer.stop()
        volumeApplyTimer.restart()
    }

    function flushVolumeApply() {
        if (!volumeApplyPending)
            return
        if (cmdProc.running) {
            volumeApplyTimer.restart()
            return
        }
        runMusic(["player", "volume", "set", String(volumeApplyTarget)], null, cmdProc)
        volumeSettleTimer.restart()
    }

    function finishVolumeSettle() {
        if (!volumeApplyPending)
            return
        volumeApplyPending = false
    }

    function adjustVolume(delta) {
        if (!delta) return
        var cur = Number(player.volume !== undefined ? player.volume : 100)
        var next = Math.max(0, Math.min(100, Math.round(cur + Number(delta))))
        previewVolume(next)
        queueVolumeApply(next)
    }

    function setVolume(percent) {
        var v = Math.max(0, Math.min(100, Math.round(percent)))
        previewVolume(v)
        queueVolumeApply(v)
    }

    function toggleVolumeMute() {
        var cur = Number(player.volume !== undefined ? player.volume : 100)
        setVolume(cur <= 0 ? 100 : 0)
    }

    function volumeIcon(level) {
        var v = Number(level || 0)
        if (v <= 0) return "󰝟"
        if (v < 34) return "󰕿"
        if (v < 67) return "󰖀"
        return "󰕾"
    }

    function startLoad(path) {
        if (!path)
            return
        loadProc.command = ["bash", musicScript, "player", "load", path]
        loadProc.running = true
    }

    function playPath(path) {
        if (!path)
            return
        primePlayerForPath(path)
        if (loadProc.running) {
            loadProc.pendingPath = String(path)
            return
        }
        startLoad(path)
    }

    function playTrackAt(index) {
        if (index < 0 || index >= tracks.length)
            return
        var path = tracks[index].path
        if (!path)
            return
        selectedTrackIndex = index
        playPath(path)
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
            loadPlaylists()
            if (playerScreen === "browse")
                loadBrowse(browsePath)
            if (playerScreen === "playlists" && selectedPlaylist)
                loadPlaylistTracks(selectedPlaylist)
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
        stdout: StdioCollector {
            id: jobOut
            waitForEnd: false
        }
        stderr: StdioCollector {
            id: jobErr
            waitForEnd: false
        }
        onExited: function(exitCode) {
            root.onJobFinished(exitCode)
        }
    }

    Timer {
        id: jobLogTimer
        interval: 100
        repeat: true
        running: root.jobBusy
        onTriggered: root.syncJobLog()
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
        id: loadProc
        property string pendingPath: ""
        stdout: StdioCollector {}
        onExited: function() {
            root.refreshStatus()
            if (pendingPath) {
                var next = pendingPath
                pendingPath = ""
                root.startLoad(next)
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
        id: playlistQueryProc
        property var _onDone: null
        stdout: StdioCollector {
            onStreamFinished: {
                if (playlistQueryProc._onDone)
                    playlistQueryProc._onDone(text)
            }
        }
        onExited: playlistQueryProc._onDone = null
    }

    ListModel {
        id: playlistTabModel
    }

    Process {
        id: statusQueryProc
        property var _onDone: null
        stdout: StdioCollector {
            onStreamFinished: {
                if (statusQueryProc._onDone)
                    statusQueryProc._onDone(text)
                statusQueryProc._onDone = null
            }
        }
        onExited: statusQueryProc._onDone = null
    }

    FileView {
        id: waveformFile
        path: (root.player.path && root.player.waveform && root.active) ? String(root.player.waveform) : ""
        watchChanges: true
        onLoaded: root.applyWaveform(text())
        onLoadFailed: root.applyWaveform("")
    }

    Timer {
        id: statusTimer
        interval: 500
        repeat: true
        onTriggered: root.refreshStatus()
    }

    Timer {
        id: saveStateTimer
        interval: 10000
        repeat: true
        onTriggered: root.runMusic(["player", "save"], null, cmdProc)
    }

    Timer {
        id: volumeApplyTimer
        interval: 450
        repeat: false
        onTriggered: root.flushVolumeApply()
    }

    Timer {
        id: volumeSettleTimer
        interval: 1500
        repeat: false
        onTriggered: root.finishVolumeSettle()
    }

    Timer {
        id: playbackToggleTimer
        interval: 80
        repeat: false
        onTriggered: root.sendPlaybackToggle()
    }

    Timer {
        id: playbackSettleTimer
        interval: 1500
        repeat: false
        onTriggered: root.finishPlaybackSettle()
    }

    ColumnLayout {
        id: rootLayout
        anchors.fill: parent
        anchors.margins: pad
        spacing: pad

        // Tabs
        SectionPanel {
            label: ""
            Layout.fillWidth: true
            fillHeight: false

            RowLayout {
                id: tabBarHost
                Layout.fillWidth: true
                Layout.preferredHeight: root.genreTabHeight
                spacing: 8

                IconTab {
                    icon: "󰎈"
                    active: root.playerScreen === "nowPlaying"
                    onActivated: root.playerScreen = "nowPlaying"
                }
                IconTab {
                    icon: "󰠮"
                    active: root.playerScreen === "library"
                    onActivated: root.playerScreen = "library"
                }
                IconTab {
                    icon: "󰉋"
                    active: root.playerScreen === "browse"
                    onActivated: root.openBrowse()
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: Math.max(12, root.genreTabHeight - 16)
                    Layout.alignment: Qt.AlignVCenter
                    color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.14)
                }

                Item {
                    id: playlistTabBarHost
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: playlistTabBar
                        anchors.fill: parent
                        orientation: ListView.Horizontal
                        spacing: 6
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: playlistTabModel

                        onCountChanged: Qt.callLater(root.syncPlaylistTabPosition)
                        Component.onCompleted: root.syncPlaylistTabPosition()

                        delegate: Item {
                            required property int index
                            required property string name
                            required property int count
                            width: playlistTabContent.implicitWidth + 20
                            height: root.genreTabHeight

                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: root.playerScreen === "playlists" && root.selectedPlaylist === name
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
                                    : (playlistTabMouse.containsMouse
                                        ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.06)
                                        : "transparent")
                            }

                            Row {
                                id: playlistTabContent
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: name
                                    color: root.playerScreen === "playlists" && root.selectedPlaylist === name ? Theme.accent : Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.hintFont
                                    font.bold: root.playerScreen === "playlists" && root.selectedPlaylist === name && Theme.fontBold
                                    opacity: root.playerScreen === "playlists" && root.selectedPlaylist === name ? 1 : 0.78
                                }

                                Text {
                                    text: String(count || 0)
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.libraryFont
                                    opacity: 0.45
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: playlistTabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectPlaylist(name)
                            }
                        }
                    }
                }
            }
        }

        // Now playing / tracklist
        StackLayout {
            id: screenStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            currentIndex: root.screenStackIndex

            SectionPanel {
                label: ""
                Layout.fillWidth: true
                Layout.fillHeight: true
                fillHeight: true

                Item {
                    id: nowPlayingPanel
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    RowLayout {
                        anchors.fill: parent
                        spacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: root.player.title || "No track"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.nowPlayingTitleFont
                        font.bold: Theme.fontBold
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: root.player.artist || "—"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: 0.55
                            elide: Text.ElideRight
                            Layout.maximumWidth: parent.width * 0.45
                        }

                        Text {
                            text: "·"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: 0.35
                        }

                        Text {
                            id: metaGenre
                            text: root.player.genre || "—"
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: root.retagBusy ? 0.45 : 0.8
                            elide: Text.ElideRight
                            Layout.fillWidth: true

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !root.retagBusy && (root.player.path || "") !== ""
                                onClicked: root.genrePickerOpen = !root.genrePickerOpen
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.selectedPlaylist !== ""
                        text: "From playlist: " + root.selectedPlaylist
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.libraryFont
                        opacity: 0.45
                    }

                    Flow {
                        Layout.fillWidth: true
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

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 96

                        Canvas {
                            id: waveCanvas
                            anchors.fill: parent
                            anchors.rightMargin: 56
                            property real playProgress: root.progress
                            property var wfData: root.waveformSamples

                            onPlayProgressChanged: requestPaint()
                            onWfDataChanged: requestPaint()
                            onWidthChanged: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                var mid = height / 2
                                var prog = playProgress
                                var samples = root.waveformSamples
                                var n = samples.length

                                if (n === 0) {
                                    var trackH = 3
                                    var trackY = mid - trackH / 2
                                    ctx.fillStyle = Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.1)
                                    ctx.fillRect(0, trackY, width, trackH)
                                    if (prog > 0) {
                                        ctx.fillStyle = Theme.accent
                                        ctx.fillRect(0, trackY, width * prog, trackH)
                                    }
                                    return
                                }

                                var barCount = Math.max(96, Math.min(280, Math.floor(width / 2)))
                                var peaks = []
                                if (n <= barCount) {
                                    barCount = n
                                    for (var bi = 0; bi < n; bi++)
                                        peaks.push(Number(samples[bi]) || 0)
                                } else {
                                    var step = n / barCount
                                    for (var b = 0; b < barCount; b++) {
                                        var start = Math.floor(b * step)
                                        var end = Math.floor((b + 1) * step)
                                        var peak = 0
                                        for (var j = start; j < end && j < n; j++)
                                            peak = Math.max(peak, Number(samples[j]) || 0)
                                        peaks.push(peak)
                                    }
                                }

                                var barW = width / barCount
                                var gap = Math.min(2, Math.max(0.5, barW * 0.22))
                                var maxAmp = height * 0.46
                                var playX = width * prog

                                for (var i = 0; i < barCount; i++) {
                                    var amp = Math.max(2, (peaks[i] / 255) * maxAmp)
                                    var x = i * barW + gap * 0.5
                                    var w = Math.max(1, barW - gap)
                                    var played = (x + w * 0.5) <= playX

                                    ctx.fillStyle = played
                                        ? Theme.accent
                                        : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.18)
                                    ctx.globalAlpha = played ? 0.95 : 0.5
                                    ctx.fillRect(x, mid - amp, w, amp * 2)
                                }
                                ctx.globalAlpha = 1

                                if (prog > 0) {
                                    ctx.fillStyle = Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.95)
                                    ctx.fillRect(Math.max(0, playX - 1), 2, 2, height - 4)
                                }
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -14
                            text: root.player.position_label || "0:00"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.libraryFont
                            opacity: 0.7
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: 14
                            text: root.player.duration_label || "0:00"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.libraryFont
                            opacity: 0.7
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                root.seekFromX(mouse.x, width)
                            }
                        }
                    }
                }

                Item {
                    Layout.preferredWidth: root.nowPlayingArtSize
                    Layout.preferredHeight: root.nowPlayingArtSize
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        id: coverFrame
                        anchors.fill: parent
                        radius: 16
                        clip: true
                        color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)

                        Image {
                            id: coverImage
                            anchors.fill: parent
                            visible: (root.player.art || "") !== "" && status === Image.Ready
                            source: root.artUrl(root.player.art)
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: true
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
                    }
                }
            }
            }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: pad

                SectionPanel {
                    label: root.jobBusy ? root.jobLabel : (root.jobLog !== "" ? "log" : "Library log")
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    fillHeight: true

                    Flickable {
                        id: jobLogScroll
                        anchors.fill: parent
                        clip: true
                        contentWidth: width
                        contentHeight: jobLogText.height
                        boundsBehavior: Flickable.StopAtBounds

                        Text {
                            id: jobLogText
                            width: jobLogScroll.width
                            text: root.jobLog || (root.jobBusy ? (root.jobLabel + "…") : "run a library task to see output here")
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.libraryFont
                            opacity: 0.75
                            wrapMode: Text.Wrap
                        }

                        onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
                    }

                    Connections {
                        target: root
                        function onJobLogChanged() {
                            jobLogScroll.contentY = Math.max(0, jobLogScroll.contentHeight - jobLogScroll.height)
                        }
                    }
                }

                SectionPanel {
                    label: "Library"
                    Layout.preferredWidth: root.libraryPanelWidth
                    Layout.minimumWidth: 148
                    Layout.fillHeight: true
                    fillHeight: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: root.jobBusy
                                ? root.jobLabel + "…"
                                : (root.libraryStats.tracks || 0) + " tracks · " + (root.libraryStats.genres || 0) + " genres"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.libraryFont
                            opacity: root.jobBusy ? 0.9 : 0.55
                            wrapMode: Text.Wrap
                        }

                        LibraryBtn {
                            icon: "󰕧"
                            label: "sync soundcloud"
                            dimmed: root.jobBusy
                            onActivated: if (!root.jobBusy) root.runJob(["soundcloud"], "sync soundcloud")
                        }
                        LibraryBtn {
                            icon: "󰋋"
                            label: "import incoming"
                            dimmed: root.jobBusy
                            onActivated: if (!root.jobBusy) root.runJob(["import"], "import incoming")
                        }
                        LibraryBtn {
                            icon: "󰲹"
                            label: "rebuild library"
                            dimmed: root.jobBusy
                            onActivated: if (!root.jobBusy) root.runJob(["rebuild"], "rebuild library")
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }

            SectionPanel {
                label: ""
                Layout.fillWidth: true
                Layout.fillHeight: true
                fillHeight: true

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            TransportBtn {
                                icon: "󰁍"
                                compact: true
                                visible: root.browsePath !== ""
                                onActivated: root.browseUp()
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.browseLabel()
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.libraryFont
                                opacity: 0.55
                                elide: Text.ElideRight
                            }
                        }

                        ListView {
                            id: browseList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 2
                            model: root.browseEntries

                            Text {
                                anchors.centerIn: parent
                                visible: root.browseLoading && root.browseEntries.length === 0
                                text: "loading…"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.hintFont
                                opacity: 0.45
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !root.browseLoading && root.browseEntries.length === 0
                                text: "empty folder"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.hintFont
                                opacity: 0.45
                            }

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: browseList.width
                                height: 40
                                radius: 4
                                color: modelData.type === "dir"
                                    ? (browseMouse.containsMouse
                                        ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.05)
                                        : "transparent")
                                    : (root.isTrackPlaying(modelData.path)
                                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
                                        : (browseMouse.containsMouse
                                            ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.05)
                                            : "transparent"))

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 10
                                    visible: modelData.type === "dir"

                                    Text {
                                        text: "󰉋"
                                        color: Theme.foreground
                                        opacity: 0.55
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.libraryFont + 2
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.hintFont
                                        elide: Text.ElideRight
                                        opacity: 0.85
                                    }

                                    Text {
                                        text: String(modelData.count || "")
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.libraryFont
                                        opacity: 0.45
                                    }
                                }

                                TrackListRow {
                                    anchors.fill: parent
                                    visible: modelData.type === "track"
                                    rowWidth: browseList.width
                                    track: modelData
                                    number: root.browseTrackNumber(index)
                                    selected: root.isTrackSelected(modelData.path)
                                    onPressed: root.selectBrowseTrack(modelData)
                                    onActivated: root.playBrowseTrack(modelData)
                                }

                                MouseArea {
                                    id: browseMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    visible: modelData.type === "dir"
                                    onClicked: root.browseEnter(modelData)
                                }
                            }
                        }
                    }
                }
            }

            SectionPanel {
                label: root.selectedPlaylist !== "" ? root.selectedPlaylist : "Playlist"
                Layout.fillWidth: true
                Layout.fillHeight: true
                fillHeight: true

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: playlistTrackList
                        anchors.fill: parent
                        clip: true
                        spacing: 2
                        model: root.tracks

                        Text {
                            anchors.centerIn: parent
                            visible: root.playlistsLoading && root.playlists.length === 0
                            text: "loading…"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: 0.45
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: root.tracksLoading && root.selectedPlaylist !== ""
                            text: "loading…"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: 0.45
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !root.playlistsLoading && root.selectedPlaylist === ""
                            text: "select a playlist"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: 0.45
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !root.tracksLoading && root.tracks.length === 0 && root.selectedPlaylist !== ""
                            text: "no tracks"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: 0.45
                        }

                        delegate: TrackListRow {
                            required property var modelData
                            required property int index
                            rowWidth: playlistTrackList.width
                            track: modelData
                            number: index + 1
                            selected: root.isTrackSelected(modelData.path)
                            onPressed: root.selectedTrackIndex = index
                            onActivated: root.playTrackAt(index)
                        }
                        }
                }
            }
        }

        // Bottom control bar — pinned full width
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
                        Layout.fillWidth: true
                        spacing: 24

                        Item { Layout.fillWidth: true }

                        TransportBtn { icon: "󰒮"; onActivated: root.runMusic(["player", "prev"], root.refreshStatus, cmdProc) }
                        TransportBtn {
                            icon: root.playerPlaying ? "󰏤" : "󰐊"
                            accent: true
                            onActivated: root.togglePlayback()
                        }
                        TransportBtn { icon: "󰒭"; onActivated: root.runMusic(["player", "next"], root.refreshStatus, cmdProc) }
                        TransportBtn {
                            icon: "󰒟"
                            dimmed: !root.player.shuffle
                            onActivated: root.runMusic(["player", "shuffle", "toggle"], root.refreshStatus, cmdProc)
                        }

                        TransportBtn {
                            icon: "󰋑"
                            compact: true
                            liked: !!root.player.liked
                            onActivated: root.toggleFavorite()
                        }
                        VolumeTransportBtn {}

                        Item { Layout.fillWidth: true }
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

            }
        }
    }

    component VolumeTransportBtn: Item {
        id: volBtn
        readonly property int level: Math.round(root.player.volume !== undefined ? root.player.volume : 100)
        property bool wheelPopupActive: false
        readonly property bool popupVisible: volHover.containsMouse || sliderArea.pressed || wheelPopupActive

        width: Math.max(volIcon.implicitWidth + 16, 36)
        height: Math.max(volIcon.implicitHeight + 16, 36)

        function nudgeVolume(delta) {
            if (!delta)
                return
            wheelPopupActive = true
            popupHideTimer.restart()
            root.adjustVolume(delta)
        }

        function handleWheel(wheel) {
            if (!wheel.angleDelta.y)
                return
            nudgeVolume(wheel.angleDelta.y > 0 ? 5 : -5)
            wheel.accepted = true
        }

        Timer {
            id: popupHideTimer
            interval: 1600
            repeat: false
            onTriggered: volBtn.wheelPopupActive = false
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
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleVolumeMute()
            onWheel: function(wheel) { volBtn.handleWheel(wheel) }
        }

        Item {
            visible: popupVisible
            z: 10
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: 8
            width: 44
            height: 152

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: Theme.mantle
                border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.18)
                border.width: 1
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: volBtn.level + "%"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: root.hintFont - 1
                    font.bold: Theme.fontBold
                }

                Item {
                    id: sliderHost
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96

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
                        id: volThumb
                        anchors.horizontalCenter: volTrack.horizontalCenter
                        anchors.bottom: volTrack.bottom
                        anchors.bottomMargin: (volTrack.height - height) * (volBtn.level / 100)
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
                            volBtn.wheelPopupActive = true
                            popupHideTimer.restart()
                            root.setVolume(volumeAt(mouse.y))
                        }

                        onPositionChanged: function(mouse) {
                            if (pressed) {
                                volBtn.wheelPopupActive = true
                                popupHideTimer.restart()
                                root.setVolume(volumeAt(mouse.y))
                            }
                        }

                        onWheel: function(wheel) { volBtn.handleWheel(wheel) }
                    }
                }
            }
        }
    }

    component TrackListRow: Rectangle {
        id: trackRow
        property var track: ({})
        property int number: 0
        property bool selected: false
        property int rowWidth: 0
        signal pressed()
        signal activated()

        width: rowWidth
        height: 40
        radius: 4
        color: selected
            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
            : (trackRowMouse.containsMouse
                ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.05)
                : "transparent")

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 10

            Item {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    clip: true
                    color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)
                    visible: !trackArt.visible
                }

                Text {
                    anchors.centerIn: parent
                    visible: !trackArt.visible
                    text: "󰎈"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    opacity: 0.35
                }

                Image {
                    id: trackArt
                    anchors.fill: parent
                    visible: status === Image.Ready
                    source: (trackRow.track.art || "") !== "" ? root.artUrl(trackRow.track.art) : ""
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                    layer.enabled: true
                    layer.smooth: true
                }
            }

            Text {
                text: String(trackRow.number)
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFont
                font.bold: Theme.fontBold
            }

            Text {
                text: "·"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFont
                opacity: 0.35
            }

            Text {
                Layout.maximumWidth: Math.min(180, trackRow.rowWidth * 0.28)
                text: trackRow.track.artist || "—"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFont
                opacity: 0.65
                elide: Text.ElideRight
            }

            Text {
                text: "·"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFont
                opacity: 0.35
            }

            Text {
                Layout.fillWidth: true
                text: trackRow.track.title || ""
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFont
                elide: Text.ElideRight
                opacity: trackRow.selected ? 1 : 0.9
            }
        }

        MouseArea {
            id: trackRowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: trackRow.pressed()
            onDoubleClicked: trackRow.activated()
        }
    }

    component IconTab: Item {
        id: iconTab
        property string icon: ""
        property bool active: false
        signal activated()

        implicitWidth: root.genreTabHeight
        implicitHeight: root.genreTabHeight
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: iconTab.active
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
                : (iconTabMouse.containsMouse
                    ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.06)
                    : "transparent")
        }

        Text {
            anchors.centerIn: parent
            text: iconTab.icon
            color: iconTab.active ? Theme.accent : Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: root.iconFont + 4
            opacity: iconTab.active ? 1 : 0.78
        }

        MouseArea {
            id: iconTabMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: iconTab.activated()
        }
    }

    component LibraryBtn: Item {
        id: libBtn
        property string icon: ""
        property string label: ""
        property bool accent: false
        property bool dimmed: false
        signal activated()

        implicitWidth: libRow.implicitWidth + 8
        implicitHeight: libRow.implicitHeight + 4

        Row {
            id: libRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: libBtn.icon
                color: accent ? Theme.accent : Theme.foreground
                opacity: dimmed ? 0.35 : 0.9
                font.family: Theme.fontFamily
                font.pixelSize: root.libraryFont + 2
            }

            Text {
                text: libBtn.label
                color: accent ? Theme.accent : Theme.foreground
                opacity: dimmed ? 0.35 : (libMouse.containsMouse ? 1 : 0.78)
                font.family: Theme.fontFamily
                font.pixelSize: root.libraryFont
                font.bold: accent && Theme.fontBold
            }
        }

        MouseArea {
            id: libMouse
            anchors.fill: parent
            anchors.margins: -4
            enabled: !dimmed
            hoverEnabled: true
            cursorShape: dimmed ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: libBtn.activated()
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
}
