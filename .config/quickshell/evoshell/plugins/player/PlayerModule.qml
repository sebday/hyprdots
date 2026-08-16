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
    readonly property string playerScript: (Quickshell.env("HOME") || "") + "/.local/bin/evo-player"
    readonly property int pad: Theme.hoverPopupMargin
    readonly property int bodyFont: Theme.hoverPopupBodyFontPixelSize
    readonly property int hintFont: Theme.hoverPopupHintFontPixelSize
    readonly property int titleFont: bodyFont + 6
    readonly property int nowPlayingArtWidth: nowPlayingPanel.height > 0
        ? Math.max(160, nowPlayingPanel.height)
        : 320
    readonly property int nowPlayingControlsHeight: 52
    readonly property int transportBtnSize: 36
    readonly property int nowPlayingTitleFont: bodyFont + 10
    property var waveformSamples: []
    readonly property int iconFont: Theme.hoverPopupIconFontPixelSize
    readonly property int transportIconFont: iconFont * 2
    readonly property int transportSecondaryIconFont: Math.round(transportIconFont * 0.74)
    readonly property int libraryFont: Math.max(9, hintFont - 3)
    readonly property int sectionLabelFont: Theme.hoverPopupLabelFontPixelSize
    readonly property int genreTabHeight: 34
    readonly property bool playerPlaying: String(player.state || "") === "playing"
    readonly property real progress: player.duration > 0
        ? Math.max(0, Math.min(1, player.position / player.duration))
        : 0
    readonly property int playerVolumePercent: volumeApplyPending
        ? volumeApplyTarget
        : Math.max(0, Math.min(100, Math.round(Number(player.volume !== undefined ? player.volume : 100))))
    property real volumeBarBoost: 0

    property var genres: []
    property var tracks: []
    property int selectedTrackIndex: -1
    property var player: ({})
    property var libraryStats: ({ tracks: 0, genres: 0 })
    property bool jobBusy: false
    property string jobLabel: ""
    property string jobLog: ""
    property bool externalJobBusy: false
    property string externalJobLabel: ""
    readonly property bool libraryJobBusy: jobBusy || externalJobBusy
    readonly property string libraryJobActiveLabel: jobBusy ? jobLabel : externalJobLabel
    readonly property bool buildBusy: libraryJobBusy && (libraryJobActiveLabel === "build library" || libraryJobActiveLabel === "warm cache")
    readonly property bool rebuildBusy: libraryJobBusy && libraryJobActiveLabel === "rebuild library"
    property bool tracksLoading: false
    property string browsePath: ""
    property string browseParent: ""
    property var browseEntries: []
    property bool browseLoading: false
    property string browseForPath: ""
    property var browseCrumbs: []
    property var playlists: []
    property var libraryPlaylists: []
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
        : (playerScreen === "browse" ? 2
        : (playerScreen === "playlistLibrary" ? 3 : 4)))
    readonly property var nowPlayingMetaChips: {
        var chips = []
        var year = String(player.year || "").trim()
        if (year !== "")
            chips.push({ label: year, accent: false })
        var genre = String(player.genre || "").trim()
        if (genre !== "")
            chips.push({ label: genre, accent: true })
        var album = String(player.album || "").trim()
        var title = String(player.title || "").trim()
        if (album !== "" && album !== title)
            chips.push({ label: album, accent: false })
        var durationLabel = String(player.duration_label || "").trim()
        if (durationLabel !== "" && Number(player.duration || 0) > 0)
            chips.push({ label: durationLabel, accent: false })
        return chips
    }
    readonly property int libraryPanelWidth: Math.round(Math.max(156, Math.min(width * 0.22, 220)))
    readonly property var browseGenrePresets: [
        { label: "Drum & Bass", folder: "drum&bass" },
        { label: "Dubstep", folder: "dubstep" },
        { label: "Hip-Hop", folder: "hiphop" }
    ]

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

    function bumpTransportVolumeBar() {
        if (!active)
            return
        volumeBarBoost = 1
        volumeBarBoostTimer.restart()
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

    function runJob(args, label, options) {
        if (libraryJobBusy) {
            notify("busy — " + libraryJobActiveLabel, 2000)
            return
        }
        jobBusy = true
        jobLabel = label
        jobLog = label + "…\n"
        if (!(options && options.stayOnScreen))
            playerScreen = "library"
        jobProc.command = ["bash", musicScript].concat(args || [])
        notify(label + "…", 2000)
        jobProc.running = true
    }

    function syncExternalJobStatus() {
        if (jobProc.running)
            return
        runQuery(["job", "status", "--json"], function(text) {
            try {
                var st = JSON.parse(String(text || "{}"))
                if (st.busy && !root.jobBusy) {
                    root.externalJobBusy = true
                    root.externalJobLabel = String(st.label || st.command || "library task")
                    if (!root.jobLog || root.jobLog.indexOf("running") < 0)
                        root.jobLog = root.externalJobLabel + " running…\n"
                } else if (!root.jobBusy) {
                    root.externalJobBusy = false
                    root.externalJobLabel = ""
                }
            } catch (e) {
                if (!root.jobBusy) {
                    root.externalJobBusy = false
                    root.externalJobLabel = ""
                }
            }
        })
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
        } else if (exitCode === 2) {
            var busy = jobErr.text ? String(jobErr.text).trim().split("\n").pop() : ""
            notify(busy || (label + " — already running"), 4000)
            syncExternalJobStatus()
        } else {
            var err = jobErr.text ? String(jobErr.text).trim() : ""
            if (err)
                err = err.split("\n").pop()
            notify(label + " failed" + (err ? " — " + err : ""), 5000)
        }
        if (exitCode !== 2)
            syncExternalJobStatus()
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

    function runPlayer(args, onDone, proc) {
        var runner = proc || cmdProc
        if (runner.running) return false
        runner.command = ["bash", playerScript].concat(args || [])
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

    function runPlayerQuery(args, onDone) {
        if (playerQueryProc.running) return false
        playerQueryProc.command = ["bash", playerScript].concat(args || [])
        playerQueryProc._onDone = onDone || null
        playerQueryProc.running = true
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
        var all = []
        var starred = []
        for (var j = 0; j < list.length; j++) {
            var item = list[j]
            all.push(item)
            if (item.starred === true)
                starred.push(item)
        }
        all.sort(function(a, b) {
            return String(a.name || "").localeCompare(String(b.name || ""))
        })
        libraryPlaylists = all
        playlists = starred
        playlistTabModel.clear()
        for (var k = 0; k < starred.length; k++) {
            playlistTabModel.append({
                name: starred[k].name,
                count: starred[k].count || 0
            })
        }
    }

    function playlistTabLabel(name) {
        return String(name || "")
    }

    function onActivated() {
        if (!runPlayerQuery(["open", "--json"], function(text) {
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
        jobStatusTimer.start()
        syncExternalJobStatus()
    }

    function finishDeactivate() {
        playerScreen = "nowPlaying"
        player = {}
        waveformSamples = []
    }

    function onDeactivated() {
        statusTimer.stop()
        saveStateTimer.stop()
        jobStatusTimer.stop()
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
        function runClose() {
            if (!runPlayer(["close"], finishDeactivate, deactivateProc))
                Qt.callLater(runClose)
        }
        runClose()
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

    function openPlaylistLibrary() {
        playerScreen = "playlistLibrary"
        if (!libraryPlaylists.length && !playlistsLoading)
            loadPlaylists()
    }

    function selectGenrePlaylist(name) {
        if (!name)
            return
        selectPlaylist(String(name), true)
    }

    function togglePlaylistStar(name) {
        var playlistName = String(name || "")
        if (!playlistName)
            return
        var nextList = []
        for (var i = 0; i < libraryPlaylists.length; i++) {
            var item = libraryPlaylists[i]
            if (item.name === playlistName)
                nextList.push(Object.assign({}, item, { starred: !item.starred }))
            else
                nextList.push(item)
        }
        applyPlaylists(nextList)
        runPlaylistQuery(["playlist", "star", "toggle", playlistName, "--json"], function(text) {
            try {
                JSON.parse(String(text || "{}"))
            } catch (e) {
            }
            root.loadPlaylists()
        })
    }

    function runBrowseQuery(args, onDone) {
        if (browseProc.running) {
            Qt.callLater(function() { runBrowseQuery(args, onDone) })
            return
        }
        browseProc.command = ["bash", musicScript].concat(args || [])
        browseProc._onDone = onDone || null
        browseProc.running = true
    }

    function loadBrowse(relPath) {
        var requested = String(relPath || "")
        browseForPath = requested
        browsePath = requested
        updateBrowseCrumbs()
        browseLoading = true
        browseEntries = []
        runBrowseQuery(["browse", requested, "--json"], function(text) {
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
                updateBrowseCrumbs()
                syncBrowseTracks()
            } catch (e) {
                browseEntries = []
                tracks = []
            }
        })
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

    function browseDirGenre(path) {
        var p = String(path || "")
        if (!p)
            return ""
        var slash = p.indexOf("/")
        return slash < 0 ? p : p.substring(0, slash)
    }

    function browseGenreLabel(entry) {
        if (!entry)
            return ""
        var tag = String(entry.genre || "").trim()
        if (tag !== "")
            return tag
        var folder = root.browseDirGenre(String(entry.path || ""))
        for (var i = 0; i < browseGenrePresets.length; i++) {
            if (browseGenrePresets[i].folder === folder)
                return browseGenrePresets[i].label
        }
        return folder
    }

    function browseGenrePresetIndex(entry) {
        if (!entry)
            return -1
        var tag = String(entry.genre || "").trim().toLowerCase()
        var folder = root.browseDirGenre(String(entry.path || ""))
        for (var i = 0; i < browseGenrePresets.length; i++) {
            var preset = browseGenrePresets[i]
            if (preset.folder === folder)
                return i
            if (preset.label.toLowerCase() === tag)
                return i
            if (preset.folder.toLowerCase() === tag)
                return i
        }
        return -1
    }

    function cycleBrowseGenre(entry) {
        if (!entry || !entry.path)
            return
        var idx = root.browseGenrePresetIndex(entry)
        var next = browseGenrePresets[(idx + 1) % browseGenrePresets.length]
        root.retagBrowseTrack(entry, next.folder)
    }

    function retagBrowseTrack(entry, genreFolder) {
        if (!entry || !entry.path || !genreFolder)
            return
        var trackPath = String(entry.path)
        var folder = String(browsePath || "")
        runMusic(["retag", trackPath, genreFolder, "--json"], function(text) {
            try {
                var result = JSON.parse(String(text || "{}"))
                var newPath = String(result.path || "")
                if (player.path === trackPath) {
                    var p = Object.assign({}, player)
                    p.path = newPath
                    p.genre = String(result.genre || genreFolder)
                    player = p
                }
            } catch (e) {
            }
            root.loadBrowse(folder)
        }, cmdProc)
    }

    function rebuildBrowseDir(entry) {
        var genre = browseDirGenre(entry.path)
        if (!genre)
            return
        runJob(["cache", "--force", genre], "rebuild " + genre, { stayOnScreen: true })
    }

    function browseEnter(entry) {
        if (!entry)
            return
        if (entry.type === "dir")
            loadBrowse(entry.path)
        else if (entry.type === "track")
            playBrowseTrack(entry)
    }

    function browseHome() {
        loadBrowse("")
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
        playerScreen = "nowPlaying"
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

    function updateBrowseCrumbs() {
        var crumbs = []
        var path = String(browsePath || "")
        if (!path) {
            browseCrumbs = [{ label: "Library", path: "" }]
            return
        }
        var parts = path.split("/")
        var acc = ""
        for (var i = 0; i < parts.length; i++) {
            if (!parts[i])
                continue
            acc = acc ? acc + "/" + parts[i] : parts[i]
            crumbs.push({ label: parts[i], path: acc })
        }
        browseCrumbs = crumbs
    }

    function browseCrumbCount() {
        return browseCrumbs.length
    }

    function refreshStatus() {
        if (!active)
            return
        pollStatus(applyStatus)
    }

    function pollStatus(onDone) {
        if (statusQueryProc.running)
            return false
        statusQueryProc.command = ["bash", playerScript, "status", "--json"]
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
        runPlayer(["toggle"], null, cmdProc)
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
        if (!String(parsed.path || "") && prevPath)
            return
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
        player = Object.assign({}, player, parsed)
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
        runPlayer(["seek", String(ratio * player.duration)], refreshStatus, cmdProc)
    }

    function previewVolume(percent) {
        var v = Math.max(0, Math.min(100, Math.round(percent)))
        var next = Object.assign({}, player)
        next.volume = v
        player = next
        bumpTransportVolumeBar()
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
        runPlayer(["volume", "set", String(volumeApplyTarget)], null, cmdProc)
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
        loadProc.command = ["bash", playerScript, "load", path]
        loadProc.running = true
    }

    function playPath(path) {
        if (!path)
            return
        primePlayerForPath(path)
        var trackPath = String(path)
        if (loadProc.running) {
            loadProc.pendingPath = trackPath
            return
        }
        startLoad(trackPath)
    }

    function playTrackAt(index) {
        if (index < 0 || index >= tracks.length)
            return
        var path = tracks[index].path
        if (!path)
            return
        selectedTrackIndex = index
        playerScreen = "nowPlaying"
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

    function runFavoriteQuery(args, onDone) {
        if (favoriteProc.running) {
            Qt.callLater(function() { runFavoriteQuery(args, onDone) })
            return
        }
        favoriteProc.command = ["bash", musicScript].concat(args || [])
        favoriteProc._onDone = onDone || null
        favoriteProc.running = true
    }

    function toggleTrackFavorite(path) {
        var trackPath = String(path || "")
        if (!trackPath)
            return
        var applyFavorite = function(text) {
            try {
                var result = JSON.parse(String(text || "{}"))
                var liked = !!result.liked
                var i, entry, nextTracks = [], nextBrowse = []
                for (i = 0; i < tracks.length; i++) {
                    entry = tracks[i]
                    if (entry.path === trackPath)
                        nextTracks.push(Object.assign({}, entry, { liked: liked }))
                    else
                        nextTracks.push(entry)
                }
                tracks = nextTracks
                for (i = 0; i < browseEntries.length; i++) {
                    entry = browseEntries[i]
                    if (entry.type === "track" && entry.path === trackPath)
                        nextBrowse.push(Object.assign({}, entry, { liked: liked }))
                    else
                        nextBrowse.push(entry)
                }
                browseEntries = nextBrowse
                if (player.path === trackPath) {
                    var p = Object.assign({}, player)
                    p.liked = liked
                    player = p
                }
                if (!liked && String(root.selectedPlaylist).endsWith("-fav"))
                    root.loadPlaylistTracks(root.selectedPlaylist)
            } catch (e) {
            }
        }
        var optimisticLiked = true
        var j, t
        for (j = 0; j < tracks.length; j++) {
            if (tracks[j].path === trackPath) {
                optimisticLiked = !tracks[j].liked
                break
            }
        }
        if (j >= tracks.length) {
            for (j = 0; j < browseEntries.length; j++) {
                t = browseEntries[j]
                if (t.type === "track" && t.path === trackPath) {
                    optimisticLiked = !t.liked
                    break
                }
            }
        }
        applyFavorite(JSON.stringify({ liked: optimisticLiked }))
        runFavoriteQuery(["favorite", "toggle", trackPath, "--json"], applyFavorite)
    }

    function toggleBrowseFavorite(path) {
        root.toggleTrackFavorite(path)
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
        id: jobStatusTimer
        interval: 2000
        repeat: true
        onTriggered: root.syncExternalJobStatus()
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
        id: deactivateProc
        property var _onDone: null
        stdout: StdioCollector {
            onStreamFinished: {
                if (deactivateProc._onDone)
                    deactivateProc._onDone(text)
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
        id: browseProc
        property var _onDone: null
        stdout: StdioCollector {
            onStreamFinished: {
                if (browseProc._onDone)
                    browseProc._onDone(text)
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
        id: favoriteProc
        property var _onDone: null
        stdout: StdioCollector {
            onStreamFinished: {
                if (favoriteProc._onDone)
                    favoriteProc._onDone(text)
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
        id: playerQueryProc
        property var _onDone: null
        stdout: StdioCollector {
            onStreamFinished: {
                if (playerQueryProc._onDone)
                    playerQueryProc._onDone(text)
                playerQueryProc._onDone = null
            }
        }
        onExited: playerQueryProc._onDone = null
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
        onTriggered: root.runPlayer(["save"], null, cmdProc)
    }

    Timer {
        id: volumeBarBoostTimer
        interval: 1400
        repeat: false
        onTriggered: root.volumeBarBoost = 0
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
                    icon: "󰉋"
                    active: root.playerScreen === "browse"
                    onActivated: root.openBrowse()
                }
                IconTab {
                    icon: "󰎄"
                    active: root.playerScreen === "playlistLibrary"
                    onActivated: root.openPlaylistLibrary()
                }
                IconTab {
                    icon: "󰠮"
                    active: root.playerScreen === "library"
                    onActivated: root.playerScreen = "library"
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
                                    text: root.playlistTabLabel(name)
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

            Item {
                id: nowPlayingPanel
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    anchors.fill: parent
                    spacing: pad

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: pad

                        SectionPanel {
                            label: ""
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            fillHeight: true

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: pad

                                ColumnLayout {
                                    id: titleCol
                                    Layout.fillWidth: true
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

                                    Text {
                                        Layout.fillWidth: true
                                        visible: (root.player.artist || "") !== ""
                                        text: root.player.artist
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.hintFont + 1
                                        font.bold: Theme.fontBold
                                        opacity: 0.72
                                        elide: Text.ElideRight
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        visible: root.nowPlayingMetaChips.length > 0

                                        Repeater {
                                            model: root.nowPlayingMetaChips

                                            delegate: MetaChip {
                                                required property var modelData
                                                label: modelData.label
                                                accent: !!modelData.accent
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: root.selectedPlaylist !== ""
                                        text: "From playlist: " + root.playlistTabLabel(root.selectedPlaylist)
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.libraryFont
                                        opacity: 0.45
                                    }
                                }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 6

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.minimumHeight: 96

                                    Canvas {
                                        id: waveCanvas
                                        anchors.fill: parent
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

                                        var barW = 4
                                        var gap = 1
                                        var barCount = Math.max(48, Math.floor(width / barW))
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

                                        var maxAmp = height * 0.48
                                        var playX = width * prog
                                        var refPeak = 0
                                        for (var pk = 0; pk < barCount; pk++)
                                            refPeak = Math.max(refPeak, peaks[pk])
                                        refPeak = Math.max(1, refPeak * 1.05)

                                        for (var i = 0; i < barCount; i++) {
                                            var amp = Math.max(2, (peaks[i] / refPeak) * maxAmp)
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

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: function(mouse) {
                                        var pos = mapToItem(waveCanvas, mouse.x, mouse.y)
                                        root.seekFromX(pos.x, waveCanvas.width)
                                    }
                                }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: root.player.position_label || "0:00"
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.hintFont
                                        opacity: 0.65
                                    }

                                    Item { Layout.fillWidth: true }

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

                        SectionPanel {
                            label: ""
                            Layout.fillWidth: true
                            contentPad: 10

                            PlayerTransportBar {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: root.nowPlayingControlsHeight
                                showTimestamps: false
                            }
                        }
                    }

                    SectionPanel {
                        label: ""
                        Layout.fillHeight: true
                        Layout.preferredWidth: root.nowPlayingArtWidth
                        Layout.minimumWidth: 120
                        fillHeight: true

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Rectangle {
                                id: coverFrame
                                anchors.fill: parent
                                radius: 3
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
                                    font.pixelSize: Math.round(root.nowPlayingArtWidth * 0.22)
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
                    label: root.libraryJobBusy ? root.libraryJobActiveLabel : (root.jobLog !== "" ? "log" : "Library log")
                    labelFontSize: root.sectionLabelFont
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
                            text: root.jobLog || (root.libraryJobBusy ? (root.libraryJobActiveLabel + "…") : "run a library task to see output here")
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
                            text: root.libraryJobBusy
                                ? root.libraryJobActiveLabel + "…"
                                : (root.libraryStats.tracks || 0) + " tracks · " + (root.libraryStats.genres || 0) + " genres"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.libraryFont
                            opacity: root.libraryJobBusy ? 0.9 : 0.55
                            wrapMode: Text.Wrap
                        }

                        LibraryBtn {
                            icon: "󰲹"
                            label: "build library"
                            dimmed: root.libraryJobBusy
                            spinning: root.buildBusy
                            onActivated: if (!root.libraryJobBusy) root.runJob(["build"], "build library")
                        }
                        LibraryBtn {
                            icon: "󰖟"
                            label: "warm cache"
                            dimmed: root.libraryJobBusy
                            onActivated: if (!root.libraryJobBusy) root.runJob(["warm"], "warm cache")
                        }
                        LibraryBtn {
                            icon: "󰕧"
                            label: "sync soundcloud"
                            dimmed: true
                            onActivated: if (!root.libraryJobBusy) root.runJob(["soundcloud"], "sync soundcloud")
                        }
                        LibraryBtn {
                            icon: "󰋋"
                            label: "import incoming"
                            dimmed: true
                            onActivated: if (!root.libraryJobBusy) root.runJob(["import"], "import incoming")
                        }
                        LibraryBtn {
                            icon: "󰑐"
                            label: "rebuild tags"
                            dimmed: root.libraryJobBusy
                            spinning: root.rebuildBusy
                            onActivated: if (!root.libraryJobBusy) root.runJob(["rebuild"], "rebuild library")
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
                            Layout.bottomMargin: 10
                            spacing: 6

                            Text {
                                visible: root.browsePath !== ""
                                text: "󰋜"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.sectionLabelFont
                                opacity: browseHomeMouse.containsMouse ? 0.95 : 0.62
                                Layout.alignment: Qt.AlignVCenter

                                MouseArea {
                                    id: browseHomeMouse
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.browseHome()
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: browseCrumbRow.implicitHeight
                                clip: true

                                Row {
                                    id: browseCrumbRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, parent.width)
                                    spacing: 0

                                    Repeater {
                                        model: root.browseCrumbs

                                        Row {
                                            spacing: 0

                                            Text {
                                                visible: index > 0
                                                text: " / "
                                                color: Theme.foreground
                                                font.family: Theme.fontFamily
                                                font.pixelSize: root.sectionLabelFont
                                                opacity: 0.28
                                            }

                                            BrowseCrumb {
                                                label: modelData.label
                                                path: modelData.path
                                                current: index === root.browseCrumbCount() - 1
                                                onActivated: root.loadBrowse(path)
                                            }
                                        }
                                    }
                                }
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
                                visible: root.browseLoading
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
                                        : (browseTrackRow.hovered
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

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Text {
                                            anchors.fill: parent
                                            text: modelData.name
                                            color: Theme.foreground
                                            font.family: Theme.fontFamily
                                            font.pixelSize: root.hintFont
                                            elide: Text.ElideRight
                                            opacity: 0.85
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        MouseArea {
                                            id: browseMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.browseEnter(modelData)
                                        }
                                    }

                                    Item {
                                        z: 2
                                        Layout.preferredWidth: 22
                                        Layout.preferredHeight: 22
                                        Layout.alignment: Qt.AlignVCenter

                                        Text {
                                            id: rebuildDirIcon
                                            anchors.centerIn: parent
                                            text: "󰑐"
                                            color: Theme.foreground
                                            opacity: root.libraryJobBusy
                                                ? 0.2
                                                : (rebuildDirMouse.containsMouse ? 0.9 : 0.42)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: root.libraryFont + 1
                                            transformOrigin: Item.Center

                                            RotationAnimation on rotation {
                                                running: root.libraryJobBusy
                                                    && root.libraryJobActiveLabel === ("rebuild " + root.browseDirGenre(modelData.path))
                                                from: 0
                                                to: 360
                                                duration: 900
                                                loops: Animation.Infinite
                                            }
                                        }

                                        MouseArea {
                                            id: rebuildDirMouse
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            hoverEnabled: true
                                            enabled: !root.libraryJobBusy
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: function(mouse) {
                                                mouse.accepted = true
                                                root.rebuildBrowseDir(modelData)
                                            }
                                        }
                                    }

                                    Rectangle {
                                        z: 2
                                        visible: modelData.count !== undefined && modelData.count !== null
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: 8
                                        color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.07)
                                        border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.14)
                                        border.width: 1
                                        implicitWidth: browseCountPill.implicitWidth + 12
                                        implicitHeight: browseCountPill.implicitHeight + 4

                                        Text {
                                            id: browseCountPill
                                            anchors.centerIn: parent
                                            text: String(modelData.count)
                                            color: Theme.foreground
                                            font.family: Theme.fontFamily
                                            font.pixelSize: root.libraryFont
                                            opacity: 0.72
                                        }
                                    }
                                }

                                BrowseTrackRow {
                                    id: browseTrackRow
                                    anchors.fill: parent
                                    visible: modelData.type === "track"
                                    rowWidth: browseList.width
                                    track: modelData
                                    selected: root.isTrackSelected(modelData.path)
                                    genreLabel: root.browseGenreLabel(modelData)
                                    onPressed: root.selectBrowseTrack(modelData)
                                    onPlayRequested: root.playBrowseTrack(modelData)
                                    onGenreClicked: root.cycleBrowseGenre(modelData)
                                    onLikeToggled: root.toggleBrowseFavorite(modelData.path)
                                }
                            }
                        }
                    }
                }
            }

            SectionPanel {
                label: "Playlists"
                labelFontSize: root.sectionLabelFont
                Layout.fillWidth: true
                Layout.fillHeight: true
                fillHeight: true

                ListView {
                    id: playlistLibraryList
                    anchors.fill: parent
                    clip: true
                    spacing: 2
                    model: root.libraryPlaylists

                    Text {
                        anchors.centerIn: parent
                        visible: root.playlistsLoading && root.libraryPlaylists.length === 0
                        text: "loading…"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                        opacity: 0.45
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !root.playlistsLoading && root.libraryPlaylists.length === 0
                        text: "no playlists"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                        opacity: 0.45
                    }

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property int pinReserve: 30
                        width: playlistLibraryList.width
                        height: 40
                        radius: 4
                        color: genrePlaylistMouse.containsMouse
                            ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.05)
                            : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Item {
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.starred ? "󰓎" : "󰓄"
                                    color: modelData.starred ? Theme.accent : Theme.foreground
                                    opacity: modelData.starred ? 1 : (playlistPinMouse.containsMouse ? 0.65 : 0.42)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.bodyFont
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.playlistTabLabel(modelData.name || "")
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.bodyFont
                                elide: Text.ElideRight
                            }

                            Text {
                                text: String(modelData.count || 0)
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.libraryFont
                                opacity: 0.45
                            }
                        }

                        MouseArea {
                            id: genrePlaylistMouse
                            anchors.fill: parent
                            anchors.leftMargin: pinReserve
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectGenrePlaylist(modelData.name)
                        }

                        MouseArea {
                            id: playlistPinMouse
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 26
                            height: 26
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                mouse.accepted = true
                                root.togglePlaylistStar(modelData.name)
                            }
                        }
                    }
                }
            }

            SectionPanel {
                label: root.selectedPlaylist !== "" ? root.playlistTabLabel(root.selectedPlaylist) : "Playlist"
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
                            showLike: true
                            onPressed: root.selectedTrackIndex = index
                            onActivated: root.playTrackAt(index)
                            onLikeToggled: root.toggleTrackFavorite(modelData.path)
                        }
                        }
                }
            }
        }

        // Bottom control bar — other screens only
        SectionPanel {
            label: ""
            Layout.fillWidth: true
            visible: root.playerScreen !== "nowPlaying"
            contentPad: 10

            PlayerTransportBar {
                Layout.fillWidth: true
            }
        }
    }

    component MetaChip: Rectangle {
        property string label: ""
        property bool accent: false
        property bool clickable: false
        property int maxLabelWidth: 0
        signal activated()

        radius: 10
        color: accent
            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, (clickable && chipMouse.containsMouse) ? 0.22 : 0.14)
            : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, (clickable && chipMouse.containsMouse) ? 0.1 : 0.06)
        border.color: accent
            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.38)
            : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.14)
        border.width: 1
        implicitWidth: (maxLabelWidth > 0 ? Math.min(chipText.implicitWidth, maxLabelWidth) : chipText.implicitWidth) + 16
        implicitHeight: chipText.implicitHeight + 6

        Text {
            id: chipText
            anchors.centerIn: parent
            width: parent.maxLabelWidth > 0 ? parent.maxLabelWidth : implicitWidth
            text: parent.label
            color: parent.accent ? Theme.accent : Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: root.libraryFont
            font.bold: parent.accent && Theme.fontBold
            opacity: parent.accent ? 0.95 : 0.68
            elide: parent.maxLabelWidth > 0 ? Text.ElideRight : Text.ElideNone
            horizontalAlignment: Text.AlignHCenter
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            visible: parent.clickable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) {
                mouse.accepted = true
                parent.activated()
            }
        }
    }

    component TransportTimePill: Rectangle {
        property string label: ""
        property bool highlight: false

        radius: 4
        color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.06)
        border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.14)
        border.width: 1
        implicitWidth: pillText.implicitWidth + 20
        implicitHeight: pillText.implicitHeight + 10
        Layout.alignment: Qt.AlignVCenter

        Text {
            id: pillText
            anchors.centerIn: parent
            text: parent.label
            color: parent.highlight ? Theme.accent : Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: root.hintFont
            font.bold: parent.highlight && Theme.fontBold
            opacity: parent.highlight ? 1 : 0.65
        }
    }

    component PlayerTransportBar: Item {
        property bool showTimestamps: true
        implicitHeight: root.nowPlayingControlsHeight

        Rectangle {
            id: volumeFlashBg
            anchors.fill: parent
            radius: Theme.fieldsetCornerRadius
            color: Theme.accent
            opacity: root.volumeBarBoost > 0
                ? (0.12 + root.playerVolumePercent / 100 * 0.3)
                : 0
            z: 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 320
                    easing.type: Easing.OutCubic
                }
            }
        }

        RowLayout {
            id: transportRow
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 12
            z: 1

            TransportTimePill {
                visible: showTimestamps
                label: root.player.position_label || "0:00"
            }

            Item {
                visible: showTimestamps
                Layout.fillWidth: true
                Layout.minimumWidth: 4
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 24

                Item { Layout.fillWidth: true }

                TransportBtn {
                    icon: "󰒮"
                    onActivated: root.runPlayer(["prev"], root.refreshStatus, cmdProc)
                }
                TransportBtn {
                    icon: root.playerPlaying ? "󰏤" : "󰐊"
                    accent: true
                    onActivated: root.togglePlayback()
                }
                TransportBtn {
                    icon: "󰒭"
                    onActivated: root.runPlayer(["next"], root.refreshStatus, cmdProc)
                }
                TransportBtn {
                    icon: "󰒟"
                    smallGlyph: true
                    dimmed: !root.player.shuffle
                    onActivated: root.runPlayer(["shuffle", "toggle"], root.refreshStatus, cmdProc)
                }

                TransportBtn {
                    icon: "󰋑"
                    smallGlyph: true
                    liked: !!root.player.liked
                    onActivated: root.toggleFavorite()
                }
                VolumeTransportBtn {}

                Item { Layout.fillWidth: true }
            }

            Item {
                visible: showTimestamps
                Layout.fillWidth: true
                Layout.minimumWidth: 4
            }

            TransportTimePill {
                visible: showTimestamps || root.volumeBarBoost > 0
                label: root.volumeBarBoost > 0
                    ? (root.playerVolumePercent + "%")
                    : (root.player.duration_label || "0:00")
                highlight: root.volumeBarBoost > 0
            }
        }
    }

    component VolumeTransportBtn: Item {
        id: volBtn
        readonly property int level: Math.round(root.player.volume !== undefined ? root.player.volume : 100)
        property bool wheelPopupActive: false
        readonly property bool popupVisible: volHover.containsMouse || sliderArea.pressed || wheelPopupActive

        implicitWidth: root.transportBtnSize
        implicitHeight: root.transportBtnSize
        Layout.preferredWidth: root.transportBtnSize
        Layout.preferredHeight: root.transportBtnSize
        Layout.alignment: Qt.AlignVCenter

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
            font.pixelSize: root.transportSecondaryIconFont
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

    component BrowseTrackRow: Rectangle {
        id: browseRow
        property var track: ({})
        property bool selected: false
        property int rowWidth: 0
        property string genreLabel: ""
        signal pressed()
        signal playRequested()
        signal genreClicked()
        signal likeToggled()

        readonly property bool trackLiked: !!track.liked
        readonly property int genreReserve: 108
        readonly property int likeReserve: 30
        readonly property bool hovered: browseRowMouse.containsMouse
            || browsePlayMouse.containsMouse
            || browseLikeMouse.containsMouse
            || (!browseRow.selected && browseArtSelectMouse.containsMouse)

        width: rowWidth
        height: 40
        radius: 4
        color: selected
            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
            : (browseRowMouse.containsMouse
                ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.05)
                : "transparent")

        RowLayout {
            z: 0
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            Item {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    clip: true
                    color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)
                    visible: !browseArt.visible
                }

                Text {
                    anchors.centerIn: parent
                    visible: !browseArt.visible
                    text: "󰎈"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    opacity: 0.35
                }

                Image {
                    id: browseArt
                    anchors.fill: parent
                    visible: status === Image.Ready
                    source: (browseRow.track.art || "") !== "" ? root.artUrl(browseRow.track.art) : ""
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                    layer.enabled: true
                    layer.smooth: true
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    visible: browseRow.selected
                    color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.48)
                }

                Text {
                    anchors.centerIn: parent
                    visible: browseRow.selected
                    text: "󰐊"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    opacity: browsePlayMouse.containsMouse ? 1 : 0.92
                }

                MouseArea {
                    id: browsePlayMouse
                    z: 3
                    anchors.fill: parent
                    visible: browseRow.selected
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        mouse.accepted = true
                        browseRow.playRequested()
                    }
                }

                MouseArea {
                    id: browseArtSelectMouse
                    z: 2
                    anchors.fill: parent
                    visible: !browseRow.selected
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: browseRow.pressed()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 48
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: browseRow.track.title || ""
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: root.hintFont
                    elide: Text.ElideRight
                    opacity: browseRow.selected ? 1 : 0.9
                }

                Text {
                    Layout.fillWidth: true
                    visible: String(browseRow.track.artist || "").trim() !== ""
                    text: browseRow.track.artist || ""
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.libraryFont
                    elide: Text.ElideRight
                    opacity: 0.55
                }
            }

            MetaChip {
                visible: browseRow.genreLabel !== ""
                label: browseRow.genreLabel
                accent: true
                clickable: true
                maxLabelWidth: 96
                Layout.alignment: Qt.AlignVCenter
                onActivated: browseRow.genreClicked()
            }

            Item {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    text: "󰋑"
                    color: browseRow.trackLiked ? Theme.urgent : Theme.foreground
                    opacity: browseRow.trackLiked ? 1 : (browseLikeMouse.containsMouse ? 0.55 : 0.28)
                    font.family: Theme.fontFamily
                    font.pixelSize: root.bodyFont
                }

                MouseArea {
                    id: browseLikeMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        mouse.accepted = true
                        browseRow.likeToggled()
                    }
                }
            }
        }

        MouseArea {
            id: browseRowMouse
            z: 1
            anchors.fill: parent
            anchors.leftMargin: 44
            anchors.rightMargin: browseRow.genreReserve + browseRow.likeReserve
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: browseRow.pressed()
        }
    }

    component TrackListRow: Rectangle {
        id: trackRow
        property var track: ({})
        property int number: 0
        property bool selected: false
        property bool showMeta: false
        property bool showLike: false
        property bool capturePress: true
        property int rowWidth: 0
        signal pressed()
        signal activated()
        signal likeToggled()

        readonly property string trackGenre: String(track.genre || "").trim()
        readonly property bool trackLiked: !!track.liked
        readonly property bool likeEnabled: showMeta || showLike
        readonly property int likeReserve: showMeta ? 136 : (showLike ? 36 : 0)
        readonly property int artReserve: likeEnabled ? 44 : 0

        width: rowWidth
        height: 40
        radius: 4
        color: selected
            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
            : (trackRowMouse.containsMouse
                ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.05)
                : "transparent")

        RowLayout {
            z: 0
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
                    opacity: trackArtMouse.containsMouse ? 0.55 : 0.35
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
                Layout.minimumWidth: 48
                text: trackRow.track.title || ""
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFont
                elide: Text.ElideRight
                opacity: trackRow.selected ? 1 : 0.9
            }

            MetaChip {
                visible: trackRow.showMeta && trackRow.trackGenre !== ""
                label: trackRow.trackGenre
                accent: true
                maxLabelWidth: Math.min(108, trackRow.rowWidth * 0.18)
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                visible: trackRow.likeEnabled
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    text: "󰋑"
                    color: trackRow.trackLiked ? Theme.urgent : Theme.foreground
                    opacity: trackRow.trackLiked ? 1 : (trackLikeMouse.containsMouse ? 0.55 : 0.28)
                    font.family: Theme.fontFamily
                    font.pixelSize: root.bodyFont
                }
            }
        }

        MouseArea {
            id: trackRowMouse
            z: 1
            visible: trackRow.capturePress
            anchors.fill: parent
            anchors.leftMargin: trackRow.artReserve
            anchors.rightMargin: trackRow.likeReserve
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onClicked: trackRow.pressed()
            onDoubleClicked: function(mouse) {
                mouse.accepted = true
                trackRow.activated()
            }
        }

        MouseArea {
            id: trackArtMouse
            z: 2
            visible: trackRow.likeEnabled
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) {
                mouse.accepted = true
                trackRow.likeToggled()
            }
        }

        MouseArea {
            id: trackLikeMouse
            z: 2
            visible: trackRow.likeEnabled
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 30
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) {
                mouse.accepted = true
                trackRow.likeToggled()
            }
        }
    }

    component BrowseCrumb: Item {
        id: crumb
        property string label: ""
        property string path: ""
        property bool current: false
        signal activated()

        implicitWidth: crumbLabel.implicitWidth
        implicitHeight: crumbLabel.implicitHeight

        Text {
            id: crumbLabel
            text: crumb.label
            color: crumb.current ? Theme.accent : Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: root.sectionLabelFont
            font.bold: crumb.current && Theme.fontBold
            opacity: crumb.current ? 0.95 : (crumbMouse.containsMouse ? 0.92 : 0.62)
        }

        Rectangle {
            anchors.left: crumbLabel.left
            anchors.right: crumbLabel.right
            anchors.bottom: crumbLabel.bottom
            anchors.bottomMargin: 1
            height: 1
            visible: !crumb.current && crumbMouse.containsMouse
            color: Theme.accent
            opacity: 0.55
        }

        MouseArea {
            id: crumbMouse
            anchors.fill: parent
            anchors.margins: -2
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: crumb.activated()
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
        property bool spinning: false
        signal activated()

        implicitWidth: libRow.implicitWidth + 8
        implicitHeight: libRow.implicitHeight + 4

        Row {
            id: libRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                id: libIcon
                text: libBtn.icon
                color: accent ? Theme.accent : Theme.foreground
                opacity: dimmed && !libBtn.spinning ? 0.35 : 0.9
                font.family: Theme.fontFamily
                font.pixelSize: root.libraryFont + 2
                transformOrigin: Item.Center

                RotationAnimation on rotation {
                    running: libBtn.spinning
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                }
            }

            Text {
                text: libBtn.label
                color: accent ? Theme.accent : Theme.foreground
                opacity: dimmed && !libBtn.spinning ? 0.35 : (libMouse.containsMouse ? 1 : 0.78)
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

    component TransportBtn: Item {
        id: btn
        property string icon: ""
        property bool accent: false
        property bool dimmed: false
        property bool liked: false
        property bool smallGlyph: false
        signal activated()

        implicitWidth: root.transportBtnSize
        implicitHeight: root.transportBtnSize
        Layout.preferredWidth: root.transportBtnSize
        Layout.preferredHeight: root.transportBtnSize
        Layout.alignment: Qt.AlignVCenter

        Text {
            anchors.centerIn: parent
            text: btn.icon
            color: liked ? Theme.urgent : (accent ? Theme.accent : Theme.foreground)
            opacity: dimmed ? 0.35 : (liked ? 1 : 0.9)
            font.family: Theme.fontFamily
            font.pixelSize: accent
                ? Math.round(root.transportIconFont * 1.2)
                : (smallGlyph ? root.transportSecondaryIconFont : root.transportIconFont)
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.activated()
        }
    }
}
