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

    readonly property string playerScript: (Quickshell.env("HOME") || "") + "/.local/bin/evo-player"
    readonly property int pad: Theme.hoverPopupMargin
    readonly property int bodyFont: Theme.hoverPopupBodyFontPixelSize
    readonly property int hintFont: Theme.hoverPopupHintFontPixelSize
    readonly property int listFont: hintFont
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
    readonly property bool buildBusy: libraryJobBusy
        && (libraryJobActiveLabel === "build all" || libraryJobActiveLabel === "build quick" || libraryJobActiveLabel === "build")
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
    readonly property string currentPlaylistId: "current"
    property bool currentPlaylistActive: false
    property string currentPlaylistPath: ""
    property var currentPlaylistTracks: []
    property bool playlistsLoading: false
    property string resumePlaylist: ""
    property string playerScreen: "nowPlaying"
    property int volumeApplyTarget: 100
    property bool volumeApplyPending: false
    property real seekApplyTarget: 0
    property bool seekApplyPending: false
    property bool playbackStatePending: false
    property string playbackStateTarget: ""
    readonly property int screenStackIndex:
        playerScreen === "nowPlaying" ? 0
        : (playerScreen === "browse" ? 1
        : (playerScreen === "playlistLibrary" ? 2 : 3))
    property bool libraryMenuOpen: true
    readonly property var libraryActions: [
        { icon: "󰲹", label: "build all", args: ["build", "all"] },
        { icon: "󰖟", label: "build quick", args: ["build", "quick"] },
        { icon: "󰕧", label: "sync soundcloud", args: ["soundcloud"] },
        { icon: "󰋋", label: "import incoming", args: ["import"] },
        { icon: "󰩹", label: "prune art", args: ["cache", "--prune-art"] },
        { icon: "󰋩", label: "embed art", args: ["art", "embed"] }
    ]
    property int artRevision: 0
    property bool artPickerOpen: false
    property bool artPickerLoading: false
    property string artPickerQuery: ""
    property var artPickerResults: []
    readonly property var nowPlayingMetaChips: {
        var chips = []
        var year = String(player.year || "").trim()
        if (year !== "")
            chips.push({ label: year, accent: false })
        var genre = String(player.genre || "").trim()
        if (genre !== "")
            chips.push({ label: genre, accent: true })
        var durationLabel = String(player.duration_label || "").trim()
        if (durationLabel !== "" && Number(player.duration || 0) > 0)
            chips.push({ label: durationLabel, accent: false })
        return chips
    }
    readonly property string nowPlayingAlbum: {
        var album = String(player.album || "").trim()
        var title = String(player.title || "").trim()
        if (album === "" || album === title)
            return ""
        return album
    }
    readonly property int libraryPanelWidth: Math.round(Math.max(156, Math.min(width * 0.22, 220)))
    readonly property var genreLabelOverrides: ({
        "drum&bass": "Drum & Bass",
        "dubstep": "Dubstep",
        "hiphop": "Hip-Hop"
    })

    function artUrl(path) {
        if (!path) return ""
        var base = path.startsWith("file://") ? path : Util.fileUrl(path)
        var sep = base.indexOf("?") >= 0 ? "&" : "?"
        return base + sep + "rev=" + artRevision
    }

    function localPathFromUrl(url) {
        if (!url)
            return ""
        var s = url.toString ? url.toString() : String(url)
        if (s.indexOf("file://") === 0) {
            var p = s.replace(/^file:\/\//, "")
            if (p.indexOf("localhost/") === 0)
                p = p.substring("localhost/".length)
            return decodeURIComponent(p)
        }
        return s
    }

    function isImagePath(path) {
        var p = String(path || "").toLowerCase()
        return /\.(jpe?g|png|webp|gif|bmp)$/.test(p)
    }

    function bumpArtRevision() {
        artRevision++
    }

    function onAlbumArtUpdated() {
        bumpArtRevision()
        refreshStatus()
        notify("album art updated", 2500)
    }

    function setAlbumArtFromFile(imagePath) {
        var track = String(player.path || "")
        if (!track || !imagePath)
            return
        runMusic(["art", "set", track, imagePath, "--json"], function(text) {
            try {
                JSON.parse(String(text || "{}"))
                root.onAlbumArtUpdated()
            } catch (e) {
                root.notify("could not update art", 3000)
            }
        })
    }

    function applyAlbumArtFromUrl(url) {
        var track = String(player.path || "")
        if (!track || !url)
            return
        artPickerLoading = true
        runMusic(["art", "apply", track, url, "--json"], function(text) {
            artPickerLoading = false
            try {
                JSON.parse(String(text || "{}"))
                artPickerOpen = false
                root.onAlbumArtUpdated()
            } catch (e) {
                root.notify("could not update art", 3000)
            }
        })
    }

    function openArtPicker() {
        var track = String(player.path || "")
        if (!track)
            return
        artPickerOpen = true
        artPickerLoading = true
        artPickerResults = []
        artPickerQuery = ""
        runQuery(["art", "search", track, "--json"], function(text) {
            root.artPickerLoading = false
            try {
                var data = JSON.parse(String(text || "{}"))
                root.artPickerQuery = String(data.query || "")
                root.artPickerResults = data.results || []
            } catch (e) {
                root.artPickerResults = []
            }
        })
    }

    function closeArtPicker() {
        artPickerOpen = false
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

    function runLibraryAction(action) {
        if (!action)
            return
        runJob(action.args || [], action.label || "library task")
    }

    function runJob(args, label, options) {
        if (libraryJobBusy) {
            notify("busy — " + libraryJobActiveLabel, 2000)
            return
        }
        jobBusy = true
        jobLabel = label
        jobLog = label + "…\n"
        if (!(options && options.stayOnScreen)) {
            if (playerScreen !== "playlistLibrary" && playerScreen !== "playlists")
                playerScreen = "playlistLibrary"
        }
        libraryMenuOpen = false
        jobProc.command = ["bash", playerScript].concat(args || [])
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
        runQuery(["stats", "--json"], function(text) {
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
        runner.command = ["bash", playerScript].concat(args || [])
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
        queryProc.command = ["bash", playerScript].concat(args || [])
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
        playlistQueryProc.command = ["bash", playerScript].concat(args || [])
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
        injectCurrentPlaylist()
    }

    function currentPlaylistEntry() {
        return {
            name: currentPlaylistId,
            count: currentPlaylistTracks.length,
            kind: "current",
            starred: true
        }
    }

    function injectCurrentPlaylist() {
        if (!currentPlaylistActive) {
            var libs = []
            for (var i = 0; i < libraryPlaylists.length; i++) {
                if (libraryPlaylists[i].name !== currentPlaylistId)
                    libs.push(libraryPlaylists[i])
            }
            libraryPlaylists = libs

            var tabNames = []
            for (var t = 0; t < playlistTabModel.count; t++) {
                var tabName = playlistTabModel.get(t).name
                if (tabName !== currentPlaylistId)
                    tabNames.push({ name: tabName, count: playlistTabModel.get(t).count })
            }
            playlistTabModel.clear()
            for (var v = 0; v < tabNames.length; v++) {
                playlistTabModel.append({
                    name: tabNames[v].name,
                    count: tabNames[v].count || 0
                })
            }
            return
        }
        var entry = currentPlaylistEntry()
        var libs = []
        var found = false
        for (var i = 0; i < libraryPlaylists.length; i++) {
            if (libraryPlaylists[i].name === currentPlaylistId) {
                libs.push(entry)
                found = true
            } else {
                libs.push(libraryPlaylists[i])
            }
        }
        if (!found)
            libs.unshift(entry)
        libraryPlaylists = libs

        var tabNames = []
        for (var t = 0; t < playlistTabModel.count; t++)
            tabNames.push({ name: playlistTabModel.get(t).name, count: playlistTabModel.get(t).count })
        var hasCurrent = false
        for (var u = 0; u < tabNames.length; u++) {
            if (tabNames[u].name === currentPlaylistId) {
                tabNames[u].count = entry.count
                hasCurrent = true
                break
            }
        }
        if (!hasCurrent)
            tabNames.unshift({ name: currentPlaylistId, count: entry.count })
        playlistTabModel.clear()
        for (var v = 0; v < tabNames.length; v++) {
            playlistTabModel.append({
                name: tabNames[v].name,
                count: tabNames[v].count || 0
            })
        }
        refreshCurrentPlaylistView()
    }

    function refreshCurrentPlaylistView() {
        if (!currentPlaylistActive)
            return
        if (playerScreen === "playlists" && selectedPlaylist === currentPlaylistId) {
            tracks = currentPlaylistTracks.slice()
            syncSelectedTrackIndex()
        }
    }

    function commitCurrentPlaylist() {
        injectCurrentPlaylist()
        syncPlaylistTabPosition()
        if (selectedPlaylist === currentPlaylistId && playerScreen === "playlists")
            loadPlaylistTracks(currentPlaylistId)
        prioritizeCurrentAssets()
    }

    function prioritizeCurrentAssets() {
        if (!currentPlaylistActive || !currentPlaylistTracks.length)
            return
        var args = ["prioritize"]
        var limit = Math.min(currentPlaylistTracks.length, 32)
        for (var i = 0; i < limit; i++) {
            if (currentPlaylistTracks[i].path)
                args.push(currentPlaylistTracks[i].path)
        }
        if (args.length > 1)
            runMusic(args, null, cmdProc)
    }

    function stageCurrentPlaylistFromBrowse(entry) {
        if (!entry || !entry.path)
            return
        setCurrentPlaylistFromBrowse(entry)
        selectedPlaylist = currentPlaylistId
        commitCurrentPlaylist()
    }

    function clearCurrentPlaylist() {
        if (!currentPlaylistActive)
            return
        currentPlaylistActive = false
        currentPlaylistTracks = []
        currentPlaylistPath = ""
        injectCurrentPlaylist()
        if (selectedPlaylist === currentPlaylistId)
            tracks = []
    }

    function setCurrentPlaylistFromBrowse(entry) {
        var idx = -1
        for (var i = 0; i < tracks.length; i++) {
            if (tracks[i].path === entry.path) {
                idx = i
                break
            }
        }
        var queued = []
        if (idx >= 0) {
            for (var j = idx; j < tracks.length; j++)
                queued.push(tracks[j])
        } else {
            queued = tracks.slice()
        }
        currentPlaylistTracks = queued
        currentPlaylistPath = String(browsePath || "")
        currentPlaylistActive = true
    }

    function playlistTabLabel(name) {
        if (String(name || "") === currentPlaylistId)
            return "current"
        if (currentPlaylistActive && String(name || "") === currentPlaylistPath)
            return "current"
        return String(name || "")
    }

    function nowPlayingPlaylistLabel() {
        if (currentPlaylistActive || selectedPlaylist === currentPlaylistId)
            return "current"
        return playlistTabLabel(selectedPlaylist)
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
        if (n === "favorites")
            return "all"
        if (n.endsWith("-fav"))
            return n.slice(0, -4)
        return n
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
            if (preferred === currentPlaylistId) {
                syncPlaylistTabPosition()
            } else if (preferred) {
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
        if (!playlistName || playlistName === currentPlaylistId)
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
        browseProc.command = ["bash", playerScript].concat(args || [])
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

    function retaggableGenres() {
        var names = []
        for (var i = 0; i < genres.length; i++) {
            var name = String(genres[i].name || "").trim()
            if (name !== "")
                names.push(name)
        }
        names.sort(function(a, b) { return a.localeCompare(b) })
        return names
    }

    function genreFolderLabel(folder) {
        var key = String(folder || "")
        if (genreLabelOverrides[key])
            return genreLabelOverrides[key]
        return key
    }

    function browseGenreLabel(entry) {
        if (!entry)
            return ""
        var tag = String(entry.genre || "").trim()
        if (tag !== "")
            return tag
        var folder = root.browseDirGenre(String(entry.path || ""))
        return root.genreFolderLabel(folder)
    }

    function browseGenreIndex(entry) {
        if (!entry)
            return -1
        var folders = root.retaggableGenres()
        if (!folders.length)
            return -1
        var tag = String(entry.genre || "").trim().toLowerCase()
        var folder = root.browseDirGenre(String(entry.path || ""))
        for (var i = 0; i < folders.length; i++) {
            if (folders[i] === folder)
                return i
            if (root.genreFolderLabel(folders[i]).toLowerCase() === tag)
                return i
            if (folders[i].toLowerCase() === tag)
                return i
        }
        return -1
    }

    function cycleBrowseGenre(entry) {
        if (!entry || !entry.path)
            return
        var folders = root.retaggableGenres()
        if (!folders.length) {
            root.notify("no genres available", 2500)
            return
        }
        var idx = root.browseGenreIndex(entry)
        var next = folders[(idx + 1) % folders.length]
        root.retagBrowseTrack(entry, next)
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
                stageCurrentPlaylistFromBrowse(entry)
                return
            }
        }
        selectedTrackIndex = -1
    }

    function browseFolderLabel() {
        var p = String(browsePath || "").trim()
        return p === "" ? "library root" : p
    }

    function currentFolderLabel() {
        var p = String(currentPlaylistPath || browsePath || "").trim()
        return p === "" ? "library root" : p
    }

    function setCurrentPlaylistFromTracks(folderPath, folderTracks) {
        currentPlaylistTracks = folderTracks.slice()
        currentPlaylistPath = String(folderPath || "")
        currentPlaylistActive = true
    }

    function browseQueueFolder(entry) {
        if (!entry || entry.type !== "dir" || !entry.path)
            return
        var folderPath = String(entry.path)
        runBrowseQuery(["browse", folderPath, "--json", "--queue"], function(text) {
            try {
                var data = JSON.parse(String(text || "{}"))
                var folderTracks = data.tracks || []
                if (!folderTracks.length) {
                    root.notify("no tracks in folder", 2500)
                    return
                }
                if (root.currentPlaylistActive) {
                    var seen = {}
                    for (var j = 0; j < root.currentPlaylistTracks.length; j++)
                        seen[root.currentPlaylistTracks[j].path] = true
                    var toAppend = []
                    for (var k = 0; k < folderTracks.length; k++) {
                        if (!seen[folderTracks[k].path])
                            toAppend.push(folderTracks[k])
                    }
                    if (!toAppend.length) {
                        root.notify("folder already in queue", 2500)
                        return
                    }
                    root.currentPlaylistTracks = root.currentPlaylistTracks.concat(toAppend)
                    root.selectedPlaylist = root.currentPlaylistId
                    root.commitCurrentPlaylist()
                    var args = ["queue", "append"]
                    for (var m = 0; m < toAppend.length; m++)
                        args.push(toAppend[m].path)
                    root.runMusic(args, function() { root.refreshStatus() }, cmdProc)
                } else {
                    root.setCurrentPlaylistFromTracks(folderPath, folderTracks)
                    root.selectedPlaylist = root.currentPlaylistId
                    root.commitCurrentPlaylist()
                    root.playPath(folderTracks[0].path, true)
                }
            } catch (e) {
                root.notify("could not load folder", 2500)
            }
        })
    }

    function playBrowseTrack(entry) {
        if (!entry || !entry.path)
            return
        if (!root.isTrackSelected(entry.path)) {
            selectBrowseTrack(entry)
            return
        }
        stageCurrentPlaylistFromBrowse(entry)
        selectedPlaylist = currentPlaylistId
        playPathFromList(entry.path, true)
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
        if (requested === currentPlaylistId) {
            tracksLoading = false
            tracks = currentPlaylistTracks.slice()
            syncSelectedTrackIndex()
            mergePlayerFromTrackList()
            return
        }
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
        if (seekApplyPending) {
            var reportedPos = Number(parsed.position !== undefined ? parsed.position : seekApplyTarget)
            if (Math.abs(reportedPos - seekApplyTarget) <= 2) {
                seekApplyPending = false
                seekSettleTimer.stop()
            } else {
                parsed = Object.assign({}, parsed, {
                    position: seekApplyTarget,
                    position_label: root.formatPlaybackTime(seekApplyTarget)
                })
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

    function formatPlaybackTime(sec) {
        var s = Math.max(0, Math.floor(Number(sec) || 0))
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        var r = s % 60
        var mm = h > 0 ? (m < 10 ? "0" : "") + m : String(m)
        var rr = (r < 10 ? "0" : "") + r
        return h > 0 ? (h + ":" + mm + ":" + rr) : (mm + ":" + rr)
    }

    function scrubSecondsFromX(x, width) {
        if (!player.duration || width <= 0)
            return -1
        var ratio = Math.max(0, Math.min(1, x / width))
        return ratio * player.duration
    }

    function scrubTo(seconds) {
        var dur = Number(player.duration) || 0
        if (dur <= 0)
            return
        var sec = Math.max(0, Math.min(dur, Number(seconds) || 0))
        seekApplyTarget = sec
        seekApplyPending = true
        seekSettleTimer.stop()
        var next = Object.assign({}, player)
        next.position = sec
        next.position_label = formatPlaybackTime(sec)
        player = next
        if (waveCanvas)
            waveCanvas.requestPaint()
    }

    function previewSeekFromX(x, width) {
        var sec = scrubSecondsFromX(x, width)
        if (sec >= 0)
            scrubTo(sec)
    }

    function queueSeek(seconds) {
        var dur = Number(player.duration) || 0
        if (dur <= 0)
            return
        seekApplyTarget = Math.max(0, Math.min(dur, Number(seconds) || 0))
        seekApplyPending = true
        seekSettleTimer.stop()
        seekApplyTimer.restart()
    }

    function flushSeekApply() {
        if (!seekApplyPending)
            return
        if (seekProc.running) {
            seekApplyTimer.restart()
            return
        }
        runPlayer(["seek", String(seekApplyTarget)], null, seekProc)
        seekSettleTimer.restart()
    }

    function finishSeekSettle() {
        if (!seekApplyPending)
            return
        seekApplyPending = false
    }

    function commitSeekFromX(x, width) {
        var sec = scrubSecondsFromX(x, width)
        if (sec < 0)
            return
        scrubTo(sec)
        queueSeek(sec)
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
        if (volumeProc.running) {
            volumeApplyTimer.restart()
            return
        }
        runPlayer(["volume", "set", String(volumeApplyTarget)], null, volumeProc)
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

    function startLoad(path, useFolder) {
        if (!path)
            return
        var args = ["bash", playerScript, "load", path]
        if (useFolder)
            args.push("--folder")
        loadProc.command = args
        loadProc.running = true
    }

    function playPath(path, useFolder) {
        if (!path)
            return
        primePlayerForPath(path)
        var trackPath = String(path)
        var folderQueue = !!useFolder
        if (loadProc.running) {
            loadProc.pendingPath = trackPath
            loadProc.pendingFolder = folderQueue
            return
        }
        startLoad(trackPath, folderQueue)
    }

    function playPathFromList(path, useFolder) {
        if (!path)
            return
        playPath(path, useFolder)
    }

    function setCurrentPlaylistFromIndex(index) {
        if (index < 0 || index >= tracks.length)
            return
        var queued = []
        for (var j = index; j < tracks.length; j++)
            queued.push(tracks[j])
        currentPlaylistTracks = queued
        currentPlaylistActive = true
        injectCurrentPlaylist()
        refreshCurrentPlaylistView()
    }

    function playTrackAt(index) {
        if (index < 0 || index >= tracks.length)
            return
        var path = tracks[index].path
        if (!path)
            return
        if (selectedTrackIndex === index) {
            var folderQueue = selectedPlaylist === currentPlaylistId
            if (folderQueue)
                setCurrentPlaylistFromIndex(index)
            else
                clearCurrentPlaylist()
            playPathFromList(path, folderQueue)
            return
        }
        selectedTrackIndex = index
    }

    function selectPlaylistTrack(index) {
        if (index < 0 || index >= tracks.length)
            return
        selectedTrackIndex = index
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
        favoriteProc.command = ["bash", playerScript].concat(args || [])
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
                if (!liked && root.selectedPlaylist !== "all" && root.selectedPlaylist !== root.currentPlaylistId)
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
        id: seekProc
        property var _onDone: null
        stdout: StdioCollector {
            onStreamFinished: {
                if (seekProc._onDone)
                    seekProc._onDone(text)
            }
        }
    }

    Process {
        id: volumeProc
        property var _onDone: null
        stdout: StdioCollector {
            onStreamFinished: {
                if (volumeProc._onDone)
                    volumeProc._onDone(text)
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
        property bool pendingFolder: false
        stdout: StdioCollector {}
        onExited: function() {
            root.refreshStatus()
            if (pendingPath) {
                var next = pendingPath
                var folder = pendingFolder
                pendingPath = ""
                pendingFolder = false
                root.startLoad(next, folder)
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
        id: seekApplyTimer
        interval: 120
        repeat: false
        onTriggered: root.flushSeekApply()
    }

    Timer {
        id: seekSettleTimer
        interval: 1500
        repeat: false
        onTriggered: root.finishSeekSettle()
    }

    Timer {
        id: volumeApplyTimer
        interval: 120
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
                    active: root.playerScreen === "playlistLibrary" || root.playerScreen === "playlists"
                    onActivated: root.openPlaylistLibrary()
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
                                    font.pixelSize: root.listFont
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
                                        visible: root.nowPlayingAlbum !== ""
                                        text: root.nowPlayingAlbum
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.listFont + 1
                                        opacity: 0.62
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: (root.player.artist || "") !== ""
                                        text: root.player.artist
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.listFont + 1
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
                                        visible: root.selectedPlaylist !== "" || root.currentPlaylistActive
                                        text: "From playlist: " + root.nowPlayingPlaylistLabel()
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
                                        var vPad = Math.max(12, height * 0.12)
                                        var drawH = Math.max(8, height - vPad * 2)
                                        var mid = vPad + drawH / 2
                                        var halfH = drawH * 0.5
                                        var maxAmp = halfH * 0.93
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
                                        var pitch = barW + gap
                                        var barCount = Math.max(64, Math.floor(width / pitch))
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
                                                var sum = 0
                                                var cnt = 0
                                                for (var j = start; j < end && j < n; j++) {
                                                    var v = Number(samples[j]) || 0
                                                    peak = Math.max(peak, v)
                                                    sum += v
                                                    cnt++
                                                }
                                                var avg = cnt ? sum / cnt : 0
                                                peaks.push(peak * 0.48 + avg * 0.52)
                                            }
                                        }

                                        var playX = width * prog
                                        var sorted = peaks.slice(0, barCount)
                                        sorted.sort(function(a, b) { return a - b })
                                        var floorVal = sorted[Math.max(0, Math.floor(barCount * 0.04))]
                                        var ceilVal = sorted[Math.min(barCount - 1, Math.floor(barCount * 0.994))]
                                        var span = Math.max(1, ceilVal - floorVal)
                                        var refPeak = Math.max(1, sorted[barCount - 1])

                                        var fg = Theme.foreground
                                        var accent = Theme.accent
                                        var win = 5
                                        var halfWin = Math.floor(win / 2)

                                        for (var i = 0; i < barCount; i++) {
                                            var lo = peaks[i]
                                            var hi = peaks[i]
                                            var w0 = Math.max(0, i - halfWin)
                                            var w1 = Math.min(barCount - 1, i + halfWin)
                                            for (var k = w0; k <= w1; k++) {
                                                lo = Math.min(lo, peaks[k])
                                                hi = Math.max(hi, peaks[k])
                                            }
                                            var localSpan = hi - lo
                                            var local = localSpan > 0.5
                                                ? (peaks[i] - lo) / localSpan
                                                : (((i * 11 + Math.floor(peaks[i] * 3)) % 29) / 29)
                                            var global = Math.max(0, Math.min(1, (peaks[i] - floorVal) / span))
                                            var envelope = 0.72 + 0.28 * Math.pow(peaks[i] / refPeak, 0.45)
                                            var blended = 0.38 * Math.pow(local, 0.9) + 0.62 * Math.pow(global, 0.8)
                                            var signal = 0.34 + 0.66 * blended
                                            var amp = Math.pow(signal, 1.38) * maxAmp * envelope
                                            amp = Math.max(1.2, amp)
                                            var x = i * pitch
                                            var w = barW
                                            var played = (x + w * 0.5) <= playX

                                            if (played) {
                                                ctx.fillStyle = accent
                                                ctx.globalAlpha = 0.98
                                                ctx.fillRect(x, mid - amp, w, amp)
                                                ctx.globalAlpha = 0.38
                                                ctx.fillRect(x, mid, w, amp)
                                            } else {
                                                ctx.fillStyle = Qt.rgba(fg.r, fg.g, fg.b, 1)
                                                ctx.globalAlpha = 0.58
                                                ctx.fillRect(x, mid - amp, w, amp)
                                                ctx.globalAlpha = 0.24
                                                ctx.fillRect(x, mid, w, amp)
                                            }
                                        }
                                        ctx.globalAlpha = 1

                                        ctx.strokeStyle = accent
                                        ctx.lineWidth = 1
                                        ctx.beginPath()
                                        ctx.moveTo(0, mid + 0.5)
                                        ctx.lineTo(width, mid + 0.5)
                                        ctx.stroke()

                                        if (prog > 0) {
                                            ctx.fillStyle = Qt.rgba(accent.r, accent.g, accent.b, 0.95)
                                            ctx.fillRect(Math.max(0, playX - 1), vPad, 2, drawH)
                                        }
                                    }
                                }

                                MouseArea {
                                    z: 1
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: function(mouse) {
                                        root.previewSeekFromX(mouse.x, width)
                                    }
                                    onPositionChanged: function(mouse) {
                                        if (pressed)
                                            root.previewSeekFromX(mouse.x, width)
                                    }
                                    onReleased: function(mouse) {
                                        root.commitSeekFromX(mouse.x, width)
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
                                        font.pixelSize: root.listFont
                                        opacity: 0.65
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: root.player.duration_label || "0:00"
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.listFont
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

                                Rectangle {
                                    anchors.fill: parent
                                    visible: coverDrop.containsDrag
                                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                    border.color: Theme.accent
                                    border.width: 2
                                    radius: 3

                                    Text {
                                        anchors.centerIn: parent
                                        text: "drop image"
                                        color: Theme.accent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.libraryFont
                                        opacity: 0.9
                                    }
                                }

                                DropArea {
                                    id: coverDrop
                                    anchors.fill: parent
                                    keys: ["text/uri-list"]

                                    onEntered: function(drag) {
                                        var ok = false
                                        if (drag.hasUrls) {
                                            for (var i = 0; i < drag.urls.length; i++) {
                                                if (root.isImagePath(root.localPathFromUrl(drag.urls[i]))) {
                                                    ok = true
                                                    break
                                                }
                                            }
                                        }
                                        drag.accepted = ok
                                    }

                                    onDropped: function(drop) {
                                        if (!drop.hasUrls || !root.player.path)
                                            return
                                        for (var j = 0; j < drop.urls.length; j++) {
                                            var p = root.localPathFromUrl(drop.urls[j])
                                            if (root.isImagePath(p)) {
                                                root.setAlbumArtFromFile(p)
                                                break
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: coverClick
                                    z: 1
                                    anchors.fill: parent
                                    enabled: !root.artPickerOpen
                                    hoverEnabled: true
                                    cursorShape: (root.player.path || "") !== ""
                                        ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: function(mouse) {
                                        if (!(root.player.path || ""))
                                            return
                                        mouse.accepted = true
                                        root.openArtPicker()
                                    }
                                }

                                ArtPickerOverlay {
                                    z: 2
                                    anchors.fill: parent
                                    visible: root.artPickerOpen
                                }
                            }
                        }
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
                                font.pixelSize: root.listFont
                                opacity: 0.45
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !root.browseLoading && root.browseEntries.length === 0
                                text: "empty folder"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.listFont
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
                                        font.pixelSize: root.listFont
                                    }

                                    Item {
                                        z: 2
                                        Layout.preferredWidth: 22
                                        Layout.preferredHeight: 22
                                        Layout.alignment: Qt.AlignVCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰐊"
                                            color: Theme.accent
                                            opacity: browseFolderPlayMouse.containsMouse ? 1 : 0.55
                                            font.family: Theme.fontFamily
                                            font.pixelSize: root.listFont
                                        }

                                        MouseArea {
                                            id: browseFolderPlayMouse
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: function(mouse) {
                                                mouse.accepted = true
                                                root.browseQueueFolder(modelData)
                                            }
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Text {
                                            anchors.fill: parent
                                            text: modelData.name
                                            color: Theme.foreground
                                            font.family: Theme.fontFamily
                                            font.pixelSize: root.listFont
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
                                            font.pixelSize: root.listFont
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

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: pad

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
                            font.pixelSize: root.listFont
                            opacity: 0.45
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !root.playlistsLoading && root.libraryPlaylists.length === 0
                            text: "no playlists"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.listFont
                            opacity: 0.45
                        }

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            readonly property bool isCurrentEntry: modelData.name === root.currentPlaylistId
                            readonly property int pinReserve: isCurrentEntry ? 0 : 30
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
                                    visible: !parent.parent.isCurrentEntry

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.starred ? "󰓎" : "󰓄"
                                        color: modelData.starred ? Theme.accent : Theme.foreground
                                        opacity: modelData.starred ? 1 : (playlistPinMouse.containsMouse ? 0.65 : 0.42)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.listFont
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.playlistTabLabel(modelData.name || "")
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.listFont
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: String(modelData.count || 0)
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.listFont
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
                                visible: !parent.isCurrentEntry
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

                LibrarySidePanel {}
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: pad

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
                                font.pixelSize: root.listFont
                                opacity: 0.45
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: root.tracksLoading && root.selectedPlaylist !== ""
                                text: "loading…"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.listFont
                                opacity: 0.45
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !root.playlistsLoading && root.selectedPlaylist === ""
                                text: "select a playlist"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.listFont
                                opacity: 0.45
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !root.tracksLoading && root.tracks.length === 0 && root.selectedPlaylist !== ""
                                text: "no tracks"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.listFont
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
                                onPressed: root.selectPlaylistTrack(index)
                                onActivated: root.playTrackAt(index)
                                onLikeToggled: root.toggleTrackFavorite(modelData.path)
                            }
                        }
                    }
                }

                LibrarySidePanel {}
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
            font.pixelSize: root.listFont
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

        RowLayout {
            id: transportRow
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 12

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
                visible: showTimestamps
                label: root.player.duration_label || "0:00"
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
                    font.pixelSize: root.listFont - 1
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
                    font.pixelSize: root.listFont
                    elide: Text.ElideRight
                    opacity: browseRow.selected ? 1 : 0.9
                }

                Text {
                    Layout.fillWidth: true
                    visible: String(browseRow.track.artist || "").trim() !== ""
                    text: browseRow.track.artist || ""
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.listFont
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
            onClicked: {
                if (browseRow.selected)
                    browseRow.playRequested()
                else
                    browseRow.pressed()
            }
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
        readonly property bool hovered: trackRowMouse.containsMouse
            || trackPlayMouse.containsMouse
            || trackLikeMouse.containsMouse
            || (!trackRow.selected && trackArtSelectMouse.containsMouse)

        width: rowWidth
        height: 40
        radius: 4
        color: selected
            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
            : (trackRow.hovered
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

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    visible: trackRow.selected
                    color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.48)
                }

                Text {
                    anchors.centerIn: parent
                    visible: trackRow.selected
                    text: "󰐊"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    opacity: trackPlayMouse.containsMouse ? 1 : 0.92
                }

                MouseArea {
                    id: trackPlayMouse
                    z: 3
                    anchors.fill: parent
                    visible: trackRow.selected
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        mouse.accepted = true
                        trackRow.activated()
                    }
                }

                MouseArea {
                    id: trackArtSelectMouse
                    z: 2
                    anchors.fill: parent
                    visible: !trackRow.selected
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: trackRow.pressed()
                }
            }

            Text {
                text: String(trackRow.number)
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: root.listFont
                font.bold: Theme.fontBold
            }

            Text {
                text: "·"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.listFont
                opacity: 0.35
            }

            Text {
                Layout.maximumWidth: Math.min(180, trackRow.rowWidth * 0.28)
                text: trackRow.track.artist || "—"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.listFont
                opacity: 0.65
                elide: Text.ElideRight
            }

            Text {
                text: "·"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.listFont
                opacity: 0.35
            }

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 48
                text: trackRow.track.title || ""
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: root.listFont
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
            onClicked: {
                if (trackRow.selected)
                    trackRow.activated()
                else
                    trackRow.pressed()
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

    component ArtPickerOverlay: Rectangle {
        id: artPickerRoot
        radius: 3
        color: Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.97)
        border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.16)
        border.width: 1
        clip: true

        readonly property int gridColumns: 2
        readonly property int gridSpacing: 4
        readonly property int gridPad: 6
        readonly property int cellSize: Math.max(
            52,
            Math.floor((width - gridPad * 2 - gridSpacing * (gridColumns - 1)) / gridColumns))

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: gridPad
            spacing: 4

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 18

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰅖"
                    color: Theme.foreground
                    opacity: artPickerCloseMouse.containsMouse ? 1 : 0.55
                    font.family: Theme.fontFamily
                    font.pixelSize: root.libraryFont + 1

                    MouseArea {
                        id: artPickerCloseMouse
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeArtPicker()
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.artPickerLoading

                Text {
                    id: artPickerSpinner
                    anchors.centerIn: parent
                    text: "󰇘"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(artPickerRoot.cellSize * 0.45)
                    opacity: 0.9
                    transformOrigin: Item.Center

                    RotationAnimation on rotation {
                        running: root.artPickerLoading
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                visible: !root.artPickerLoading && root.artPickerResults.length === 0
                text: "no results"
                horizontalAlignment: Text.AlignHCenter
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.libraryFont
                opacity: 0.45
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: artPickerGrid.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                visible: !root.artPickerLoading && root.artPickerResults.length > 0

                GridLayout {
                    id: artPickerGrid
                    width: parent.width
                    columns: artPickerRoot.gridColumns
                    columnSpacing: artPickerRoot.gridSpacing
                    rowSpacing: artPickerRoot.gridSpacing

                    Repeater {
                        model: root.artPickerResults

                        Rectangle {
                            required property var modelData
                            required property int index
                            Layout.preferredWidth: artPickerRoot.cellSize
                            Layout.preferredHeight: artPickerRoot.cellSize
                            radius: 3
                            clip: true
                            color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.06)
                            border.color: artPickMouse.containsMouse
                                ? Theme.accent
                                : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.12)
                            border.width: artPickMouse.containsMouse ? 2 : 1

                            Image {
                                anchors.fill: parent
                                source: modelData.url || ""
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                asynchronous: true
                            }

                            MouseArea {
                                id: artPickMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.applyAlbumArtFromUrl(modelData.url)
                            }
                        }
                    }
                }
            }
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

    component LibrarySidePanel: SectionPanel {
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

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: 4
                color: libraryMenuMouse.containsMouse
                    ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.07)
                    : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.04)
                border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.1)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    Text {
                        text: "󰍜"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.libraryFont + 1
                        opacity: 0.8
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "actions"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.libraryFont
                        opacity: libraryMenuMouse.containsMouse ? 1 : 0.78
                    }

                    Text {
                        text: root.libraryMenuOpen ? "󰅃" : "󰅀"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.libraryFont
                        opacity: 0.45
                    }
                }

                MouseArea {
                    id: libraryMenuMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.libraryMenuOpen = !root.libraryMenuOpen
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.libraryMenuOpen
                spacing: 2

                Repeater {
                    model: root.libraryActions

                    LibraryMenuItem {
                        required property var modelData
                        icon: modelData.icon
                        label: modelData.label
                        dimmed: root.libraryJobBusy
                        spinning: root.libraryJobBusy && root.libraryJobActiveLabel === modelData.label
                        onActivated: if (!root.libraryJobBusy) root.runLibraryAction(modelData)
                    }
                }
            }

            Flickable {
                id: libraryJobLogFlickable
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 72
                visible: root.libraryJobBusy || root.jobLog !== ""
                clip: true
                contentWidth: width
                contentHeight: libraryJobLogText.height
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    id: libraryJobLogText
                    width: parent.width
                    text: root.jobLog || (root.libraryJobBusy ? (root.libraryJobActiveLabel + "…") : "")
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
                    libraryJobLogFlickable.contentY = Math.max(0, libraryJobLogFlickable.contentHeight - libraryJobLogFlickable.height)
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    component LibraryMenuItem: Item {
        id: menuItem
        property string icon: ""
        property string label: ""
        property bool dimmed: false
        property bool spinning: false
        signal activated()

        Layout.fillWidth: true
        implicitHeight: 28

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: menuMouse.containsMouse
                ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.06)
                : "transparent"
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Text {
                text: menuItem.icon
                color: Theme.foreground
                opacity: dimmed && !menuItem.spinning ? 0.35 : 0.9
                font.family: Theme.fontFamily
                font.pixelSize: root.libraryFont + 1
                transformOrigin: Item.Center

                RotationAnimation on rotation {
                    running: menuItem.spinning
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                }
            }

            Text {
                text: menuItem.label
                color: Theme.foreground
                opacity: dimmed && !menuItem.spinning ? 0.35 : (menuMouse.containsMouse ? 1 : 0.78)
                font.family: Theme.fontFamily
                font.pixelSize: root.libraryFont
            }
        }

        MouseArea {
            id: menuMouse
            anchors.fill: parent
            enabled: !dimmed
            hoverEnabled: true
            cursorShape: dimmed ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: menuItem.activated()
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
