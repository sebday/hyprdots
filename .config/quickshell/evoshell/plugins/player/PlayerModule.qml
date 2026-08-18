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

    readonly property string playerScript: (Quickshell.env("HOME") || "") + "/.local/bin/evo-player"
    readonly property int pad: Theme.hoverPopupMargin
    readonly property int bodyFont: Theme.fontSize3xl
    readonly property int hintFont: Theme.fontSizeL
    readonly property int listFont: hintFont
    readonly property int titleFont: Theme.fontSize7xl
    readonly property int nowPlayingCompactBreakpoint: 1000
    readonly property bool nowPlayingCompact: root.width > 0 && root.width < nowPlayingCompactBreakpoint
    readonly property int nowPlayingInlineArtSize: 112
    readonly property int nowPlayingArtMaxWidth: !nowPlayingCompact && nowPlayingPanel.width > 0
        ? Math.floor(nowPlayingPanel.width * 0.5)
        : 0
    readonly property int nowPlayingArtWidth: !nowPlayingCompact && nowPlayingPanel.height > 0 && nowPlayingArtMaxWidth > 0
        ? Math.max(160, Math.min(nowPlayingPanel.height, nowPlayingArtMaxWidth))
        : Math.max(160, nowPlayingArtMaxWidth)
    readonly property int nowPlayingControlsHeight: 52
    readonly property int transportBtnSize: 36
    readonly property int nowPlayingTitleFont: nowPlayingCompact
        ? Theme.fontSize6xl
        : Theme.fontSize9xl
    property var waveformSamples: []
    readonly property int iconFont: Theme.fontSize4xl
    readonly property int transportIconFont: iconFont * 2
    readonly property int transportSecondaryIconFont: Math.round(transportIconFont * 0.74)
    readonly property int libraryFont: Theme.fontSizeS
    readonly property int sectionLabelFont: Theme.fontSizeL
    readonly property int genreTabHeight: 34
    readonly property int tabSearchBarWidth: 168
    readonly property bool playerPlaying: String(player.state || "") === "playing"
    readonly property real progress: player.duration > 0
        ? Math.max(0, Math.min(1, player.position / player.duration))
        : 0

    property var genres: []
    property var tracks: []
    property int selectedTrackIndex: -1
    property var player: ({})
    property var libraryStats: ({ tracks: 0, genres: 0 })
    property string musicRoot: ""
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
    property var browseTreeExpanded: ({})
    property var browseTreeChildren: ({})
    property var browseTreeRows: []
    property bool browseTreeLoading: false
    property real browseTreeScrollY: 0
    property real browseTreeRestoreY: -1
    property var browseTreeListView: null
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
    property string tabSearchText: ""
    property bool browseQueueBusy: false
    property bool browsePanelOpen: false
    property bool playlistPanelOpen: false
    readonly property bool sidePanelOpen: browsePanelOpen || playlistPanelOpen
    readonly property bool splitSidePanelMode: browsePanelOpen || playlistPanelOpen
        || playerScreen === "tags" || playerScreen === "filter"
    readonly property bool nowPlayingTabActive: !browsePanelOpen && !playlistPanelOpen
        && !libraryPanelOpen && playerScreen === "nowPlaying"
    property string playlistPanelMode: "tracks"
    property bool queueExtendBusy: false
    property string filterKind: ""
    property string filterLabel: ""
    property var filterTracks: []
    property bool filterLoading: false
    property int volumeApplyTarget: 100
    property bool volumeApplyPending: false
    property bool transportApplyPending: false
    property var transportApplyTarget: null
    property string transportPreviewPath: ""
    property real seekApplyTarget: 0
    property bool seekApplyPending: false
    property bool playbackStatePending: false
    property string playbackStateTarget: ""
    property bool libraryPanelOpen: false
    readonly property var libraryActions: [
        { icon: "󰲹", label: "build all", args: ["build", "all"] },
        { icon: "󰖟", label: "build quick", args: ["build", "quick"] },
        { icon: "󰕧", label: "sync soundcloud", args: ["soundcloud"] },
        { icon: "󰋋", label: "import .incoming", args: ["import"] },
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
            chips.push({ label: year, accent: false, kind: "year", value: year })
        var genre = String(player.genre || "").trim()
        if (genre !== "")
            chips.push({ label: genre, accent: true, kind: "genre", value: genre })
        var durationLabel = String(player.duration_label || "").trim()
        if (durationLabel !== "" && Number(player.duration || 0) > 0)
            chips.push({ label: durationLabel, accent: false, kind: "duration", value: durationLabel })
        return chips
    }
    readonly property string nowPlayingAlbum: {
        var album = String(player.album || "").trim()
        var title = String(player.title || "").trim()
        if (album === "" || album === title)
            return ""
        return album
    }
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

    function showNowPlaying() {
        browsePanelOpen = false
        playlistPanelOpen = false
        libraryPanelOpen = false
        playerScreen = "nowPlaying"
    }

    function toggleBrowsePanel() {
        if (browsePanelOpen) {
            browsePanelOpen = false
            return
        }
        playlistPanelOpen = false
        libraryPanelOpen = false
        browsePanelOpen = true
        playerScreen = "nowPlaying"
        if (!browsePath && !browseTreeRows.length)
            loadBrowseTreeRoot()
    }

    function togglePlaylistPanel() {
        if (playlistPanelOpen) {
            playlistPanelOpen = false
            return
        }
        browsePanelOpen = false
        libraryPanelOpen = false
        playlistPanelOpen = true
        playerScreen = "nowPlaying"
        if (!selectedPlaylist) {
            selectedPlaylist = currentPlaylistId
            loadPlaylistTracks(selectedPlaylist)
        }
    }

    function toggleTagsPanel() {
        if (playerScreen === "tags") {
            playerScreen = "nowPlaying"
            return
        }
        browsePanelOpen = false
        playlistPanelOpen = false
        libraryPanelOpen = false
        playerScreen = "tags"
        loadGenres()
    }

    function isCurrentGenreFolder(folderName) {
        var folder = String(folderName || "")
        if (!folder)
            return false
        var tag = String(player.genre || "").trim().toLowerCase()
        if (folder.toLowerCase() === tag)
            return true
        if (root.genreFolderLabel(folder).toLowerCase() === tag)
            return true
        var path = String(player.path || "").toLowerCase()
        return path.indexOf("/" + folder.toLowerCase() + "/") >= 0
    }

    function retagCurrentTrack(genreFolder) {
        var trackPath = String(player.path || "").trim()
        if (!trackPath) {
            root.notify("nothing playing", 2500)
            return
        }
        if (!genreFolder)
            return
        runMusic(["retag", trackPath, genreFolder, "--json"], function(text) {
            try {
                var result = JSON.parse(String(text || "{}"))
                var newPath = String(result.path || "")
                var p = Object.assign({}, player)
                if (newPath)
                    p.path = newPath
                p.genre = String(result.genre || genreFolder)
                player = p
                root.refreshStatus()
                root.loadGenres()
                root.notify("genre updated", 2000)
            } catch (e) {
                root.notify("could not retag", 2500)
            }
        })
    }

    function checkAutoExtendQueue() {
        if (queueExtendBusy || !currentPlaylistTracks.length)
            return
        var path = String(player.path || "")
        if (!path)
            return
        var idx = -1
        for (var i = 0; i < currentPlaylistTracks.length; i++) {
            if (currentPlaylistTracks[i].path === path) {
                idx = i
                break
            }
        }
        if (idx < 0 || idx < currentPlaylistTracks.length - 1)
            return
        var dur = Number(player.duration) || 0
        var pos = Number(player.position) || 0
        if (dur > 0 && String(player.state || "") === "playing" && pos < dur - 1.5)
            return
        autoExtendQueue()
    }

    function autoExtendQueue() {
        if (queueExtendBusy)
            return
        queueExtendBusy = true
        runMusic(["queue", "extend", "--json"], function(text) {
            queueExtendBusy = false
            try {
                var result = JSON.parse(String(text || "{}"))
                if (Number(result.added || 0) > 0) {
                    root.loadCurrentPlaylist(function() {
                        if (root.playlistPanelOpen && root.selectedPlaylist === root.currentPlaylistId)
                            root.tracks = root.currentPlaylistTracks.slice()
                    })
                    root.notify("+" + result.added + " from " + String(result.folder || "").split("/").pop(), 2500)
                }
            } catch (e) {
            }
            root.refreshStatus()
        }, queuePlayProc)
    }

    function notify(body, durationMs) {
        if (!shell) return
        var notif = shell.serviceFor("evo.notifications")
        if (notif && typeof notif.showBrief === "function")
            notif.showBrief("evo.player", String(body || ""), durationMs || 3000)
    }

    function clearAlbumArt() {
        var track = String(player.path || "")
        if (!track)
            return
        runMusic(["art", "clear", track, "--json"], function() {
            root.onAlbumArtUpdated()
            root.artPickerOpen = false
        })
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

    function toggleLibraryPanel() {
        if (libraryPanelOpen) {
            libraryPanelOpen = false
            return
        }
        playerScreen = "nowPlaying"
        libraryPanelOpen = true
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
            libraryPanelOpen = true
            if (playerScreen !== "tags" && playerScreen !== "filter")
                playerScreen = "nowPlaying"
        }
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
            if (browsePanelOpen)
                loadBrowseTreeRoot()
            if (playlistPanelOpen && selectedPlaylist)
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
                var data = JSON.parse(String(text || "{}"))
                libraryStats = data
                if (data.root)
                    musicRoot = String(data.root)
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
        if (playlistPanelOpen && selectedPlaylist === currentPlaylistId) {
            tracks = currentPlaylistTracks.slice()
            syncSelectedTrackIndex()
        }
    }

    function commitCurrentPlaylist() {
        injectCurrentPlaylist()
        syncPlaylistTabPosition()
        if (selectedPlaylist === currentPlaylistId && playlistPanelOpen)
            loadPlaylistTracks(currentPlaylistId)
        persistCurrentPlaylist()
        prioritizeCurrentAssets()
    }

    function persistCurrentPlaylist() {
        if (!currentPlaylistActive || !currentPlaylistTracks.length) {
            runMusic(["current", "clear"], null, saveCurrentProc)
            return
        }
        var args = ["current", "save"]
        for (var i = 0; i < currentPlaylistTracks.length; i++) {
            if (currentPlaylistTracks[i].path)
                args.push(currentPlaylistTracks[i].path)
        }
        runMusic(args, null, saveCurrentProc)
    }

    function loadCurrentPlaylist(onDone) {
        runPlaylistQuery(["current", "load", "--json"], function(text) {
            try {
                var list = JSON.parse(String(text || "[]"))
                if (list.length > 0) {
                    currentPlaylistTracks = list
                    currentPlaylistActive = true
                    injectCurrentPlaylist()
                }
            } catch (e) {
            }
            if (onDone)
                onDone()
        })
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
        runMusic(["current", "clear"], null, saveCurrentProc)
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
            loadCurrentPlaylist()
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
        if (transportApplyPending) {
            transportApplyTimer.stop()
            transportSettleTimer.stop()
            flushTransportApply()
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
                if (currentPlaylistActive) {
                    selectedPlaylist = currentPlaylistId
                    tracks = currentPlaylistTracks.slice()
                    syncSelectedTrackIndex()
                }
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
        toggleBrowsePanel()
    }

    function openPlaylistLibrary() {
        playerScreen = "nowPlaying"
        browsePanelOpen = false
        playlistPanelOpen = true
        playlistPanelMode = "library"
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

    function browseTreeFolderEntry(path, name) {
        return { type: "dir", path: String(path || ""), name: String(name || "") }
    }

    function rebuildBrowseTreeRows(preserveScroll) {
        var rows = []
        function appendChildren(parentPath, depth) {
            var key = String(parentPath || "")
            var kids = browseTreeChildren[key]
            if (!kids)
                return
            for (var i = 0; i < kids.length; i++) {
                var kid = kids[i]
                if (kid.type === "track") {
                    rows.push({
                        type: "track",
                        path: String(kid.path || ""),
                        name: String(kid.title || kid.name || String(kid.path || "").split("/").pop() || ""),
                        artist: String(kid.artist || ""),
                        track: kid,
                        depth: depth
                    })
                    continue
                }
                var path = String(kid.path || "")
                var expanded = !!browseTreeExpanded[path]
                rows.push({
                    type: "dir",
                    path: path,
                    name: String(kid.name || path.split("/").pop() || path),
                    depth: depth,
                    expanded: expanded,
                    count: kid.count
                })
                if (expanded)
                    appendChildren(path, depth + 1)
            }
        }
        appendChildren("", 0)
        if (preserveScroll && browseTreeListView)
            browseTreeRestoreY = browseTreeListView.contentY
        else if (preserveScroll)
            browseTreeRestoreY = browseTreeScrollY
        else
            browseTreeRestoreY = -1
        browseTreeRows = rows
    }

    function fetchBrowseTreeEntries(relPath, onDone) {
        runBrowseQuery(["browse", String(relPath || ""), "--json"], function(text) {
            try {
                var data = JSON.parse(String(text || "{}"))
                var entries = data.entries || []
                if (onDone)
                    onDone(entries)
            } catch (e) {
                if (onDone)
                    onDone([])
            }
        })
    }

    function loadBrowseTreeRoot() {
        browseTreeLoading = true
        fetchBrowseTreeEntries("", function(entries) {
            browseTreeLoading = false
            var next = Object.assign({}, browseTreeChildren)
            next[""] = entries
            browseTreeChildren = next
            rebuildBrowseTreeRows(false)
        })
    }

    function toggleBrowseTreeNode(path) {
        path = String(path || "")
        var nextExp = Object.assign({}, browseTreeExpanded)
        if (nextExp[path]) {
            delete nextExp[path]
            browseTreeExpanded = nextExp
            rebuildBrowseTreeRows(true)
            return
        }
        nextExp[path] = true
        browseTreeExpanded = nextExp
        if (browseTreeChildren[path]) {
            rebuildBrowseTreeRows(true)
            return
        }
        fetchBrowseTreeEntries(path, function(entries) {
            var nextChild = Object.assign({}, browseTreeChildren)
            nextChild[path] = entries
            browseTreeChildren = nextChild
            rebuildBrowseTreeRows(true)
        })
    }

    function playBrowseTreeTrack(entry) {
        if (!entry || !entry.path)
            return
        playPath(entry.path, false)
    }

    function browseTreeHome() {
        browseTreeExpanded = {}
        browseTreeChildren = {}
        browseTreeRows = []
        loadBrowseTreeRoot()
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
        browseTreeHome()
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
        browseQueueBusy = true
        var folderPath = String(entry.path)
        runBrowseQuery(["browse", folderPath, "--json", "--queue"], function(text) {
            browseQueueBusy = false
            try {
                var data = JSON.parse(String(text || "{}"))
                var folderTracks = data.tracks || []
                if (!folderTracks.length) {
                    root.notify("no tracks in folder", 2500)
                    return
                }
                root.setCurrentPlaylistFromTracks(folderPath, folderTracks)
                root.selectedPlaylist = root.currentPlaylistId
                root.selectedTrackIndex = 0
                var paths = root.pathsFromTracks(folderTracks)
                root.playQueueAt(paths[0], paths)
                root.commitCurrentPlaylist()
            } catch (e) {
                root.notify("could not load folder", 2500)
            }
        })
    }

    function browseAppendFolder(entry) {
        if (!entry || entry.type !== "dir" || !entry.path)
            return
        browseQueueBusy = true
        var folderPath = String(entry.path)
        runBrowseQuery(["browse", folderPath, "--json", "--queue"], function(text) {
            browseQueueBusy = false
            try {
                var data = JSON.parse(String(text || "{}"))
                var folderTracks = data.tracks || []
                if (!folderTracks.length) {
                    root.notify("no tracks in folder", 2500)
                    return
                }
                root.appendTracksToCurrent(folderTracks)
                root.selectedPlaylist = root.currentPlaylistId
                var paths = root.pathsFromTracks(folderTracks)
                if (!paths.length)
                    return
                var args = ["queue", "append"].concat(paths)
                runMusic(args, function() {
                    root.refreshStatus()
                    root.commitCurrentPlaylist()
                }, queuePlayProc)
            } catch (e) {
                root.notify("could not append folder", 2500)
            }
        })
    }

    function openTagsScreen() {
        toggleTagsPanel()
    }

    function openFilter(kind, value, label) {
        browsePanelOpen = false
        playlistPanelOpen = false
        filterKind = String(kind || "")
        filterLabel = String(label || value || "")
        filterTracks = []
        filterLoading = true
        playerScreen = "filter"
        var args = ["find"]
        if (kind === "artist")
            args = args.concat(["--artist", String(value || "")])
        else if (kind === "genre")
            args = args.concat(["--genre", String(value || "")])
        else if (kind === "year")
            args = args.concat(["--year", String(value || "")])
        else
            args.push(String(value || ""))
        args.push("--json")
        runQuery(args, function(text) {
            filterLoading = false
            try {
                filterTracks = JSON.parse(String(text || "[]"))
            } catch (e) {
                filterTracks = []
            }
        })
    }

    function runTabSearch() {
        var q = String(tabSearchText || "").trim()
        if (!q)
            return
        openFilter("search", q, q)
    }

    function filterHeaderTitle() {
        if (filterKind === "artist")
            return "Artist · " + filterLabel
        if (filterKind === "genre")
            return "Genre · " + filterLabel
        if (filterKind === "year")
            return "Year · " + filterLabel
        if (filterKind === "search")
            return "Search · " + filterLabel
        return filterLabel
    }

    function playFilterTrackAt(index) {
        if (index < 0 || index >= filterTracks.length)
            return
        var folderTracks = filterTracks.slice()
        var label = filterHeaderTitle()
        setCurrentPlaylistFromTracks(label, folderTracks)
        selectedPlaylist = currentPlaylistId
        selectedTrackIndex = index
        var paths = pathsFromTracks(folderTracks)
        playQueueAt(paths[index], paths)
        commitCurrentPlaylist()
    }

    function openGenreTracks(genreName) {
        browsePanelOpen = false
        playlistPanelOpen = false
        filterKind = "genre"
        filterLabel = playlistTabLabel(genreName)
        filterTracks = []
        filterLoading = true
        playerScreen = "filter"
        runQuery(["tracks", genreName, "--json"], function(text) {
            filterLoading = false
            try {
                filterTracks = JSON.parse(String(text || "[]"))
            } catch (e) {
                filterTracks = []
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
        if (switchScreen !== false) {
            playerScreen = "nowPlaying"
            browsePanelOpen = false
            playlistPanelOpen = true
            playlistPanelMode = "tracks"
        }
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
        if (transportApplyPending)
            return
        var path = String(player.path)
        var playingIdx = -1
        for (var i = 0; i < tracks.length; i++) {
            if (tracks[i].path === path) {
                playingIdx = i
                break
            }
        }
        if (playingIdx < 0)
            return
        // keep a manual row selection until the user plays or picks another track
        if (selectedTrackIndex >= 0 && selectedTrackIndex < tracks.length
                && tracks[selectedTrackIndex].path !== path)
            return
        selectedTrackIndex = playingIdx
        if (playerScreen !== "playlists")
            return
        var idx = playingIdx
        Qt.callLater(function() {
            if (playlistTrackList && playlistTrackList.count > idx)
                playlistTrackList.positionViewAtIndex(idx, ListView.Center)
        })
    }

    function updateBrowseCrumbs() {
        var crumbs = []
        var path = String(browsePath || "")
        if (!path) {
            browseCrumbs = []
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
        for (var c = 0; c < currentPlaylistTracks.length; c++) {
            if (currentPlaylistTracks[c].path === p)
                return currentPlaylistTracks[c]
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
        if (transportApplyPending && transportPreviewPath) {
            var reportedTrack = String(parsed.path || "")
            if (reportedTrack !== transportPreviewPath) {
                var previewMeta = trackMetaForPath(transportPreviewPath)
                var held = {
                    path: transportPreviewPath,
                    state: "playing"
                }
                if (previewMeta) {
                    if (previewMeta.title)
                        held.title = previewMeta.title
                    if (previewMeta.artist)
                        held.artist = previewMeta.artist
                    if (previewMeta.genre)
                        held.genre = previewMeta.genre
                }
                parsed = Object.assign({}, parsed, held)
            }
        }
        player = Object.assign({}, player, parsed)
        if (String(player.path || "") !== prevPath)
            waveformSamples = []
        checkAutoExtendQueue()
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

    function pathsFromTracks(trackList) {
        var paths = []
        for (var i = 0; i < trackList.length; i++) {
            if (trackList[i] && trackList[i].path)
                paths.push(trackList[i].path)
        }
        return paths
    }

    function appendTracksToCurrent(slice) {
        var seen = {}
        var i
        for (i = 0; i < currentPlaylistTracks.length; i++) {
            if (currentPlaylistTracks[i].path)
                seen[currentPlaylistTracks[i].path] = true
        }
        var merged = currentPlaylistTracks.slice()
        for (i = 0; i < slice.length; i++) {
            if (!slice[i] || !slice[i].path || seen[slice[i].path])
                continue
            seen[slice[i].path] = true
            merged.push(slice[i])
        }
        currentPlaylistTracks = merged
        currentPlaylistActive = true
    }

    function playQueueAt(startPath, pathList) {
        if (!startPath || !pathList || !pathList.length)
            return
        primePlayerForPath(startPath)
        var args = ["queue", "play", startPath]
        for (var i = 0; i < pathList.length; i++)
            args.push(pathList[i])
        runMusic(args, function() { root.refreshStatus() }, queuePlayProc)
    }

    function jumpCurrentAtNow(index) {
        if (index < 0)
            return
        var startPath = ""
        if (index < tracks.length && tracks[index] && tracks[index].path)
            startPath = tracks[index].path
        else if (index < currentPlaylistTracks.length && currentPlaylistTracks[index])
            startPath = currentPlaylistTracks[index].path
        if (!startPath)
            return
        var paths = pathsFromTracks(currentPlaylistTracks)
        if (paths.indexOf(startPath) < 0)
            return
        playQueueAt(startPath, paths)
        selectedTrackIndex = index
    }

    function playFromPlaylistAtNow(index) {
        if (index < 0 || index >= tracks.length)
            return
        var startPath = tracks[index].path
        if (!startPath)
            return
        var slice = tracks.slice(index)
        appendTracksToCurrent(slice)
        selectedPlaylist = currentPlaylistId
        var startIdx = -1
        for (var k = 0; k < currentPlaylistTracks.length; k++) {
            if (currentPlaylistTracks[k].path === startPath) {
                startIdx = k
                break
            }
        }
        var paths = pathsFromTracks(currentPlaylistTracks)
        playQueueAt(startPath, paths)
        selectedTrackIndex = startIdx >= 0 ? startIdx : index
        commitCurrentPlaylist()
    }

    function resolveCurrentTrackIndex() {
        var path = String(player.path || "")
        var i
        if (path) {
            for (i = 0; i < tracks.length; i++) {
                if (tracks[i].path === path)
                    return i
            }
            for (i = 0; i < currentPlaylistTracks.length; i++) {
                if (currentPlaylistTracks[i].path === path)
                    return i
            }
        }
        if (selectedTrackIndex >= 0)
            return selectedTrackIndex
        return 0
    }

    function previewTrackIndex(index) {
        var path = ""
        if (index >= 0 && index < tracks.length && tracks[index] && tracks[index].path)
            path = tracks[index].path
        else if (index >= 0 && index < currentPlaylistTracks.length && currentPlaylistTracks[index])
            path = currentPlaylistTracks[index].path
        if (!path)
            return false
        selectedTrackIndex = index
        transportPreviewPath = path
        primePlayerForPath(path)
        var next = Object.assign({}, player)
        next.state = "playing"
        player = next
        return true
    }

    function queueTransportAction(target) {
        transportApplyTarget = target
        transportApplyPending = true
        transportSettleTimer.stop()
        transportApplyTimer.restart()
    }

    function flushTransportApply() {
        if (!transportApplyPending || !transportApplyTarget)
            return
        if (queuePlayProc.running || transportProc.running) {
            transportApplyTimer.restart()
            return
        }
        var t = transportApplyTarget
        if (t.kind === "jump")
            jumpCurrentAtNow(t.index)
        else if (t.kind === "playlist")
            playFromPlaylistAtNow(t.index)
        else if (t.kind === "mpv")
            runPlayer([t.forward ? "next" : "prev"], function() { root.refreshStatus() }, transportProc)
        transportSettleTimer.restart()
    }

    function finishTransportSettle() {
        if (!transportApplyPending)
            return
        transportApplyPending = false
        transportApplyTarget = null
        transportPreviewPath = ""
    }

    function jumpCurrentAt(index) {
        previewTrackIndex(index)
        queueTransportAction({ kind: "jump", index: index })
    }

    function playFromPlaylistAt(index) {
        previewTrackIndex(index)
        queueTransportAction({ kind: "playlist", index: index })
    }

    function playPathFromList(path, useFolder) {
        if (!path)
            return
        playPath(path, useFolder)
    }

    function playTrackAt(index) {
        if (index < 0 || index >= tracks.length)
            return
        if (!tracks[index].path)
            return
        if (selectedPlaylist === currentPlaylistId)
            jumpCurrentAt(index)
        else
            playFromPlaylistAt(index)
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

    function restoreListViewport(listView, contentY) {
        if (!listView || contentY < 0)
            return
        Qt.callLater(function() {
            if (listView)
                listView.contentY = contentY
        })
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
                for (i = 0; i < browseEntries.length; i++) {
                    entry = browseEntries[i]
                    if (entry.type === "track" && entry.path === trackPath)
                        nextBrowse.push(Object.assign({}, entry, { liked: liked }))
                    else
                        nextBrowse.push(entry)
                }
                var playlistY = playlistTrackList ? playlistTrackList.contentY : -1
                var browseY = browseList ? browseList.contentY : -1
                tracks = nextTracks
                browseEntries = nextBrowse
                restoreListViewport(playlistTrackList, playlistY)
                restoreListViewport(browseList, browseY)
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

    function skipTrack(forward) {
        if (currentPlaylistTracks.length > 1 && selectedPlaylist === currentPlaylistId) {
            var idx = resolveCurrentTrackIndex()
            var nextIdx = forward ? idx + 1 : idx - 1
            if (nextIdx >= 0 && nextIdx < currentPlaylistTracks.length) {
                previewTrackIndex(nextIdx)
                queueTransportAction({ kind: "jump", index: nextIdx })
                return
            }
        }
        queueTransportAction({ kind: "mpv", forward: forward })
    }

    function toggleBrowseFavorite(path) {
        root.toggleTrackFavorite(path)
    }

    function browseAbsPath(relPath) {
        var rel = String(relPath || "").replace(/^\/+/, "")
        var rootPath = String(musicRoot || "").replace(/\/+$/, "")
        if (!rootPath)
            return rel
        return rel ? rootPath + "/" + rel : rootPath
    }

    function openInThunar(targetPath) {
        var target = String(targetPath || "").trim()
        if (!target)
            return
        if (openDirProc.running)
            return
        openDirProc.command = ["thunar", target]
        openDirProc.running = true
    }

    function openBrowseFolder(entry) {
        if (!entry)
            return
        openInThunar(browseAbsPath(entry.path))
    }

    function openTrackInThunar(trackPath) {
        var path = String(trackPath || "").trim()
        if (!path)
            return
        openInThunar(path)
    }

    function openPlaylistFolder(playlistName) {
        var name = String(playlistName || "").trim()
        if (!name)
            return
        if (name === currentPlaylistId) {
            var rel = String(currentPlaylistPath || "").trim()
            openInThunar(rel ? browseAbsPath(rel) : browseAbsPath(""))
            return
        }
        if (name === "all") {
            openInThunar(browseAbsPath(""))
            return
        }
        openInThunar(browseAbsPath(name))
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
        id: openDirProc
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
        id: queuePlayProc
        property var _onDone: null
        stdout: StdioCollector {
            onStreamFinished: {
                if (queuePlayProc._onDone)
                    queuePlayProc._onDone(text)
            }
        }
    }

    Process {
        id: transportProc
        property var _onDone: null
        stdout: StdioCollector {
            onStreamFinished: {
                if (transportProc._onDone)
                    transportProc._onDone(text)
            }
        }
    }

    Process {
        id: saveCurrentProc
        property var _onDone: null
        stdout: StdioCollector {
            onStreamFinished: {
                if (saveCurrentProc._onDone)
                    saveCurrentProc._onDone(text)
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
        id: tabSearchDebounce
        interval: 650
        repeat: false
        onTriggered: {
            var q = String(root.tabSearchText || "").trim()
            if (!q)
                return
            root.runTabSearch()
        }
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
        id: transportApplyTimer
        interval: 120
        repeat: false
        onTriggered: root.flushTransportApply()
    }

    Timer {
        id: transportSettleTimer
        interval: 1500
        repeat: false
        onTriggered: root.finishTransportSettle()
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
                spacing: Theme.spacingM

                RowLayout {
                    id: standardTabBar
                    visible: !root.libraryPanelOpen
                    Layout.fillWidth: true
                    spacing: Theme.spacingM

                IconTab {
                    icon: "󰎆"
                    active: root.nowPlayingTabActive
                    spinning: queuePlayProc.running || loadProc.running || root.browseQueueBusy
                    onActivated: root.showNowPlaying()
                }
                IconTab {
                    icon: "󰉋"
                    active: root.browsePanelOpen
                    onActivated: root.toggleBrowsePanel()
                }
                IconTab {
                    icon: "󰓹"
                    active: root.playerScreen === "tags"
                    onActivated: root.toggleTagsPanel()
                }
                IconTab {
                    icon: "󰲸"
                    active: root.playlistPanelOpen
                    onActivated: root.togglePlaylistPanel()
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: Math.max(12, root.genreTabHeight - 16)
                    Layout.alignment: Qt.AlignVCenter
                    color: Theme.foregroundDivider
                }

                Item {
                    id: playlistTabBarHost
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: playlistTabBar
                        anchors.fill: parent
                        orientation: ListView.Horizontal
                        spacing: Theme.spacingS
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
                                color: root.playlistPanelOpen && root.selectedPlaylist === name
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
                                    : (playlistTabMouse.containsMouse
                                        ? Theme.foregroundWash
                                        : "transparent")
                            }

                            Row {
                                id: playlistTabContent
                                anchors.centerIn: parent
                                spacing: Theme.spacingS

                                Text {
                                    text: root.playlistTabLabel(name)
                                    color: root.playlistPanelOpen && root.selectedPlaylist === name ? Theme.accent : Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.listFont
                                    font.bold: root.playlistPanelOpen && root.selectedPlaylist === name && Theme.fontBold
                                    opacity: root.playlistPanelOpen && root.selectedPlaylist === name ? 1 : 0.78
                                }

                                Text {
                                    text: String(count || 0)
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.libraryFont
                                    opacity: Theme.opacityDisabled
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

                RowLayout {
                    visible: root.libraryPanelOpen
                    Layout.fillWidth: true
                    spacing: Theme.spacingM

                    Text {
                        visible: root.libraryJobBusy
                        text: root.libraryJobActiveLabel + "…"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: root.libraryFont
                        font.bold: Theme.fontBold
                        elide: Text.ElideRight
                        Layout.maximumWidth: 140
                    }

                    Text {
                        visible: !root.libraryJobBusy
                        text: (root.libraryStats.tracks || 0) + " tracks · " + (root.libraryStats.genres || 0) + " genres"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.libraryFont
                        opacity: 0.5
                        elide: Text.ElideRight
                        Layout.maximumWidth: 160
                    }

                    ListView {
                        id: libraryActionBar
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        orientation: ListView.Horizontal
                        spacing: Theme.spacingS
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.libraryActions

                        delegate: LibraryBarAction {
                            required property var modelData
                            barHeight: root.genreTabHeight
                            icon: modelData.icon
                            label: modelData.label
                            dimmed: root.libraryJobBusy
                            spinning: root.libraryJobBusy && root.libraryJobActiveLabel === modelData.label
                            onActivated: if (!root.libraryJobBusy) root.runLibraryAction(modelData)
                        }
                    }
                }

                Item {
                    Layout.preferredWidth: root.tabSearchBarWidth
                    Layout.preferredHeight: root.genreTabHeight
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: Theme.foregroundWash
                        border.color: tabSearchInput.activeFocus
                            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                            : Theme.foregroundDivider
                        border.width: 1

                        TextInput {
                            id: tabSearchInput
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.libraryFont
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.mantle
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            onTextChanged: {
                                root.tabSearchText = text
                                tabSearchDebounce.restart()
                            }
                            onAccepted: {
                                tabSearchDebounce.stop()
                                root.runTabSearch()
                            }
                            Keys.onEscapePressed: {
                                tabSearchDebounce.stop()
                                root.tabSearchText = ""
                                text = ""
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            visible: !tabSearchInput.text && !tabSearchInput.activeFocus
                            text: "search…"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.libraryFont
                            opacity: 0.4
                        }
                    }
                }

                IconTab {
                    icon: "󰠮"
                    active: root.libraryPanelOpen
                    spinning: root.libraryJobBusy
                    onActivated: root.toggleLibraryPanel()
                }
            }
        }

        // Now playing / library panels
        Item {
            id: nowPlayingPanel
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0

            RowLayout {
                    anchors.fill: parent
                    spacing: pad

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: pad

                        SectionPanel {
                            label: ""
                            visible: !root.splitSidePanelMode
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            fillHeight: true

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: pad

                                RowLayout {
                                    id: titleRow
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingL

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingM

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
                                            font.pixelSize: Theme.fontSizeXl
                                            opacity: 0.62
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            visible: (root.player.artist || "") !== ""
                                            text: String(root.player.artist || "")
                                            color: Theme.foreground
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXl
                                            font.bold: Theme.fontBold
                                            opacity: artistMouse.containsMouse ? 1 : 0.72
                                            elide: Text.ElideRight

                                            MouseArea {
                                                id: artistMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: function(mouse) {
                                                    var artist = String(root.player.artist || "").trim()
                                                    if (!artist)
                                                        return
                                                    mouse.accepted = true
                                                    root.openFilter("artist", artist, artist)
                                                }
                                            }
                                        }

                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: Theme.spacingS
                                            visible: root.nowPlayingMetaChips.length > 0

                                            Repeater {
                                                model: root.nowPlayingMetaChips

                                                delegate: MetaChip {
                                                    required property var modelData
                                                    label: modelData.label
                                                    accent: !!modelData.accent
                                                    clickable: modelData.kind === "genre" || modelData.kind === "year"
                                                    onActivated: {
                                                        if (modelData.kind === "genre")
                                                            root.openFilter("genre", modelData.value, modelData.value)
                                                        else if (modelData.kind === "year")
                                                            root.openFilter("year", modelData.value, modelData.value)
                                                    }
                                                }
                                            }
                                        }

                                    }

                                    AlbumArtThumbnail {
                                        visible: root.nowPlayingCompact
                                        side: root.nowPlayingInlineArtSize
                                        showPickerOverlay: false
                                        Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                    }
                                }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: Theme.spacingS

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
                                            ctx.fillStyle = Theme.foregroundHoverWash
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
                                    spacing: Theme.spacingM

                                    Text {
                                        text: root.player.position_label || "0:00"
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.listFont
                                        opacity: Theme.opacityHover
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: root.player.duration_label || "0:00"
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.listFont
                                        opacity: Theme.opacityHover
                                    }
                                }
                            }
                        }
                        }

                        PlayerSideBrowsePanel {
                            visible: root.browsePanelOpen
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }

                        PlayerSidePlaylistPanel {
                            visible: root.playlistPanelOpen
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }

                        PlayerSideTagsPanel {
                            visible: root.playerScreen === "tags"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }

                        PlayerSideFilterPanel {
                            visible: root.playerScreen === "filter"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }

                        SectionPanel {
                            label: ""
                            Layout.fillWidth: true
                            contentPad: Theme.panelContentPad

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
                        visible: !root.nowPlayingCompact
                        Layout.fillHeight: true
                        Layout.preferredWidth: root.nowPlayingArtWidth
                        Layout.maximumWidth: root.nowPlayingArtMaxWidth
                        Layout.minimumWidth: 120
                        fillHeight: true

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            AlbumArtThumbnail {
                                readonly property int fitSide: Math.min(parent.width, parent.height, root.nowPlayingArtWidth)
                                side: fitSide
                                showPickerOverlay: true
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                ArtPickerOverlay {
                    anchors.fill: parent
                    anchors.margins: pad
                    visible: root.nowPlayingCompact && root.artPickerOpen
                    z: 100
                }
            }
        }
    }

    component AlbumArtThumbnail: Item {
        id: thumbRoot
        property int side: 56
        property bool showPickerOverlay: false
        property bool fillPane: false

        implicitWidth: fillPane ? 0 : side
        implicitHeight: fillPane ? 0 : side
        width: fillPane ? undefined : side
        height: fillPane ? undefined : side

        Rectangle {
            id: coverFrame
            anchors.fill: parent
            radius: fillPane ? Theme.fieldsetCornerRadius : 3
            clip: true
            color: Theme.foregroundFaint

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
                font.pixelSize: Math.round((fillPane ? Math.min(thumbRoot.width, thumbRoot.height) : thumbRoot.side) * 0.38)
                opacity: 0.5
            }

            Rectangle {
                anchors.fill: parent
                visible: coverDrop.containsDrag
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                border.color: Theme.accent
                border.width: 2
                radius: Theme.radiusM

                Text {
                    anchors.centerIn: parent
                    text: "drop image"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: root.libraryFont
                    opacity: Theme.opacityEmphasis
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
                onWheel: function(wheel) {
                    if (!wheel.angleDelta.y)
                        return
                    root.adjustVolume(wheel.angleDelta.y > 0 ? 5 : -5)
                    wheel.accepted = true
                }
            }

            ArtPickerOverlay {
                z: 2
                anchors.fill: parent
                visible: thumbRoot.showPickerOverlay && root.artPickerOpen
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
            : (clickable && chipMouse.containsMouse) ? Theme.foregroundHoverWash : Theme.foregroundWash
        border.color: accent
            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.38)
            : Theme.foregroundDivider
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

        radius: Theme.radiusL
        color: Theme.foregroundWash
        border.color: Theme.foregroundDivider
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
                    onActivated: root.skipTrack(false)
                }
                TransportBtn {
                    icon: root.playerPlaying ? "󰏤" : "󰐊"
                    accent: true
                    onActivated: root.togglePlayback()
                }
                TransportBtn {
                    icon: "󰒭"
                    onActivated: root.skipTrack(true)
                }
                TransportBtn {
                    icon: "󰒟"
                    smallGlyph: true
                    dimmed: !root.player.shuffle
                    onActivated: root.runPlayer(["shuffle", "toggle"], root.refreshStatus, transportProc)
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
                border.color: Theme.foregroundTrack
                border.width: 1
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: Theme.spacingM

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: volBtn.level + "%"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeM
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
                        radius: Theme.radiusS
                        color: Theme.foregroundDivider
                    }

                    Rectangle {
                        anchors.horizontalCenter: volTrack.horizontalCenter
                        anchors.bottom: volTrack.bottom
                        width: volTrack.width
                        height: volTrack.height * (volBtn.level / 100)
                        radius: Theme.radiusS
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

    component RowIconButton: Item {
        id: rowIconBtn
        property string icon: ""
        property color iconColor: Theme.foreground
        property real opacityIdle: 0.42
        property real opacityHover: 0.9
        property bool enabled: true
        property int iconSize: root.listFont
        signal activated()

        implicitWidth: 22
        implicitHeight: 22
        Layout.preferredWidth: 22
        Layout.preferredHeight: 22
        Layout.alignment: Qt.AlignVCenter
        z: 2

        Text {
            anchors.centerIn: parent
            text: rowIconBtn.icon
            color: rowIconBtn.iconColor
            opacity: !rowIconBtn.enabled ? 0.2
                : (rowIconMouse.containsMouse ? rowIconBtn.opacityHover : rowIconBtn.opacityIdle)
            font.family: Theme.fontFamily
            font.pixelSize: rowIconBtn.iconSize
        }

        MouseArea {
            id: rowIconMouse
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            enabled: rowIconBtn.enabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: function(mouse) {
                mouse.accepted = true
                rowIconBtn.activated()
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
        signal folderOpenRequested()

        readonly property bool trackLiked: !!track.liked
        readonly property int genreReserve: 108
        readonly property int likeReserve: 30
        readonly property int folderReserve: 30
        readonly property bool hovered: browseRowMouse.containsMouse
            || browsePlayMouse.containsMouse
            || browseLikeMouse.containsMouse
            || (!browseRow.selected && browseArtSelectMouse.containsMouse)

        width: rowWidth
        height: 40
        radius: Theme.radiusL
        color: selected
            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
            : (browseRowMouse.containsMouse
                ? Theme.foregroundGhost
                : "transparent")

        RowLayout {
            z: 0
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: Theme.spacingM

            Item {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusL
                    clip: true
                    color: Theme.foregroundFaint
                    visible: !browseArt.visible
                }

                Text {
                    anchors.centerIn: parent
                    visible: !browseArt.visible
                    text: "󰎈"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeL
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
                    radius: Theme.radiusL
                    visible: browseRow.selected
                    color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.48)
                }

                Text {
                    anchors.centerIn: parent
                    visible: browseRow.selected
                    text: "󰐊"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize3xl
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
                    opacity: Theme.opacityMuted
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

            RowIconButton {
                icon: "󰉖"
                onActivated: browseRow.folderOpenRequested()
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
            anchors.rightMargin: browseRow.genreReserve + browseRow.likeReserve + browseRow.folderReserve
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
        property bool showNumber: true
        property bool selected: false
        property bool showMeta: false
        property bool showLike: false
        property bool showFolderOpen: false
        property bool capturePress: true
        property int rowWidth: 0
        signal pressed()
        signal activated()
        signal likeToggled()
        signal folderOpenRequested()

        readonly property string trackGenre: String(track.genre || "").trim()
        readonly property bool trackLiked: !!track.liked
        readonly property bool likeEnabled: showMeta || showLike
        readonly property int folderReserve: showFolderOpen ? 30 : 0
        readonly property int likeReserve: (showMeta ? 136 : (showLike ? 36 : 0)) + folderReserve
        readonly property int artReserve: likeEnabled || showFolderOpen ? 44 : 0
        readonly property bool hovered: trackRowMouse.containsMouse
            || trackPlayMouse.containsMouse
            || trackLikeMouse.containsMouse
            || (!trackRow.selected && trackArtSelectMouse.containsMouse)

        width: rowWidth
        height: 40
        radius: Theme.radiusL
        color: selected
            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
            : (trackRow.hovered
                ? Theme.foregroundGhost
                : "transparent")

        RowLayout {
            z: 0
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: Theme.spacingL

            Item {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusL
                    clip: true
                    color: Theme.foregroundFaint
                    visible: !trackArt.visible
                }

                Text {
                    anchors.centerIn: parent
                    visible: !trackArt.visible
                    text: "󰎈"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeL
                    opacity: trackArtSelectMouse.containsMouse ? 0.55 : 0.35
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
                    radius: Theme.radiusL
                    visible: trackRow.selected
                    color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.48)
                }

                Text {
                    anchors.centerIn: parent
                    visible: trackRow.selected
                    text: "󰐊"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize3xl
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
                visible: trackRow.showNumber
                text: String(trackRow.number)
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: root.listFont
                font.bold: Theme.fontBold
            }

            Text {
                visible: trackRow.showNumber
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
                opacity: Theme.opacityHover
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

            RowIconButton {
                visible: trackRow.showFolderOpen
                icon: "󰉖"
                onActivated: trackRow.folderOpenRequested()
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
            opacity: Theme.opacityMuted
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
        radius: Theme.radiusM
        color: Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.97)
        border.color: Theme.foregroundSubtle
        border.width: 1
        clip: true

        readonly property int gridSpacing: 4
        readonly property int gridPad: 6

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: gridPad
            spacing: 4

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 18

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: (root.player.art || "") !== ""
                    text: "remove current art"
                    color: artPickerClearMouse.containsMouse ? Theme.accent : Theme.foreground
                    opacity: artPickerClearMouse.containsMouse ? 1 : 0.55
                    font.family: Theme.fontFamily
                    font.pixelSize: root.libraryFont

                    MouseArea {
                        id: artPickerClearMouse
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.clearAlbumArt()
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰅖"
                    color: Theme.foreground
                    opacity: artPickerCloseMouse.containsMouse ? 1 : 0.55
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeM

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

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(artPickerRoot.width * 0.42, 120)
                visible: (root.player.art || "") !== "" && !root.artPickerLoading
                radius: Theme.radiusM
                clip: true
                color: Theme.foregroundWash
                border.color: artCurrentMouse.containsMouse
                    ? Theme.accent
                    : Theme.foregroundRaised
                border.width: artCurrentMouse.containsMouse ? 2 : 1

                Image {
                    anchors.fill: parent
                    source: root.artUrl(root.player.art || "")
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 18
                    color: Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.72)

                    Text {
                        anchors.centerIn: parent
                        text: "current · click to remove"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.libraryFont
                        opacity: 0.8
                    }
                }

                MouseArea {
                    id: artCurrentMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clearAlbumArt()
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
                    font.pixelSize: Math.round(artPickerRoot.width * 0.12)
                    opacity: Theme.opacityEmphasis
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
                opacity: Theme.opacityDisabled
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: artPickerColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                visible: !root.artPickerLoading && root.artPickerResults.length > 0

                Column {
                    id: artPickerColumn
                    width: parent.width
                    spacing: artPickerRoot.gridSpacing

                    Repeater {
                        model: root.artPickerResults

                        Rectangle {
                            required property var modelData
                            required property int index
                            width: artPickerColumn.width
                            height: width
                            radius: Theme.radiusM
                            clip: true
                            color: Theme.foregroundWash
                            border.color: artPickMouse.containsMouse
                                ? Theme.accent
                                : Theme.foregroundRaised
                            border.width: artPickMouse.containsMouse ? 2 : 1

                            Image {
                                anchors.fill: parent
                                source: modelData.url || ""
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                asynchronous: true
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 16
                                visible: String(modelData.source || "") !== ""
                                color: Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.78)

                                Text {
                                    anchors.centerIn: parent
                                    text: String(modelData.source || "")
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.libraryFont
                                    opacity: 0.85
                                }
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
        property bool spinning: false
        signal activated()

        function finishSpinUpright() {
            var r = ((iconTabGlyph.rotation % 360) + 360) % 360
            if (r === 0) {
                iconTabGlyph.rotation = 0
                return
            }
            iconTabFinishSpin.from = iconTabGlyph.rotation
            iconTabFinishSpin.to = iconTabGlyph.rotation + (360 - r)
            iconTabFinishSpin.duration = Math.max(80, Math.round(900 * (360 - r) / 360))
            iconTabFinishSpin.start()
        }

        implicitWidth: root.genreTabHeight
        implicitHeight: root.genreTabHeight
        clip: true

        Connections {
            target: iconTab
            function onSpinningChanged() {
                if (iconTab.spinning) {
                    iconTabFinishSpin.stop()
                    var r = ((iconTabGlyph.rotation % 360) + 360) % 360
                    iconTabGlyph.rotation = r
                } else {
                    iconTab.finishSpinUpright()
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: iconTab.active
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
                : (iconTabMouse.containsMouse
                    ? Theme.foregroundWash
                    : "transparent")
        }

        Text {
            id: iconTabGlyph
            anchors.centerIn: parent
            text: iconTab.icon
            color: iconTab.active || iconTab.spinning ? Theme.accent : Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize7xl
            opacity: iconTab.active || iconTab.spinning ? 1 : 0.78
            transformOrigin: Item.Center

            RotationAnimation {
                id: iconTabSpinLoop
                target: iconTabGlyph
                property: "rotation"
                running: iconTab.spinning
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
            }

            RotationAnimation {
                id: iconTabFinishSpin
                target: iconTabGlyph
                property: "rotation"
                onFinished: iconTabGlyph.rotation = 0
            }
        }

        MouseArea {
            id: iconTabMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: iconTab.activated()
        }
    }

    component PlayerSideBrowsePanel: SectionPanel {
        label: ""
        fillHeight: true

        ListView {
            id: sideBrowseTree
            anchors.fill: parent
            clip: true
            spacing: Theme.spacing2
            model: root.browseTreeRows

            Component.onCompleted: root.browseTreeListView = sideBrowseTree
            Component.onDestruction: {
                if (root.browseTreeListView === sideBrowseTree)
                    root.browseTreeListView = null
            }

            onContentYChanged: {
                if (root.browseTreeRestoreY < 0)
                    root.browseTreeScrollY = contentY
            }

            Timer {
                id: browseTreeScrollRestoreTimer
                interval: 0
                repeat: true
                property int attempts: 0
                onTriggered: {
                    if (root.browseTreeRestoreY < 0) {
                        stop()
                        attempts = 0
                        return
                    }
                    sideBrowseTree.contentY = root.browseTreeRestoreY
                    attempts++
                    if (sideBrowseTree.contentHeight > 0 || attempts > 8) {
                        root.browseTreeRestoreY = -1
                        stop()
                        attempts = 0
                    }
                }
            }

            Connections {
                target: root
                function onBrowseTreeRowsChanged() {
                    if (root.browseTreeRestoreY < 0)
                        return
                    browseTreeScrollRestoreTimer.attempts = 0
                    browseTreeScrollRestoreTimer.restart()
                }
            }

            Text {
                    anchors.centerIn: parent
                    visible: root.browseTreeLoading && root.browseTreeRows.length === 0
                    text: "loading…"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.listFont
                    opacity: Theme.opacityDisabled
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool isDir: modelData.type === "dir"
                    readonly property int indent: 8 + (Number(modelData.depth || 0) * 14)
                    width: sideBrowseTree.width
                    height: isDir ? 34 : 36
                    radius: Theme.radiusL
                    color: isDir
                        ? (treeRowMouse.containsMouse
                            ? Theme.foregroundGhost
                            : "transparent")
                        : (root.isTrackPlaying(modelData.path)
                            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
                            : (treeTrackMouse.containsMouse
                                ? Theme.foregroundGhost
                                : "transparent"))

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: indent
                        anchors.rightMargin: 6
                        spacing: Theme.spacingS
                        visible: isDir

                        Text {
                            Layout.preferredWidth: 14
                            text: modelData.expanded ? "󰅃" : "󰅂"
                            color: Theme.foreground
                            opacity: treeChevronMouse.containsMouse ? 0.9 : 0.45
                            font.family: Theme.fontFamily
                            font.pixelSize: root.libraryFont

                            MouseArea {
                                id: treeChevronMouse
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    mouse.accepted = true
                                    root.toggleBrowseTreeNode(modelData.path)
                                }
                            }
                        }

                        Text {
                            text: "󰉋"
                            color: Theme.foreground
                            opacity: Theme.opacityMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: root.listFont
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
                            visible: modelData.count !== undefined && modelData.count !== null
                            text: String(modelData.count)
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.libraryFont
                            opacity: Theme.opacityDisabled
                        }

                        Text {
                            text: "󰐕"
                            color: Theme.accent
                            opacity: treeAppendMouse.containsMouse ? 1 : 0.55
                            font.family: Theme.fontFamily
                            font.pixelSize: root.listFont

                            MouseArea {
                                id: treeAppendMouse
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    mouse.accepted = true
                                    root.browseAppendFolder(modelData)
                                }
                            }
                        }

                        Text {
                            text: "󰐊"
                            color: Theme.accent
                            opacity: treePlayMouse.containsMouse ? 1 : 0.55
                            font.family: Theme.fontFamily
                            font.pixelSize: root.listFont

                            MouseArea {
                                id: treePlayMouse
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

                        Text {
                            text: "󰉖"
                            color: Theme.foreground
                            opacity: treeOpenMouse.containsMouse ? 0.85 : 0.45
                            font.family: Theme.fontFamily
                            font.pixelSize: root.listFont

                            MouseArea {
                                id: treeOpenMouse
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    mouse.accepted = true
                                    root.openBrowseFolder(modelData)
                                }
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: indent + 14
                        anchors.rightMargin: 6
                        spacing: Theme.spacingM
                        visible: !isDir

                        Text {
                            text: "󰎈"
                            color: Theme.accent
                            opacity: Theme.opacityDisabled
                            font.family: Theme.fontFamily
                            font.pixelSize: root.listFont
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name || ""
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.listFont
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: (modelData.artist || "") !== ""
                                text: modelData.artist
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.libraryFont
                                opacity: 0.5
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            text: "󰐊"
                            color: Theme.accent
                            opacity: treeTrackPlayMouse.containsMouse ? 1 : 0.55
                            font.family: Theme.fontFamily
                            font.pixelSize: root.listFont

                            MouseArea {
                                id: treeTrackPlayMouse
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    mouse.accepted = true
                                    root.playBrowseTreeTrack(modelData.track || modelData)
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: treeRowMouse
                        anchors.fill: parent
                        anchors.rightMargin: 76
                        hoverEnabled: true
                        visible: isDir
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleBrowseTreeNode(modelData.path)
                    }

                    MouseArea {
                        id: treeTrackMouse
                        anchors.fill: parent
                        anchors.rightMargin: 28
                        hoverEnabled: true
                        visible: !isDir
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.playBrowseTreeTrack(modelData.track || modelData)
                    }
                }
            }
    }

    component PlayerSidePlaylistPanel: SectionPanel {
        label: root.playlistPanelMode === "library" ? "Playlists" : ""
        labelFontSize: root.sectionLabelFont
        fillHeight: true

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.spacingS

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingS

                RowIconButton {
                    icon: root.playlistPanelMode === "library" ? "󰎄" : "󰉹"
                    onActivated: {
                        if (root.playlistPanelMode === "library") {
                            root.playlistPanelMode = "tracks"
                            if (!root.selectedPlaylist)
                                root.selectPlaylist(root.currentPlaylistId, false)
                        } else {
                            root.playlistPanelMode = "library"
                            if (!root.libraryPlaylists.length)
                                root.loadPlaylists()
                        }
                    }
                }
            }

            ListView {
                id: sidePlaylistLibraryList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.spacing2
                visible: root.playlistPanelMode === "library"
                model: root.libraryPlaylists

                delegate: Rectangle {
                    required property var modelData
                    width: sidePlaylistLibraryList.width
                    height: 38
                    radius: Theme.radiusL
                    color: sideLibPlaylistMouse.containsMouse
                        ? Theme.foregroundGhost
                        : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: Theme.spacingM

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
                            opacity: Theme.opacityDisabled
                        }
                    }

                    MouseArea {
                        id: sideLibPlaylistMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectGenrePlaylist(modelData.name)
                    }
                }
            }

            ListView {
                id: sidePlaylistTrackList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.spacing2
                visible: root.playlistPanelMode !== "library"
                model: root.tracks

                Text {
                    anchors.centerIn: parent
                    visible: root.tracksLoading
                    text: "loading…"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.listFont
                    opacity: Theme.opacityDisabled
                }

                delegate: TrackListRow {
                    required property var modelData
                    required property int index
                    rowWidth: sidePlaylistTrackList.width
                    track: modelData
                    showNumber: false
                    selected: root.isTrackSelected(modelData.path)
                    showLike: true
                    onPressed: root.selectPlaylistTrack(index)
                    onActivated: root.playTrackAt(index)
                    onLikeToggled: root.toggleTrackFavorite(modelData.path)
                }
            }
        }
    }

    component PlayerSideTagsPanel: SectionPanel {
        label: ""
        fillHeight: true

        Flickable {
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: tagsPanelColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: tagsPanelColumn
                width: parent.width
                spacing: Theme.spacingM

                Text {
                    width: parent.width
                    visible: !String(root.player.path || "").trim()
                    text: "play a track to change tags"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.listFont
                    opacity: Theme.opacityDisabled
                }

                Text {
                    width: parent.width
                    visible: root.genres.length === 0
                    text: "no tags"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.listFont
                    opacity: Theme.opacityDisabled
                }

                Flow {
                    id: tagsFlow
                    width: parent.width
                    spacing: Theme.spacingS

                    Repeater {
                        model: root.genres

                        MetaChip {
                            required property var modelData
                            label: root.playlistTabLabel(modelData.name || "")
                            accent: root.isCurrentGenreFolder(modelData.name || "")
                            clickable: true
                            onActivated: root.retagCurrentTrack(modelData.name)
                        }
                    }
                }
            }
        }
    }

    component PlayerSideFilterPanel: SectionPanel {
        label: ""
        fillHeight: true

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.spacingM

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingM

                RowIconButton {
                    icon: "󰁍"
                    onActivated: root.openTagsScreen()
                }

                Text {
                    Layout.fillWidth: true
                    text: root.filterHeaderTitle()
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.sectionLabelFont
                    font.bold: Theme.fontBold
                    elide: Text.ElideRight
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: sideFilterTrackList
                    anchors.fill: parent
                    clip: true
                    spacing: Theme.spacing2
                    model: root.filterTracks

                    Text {
                        anchors.centerIn: parent
                        visible: root.filterLoading
                        text: "loading…"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.listFont
                        opacity: Theme.opacityDisabled
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !root.filterLoading && root.filterTracks.length === 0
                        text: "no tracks"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.listFont
                        opacity: Theme.opacityDisabled
                    }

                    delegate: TrackListRow {
                        required property var modelData
                        required property int index
                        rowWidth: sideFilterTrackList.width
                        track: modelData
                        number: index + 1
                        selected: root.isTrackSelected(modelData.path)
                        showLike: true
                        onPressed: root.selectedTrackIndex = index
                        onActivated: root.playFilterTrackAt(index)
                        onLikeToggled: root.toggleTrackFavorite(modelData.path)
                    }
                }
            }
        }
    }

    component LibraryBarAction: Rectangle {
        id: barAction
        property int barHeight: 34
        property string icon: ""
        property string label: ""
        property bool dimmed: false
        property bool spinning: false
        signal activated()

        height: barHeight
        width: actionRow.implicitWidth + 16
        radius: 6
        color: barMouse.containsMouse
            ? Theme.foregroundWash
            : (dimmed
                ? "transparent"
                : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.03))

        Row {
            id: actionRow
            anchors.centerIn: parent
            spacing: Theme.spacingS

            Text {
                text: barAction.icon
                color: Theme.foreground
                opacity: dimmed && !barAction.spinning ? 0.35 : 0.9
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeM
                transformOrigin: Item.Center

                RotationAnimation on rotation {
                    running: barAction.spinning
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                }
            }

            Text {
                text: barAction.label
                color: Theme.foreground
                opacity: dimmed && !barAction.spinning ? 0.35 : (barMouse.containsMouse ? 1 : 0.78)
                font.family: Theme.fontFamily
                font.pixelSize: root.libraryFont
            }
        }

        MouseArea {
            id: barMouse
            anchors.fill: parent
            enabled: !dimmed
            hoverEnabled: true
            cursorShape: dimmed ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: barAction.activated()
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
