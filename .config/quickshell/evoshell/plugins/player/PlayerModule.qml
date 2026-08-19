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
    property string activeLibraryJobKey: ""
    readonly property bool buildBusy: libraryJobBusy
        && root.activeLibraryJobKey === "build"
    readonly property bool libraryActivityBusy: libraryJobBusy || sortProc.running
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
    property real browseTreeHoldY: -1
    property bool browseTreeReflowHidden: false
    property var browseTreeScrollByKey: ({})
    property var browseTreeListView: null
    property var browseTreeFolderMeta: ({})
    property bool browseTreeLoadingMore: false
    property string selectedTrackPath: ""
    property var playlists: []
    property var libraryPlaylists: []
    property string selectedPlaylist: ""
    readonly property string currentPlaylistId: "current"
    property bool currentPlaylistActive: false
    property string currentPlaylistPath: ""
    property var currentPlaylistTracks: []
    property bool playlistsLoading: false
    property int playlistTrackTotal: 0
    property int playlistTrackOffset: 0
    property bool playlistTracksLoadingMore: false
    property var playlistTrackList: null
    property var playlistViewByKey: ({})
    property real playlistRestoreY: -1
    property int tracksRevision: 0
    readonly property int playlistPageSize: 50
    property string resumePlaylist: ""
    property string playerScreen: "nowPlaying"
    property string tabSearchText: ""
    property bool browseQueueBusy: false
    property bool browsePanelOpen: false
    property bool playlistPanelOpen: false
    property string playlistPanelMode: "library"
    readonly property bool sidePanelOpen: browsePanelOpen || playlistPanelOpen
    readonly property bool splitSidePanelMode: browsePanelOpen || playlistPanelOpen
        || playerScreen === "filter"
    readonly property bool nowPlayingTabActive: !browsePanelOpen && !playlistPanelOpen
        && playerScreen === "nowPlaying"
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
    property bool jobStopRequested: false
    property bool sortStopRequested: false
    property bool menuBarHidden: false
    property bool titleEditing: false
    property bool titleSaveBusy: false
    property string trashConfirmPath: ""
    property string trashConfirmTitle: ""
    readonly property bool trashConfirmOpen: trashConfirmPath !== ""
    readonly property bool keyShortcutsBlocked: tabSearchInput.activeFocus || titleEditing
        || trashConfirmOpen
    property var volumeTransportBtn: null
    readonly property var libraryActions: [
        {
            key: "build",
            icon: "󰲹",
            label: "sync",
            hint: "sync",
            args: ["build"]
        },
        {
            key: "sync",
            icon: "󰕧",
            label: "download soundcloud",
            hint: "soundcloud",
            args: ["sync"]
        },
        {
            key: "import",
            icon: "󰋋",
            label: "import incoming",
            hint: "import incoming folder",
            args: ["import"]
        },
        {
            key: "art",
            icon: "󰋩",
            label: "fix art",
            hint: "fix art",
            args: ["art", "maintain"]
        }
    ]
    property int artRevision: 0
    property bool artPickerOpen: false
    property bool artPickerLoading: false
    property string artPickerQuery: ""
    property var artPickerResults: []
    property string artApplyScope: "track"
    property string artPendingDropPath: ""
    readonly property bool artApplyAlbumAvailable: {
        var album = String(player.album || "").trim()
        var title = String(player.title || "").trim()
        return album !== "" && album !== title
    }
    readonly property var nowPlayingMetaChips: {
        var chips = []
        var label = String(player.label || "").trim()
        if (label !== "")
            chips.push({ label: label, kind: "label", value: label, tint: Theme.chartPalette[3] })
        var genre = String(player.genre || "").trim()
        if (genre !== "")
            chips.push({ label: genre, kind: "genre", value: genre, tint: Theme.accent })
        var year = String(player.year || "").trim()
        if (year !== "")
            chips.push({ label: year, kind: "year", value: year })
        var durationLabel = String(player.duration_label || "").trim()
        if (durationLabel !== "" && Number(player.duration || 0) > 0)
            chips.push({ label: durationLabel, kind: "duration", value: durationLabel })
        return chips
    }
    readonly property string nowPlayingArtist: String(player.artist || "").trim()
    readonly property string nowPlayingAlbum: {
        var album = String(player.album || "").trim()
        var title = String(player.title || "").trim()
        if (album === "" || album === title)
            return ""
        return album
    }
    readonly property bool nowPlayingBylineVisible: nowPlayingArtist !== "" || nowPlayingAlbum !== ""

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

    function onAlbumArtUpdated(scope) {
        bumpArtRevision()
        refreshStatus()
        if (scope === "album")
            notify("album art updated", 2500)
        else if (scope === "track")
            notify("track art updated", 2500)
        else
            notify("art cleared", 2500)
    }

    function defaultArtApplyScope() {
        return artApplyAlbumAvailable ? "album" : "track"
    }

    function artScopeArgs() {
        return artApplyScope === "album" ? ["--album"] : ["--track"]
    }

    function setAlbumArtFromFile(imagePath) {
        var track = String(player.path || "")
        if (!track || !imagePath)
            return
        var scope = artApplyScope
        runMusic(["art", "set", track, imagePath].concat(artScopeArgs()).concat(["--json"]), function(text) {
            try {
                JSON.parse(String(text || "{}"))
                root.onAlbumArtUpdated(scope)
            } catch (e) {
                root.notify("could not update art", 3000)
            }
        })
    }

    function selectArtApplyScope(scope) {
        artApplyScope = scope === "album" ? "album" : "track"
        if (!artPendingDropPath)
            return
        var imagePath = artPendingDropPath
        artPendingDropPath = ""
        setAlbumArtFromFile(imagePath)
        artPickerOpen = false
    }

    function openArtPickerForDrop(imagePath) {
        var track = String(player.path || "")
        imagePath = String(imagePath || "")
        if (!track || !imagePath)
            return
        artPendingDropPath = imagePath
        artApplyScope = defaultArtApplyScope()
        artPickerOpen = true
        artPickerLoading = false
        artPickerResults = []
        artPickerQuery = ""
    }

    function applyAlbumArtFromUrl(url) {
        var track = String(player.path || "")
        if (!track || !url)
            return
        var scope = artApplyScope
        artPickerLoading = true
        runMusic(["art", "apply", track, url].concat(artScopeArgs()).concat(["--json"]), function(text) {
            artPickerLoading = false
            try {
                JSON.parse(String(text || "{}"))
                artPickerOpen = false
                root.onAlbumArtUpdated(scope)
            } catch (e) {
                root.notify("could not update art", 3000)
            }
        })
    }

    function toggleMenuBar() {
        if (keyShortcutsBlocked)
            return
        menuBarHidden = !menuBarHidden
    }

    function commitTitleEdit(newTitle) {
        var path = String(player.path || "")
        var trimmed = String(newTitle || "").trim()
        titleEditing = false
        if (!path || titleSaveBusy)
            return
        if (!trimmed || trimmed === String(player.title || "").trim())
            return
        titleSaveBusy = true
        runMusic(["tag", "set", "title", path, trimmed, "--json"], function(text) {
            titleSaveBusy = false
            try {
                var data = JSON.parse(String(text || "{}"))
                if (!data.ok)
                    throw new Error("tag failed")
                player = Object.assign({}, player, {
                    path: String(data.path || path),
                    title: String(data.title || trimmed)
                })
                tracksRevision++
                refreshStatus()
                mergePlayerFromTrackList()
                if (browsePanelOpen)
                    refreshBrowseTree()
            } catch (e) {
                notify("could not update title", 3000)
                refreshStatus()
            }
        })
    }

    function openArtPicker() {
        var track = String(player.path || "")
        if (!track)
            return
        artPendingDropPath = ""
        artApplyScope = defaultArtApplyScope()
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
        artPendingDropPath = ""
        artPickerOpen = false
    }

    function showNowPlaying() {
        savePlaylistView(selectedPlaylist)
        browsePanelOpen = false
        playlistPanelOpen = false
        playerScreen = "nowPlaying"
    }

    function toggleBrowsePanel() {
        if (browsePanelOpen) {
            saveBrowseTreeScroll()
            browsePanelOpen = false
            return
        }
        savePlaylistView(selectedPlaylist)
        playlistPanelOpen = false
        browsePanelOpen = true
        playerScreen = "nowPlaying"
        if (!browsePath && !browseTreeRows.length)
            loadBrowseTreeRoot()
        else
            restoreBrowseTreeScroll()
    }

    function togglePlaylistPanel() {
        if (playlistPanelOpen) {
            savePlaylistView(selectedPlaylist)
            playlistPanelOpen = false
            return
        }
        browsePanelOpen = false
        playlistPanelOpen = true
        playlistPanelMode = "library"
        playerScreen = "nowPlaying"
        if (!libraryPlaylists.length && !playlistsLoading)
            loadPlaylists()
    }

    function showPlaylistLibrary() {
        savePlaylistView(selectedPlaylist)
        playlistPanelMode = "library"
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

    function formatVizPresetLabel(name) {
        var preset = String(name || "").trim()
        if (!preset)
            return "visualiser"
        return preset.charAt(0).toUpperCase() + preset.slice(1)
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

    function jobLogInline() {
        var text = formatJobLog(jobLog).replace(/\n/g, " ").trim()
        if (text)
            return text
        if (libraryJobBusy)
            return libraryJobActiveLabel + "…"
        if (sortProc.running)
            return String(sortProc._label || "sort") + "…"
        return ""
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
        runJob(action.args || [], action.label || "library task", { key: action.key || "" })
    }

    function runJob(args, label, options) {
        if (libraryJobBusy) {
            notify("busy — " + libraryJobActiveLabel, 2000)
            return
        }
        jobStopRequested = false
        jobBusy = true
        jobLabel = label
        activeLibraryJobKey = (options && options.key) ? String(options.key) : ""
        jobLog = label + "…\n"
        if (!(options && options.stayOnScreen) && playerScreen !== "filter")
            playerScreen = "nowPlaying"
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

    function stopLibraryJob() {
        if (!libraryJobBusy && !sortProc.running)
            return
        var label = libraryJobActiveLabel || (sortProc.running ? "sort" : "library task")
        jobStopRequested = true
        if (sortProc.running) {
            sortStopRequested = true
            sortProc.running = false
        }
        if (jobBusy && jobProc.running)
            jobProc.running = false
        runQuery(["job", "stop", "--json"], function(text) {
            var stopped = false
            try {
                stopped = !!JSON.parse(String(text || "{}")).stopped
            } catch (e) {}
            jobBusy = false
            jobLabel = ""
            activeLibraryJobKey = ""
            externalJobBusy = false
            externalJobLabel = ""
            jobStopRequested = false
            syncJobLog()
            jobLog = String(jobLog || "") + "\n" + label + " stopped"
            notify((stopped ? label : "job") + " stopped", 3000)
        })
    }

    function onJobFinished(exitCode) {
        syncJobLog()
        var label = jobLabel
        jobBusy = false
        jobLabel = ""
        activeLibraryJobKey = ""
        if (jobStopRequested) {
            jobStopRequested = false
            if (label)
                jobLog = String(jobLog || "") + "\n" + label + " stopped"
            syncExternalJobStatus()
            return
        }
        if (exitCode === 0) {
            notify(label + " complete", 4000)
            loadGenres()
            loadLibraryStats()
            loadPlaylists()
            if (browsePanelOpen || browseTreeRows.length > 0)
                reloadBrowseTreeView()
            if (playlistPanelOpen && selectedPlaylist)
                loadPlaylistTracks(selectedPlaylist, true)
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
        rebuildPlaylistTabs()
    }

    function rebuildPlaylistTabs() {
        playlistTabModel.clear()
        playlistTabModel.append({
            name: currentPlaylistId,
            count: currentPlaylistActive ? currentPlaylistTracks.length : 0
        })
        var allCount = 0
        for (var i = 0; i < libraryPlaylists.length; i++) {
            if (libraryPlaylists[i].name === "all") {
                allCount = libraryPlaylists[i].count || 0
                break
            }
        }
        playlistTabModel.append({ name: "all", count: allCount })
        for (var k = 0; k < playlists.length; k++) {
            var tabName = String(playlists[k].name || "")
            if (!tabName || tabName === currentPlaylistId || tabName === "all")
                continue
            playlistTabModel.append({
                name: tabName,
                count: playlists[k].count || 0
            })
        }
        refreshCurrentPlaylistView()
    }

    function playlistCanStar(name) {
        var n = String(name || "")
        return n && n !== currentPlaylistId && n !== "all"
    }

    function refreshCurrentPlaylistView() {
        if (!currentPlaylistActive)
            return
        if (playlistPanelOpen && selectedPlaylist === currentPlaylistId) {
            restorePlaylistScroll(currentPlaylistId)
            tracks = currentPlaylistTracks.slice()
            playlistTrackTotal = tracks.length
            playlistTrackOffset = tracks.length
            syncSelectedTrackIndex()
        }
    }

    function commitCurrentPlaylist() {
        rebuildPlaylistTabs()
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
                    rebuildPlaylistTabs()
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
        rebuildPlaylistTabs()
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
        cancelTrashTrack()
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
            } else if (preferred === "all") {
                selectPlaylist("all", false)
            } else if (preferred) {
                for (var i = 0; i < playlists.length; i++) {
                    if (playlists[i].name === preferred) {
                        selectPlaylist(preferred, false)
                        return
                    }
                }
                syncPlaylistTabPosition()
            } else {
                syncPlaylistTabPosition()
            }
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
        var next = normalizePlaylistName(name)
        if (playlistPanelMode === "tracks" && selectedPlaylist && selectedPlaylist !== next)
            savePlaylistView(selectedPlaylist)
        selectedPlaylist = next
        playlistPanelMode = "tracks"
        syncPlaylistTabPosition()
        loadPlaylistTracks(selectedPlaylist)
    }

    function togglePlaylistStar(name) {
        var playlistName = String(name || "")
        if (!playlistCanStar(playlistName))
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

    function expansionStateKey(expanded) {
        var exp = expanded !== undefined ? expanded : browseTreeExpanded
        var paths = []
        for (var p in exp) {
            if (exp[p])
                paths.push(String(p))
        }
        paths.sort()
        return paths.join("\n")
    }

    function saveBrowseTreeScroll(key) {
        if (!browseTreeListView)
            return
        var map = Object.assign({}, browseTreeScrollByKey)
        map[key !== undefined ? String(key) : expansionStateKey()] = browseTreeListView.contentY
        browseTreeScrollByKey = map
    }

    function restoreBrowseTreeScroll(key) {
        var k = key !== undefined ? String(key) : expansionStateKey()
        var y = browseTreeScrollByKey[k]
        browseTreeRestoreY = (y !== undefined && y !== null && y >= 0) ? Number(y) : -1
    }

    function pruneBrowseTreeExpansion(path) {
        var nextExp = Object.assign({}, browseTreeExpanded)
        var prefix = String(path || "")
        for (var p in nextExp) {
            if (p === prefix || (prefix && p.indexOf(prefix + "/") === 0))
                delete nextExp[p]
        }
        return nextExp
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
                        folderPath: key,
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
        browseTreeRows = rows
        if (browseTreeHoldY >= 0 && browseTreeListView)
            browseTreeListView.contentY = browseTreeHoldY
    }

    function patchTrackLikedInBrowseTree(trackPath, liked) {
        trackPath = String(trackPath || "")
        if (!trackPath)
            return false
        var nextChildren = {}
        var changed = false
        for (var key in browseTreeChildren) {
            var kids = browseTreeChildren[key]
            var nextKids = []
            for (var i = 0; i < kids.length; i++) {
                var kid = kids[i]
                if (kid.type === "track" && String(kid.path) === trackPath) {
                    nextKids.push(Object.assign({}, kid, { liked: liked }))
                    changed = true
                } else {
                    nextKids.push(kid)
                }
            }
            nextChildren[key] = nextKids
        }
        if (!changed)
            return false
        browseTreeChildren = nextChildren
        rebuildBrowseTreeRows(false)
        return true
    }

    function findTrackLikedInBrowseTree(trackPath) {
        trackPath = String(trackPath || "")
        for (var key in browseTreeChildren) {
            var kids = browseTreeChildren[key]
            for (var i = 0; i < kids.length; i++) {
                var kid = kids[i]
                if (kid.type === "track" && String(kid.path) === trackPath)
                    return !!kid.liked
            }
        }
        return undefined
    }

    function applyBrowseTreeEntries(relPath, entries, meta, append) {
        relPath = String(relPath || "")
        var next = Object.assign({}, browseTreeChildren)
        var nextMeta = Object.assign({}, browseTreeFolderMeta)
        var trackCount = 0
        var i
        for (i = 0; i < entries.length; i++) {
            if (entries[i].type === "track")
                trackCount++
        }
        if (append && next[relPath]) {
            var existing = next[relPath]
            var dirs = []
            var tracks = []
            var j
            for (j = 0; j < existing.length; j++) {
                if (existing[j].type === "dir")
                    dirs.push(existing[j])
                else if (existing[j].type === "track")
                    tracks.push(existing[j])
            }
            for (j = 0; j < entries.length; j++) {
                if (entries[j].type === "track")
                    tracks.push(entries[j])
            }
            next[relPath] = dirs.concat(tracks)
            trackCount = tracks.length
        } else {
            next[relPath] = entries
        }
        if (relPath !== "") {
            nextMeta[relPath] = {
                total: Number(meta.trackTotal) || trackCount,
                loaded: trackCount
            }
        }
        browseTreeChildren = next
        browseTreeFolderMeta = nextMeta
        rebuildBrowseTreeRows(!!append)
    }

    function fetchBrowseTreeEntries(relPath, offset, append, onDone) {
        relPath = String(relPath || "")
        var args = ["browse", relPath, "--json"]
        if (relPath !== "") {
            args = args.concat([
                "--offset", String(offset || 0),
                "--limit", String(playlistPageSize)
            ])
        }
        runBrowseQuery(args, function(text) {
            try {
                var data = JSON.parse(String(text || "{}"))
                var entries = data.entries || []
                if (onDone) {
                    onDone(entries, {
                        trackTotal: relPath === ""
                            ? 0
                            : (Number(data.trackTotal) || 0),
                        trackOffset: Number(data.trackOffset) || 0,
                        trackLimit: Number(data.trackLimit) || playlistPageSize
                    })
                }
            } catch (e) {
                if (onDone)
                    onDone([], { trackTotal: 0, trackOffset: 0, trackLimit: playlistPageSize })
            }
        })
    }

    function loadMoreBrowseTreeTracks() {
        if (browseTreeLoadingMore || browseTreeLoading)
            return
        var folderPath = ""
        var i
        for (i = browseTreeRows.length - 1; i >= 0; i--) {
            if (browseTreeRows[i].type === "track") {
                folderPath = String(browseTreeRows[i].folderPath || "")
                break
            }
        }
        if (!folderPath)
            return
        var meta = browseTreeFolderMeta[folderPath]
        if (!meta || meta.loaded >= meta.total)
            return
        var list = browseTreeListView
        var anchorY = list ? list.contentY : -1
        var anchorIndex = list && list.count > 0
            ? Math.max(0, list.indexAt(0, list.contentY + 1))
            : -1
        browseTreeLoadingMore = true
        fetchBrowseTreeEntries(folderPath, meta.loaded, true, function(entries, pagMeta) {
            browseTreeLoadingMore = false
            applyBrowseTreeEntries(folderPath, entries, pagMeta, true)
            restoreListViewport(list, anchorY, anchorIndex)
        })
    }

    function loadBrowseTreeRoot() {
        browseTreeLoading = true
        fetchBrowseTreeEntries("", 0, false, function(entries) {
            browseTreeLoading = false
            applyBrowseTreeEntries("", entries, {}, false)
            restoreBrowseTreeScroll("")
        })
    }

    function refreshBrowseTree() {
        if (browseTreeLoading)
            return
        saveBrowseTreeScroll()
        var anchorY = browseTreeListView ? browseTreeListView.contentY : -1
        var expanded = []
        for (var p in browseTreeExpanded) {
            if (browseTreeExpanded[p])
                expanded.push(String(p))
        }
        expanded.sort(function(a, b) {
            var da = a === "" ? 0 : a.split("/").length
            var db = b === "" ? 0 : b.split("/").length
            return da - db || a.localeCompare(b)
        })
        var paths = [""].concat(expanded)
        var pathIndex = 0
        var nextChildren = {}
        var nextMeta = {}
        browseTreeLoading = true

        function step() {
            if (pathIndex >= paths.length) {
                browseTreeChildren = nextChildren
                browseTreeFolderMeta = nextMeta
                browseTreeLoading = false
                beginBrowseTreeReflowHold(anchorY)
                rebuildBrowseTreeRows(false)
                restoreBrowseTreeViewport(anchorY, -1)
                return
            }
            var path = paths[pathIndex++]
            fetchBrowseTreeEntries(path, 0, false, function(entries, meta) {
                var trackCount = 0
                for (var i = 0; i < entries.length; i++) {
                    if (entries[i].type === "track")
                        trackCount++
                }
                nextChildren[path] = entries
                if (path !== "") {
                    nextMeta[path] = {
                        total: Number(meta.trackTotal) || trackCount,
                        loaded: trackCount
                    }
                }
                step()
            })
        }
        step()
    }

    function reloadBrowseTreeView() {
        if (!browsePanelOpen && browseTreeRows.length === 0)
            return
        for (var p in browseTreeExpanded) {
            if (browseTreeExpanded[p]) {
                refreshBrowseTree()
                return
            }
        }
        loadBrowseTreeRoot()
    }

    function browseTreeDirIndex(path) {
        path = String(path || "")
        for (var i = 0; i < browseTreeRows.length; i++) {
            var row = browseTreeRows[i]
            if (row && row.type === "dir" && String(row.path) === path)
                return i
        }
        return -1
    }

    function restoreBrowseTreeViewport(contentY, anchorIndex) {
        browseTreeRestoreY = -1
        if (contentY < 0 || !browseTreeListView) {
            browseTreeHoldY = -1
            browseTreeReflowHidden = false
            restoreListViewport(browseTreeListView, contentY, anchorIndex)
            return
        }
        browseTreeHoldY = contentY
        browseTreeReflowHidden = true
        browseTreeListView.contentY = contentY
        restoreListViewport(browseTreeListView, contentY, anchorIndex, function() {
            browseTreeHoldY = -1
            browseTreeReflowHidden = false
        })
    }

    function beginBrowseTreeReflowHold(contentY) {
        if (contentY < 0)
            return
        browseTreeHoldY = contentY
        browseTreeReflowHidden = true
    }

    function toggleBrowseTreeNode(path) {
        path = String(path || "")
        saveBrowseTreeScroll()
        var list = browseTreeListView
        var anchorY = list ? list.contentY : -1
        var anchorIndex = browseTreeDirIndex(path)
        var nextExp = Object.assign({}, browseTreeExpanded)
        if (nextExp[path]) {
            nextExp = pruneBrowseTreeExpansion(path)
            browseTreeExpanded = nextExp
            beginBrowseTreeReflowHold(anchorY)
            rebuildBrowseTreeRows(false)
            restoreBrowseTreeViewport(anchorY, anchorIndex)
            return
        }
        nextExp[path] = true
        browseTreeExpanded = nextExp
        if (browseTreeChildren[path]) {
            beginBrowseTreeReflowHold(anchorY)
            rebuildBrowseTreeRows(false)
            restoreBrowseTreeViewport(anchorY, anchorIndex)
            return
        }
        fetchBrowseTreeEntries(path, 0, false, function(entries, meta) {
            beginBrowseTreeReflowHold(anchorY)
            applyBrowseTreeEntries(path, entries, meta, false)
            restoreBrowseTreeViewport(anchorY, anchorIndex)
        })
    }

    function playBrowseTreeTrack(entry) {
        if (!entry || !entry.path)
            return
        selectedTrackPath = String(entry.path)
        playPath(entry.path, false)
    }

    function browseTreeHome() {
        saveBrowseTreeScroll()
        selectedTrackPath = ""
        browseTreeExpanded = {}
        browseTreeChildren = {}
        browseTreeFolderMeta = {}
        browseTreeRows = []
        browseTreeScrollByKey = {}
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
        selectedTrackPath = String(entry.path)
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

    function browseSortFolder(entry) {
        if (!entry || entry.type !== "dir" || !entry.path)
            return
        if (sortProc.running) {
            notify("busy — sort", 2000)
            return
        }
        if (libraryJobBusy && !buildBusy) {
            notify("busy — " + libraryJobActiveLabel, 2000)
            return
        }
        var folderPath = String(entry.path)
        var label = "sort " + folderPath.split("/").pop()
        if (buildBusy && libraryJobBusy) {
            runSortDuringBuild(folderPath, label)
            return
        }
        runJob(["sort", folderPath, "--json"], label, { stayOnScreen: false })
    }

    function runSortDuringBuild(folderPath, label) {
        sortStopRequested = false
        sortProc.command = ["bash", playerScript, "sort", folderPath, "--json"]
        sortProc._label = label
        jobLog = String(jobLog || "") + (jobLog ? "\n" : "") + label + "…"
        notify(label + "…", 2000)
        sortProc.running = true
    }

    function onSortFinished(exitCode) {
        var label = sortProc._label || "sort"
        sortProc._label = ""
        if (sortStopRequested) {
            sortStopRequested = false
            return
        }
        if (exitCode === 0) {
            notify(label + " complete", 4000)
            jobLog = String(jobLog || "") + "\n" + label + " complete"
            if (browsePanelOpen || browseTreeRows.length > 0)
                reloadBrowseTreeView()
        } else if (exitCode === 2) {
            notify("busy — cannot sort now", 4000)
        } else {
            var err = sortErr.text ? String(sortErr.text).trim().split("\n").pop() : ""
            notify(label + " failed" + (err ? " — " + err : ""), 5000)
        }
    }

    function browseAppendFolder(entry) {
        if (!entry || entry.type !== "dir" || !entry.path)
            return
        if (appendBrowseProc.running) {
            Qt.callLater(function() { browseAppendFolder(entry) })
            return
        }
        browseQueueBusy = true
        var folderPath = String(entry.path)
        appendBrowseProc.command = ["bash", playerScript, "queue", "append-browse", folderPath, "--json"]
        appendBrowseProc._onDone = function(text) {
            browseQueueBusy = false
            try {
                var result = JSON.parse(String(text || "{}"))
                var added = Number(result.added || 0)
                if (added <= 0) {
                    root.notify("no new tracks to add", 2500)
                    return
                }
                root.currentPlaylistActive = true
                root.currentPlaylistPath = folderPath
                root.selectedPlaylist = root.currentPlaylistId
                root.loadCurrentPlaylist(function() {
                    root.commitCurrentPlaylist()
                    root.refreshStatus()
                    var label = String(result.folder || folderPath).split("/").pop() || "folder"
                    root.notify("+" + added + " to current from " + label, 2500)
                })
            } catch (e) {
                root.notify("could not append folder", 2500)
            }
        }
        appendBrowseProc.running = true
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
        else if (kind === "album")
            args = args.concat(["--album", String(value || "")])
        else if (kind === "label")
            args = args.concat(["--label", String(value || "")])
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
        if (filterKind === "album")
            return "Album · " + filterLabel
        if (filterKind === "label")
            return "Label · " + filterLabel
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
        selectedTrackPath = String(filterTracks[index].path || "")
        var paths = pathsFromTracks(folderTracks)
        playQueueAt(paths[index], paths)
        commitCurrentPlaylist()
    }

    function selectFilterTrack(index) {
        if (index < 0 || index >= filterTracks.length)
            return
        selectedTrackPath = String(filterTracks[index].path || "")
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
        path = String(path || "")
        if (!path)
            return false
        if (isTrackPlaying(path))
            return true
        return String(selectedTrackPath) === path
    }

    function selectTrackEntry(entry) {
        if (!entry || !entry.path)
            return
        selectedTrackPath = String(entry.path)
    }

    function openTrackFolder(entry) {
        if (!entry)
            return
        var folderPath = String(entry.folderPath || "").trim()
        if (folderPath) {
            openBrowseFolder({ path: folderPath })
            return
        }
        var path = String(entry.path || "").trim()
        if (!path)
            return
        var slash = path.lastIndexOf("/")
        if (slash > 0)
            openBrowseFolder({ path: path.substring(0, slash) })
        else
            openTrackInThunar(path)
    }

    function requestTrashTrack(trackOrPath) {
        var path = ""
        var title = ""
        if (typeof trackOrPath === "string") {
            path = String(trackOrPath || "").trim()
        } else if (trackOrPath) {
            path = String(trackOrPath.path || "").trim()
            title = String(trackOrPath.title || "").trim()
        }
        if (!path || trashTrackProc.running)
            return
        if (!title) {
            var slash = path.lastIndexOf("/")
            title = slash >= 0 ? path.substring(slash + 1) : path
        }
        trashConfirmPath = path
        trashConfirmTitle = title
    }

    function cancelTrashTrack() {
        trashConfirmPath = ""
        trashConfirmTitle = ""
    }

    function confirmTrashTrack() {
        var path = String(trashConfirmPath || "").trim()
        cancelTrashTrack()
        trashTrack(path)
    }

    function trashTrack(trackPath) {
        var path = String(trackPath || "").trim()
        if (!path || trashTrackProc.running)
            return
        trashTrackProc._path = path
        trashTrackProc.command = ["gio", "trash", path]
        trashTrackProc.running = true
    }

    function removeTrackFromViews(path) {
        path = String(path || "")
        var i
        var nextTracks = []
        for (i = 0; i < tracks.length; i++) {
            if (tracks[i].path !== path)
                nextTracks.push(tracks[i])
        }
        if (nextTracks.length !== tracks.length)
            tracks = nextTracks
        var nextFilter = []
        for (i = 0; i < filterTracks.length; i++) {
            if (filterTracks[i].path !== path)
                nextFilter.push(filterTracks[i])
        }
        if (nextFilter.length !== filterTracks.length)
            filterTracks = nextFilter
        if (currentPlaylistActive) {
            var nextCurrent = []
            for (i = 0; i < currentPlaylistTracks.length; i++) {
                if (currentPlaylistTracks[i].path !== path)
                    nextCurrent.push(currentPlaylistTracks[i])
            }
            if (nextCurrent.length !== currentPlaylistTracks.length)
                currentPlaylistTracks = nextCurrent
        }
    }

    function onTrackTrashed(exitCode) {
        var path = trashTrackProc._path || ""
        trashTrackProc._path = ""
        if (exitCode !== 0) {
            notify("could not trash file", 3000)
            return
        }
        if (String(selectedTrackPath) === path)
            selectedTrackPath = ""
        if (selectedTrackIndex >= 0 && selectedTrackIndex < tracks.length
                && tracks[selectedTrackIndex].path === path)
            selectedTrackIndex = -1
        if (isTrackPlaying(path))
            runPlayer(["stop"], root.refreshStatus, cmdProc)
        removeTrackFromViews(path)
        savePlaylistView(selectedPlaylist)
        reloadBrowseTreeView()
        notify("moved to trash", 2500)
    }

    function selectPlaylist(name, switchScreen) {
        var next = normalizePlaylistName(name)
        if (playlistPanelMode === "tracks" && selectedPlaylist && selectedPlaylist !== next)
            savePlaylistView(selectedPlaylist)
        selectedPlaylist = next
        syncPlaylistTabPosition()
        if (switchScreen !== false) {
            playerScreen = "nowPlaying"
            browsePanelOpen = false
            playlistPanelOpen = true
            playlistPanelMode = "tracks"
        }
        loadPlaylistTracks(selectedPlaylist)
    }

    function savePlaylistView(name) {
        var key = String(name || "")
        if (!key)
            return
        if (!tracks.length)
            return
        var list = playlistTrackList
        var y = -1
        if (playlistRestoreY >= 0)
            y = playlistRestoreY
        else if (list && playlistPanelMode === "tracks" && list.visible && list.height > 0)
            y = list.contentY
        else if (playlistViewByKey[key] && playlistViewByKey[key].contentY >= 0)
            y = Number(playlistViewByKey[key].contentY)
        if (y < 0)
            y = 0
        var map = Object.assign({}, playlistViewByKey)
        map[key] = {
            contentY: y,
            tracks: tracks.slice(),
            offset: playlistTrackOffset,
            total: playlistTrackTotal
        }
        playlistViewByKey = map
    }

    function restorePlaylistScroll(name) {
        var key = String(name || selectedPlaylist || "")
        var saved = playlistViewByKey[key]
        var y = saved && saved.contentY !== undefined && saved.contentY !== null
            ? Number(saved.contentY)
            : -1
        playlistRestoreY = y >= 0 ? y : -1
    }

    function applyCachedPlaylistView(name) {
        var key = String(name || "")
        var saved = playlistViewByKey[key]
        if (!key || !saved || !saved.tracks || !saved.tracks.length)
            return false
        tracksLoading = false
        playlistTracksLoadingMore = false
        restorePlaylistScroll(key)
        tracks = saved.tracks.slice()
        playlistTrackOffset = Number(saved.offset) || tracks.length
        playlistTrackTotal = Number(saved.total) || tracks.length
        syncSelectedTrackIndex()
        mergePlayerFromTrackList()
        return true
    }

    function loadPlaylistTracks(name, force) {
        if (!name) {
            tracks = []
            tracksLoading = false
            playlistTrackTotal = 0
            playlistTrackOffset = 0
            return
        }
        var requested = String(name)
        if (requested === currentPlaylistId) {
            tracksLoading = false
            restorePlaylistScroll(requested)
            tracks = currentPlaylistTracks.slice()
            playlistTrackTotal = tracks.length
            playlistTrackOffset = tracks.length
            syncSelectedTrackIndex()
            mergePlayerFromTrackList()
            return
        }
        if (!force && applyCachedPlaylistView(requested))
            return
        tracksLoading = true
        playlistTracksLoadingMore = false
        playlistTrackOffset = 0
        playlistTrackTotal = 0
        runPlaylistQuery([
            "playlist", requested, "--json",
            "--offset", "0",
            "--limit", String(playlistPageSize)
        ], function(text) {
            if (selectedPlaylist !== requested)
                return
            tracksLoading = false
            restorePlaylistScroll(requested)
            applyPlaylistTracksPage(text, false)
            syncSelectedTrackIndex()
            mergePlayerFromTrackList()
        })
    }

    function applyPlaylistTracksPage(text, append) {
        try {
            var parsed = JSON.parse(String(text || "{}"))
            if (parsed && Array.isArray(parsed.items)) {
                var items = parsed.items
                tracks = append ? tracks.concat(items) : items
                playlistTrackTotal = Number(parsed.total) || tracks.length
                playlistTrackOffset = tracks.length
                return
            }
            if (Array.isArray(parsed)) {
                tracks = append ? tracks.concat(parsed) : parsed
                playlistTrackTotal = tracks.length
                playlistTrackOffset = tracks.length
                return
            }
        } catch (e) {
        }
        if (!append)
            tracks = []
        playlistTrackTotal = tracks.length
        playlistTrackOffset = tracks.length
    }

    function loadMorePlaylistTracks() {
        if (playlistTracksLoadingMore || tracksLoading)
            return
        if (!selectedPlaylist || selectedPlaylist === currentPlaylistId)
            return
        if (playlistTrackOffset >= playlistTrackTotal)
            return
        var requested = String(selectedPlaylist)
        var list = playlistTrackList
        var anchorY = list ? list.contentY : -1
        var anchorIndex = list && list.count > 0
            ? Math.max(0, list.indexAt(0, list.contentY + 1))
            : -1
        playlistTracksLoadingMore = true
        runPlaylistQuery([
            "playlist", requested, "--json",
            "--offset", String(playlistTrackOffset),
            "--limit", String(playlistPageSize)
        ], function(text) {
            if (selectedPlaylist !== requested) {
                playlistTracksLoadingMore = false
                return
            }
            applyPlaylistTracksPage(text, true)
            playlistTracksLoadingMore = false
            restoreListViewport(list, anchorY, anchorIndex)
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
        if (selectedTrackPath && selectedTrackPath !== path)
            return
        selectedTrackIndex = playingIdx
        selectedTrackPath = path
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
        if (waveformViz)
            waveformViz.recomputeVizEnvelopes()
        else if (waveCanvas)
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
        if (waveformViz)
            waveformViz.recomputeVizEnvelopes()
        else if (waveCanvas)
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
        selectedTrackPath = String(path)
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

    function appendTrackToCurrent(track) {
        var path = ""
        if (typeof track === "string")
            path = String(track || "").trim()
        else if (track)
            path = String(track.path || "").trim()
        if (!path)
            return
        var entry = (track && typeof track === "object") ? track : { path: path }
        var before = currentPlaylistTracks.length
        appendTracksToCurrent([entry])
        if (currentPlaylistTracks.length === before) {
            notify("already in current", 2000)
            return
        }
        selectedPlaylist = currentPlaylistId
        commitCurrentPlaylist()
        notify("added to current", 2000)
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
        selectedTrackPath = String(startPath)
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
        var paths = pathsFromTracks(currentPlaylistTracks)
        playQueueAt(startPath, paths)
        selectedTrackIndex = index
        selectedTrackPath = String(startPath)
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
        selectedTrackPath = String(tracks[index].path || "")
        if (selectedPlaylist === currentPlaylistId)
            jumpCurrentAt(index)
        else
            playFromPlaylistAt(index)
    }

    function selectPlaylistTrack(index) {
        if (index < 0 || index >= tracks.length)
            return
        selectedTrackIndex = index
        selectedTrackPath = String(tracks[index].path || "")
    }

    function toggleFavorite() {
        if (!player.path)
            return
        toggleTrackFavorite(player.path)
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

    function restoreListViewport(listView, contentY, anchorIndex, onSettled) {
        if (!listView) {
            if (onSettled)
                onSettled()
            return
        }
        var attempts = 0
        function step() {
            if (!listView) {
                if (onSettled)
                    onSettled()
                return
            }
            attempts++
            if (contentY >= 0) {
                var maxY = Math.max(0, listView.contentHeight - listView.height)
                listView.contentY = Math.min(contentY, maxY)
            } else if (anchorIndex >= 0 && anchorIndex < listView.count) {
                listView.positionViewAtIndex(anchorIndex, ListView.Beginning)
            }
            if (listView.contentHeight > 0 || attempts >= 20) {
                if (onSettled)
                    onSettled()
                return
            }
            Qt.callLater(step)
        }
        step()
    }

    function toggleTrackFavorite(path) {
        var trackPath = String(path || "")
        if (!trackPath)
            return
        var applyFavorite = function(text) {
            try {
                var result = JSON.parse(String(text || "{}"))
                var liked = !!result.liked
                var i, entry, nextTracks = [], nextBrowse = [], nextCurrent = [], nextFilter = []
                for (i = 0; i < tracks.length; i++) {
                    entry = tracks[i]
                    if (entry.path === trackPath)
                        nextTracks.push(Object.assign({}, entry, { liked: liked }))
                    else
                        nextTracks.push(entry)
                }
                for (i = 0; i < currentPlaylistTracks.length; i++) {
                    entry = currentPlaylistTracks[i]
                    if (entry.path === trackPath)
                        nextCurrent.push(Object.assign({}, entry, { liked: liked }))
                    else
                        nextCurrent.push(entry)
                }
                for (i = 0; i < filterTracks.length; i++) {
                    entry = filterTracks[i]
                    if (entry.path === trackPath)
                        nextFilter.push(Object.assign({}, entry, { liked: liked }))
                    else
                        nextFilter.push(entry)
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
                currentPlaylistTracks = nextCurrent
                filterTracks = nextFilter
                browseEntries = nextBrowse
                patchTrackLikedInBrowseTree(trackPath, liked)
                tracksRevision++
                restoreListViewport(playlistTrackList, playlistY)
                restoreListViewport(browseList, browseY)
                if (player.path === trackPath) {
                    var p = Object.assign({}, player)
                    p.liked = liked
                    player = p
                }
                if (!liked && root.selectedPlaylist !== "all" && root.selectedPlaylist !== root.currentPlaylistId)
                    root.loadPlaylistTracks(root.selectedPlaylist, true)
            } catch (e) {
            }
        }
        var optimisticLiked = true
        var j, t, found = false
        for (j = 0; j < tracks.length; j++) {
            if (tracks[j].path === trackPath) {
                optimisticLiked = !tracks[j].liked
                found = true
                break
            }
        }
        if (!found) {
            for (j = 0; j < currentPlaylistTracks.length; j++) {
                if (currentPlaylistTracks[j].path === trackPath) {
                    optimisticLiked = !currentPlaylistTracks[j].liked
                    found = true
                    break
                }
            }
        }
        if (!found) {
            for (j = 0; j < filterTracks.length; j++) {
                if (filterTracks[j].path === trackPath) {
                    optimisticLiked = !filterTracks[j].liked
                    found = true
                    break
                }
            }
        }
        if (!found) {
            for (j = 0; j < browseEntries.length; j++) {
                t = browseEntries[j]
                if (t.type === "track" && t.path === trackPath) {
                    optimisticLiked = !t.liked
                    found = true
                    break
                }
            }
        }
        if (!found) {
            var treeLiked = findTrackLikedInBrowseTree(trackPath)
            if (treeLiked !== undefined) {
                optimisticLiked = !treeLiked
                found = true
            }
        }
        if (!found && String(player.path || "") === trackPath)
            optimisticLiked = !player.liked
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
        var rel = String(relPath || "").trim()
        var rootPath = String(musicRoot || "").replace(/\/+$/, "")
        if (!rel)
            return rootPath
        if (rel.charAt(0) === "/")
            return rel
        if (rootPath && (rel === rootPath || rel.indexOf(rootPath + "/") === 0))
            return rel
        return rootPath ? rootPath + "/" + rel.replace(/^\/+/, "") : rel
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

    Process {
        id: sortProc
        property string _label: ""
        stdout: StdioCollector {}
        stderr: StdioCollector {
            id: sortErr
        }
        onExited: function(exitCode) {
            root.onSortFinished(exitCode)
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
        running: root.jobBusy || root.externalJobBusy
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
        id: trashTrackProc
        property string _path: ""
        onExited: function(exitCode) {
            root.onTrackTrashed(exitCode)
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
        id: appendBrowseProc
        property var _onDone: null
        stdout: StdioCollector {
            onStreamFinished: {
                if (appendBrowseProc._onDone)
                    appendBrowseProc._onDone(text)
                appendBrowseProc._onDone = null
            }
        }
        onExited: appendBrowseProc._onDone = null
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
            visible: !root.menuBarHidden
            Layout.fillWidth: true
            fillHeight: false

            RowLayout {
                id: tabBarHost
                Layout.fillWidth: true
                Layout.preferredHeight: root.genreTabHeight
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
                    spinning: root.libraryActivityBusy
                    onActivated: root.toggleBrowsePanel()
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

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: titleInput.visible
                                                ? titleInput.implicitHeight
                                                : titleLabel.implicitHeight

                                            Text {
                                                id: titleLabel
                                                width: parent.width
                                                visible: !root.titleEditing
                                                text: root.player.title || "No track"
                                                color: Theme.foreground
                                                font.family: Theme.fontFamily
                                                font.pixelSize: root.nowPlayingTitleFont
                                                font.bold: Theme.fontBold
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 2
                                                opacity: titleMouse.containsMouse && (root.player.path || "") !== ""
                                                    ? 0.82
                                                    : 1
                                            }

                                            MouseArea {
                                                id: titleMouse
                                                anchors.fill: titleLabel
                                                enabled: (root.player.path || "") !== "" && !root.titleSaveBusy
                                                hoverEnabled: true
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: {
                                                    titleInput.text = String(root.player.title || "")
                                                    root.titleEditing = true
                                                    titleInput.forceActiveFocus()
                                                    titleInput.selectAll()
                                                }
                                            }

                                            TextInput {
                                                id: titleInput
                                                width: parent.width
                                                visible: root.titleEditing
                                                text: root.player.title || ""
                                                color: Theme.foreground
                                                font.family: Theme.fontFamily
                                                font.pixelSize: root.nowPlayingTitleFont
                                                font.bold: Theme.fontBold
                                                wrapMode: TextInput.Wrap
                                                selectionColor: Theme.accent
                                                selectedTextColor: Theme.mantle
                                                focus: root.titleEditing
                                                onAccepted: root.commitTitleEdit(text)
                                                onEditingFinished: {
                                                    if (root.titleEditing && !activeFocus)
                                                        root.commitTitleEdit(text)
                                                }
                                                Keys.onEscapePressed: {
                                                    text = String(root.player.title || "")
                                                    root.titleEditing = false
                                                }
                                            }
                                        }

                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 0
                                            visible: root.nowPlayingBylineVisible

                                            Text {
                                                visible: root.nowPlayingArtist !== ""
                                                text: root.nowPlayingArtist
                                                color: Theme.foreground
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeXl
                                                opacity: artistMouse.containsMouse ? 1 : 0.62

                                                MouseArea {
                                                    id: artistMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: function(mouse) {
                                                        var artist = String(root.nowPlayingArtist || "").trim()
                                                        if (!artist)
                                                            return
                                                        mouse.accepted = true
                                                        root.openFilter("artist", artist, artist)
                                                    }
                                                }
                                            }

                                            Text {
                                                visible: root.nowPlayingArtist !== "" && root.nowPlayingAlbum !== ""
                                                text: " - "
                                                color: Theme.foreground
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeXl
                                                opacity: 0.62
                                            }

                                            Text {
                                                visible: root.nowPlayingAlbum !== ""
                                                text: root.nowPlayingAlbum
                                                color: Theme.foreground
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeXl
                                                opacity: albumMouse.containsMouse ? 1 : 0.62

                                                MouseArea {
                                                    id: albumMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: function(mouse) {
                                                        var album = String(root.nowPlayingAlbum || "").trim()
                                                        if (!album)
                                                            return
                                                        mouse.accepted = true
                                                        root.openFilter("album", album, album)
                                                    }
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
                                                    accent: false
                                                    tintColor: modelData.tint || Theme.foreground
                                                    tinted: !!modelData.tint
                                                    clickable: modelData.kind === "label"
                                                        || modelData.kind === "genre"
                                                        || modelData.kind === "year"
                                                    onActivated: {
                                                        if (modelData.kind === "label")
                                                            root.openFilter("label", modelData.value, modelData.value)
                                                        else if (modelData.kind === "genre")
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
                                spacing: Theme.spacing2

                                Item {
                                    id: waveformViz
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.minimumHeight: 96

                                    property string presetHint: ""

                                    function showPresetHint(name) {
                                        presetHint = root.formatVizPresetLabel(name)
                                        presetHintTimer.restart()
                                    }

                                    Timer {
                                        id: presetHintTimer
                                        interval: 1800
                                        repeat: false
                                        onTriggered: waveformViz.presetHint = ""
                                    }

                                    readonly property int vizBarCount: 100
                                    property var vizEnvelopes: []
                                    property real vizMid: 0
                                    property real vizVPad: 0
                                    property real vizDrawH: 0
                                    property real vizBarW: 4
                                    property real vizPitch: 5

                                    function recomputeVizEnvelopes() {
                                        var w = width
                                        var h = height
                                        if (w <= 0 || h <= 0) {
                                            vizEnvelopes = []
                                            return
                                        }
                                        var vPad = Math.max(12, h * 0.12)
                                        var drawH = Math.max(8, h - vPad * 2)
                                        var mid = vPad + drawH / 2
                                        var halfH = drawH * 0.5
                                        var maxAmp = halfH * 0.93
                                        var pitch = w / vizBarCount
                                        var barW = Math.max(2, pitch * 0.75)
                                        var samples = root.waveformSamples
                                        var n = samples.length
                                        var barCount = vizBarCount
                                        var envelopes = []

                                        vizMid = mid
                                        vizVPad = vPad
                                        vizDrawH = drawH
                                        vizBarW = barW
                                        vizPitch = pitch

                                        if (n === 0) {
                                            for (var e = 0; e < barCount; e++)
                                                envelopes.push(maxAmp * 0.35)
                                            vizEnvelopes = envelopes
                                            waveCanvas.requestPaint()
                                            cavaOverlay.requestPaint()
                                            return
                                        }

                                        var peaks = []
                                        if (n <= barCount) {
                                            for (var bi = 0; bi < n; bi++)
                                                peaks.push(Number(samples[bi]) || 0)
                                            while (peaks.length < barCount)
                                                peaks.push(0)
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

                                        var sorted = peaks.slice(0, barCount)
                                        sorted.sort(function(a, b) { return a - b })
                                        var floorVal = sorted[Math.max(0, Math.floor(barCount * 0.04))]
                                        var ceilVal = sorted[Math.min(barCount - 1, Math.floor(barCount * 0.994))]
                                        var span = Math.max(1, ceilVal - floorVal)
                                        var refPeak = Math.max(1, sorted[barCount - 1])
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
                                            envelopes.push(Math.max(1.2, amp))
                                        }
                                        vizEnvelopes = envelopes
                                        waveCanvas.requestPaint()
                                        cavaOverlay.requestPaint()
                                    }

                                    onWidthChanged: recomputeVizEnvelopes()
                                    onHeightChanged: recomputeVizEnvelopes()

                                    Connections {
                                        target: root
                                        function onWaveformSamplesChanged() {
                                            waveformViz.recomputeVizEnvelopes()
                                        }
                                    }

                                    Canvas {
                                        id: waveCanvas
                                        anchors.fill: parent
                                        property real playProgress: root.progress

                                        onPlayProgressChanged: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)
                                            var vPad = waveformViz.vizVPad
                                            var drawH = waveformViz.vizDrawH
                                            var mid = waveformViz.vizMid
                                            var prog = playProgress
                                            var samples = root.waveformSamples
                                            var n = samples.length
                                            var barCount = waveformViz.vizBarCount
                                            var pitch = waveformViz.vizPitch
                                            var barW = waveformViz.vizBarW
                                            var envelopes = waveformViz.vizEnvelopes

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

                                            var playX = width * prog
                                            var fg = Theme.foreground
                                            var accent = Theme.accent

                                            for (var i = 0; i < barCount; i++) {
                                                var amp = i < envelopes.length ? envelopes[i] : 1.2
                                                var x = i * pitch + (pitch - barW) / 2
                                                var played = (x + barW * 0.5) <= playX

                                                if (played) {
                                                    ctx.fillStyle = accent
                                                    ctx.globalAlpha = 0.98
                                                    ctx.fillRect(x, mid - amp, barW, amp)
                                                    ctx.globalAlpha = 0.38
                                                    ctx.fillRect(x, mid, barW, amp)
                                                } else {
                                                    ctx.fillStyle = Qt.rgba(fg.r, fg.g, fg.b, 1)
                                                    ctx.globalAlpha = 0.58
                                                    ctx.fillRect(x, mid - amp, barW, amp)
                                                    ctx.globalAlpha = 0.24
                                                    ctx.fillRect(x, mid, barW, amp)
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

                                    PlayerCavaBars {
                                        id: cavaOverlay
                                        z: 1
                                        anchors.fill: parent
                                        envelopes: waveformViz.vizEnvelopes
                                        vizMid: waveformViz.vizMid
                                        vizBarW: waveformViz.vizBarW
                                        vizPitch: waveformViz.vizPitch
                                        active: root.active && root.playerPlaying

                                        onPresetCycled: function(name) {
                                            waveformViz.showPresetHint(name)
                                        }
                                    }

                                    HoverPopupLabelPill {
                                        z: 3
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: waveformViz.presetHint
                                        textColor: Theme.accent
                                        textOpacity: 1
                                        fill: Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.92)
                                    }

                                    TransportTimePill {
                                        z: 3
                                        dark: true
                                        compact: true
                                        visible: waveformViz.vizMid > 0
                                        label: root.player.position_label || "0:00"
                                        x: -implicitWidth / 2
                                        y: waveformViz.vizMid - implicitHeight / 2
                                    }

                                    TransportTimePill {
                                        z: 3
                                        dark: true
                                        compact: true
                                        visible: waveformViz.vizMid > 0
                                        label: root.player.duration_label || "0:00"
                                        x: waveformViz.width > 0
                                            ? waveformViz.width - implicitWidth / 2
                                            : 0
                                        y: waveformViz.vizMid - implicitHeight / 2
                                    }

                                    MouseArea {
                                        z: 2
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: Qt.PointingHandCursor
                                        onPressed: function(mouse) {
                                            if (mouse.button === Qt.RightButton) {
                                                cavaOverlay.cyclePreset()
                                                return
                                            }
                                            root.previewSeekFromX(mouse.x, width)
                                        }
                                        onPositionChanged: function(mouse) {
                                            if (pressed && mouse.buttons & Qt.LeftButton)
                                                root.previewSeekFromX(mouse.x, width)
                                        }
                                        onReleased: function(mouse) {
                                            if (mouse.button === Qt.LeftButton)
                                                root.commitSeekFromX(mouse.x, width)
                                        }
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

    Rectangle {
        id: trashConfirmScrim
        anchors.fill: parent
        visible: root.trashConfirmOpen
        z: 400
        color: Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.72)

        MouseArea {
            anchors.fill: parent
            onClicked: root.cancelTrashTrack()
        }

        MouseArea {
            anchors.centerIn: parent
            width: trashConfirmCard.width
            height: trashConfirmCard.height
            onClicked: function(mouse) { mouse.accepted = true }

            Rectangle {
                id: trashConfirmCard
                width: Math.min(420, trashConfirmScrim.width - root.pad * 4)
                height: trashConfirmCol.implicitHeight + Theme.hoverPopupContentPad * 2
                radius: Theme.radiusL
                color: Theme.overlaySurface
                border.color: Theme.accent
                border.width: 1

                ColumnLayout {
                    id: trashConfirmCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.hoverPopupContentPad
                    spacing: Theme.spacingL

                    Text {
                        Layout.fillWidth: true
                        text: "trash this track?"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.sectionLabelFont
                        font.bold: Theme.fontBold
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.trashConfirmTitle !== ""
                        text: root.trashConfirmTitle
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: root.listFont
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spacingS
                        spacing: Theme.spacingM

                        Item { Layout.fillWidth: true }

                        MetaChip {
                            label: "cancel"
                            clickable: true
                            onActivated: root.cancelTrashTrack()
                        }

                        MetaChip {
                            label: "trash"
                            accent: true
                            clickable: true
                            onActivated: root.confirmTrashTrack()
                        }
                    }
                }
            }
        }
    }

    component AlbumArtThumbnail: Item {
        id: thumbRoot
        property int side: 56
        property bool showPickerOverlay: false
        property bool fillPane: false

        function nudgeVolume(delta) {
            if (!delta)
                return
            if (root.volumeTransportBtn)
                root.volumeTransportBtn.nudgeVolume(delta)
            else
                root.adjustVolume(delta)
        }

        function handleWheel(wheel) {
            if (!wheel.angleDelta.y)
                return
            nudgeVolume(wheel.angleDelta.y > 0 ? 5 : -5)
            wheel.accepted = true
        }

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
                            root.openArtPickerForDrop(p)
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
                onWheel: function(wheel) { thumbRoot.handleWheel(wheel) }
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
        property bool tinted: false
        property color tintColor: Theme.accent
        property bool clickable: false
        property int maxLabelWidth: 0
        signal activated()

        readonly property color chipTint: tinted ? tintColor : (accent ? Theme.accent : Theme.foreground)
        readonly property bool chipTinted: tinted || accent

        radius: 10
        color: chipTinted
            ? Theme.withOpacity(chipTint, (clickable && chipMouse.containsMouse) ? 0.22 : 0.14)
            : (clickable && chipMouse.containsMouse) ? Theme.foregroundHoverWash : Theme.foregroundWash
        border.color: chipTinted
            ? Theme.withOpacity(chipTint, 0.38)
            : Theme.foregroundDivider
        border.width: 1
        implicitWidth: (maxLabelWidth > 0 ? Math.min(chipText.implicitWidth, maxLabelWidth) : chipText.implicitWidth) + 16
        implicitHeight: chipText.implicitHeight + 6

        Text {
            id: chipText
            anchors.centerIn: parent
            width: parent.maxLabelWidth > 0 ? parent.maxLabelWidth : implicitWidth
            text: parent.label
            color: parent.chipTinted ? parent.chipTint : Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: root.listFont
            font.bold: parent.chipTinted && Theme.fontBold
            opacity: parent.chipTinted ? 0.95 : 0.68
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
        property bool dark: false
        property bool compact: false

        radius: compact ? Theme.radiusM : Theme.radiusL
        color: dark
            ? Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.98)
            : Theme.foregroundWash
        border.color: dark ? Theme.foregroundSubtle : Theme.foregroundDivider
        border.width: 1
        implicitWidth: pillText.implicitWidth + (compact ? 12 : 20)
        implicitHeight: pillText.implicitHeight + (compact ? 4 : 10)
        Layout.alignment: Qt.AlignVCenter

        Text {
            id: pillText
            anchors.centerIn: parent
            text: parent.label
            color: parent.highlight ? Theme.accent : Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: parent.compact ? root.libraryFont : root.hintFont
            font.bold: parent.highlight && Theme.fontBold
            opacity: parent.highlight ? 1 : 0.65
        }
    }

    component PlayerCavaBars: Item {
        id: cavaBars
        property bool active: false
        property var envelopes: []
        property real vizMid: 0
        property real vizBarW: 4
        property real vizPitch: 5

        readonly property int barCount: 100
        readonly property int asciiMax: 1000
        readonly property string cavaScript: (Quickshell.env("HOME") || "") + "/.local/bin/evo-cava"
        readonly property string cavaPresetFile: (Quickshell.env("HOME") || "") + "/.config/cava/cava.v"

        function zeroBarLevels() {
            var levels = []
            for (var i = 0; i < barCount; i++)
                levels.push(0)
            return levels
        }

        property var barLevels: zeroBarLevels()
        property int streamPos: 0
        property string presetName: ""

        opacity: active && cavaProc.running ? 1 : 0

        function requestPaint() {
            vizCanvas.requestPaint()
        }

        function resetBars() {
            streamPos = 0
            barLevels = zeroBarLevels()
            vizCanvas.requestPaint()
        }

        function stopCava() {
            cavaProc.running = false
            resetBars()
        }

        function applyCavaLine(line) {
            if (!line)
                return
            var parts = String(line).split(";")
            var levels = []
            var max = asciiMax
            for (var i = 0; i < barCount; i++) {
                var v = i < parts.length ? parseInt(parts[i], 10) : 0
                if (isNaN(v) || v < 0)
                    v = 0
                levels.push(Math.min(1, v / max))
            }
            barLevels = levels
            vizCanvas.requestPaint()
        }

        function parseCavaOutput() {
            var text = cavaOut.text || ""
            if (text.length < streamPos)
                streamPos = 0
            if (text.length <= streamPos)
                return

            var chunk = text.substring(streamPos)
            var lines = chunk.split("\n")
            streamPos = text.length - lines[lines.length - 1].length

            for (var i = 0; i < lines.length - 1; i++)
                applyCavaLine(lines[i])
        }

        function startCava() {
            if (cavaConfigProc.running)
                return
            cavaConfigProc._onDone = function(path) {
                path = String(path || "").trim()
                if (!path)
                    return
                stopCava()
                cavaProc.command = ["cava", "-p", path]
                cavaProc.running = true
            }
            cavaConfigProc.command = ["bash", cavaScript, "config"]
            cavaConfigProc.running = true
        }

        function cyclePreset() {
            if (cavaCycleProc.running)
                return
            cavaCycleProc._onDone = function(name) {
                presetName = String(name || "").trim()
                if (active)
                    startCava()
                presetCycled(presetName)
            }
            cavaCycleProc.command = ["bash", cavaScript, "next"]
            cavaCycleProc.running = true
        }

        signal presetCycled(string name)

        onActiveChanged: {
            if (active)
                startCava()
            else
                stopCava()
        }

        Process {
            id: cavaConfigProc
            property var _onDone: null
            stdout: StdioCollector {
                onStreamFinished: {
                    if (cavaConfigProc._onDone)
                        cavaConfigProc._onDone(text)
                    cavaConfigProc._onDone = null
                }
            }
            onExited: cavaConfigProc._onDone = null
        }

        Process {
            id: cavaCycleProc
            property var _onDone: null
            stdout: StdioCollector {
                onStreamFinished: {
                    if (cavaCycleProc._onDone)
                        cavaCycleProc._onDone(text)
                    cavaCycleProc._onDone = null
                }
            }
            onExited: cavaCycleProc._onDone = null
        }

        Process {
            id: cavaProc
            stdout: StdioCollector {
                id: cavaOut
                waitForEnd: false
            }
            onExited: cavaBars.resetBars()
        }

        Timer {
            interval: 33
            running: cavaBars.active && cavaProc.running
            repeat: true
            onTriggered: cavaBars.parseCavaOutput()
        }

        FileView {
            path: cavaBars.active ? cavaBars.cavaPresetFile : ""
            watchChanges: true
            onLoaded: {
                var name = String(text() || "").trim()
                if (!name || name === cavaBars.presetName)
                    return
                cavaBars.presetName = name
                if (cavaBars.active)
                    cavaBars.startCava()
            }
            onLoadFailed: cavaBars.presetName = ""
        }

        onEnvelopesChanged: vizCanvas.requestPaint()

        Canvas {
            id: vizCanvas
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (!cavaBars.active)
                    return

                var barCount = cavaBars.barCount
                var pitch = cavaBars.vizPitch > 0 ? cavaBars.vizPitch : width / barCount
                var barW = cavaBars.vizBarW > 0 ? cavaBars.vizBarW : Math.max(2, pitch * 0.75)
                var mid = cavaBars.vizMid > 0 ? cavaBars.vizMid : height / 2
                var envs = cavaBars.envelopes || []
                var barColor = Theme.mixColors(Theme.accent, Theme.foreground, 0.38)
                var fallbackAmp = Math.max(8, height * 0.16)

                for (var i = 0; i < barCount; i++) {
                    var frameH = i < envs.length ? envs[i] : fallbackAmp
                    var level = cavaBars.barLevels[i]
                    var liveH = Math.max(1, frameH * level)
                    var x = i * pitch + (pitch - barW) / 2
                    ctx.fillStyle = Qt.rgba(barColor.r, barColor.g, barColor.b, 0.42 + level * 0.5)
                    ctx.fillRect(x, mid - liveH, barW, liveH)
                    ctx.fillRect(x, mid, barW, liveH)
                }
            }
        }
    }

    component TransportProgressBar: Item {
        id: transportProgress
        Layout.preferredWidth: 140
        Layout.minimumWidth: 72
        Layout.maximumWidth: 240
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        implicitHeight: 20

        readonly property real value: root.progress
        readonly property bool seekable: Number(root.player.duration) > 0

        Rectangle {
            id: transportProgressTrack
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Theme.foregroundFaint

            Rectangle {
                width: parent.width * transportProgress.value
                height: parent.height
                radius: parent.radius
                color: Theme.accent
                opacity: transportProgress.seekable ? 1 : 0.35
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: transportProgress.seekable
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
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

                TransportProgressBar {}

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

    component VolumeSliderPopup: Item {
        id: volPopup
        property int level: 100
        property alias sliderPressed: sliderArea.pressed

        signal volumeSet(int percent)
        signal interacted()
        signal wheelNudge(int delta)

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
                text: volPopup.level + "%"
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
                    height: volTrack.height * (volPopup.level / 100)
                    radius: Theme.radiusS
                    color: Theme.accent
                }

                Rectangle {
                    id: volThumb
                    anchors.horizontalCenter: volTrack.horizontalCenter
                    anchors.bottom: volTrack.bottom
                    anchors.bottomMargin: (volTrack.height - height) * (volPopup.level / 100)
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
                        volPopup.interacted()
                        volPopup.volumeSet(volumeAt(mouse.y))
                    }

                    onPositionChanged: function(mouse) {
                        if (pressed) {
                            volPopup.interacted()
                            volPopup.volumeSet(volumeAt(mouse.y))
                        }
                    }

                    onWheel: function(wheel) {
                        if (!wheel.angleDelta.y)
                            return
                        volPopup.wheelNudge(wheel.angleDelta.y > 0 ? 5 : -5)
                        wheel.accepted = true
                    }
                }
            }
        }
    }

    component VolumeTransportBtn: Item {
        id: volBtn
        readonly property int level: Math.round(root.player.volume !== undefined ? root.player.volume : 100)
        property bool wheelPopupActive: false
        readonly property bool popupVisible: volHover.containsMouse || volSliderPopup.sliderPressed || wheelPopupActive

        Component.onCompleted: root.volumeTransportBtn = volBtn
        Component.onDestruction: {
            if (root.volumeTransportBtn === volBtn)
                root.volumeTransportBtn = null
        }

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

        VolumeSliderPopup {
            id: volSliderPopup
            visible: popupVisible
            z: 10
            level: volBtn.level
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: 8
            onVolumeSet: function(v) {
                volBtn.wheelPopupActive = true
                popupHideTimer.restart()
                root.setVolume(v)
            }
            onInteracted: {
                volBtn.wheelPopupActive = true
                popupHideTimer.restart()
            }
            onWheelNudge: function(delta) { volBtn.nudgeVolume(delta) }
        }
    }

    component RowIconButton: Item {
        id: rowIconBtn
        property string icon: ""
        property string tooltip: ""
        property color iconColor: Theme.foreground
        property real opacityIdle: 0.42
        property real opacityHover: 0.9
        property bool enabled: true
        property bool flashing: false
        property int iconSize: root.listFont
        signal activated()

        function restingOpacity() {
            if (!rowIconBtn.enabled)
                return 0.2
            return rowIconMouse.containsMouse ? rowIconBtn.opacityHover : rowIconBtn.opacityIdle
        }

        implicitWidth: 22
        implicitHeight: 22
        Layout.preferredWidth: 22
        Layout.preferredHeight: 22
        Layout.alignment: Qt.AlignVCenter
        z: 2

        Text {
            id: rowIconGlyph
            anchors.centerIn: parent
            text: rowIconBtn.icon
            color: rowIconBtn.iconColor
            opacity: rowIconBtn.flashing ? 1 : rowIconBtn.restingOpacity()
            font.family: Theme.fontFamily
            font.pixelSize: rowIconBtn.iconSize

            SequentialAnimation on opacity {
                running: rowIconBtn.flashing
                loops: Animation.Infinite
                NumberAnimation {
                    from: 0.35
                    to: 1.0
                    duration: 600
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: 1.0
                    to: 0.35
                    duration: 600
                    easing.type: Easing.InOutSine
                }
            }
        }

        Connections {
            target: rowIconBtn
            function onFlashingChanged() {
                if (!rowIconBtn.flashing)
                    rowIconGlyph.opacity = rowIconBtn.restingOpacity()
            }
            function onEnabledChanged() {
                if (!rowIconBtn.flashing)
                    rowIconGlyph.opacity = rowIconBtn.restingOpacity()
            }
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

        BriefTooltip {
            show: rowIconMouse.containsMouse
            text: rowIconBtn.tooltip
        }
    }

    component BrowseTrackRow: Rectangle {
        id: browseRow
        property var track: ({})
        property int trackRevision: 0
        property bool selected: false
        property bool playing: false
        property int rowWidth: 0
        property string genreLabel: ""
        property bool showGenre: true
        property bool showFolder: false
        property bool showActionButtons: true
        signal pressed()
        signal playRequested()
        signal likeToggled()
        signal revealRequested()
        signal folderOpenRequested()
        signal addRequested()

        readonly property bool trackLiked: {
            var _rev = browseRow.trackRevision
            return !!(browseRow.track && browseRow.track.liked)
        }
        readonly property string artistAlbumLine: {
            var artist = String(browseRow.track.artist || "").trim()
            var album = String(browseRow.track.album || "").trim()
            var title = String(browseRow.track.title || "").trim()
            if (album === title)
                album = ""
            if (artist && album)
                return artist + " - " + album
            return artist || album
        }
        readonly property int genreReserve: browseRow.showGenre && browseRow.genreLabel !== "" ? 108 : 0
        readonly property int likeReserve: 30
        readonly property int folderReserve: browseRow.showFolder ? 30 : 0
        readonly property int actionButtonReserve: browseRow.showActionButtons && browseRow.selected
            ? (22 * 3 + Theme.spacingM * 2)
            : 0
        readonly property bool hovered: browseRowMouse.containsMouse
            || browseLikeMouse.containsMouse
            || (!browseRow.selected && browseArtSelectMouse.containsMouse)

        width: rowWidth
        height: 40
        radius: Theme.radiusL
        color: playing
            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
            : (selected
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                : (browseRowMouse.containsMouse
                    ? Theme.foregroundGhost
                    : "transparent"))

        MouseArea {
            anchors.fill: parent
            z: 4
            acceptedButtons: Qt.RightButton
            onClicked: browseRow.revealRequested()
        }

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
                    opacity: browseRow.selected || browseRow.playing ? 1 : 0.9
                }

                Text {
                    Layout.fillWidth: true
                    visible: browseRow.artistAlbumLine !== ""
                    text: browseRow.artistAlbumLine
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.listFont
                    elide: Text.ElideRight
                    opacity: Theme.opacityMuted
                }
            }

            MetaChip {
                visible: browseRow.showGenre && browseRow.genreLabel !== ""
                label: browseRow.genreLabel
                accent: true
                clickable: false
                maxLabelWidth: 96
                Layout.alignment: Qt.AlignVCenter
            }

            RowIconButton {
                visible: browseRow.showFolder && !(browseRow.showActionButtons && browseRow.selected)
                icon: "󰉖"
                onActivated: browseRow.folderOpenRequested()
            }

            RowIconButton {
                visible: browseRow.showActionButtons && browseRow.selected
                icon: "󰉖"
                tooltip: "open folder"
                onActivated: browseRow.folderOpenRequested()
            }

            RowIconButton {
                visible: browseRow.showActionButtons && browseRow.selected
                icon: "󰐕"
                tooltip: "add to current"
                onActivated: browseRow.addRequested()
            }

            RowIconButton {
                visible: browseRow.showActionButtons && browseRow.selected
                icon: "󰐊"
                iconColor: Theme.accent
                tooltip: "play"
                opacityIdle: 0.55
                opacityHover: 1
                onActivated: browseRow.playRequested()
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
                    acceptedButtons: Qt.LeftButton
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
            anchors.rightMargin: browseRow.genreReserve + browseRow.folderReserve
                + browseRow.actionButtonReserve + browseRow.likeReserve
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            Timer {
                id: browseRowClickTimer
                interval: 220
                repeat: false
                onTriggered: {
                    if (browseRow.selected)
                        browseRow.playRequested()
                    else
                        browseRow.pressed()
                }
            }

            onClicked: browseRowClickTimer.restart()

            onDoubleClicked: {
                browseRowClickTimer.stop()
                if (!browseRow.selected)
                    browseRow.pressed()
                browseRow.playRequested()
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
            spacing: Theme.spacingS

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingS

                Text {
                    visible: root.artApplyAlbumAvailable || root.artPendingDropPath !== ""
                    text: "apply to"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.libraryFont
                    opacity: Theme.opacityDisabled
                }

                MetaChip {
                    visible: root.artApplyAlbumAvailable
                    label: root.nowPlayingAlbum !== ""
                        ? root.nowPlayingAlbum
                        : String(root.player.album || "album")
                    accent: root.artApplyScope === "album"
                    clickable: true
                    maxLabelWidth: Math.min(180, artPickerRoot.width * 0.42)
                    onActivated: root.selectArtApplyScope("album")
                }

                MetaChip {
                    visible: root.artApplyAlbumAvailable || root.artPendingDropPath !== ""
                    label: "this track"
                    accent: root.artApplyScope === "track"
                    clickable: true
                    onActivated: root.selectArtApplyScope("track")
                }

                MetaChip {
                    visible: (root.player.art || "") !== ""
                    label: "remove"
                    accent: false
                    clickable: true
                    onActivated: root.clearAlbumArt()
                }

                MetaChip {
                    label: "close"
                    accent: false
                    clickable: true
                    onActivated: root.closeArtPicker()
                }

                Item { Layout.fillWidth: true }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.artPickerLoading

                Text {
                    anchors.centerIn: parent
                    text: "󰇘"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(Math.min(parent.width, parent.height) * 0.28)
                    opacity: Theme.opacityEmphasis

                    SequentialAnimation on opacity {
                        running: root.artPickerLoading
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.28; to: 1.0; duration: 650; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.0; to: 0.28; duration: 650; easing.type: Easing.InOutSine }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !root.artPickerLoading
                    && root.artPickerResults.length === 0
                    && root.artPendingDropPath === ""
                text: "no results"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.libraryFont
                opacity: Theme.opacityDisabled
            }

            Item {
                id: artPickerGridHost
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !root.artPickerLoading
                    && (root.artPickerResults.length > 0 || root.artPendingDropPath !== "")

                readonly property int cellSize: Math.max(
                    40,
                    Math.floor(Math.min(
                        (width - artPickerRoot.gridSpacing) / 2,
                        (height - artPickerRoot.gridSpacing) / 2)))
                readonly property int gridWidth: cellSize * 2 + artPickerRoot.gridSpacing
                readonly property int gridHeight: cellSize * 2 + artPickerRoot.gridSpacing
                readonly property int xOffset: Math.max(0, Math.floor((width - gridWidth) / 2))
                readonly property int yOffset: Math.max(0, Math.floor((height - gridHeight) / 2))

                Rectangle {
                    visible: root.artPendingDropPath !== ""
                    x: artPickerGridHost.xOffset
                    y: artPickerGridHost.yOffset
                    width: artPickerGridHost.gridWidth
                    height: artPickerGridHost.gridHeight
                    radius: Theme.radiusM
                    clip: true
                    color: Theme.foregroundWash
                    border.color: Theme.foregroundRaised
                    border.width: 1

                    Image {
                        anchors.fill: parent
                        source: root.artPendingDropPath !== ""
                            ? root.artUrl(root.artPendingDropPath)
                            : ""
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                    }
                }

                Repeater {
                    model: root.artPendingDropPath !== ""
                        ? 0
                        : Math.min(4, root.artPickerResults.length)

                    Rectangle {
                        required property int index
                        readonly property var result: root.artPickerResults[index]
                        x: artPickerGridHost.xOffset + (index % 2) * (artPickerGridHost.cellSize + artPickerRoot.gridSpacing)
                        y: artPickerGridHost.yOffset + Math.floor(index / 2) * (artPickerGridHost.cellSize + artPickerRoot.gridSpacing)
                        width: artPickerGridHost.cellSize
                        height: artPickerGridHost.cellSize
                        radius: Theme.radiusM
                        clip: true
                        color: Theme.foregroundWash
                        border.color: artPickMouse.containsMouse
                            ? Theme.accent
                            : Theme.foregroundRaised
                        border.width: artPickMouse.containsMouse ? 2 : 1

                        Image {
                            anchors.fill: parent
                            source: result.url || ""
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: true
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 16
                            visible: String(result.source || "") !== ""
                            color: Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.78)

                            Text {
                                anchors.centerIn: parent
                                text: String(result.source || "")
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
                            onClicked: root.applyAlbumArtFromUrl(result.url)
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

        function restingOpacity() {
            return iconTab.active ? 1 : 0.78
        }

        implicitWidth: root.genreTabHeight
        implicitHeight: root.genreTabHeight
        clip: true

        Connections {
            target: iconTab
            function onSpinningChanged() {
                if (!iconTab.spinning)
                    iconTabGlyph.opacity = iconTab.restingOpacity()
            }
            function onActiveChanged() {
                if (!iconTab.spinning)
                    iconTabGlyph.opacity = iconTab.restingOpacity()
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: iconTab.active
                ? "transparent"
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
            opacity: iconTab.spinning ? 1 : iconTab.restingOpacity()

            SequentialAnimation on opacity {
                running: iconTab.spinning
                loops: Animation.Infinite
                NumberAnimation {
                    from: iconTab.active ? 0.55 : 0.35
                    to: 1.0
                    duration: 600
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: 1.0
                    to: iconTab.active ? 0.55 : 0.35
                    duration: 600
                    easing.type: Easing.InOutSine
                }
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

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.spacingS

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingS

                RowIconButton {
                    icon: "󰋜"
                    tooltip: "home"
                    opacityIdle: 0.5
                    enabled: !root.browseTreeLoading
                    onActivated: root.browseTreeHome()
                }

                RowIconButton {
                    icon: "󰑐"
                    tooltip: "refresh"
                    opacityIdle: 0.5
                    enabled: !root.browseTreeLoading
                    onActivated: root.refreshBrowseTree()
                }

                Repeater {
                    model: root.libraryActions

                    RowIconButton {
                        required property var modelData
                        icon: modelData.icon
                        tooltip: modelData.hint || modelData.label
                        opacityIdle: root.libraryJobBusy ? 0.2 : 0.5
                        opacityHover: root.libraryJobBusy ? 0.35 : 0.9
                        iconColor: root.libraryJobBusy && root.activeLibraryJobKey === modelData.key
                            ? Theme.accent
                            : Theme.foreground
                        flashing: root.libraryJobBusy && root.activeLibraryJobKey === modelData.key
                        enabled: !root.browseTreeLoading && !root.libraryJobBusy
                        onActivated: root.runLibraryAction(modelData)
                    }
                }

                RowIconButton {
                    visible: root.libraryActivityBusy
                    icon: "󰓛"
                    tooltip: "stop"
                    opacityIdle: 0.5
                    opacityHover: 0.9
                    iconColor: Theme.accent
                    enabled: !root.browseTreeLoading
                    onActivated: root.stopLibraryJob()
                }

                Text {
                    visible: root.libraryActivityBusy
                    Layout.fillWidth: true
                    Layout.minimumWidth: 48
                    text: root.jobLogInline()
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.libraryFont
                    opacity: Theme.opacityDisabled
                    elide: Text.ElideLeft
                }

                Item {
                    Layout.fillWidth: true
                    visible: !root.libraryActivityBusy
                }

                Text {
                    visible: root.browseTreeLoading
                    text: "refreshing…"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.libraryFont
                    opacity: Theme.opacityDisabled
                }
            }

            ListView {
                id: sideBrowseTree
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.spacing2
                model: root.browseTreeRows
                reuseItems: true
                cacheBuffer: Math.max(240, height * 2)
                opacity: root.browseTreeReflowHidden ? 0 : 1

                Component.onCompleted: root.browseTreeListView = sideBrowseTree
                Component.onDestruction: {
                    if (root.browseTreeListView === sideBrowseTree)
                        root.browseTreeListView = null
                }

                onContentYChanged: {
                    if (root.browseTreeHoldY >= 0)
                        return
                    if (root.browseTreeRestoreY < 0)
                        root.saveBrowseTreeScroll()
                }

                onContentHeightChanged: {
                    if (root.browseTreeHoldY < 0)
                        return
                    var maxY = Math.max(0, contentHeight - height)
                    contentY = Math.min(root.browseTreeHoldY, maxY)
                }

                onMovementEnded: {
                    if (atYEnd)
                        root.loadMoreBrowseTreeTracks()
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

                footer: Text {
                    width: sideBrowseTree.width
                    visible: root.browseTreeLoadingMore
                    horizontalAlignment: Text.AlignHCenter
                    text: "loading more…"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.listFont
                    opacity: Theme.opacityDisabled
                }

                delegate: Item {
                    required property var modelData
                    required property int index
                    readonly property bool isDir: modelData.type === "dir"
                    readonly property int indent: 8 + (Number(modelData.depth || 0) * 14)
                    width: sideBrowseTree.width
                    height: isDir ? 34 : 40

                    Rectangle {
                        anchors.fill: parent
                        visible: isDir
                        radius: Theme.radiusL
                        color: treeRowMouse.containsMouse
                            ? Theme.foregroundGhost
                            : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: indent
                            anchors.rightMargin: 6
                            spacing: Theme.spacingS

                            BrowseTreeIcon {
                                Layout.preferredWidth: 14
                                icon: modelData.expanded ? "󰅃" : "󰅂"
                                hint: "expand or collapse folder"
                                glyphOpacity: 0.45
                                hoverOpacity: 0.9
                                onActivated: root.toggleBrowseTreeNode(modelData.path)
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

                            BrowseTreeIcon {
                                icon: "󰉖"
                                hint: "open folder in file manager"
                                onActivated: root.openBrowseFolder(modelData)
                            }

                            BrowseTreeIcon {
                                icon: "󰉚"
                                hint: "sort files into album folders"
                                onActivated: root.browseSortFolder(modelData)
                            }

                            BrowseTreeIcon {
                                icon: "󰐕"
                                hint: "append folder to current playlist"
                                glyphColor: Theme.accent
                                glyphOpacity: 0.55
                                hoverOpacity: 1
                                onActivated: root.browseAppendFolder(modelData)
                            }

                            BrowseTreeIcon {
                                icon: "󰐊"
                                hint: "play all tracks in folder"
                                glyphColor: Theme.accent
                                glyphOpacity: 0.55
                                hoverOpacity: 1
                                onActivated: root.browseQueueFolder(modelData)
                            }
                        }

                        MouseArea {
                            id: treeRowMouse
                            anchors.fill: parent
                            anchors.rightMargin: 98
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleBrowseTreeNode(modelData.path)
                        }
                    }

                    BrowseTrackRow {
                        visible: !isDir
                        x: indent + 14
                        width: parent.width - x - 6
                        height: 40
                        track: modelData.track || modelData
                        trackRevision: root.tracksRevision
                        selected: root.isTrackSelected(modelData.path)
                        playing: root.isTrackPlaying(modelData.path)
                        showGenre: false
                        onPressed: root.selectTrackEntry(modelData.track || modelData)
                        onPlayRequested: root.playBrowseTreeTrack(modelData.track || modelData)
                        onLikeToggled: root.toggleTrackFavorite(modelData.path)
                        onRevealRequested: root.openTrackInThunar(modelData.path)
                        onFolderOpenRequested: root.openTrackFolder(modelData)
                        onAddRequested: root.appendTrackToCurrent(modelData.track || modelData)
                    }
                }
            }
        }
    }

    component PlayerSidePlaylistPanel: SectionPanel {
        label: ""
        fillHeight: true

        ColumnLayout {
            id: playlistPanelColumn
            anchors.fill: parent
            spacing: Theme.spacingS

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingM
                visible: root.playlistPanelMode === "tracks"

                RowIconButton {
                    icon: "󰁍"
                    onActivated: root.showPlaylistLibrary()
                }

                Text {
                    Layout.fillWidth: true
                    text: root.playlistTabLabel(root.selectedPlaylist)
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.sectionLabelFont
                    font.bold: Theme.fontBold
                    elide: Text.ElideRight
                }
            }

            ListView {
                id: sidePlaylistLibraryList
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.playlistPanelMode === "library"
                clip: true
                spacing: Theme.spacing2
                model: root.libraryPlaylists
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    anchors.centerIn: parent
                    visible: root.playlistsLoading && root.libraryPlaylists.length === 0
                    text: "loading…"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.listFont
                    opacity: Theme.opacityDisabled
                }

                delegate: Rectangle {
                    required property var modelData
                    width: sidePlaylistLibraryList.width
                    height: 38
                    radius: Theme.radiusL
                    color: root.selectedPlaylist === (modelData.name || "")
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
                        : (sideLibPlaylistMouse.containsMouse
                            ? Theme.foregroundGhost
                            : "transparent")

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: Theme.spacingM

                        Text {
                            Layout.fillWidth: true
                            text: root.playlistTabLabel(modelData.name || "")
                            color: root.selectedPlaylist === (modelData.name || "")
                                ? Theme.accent
                                : Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.listFont
                            font.bold: root.selectedPlaylist === (modelData.name || "") && Theme.fontBold
                            elide: Text.ElideRight
                        }

                        Text {
                            text: String(modelData.count || 0)
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.listFont
                            opacity: Theme.opacityDisabled
                        }

                        Text {
                            visible: root.playlistCanStar(modelData.name || "")
                            text: modelData.starred === true ? "󰓎" : "󰓒"
                            color: modelData.starred === true ? Theme.accent : Theme.foreground
                            opacity: modelData.starred === true
                                ? 1
                                : (playlistStarMouse.containsMouse ? 0.75 : 0.35)
                            font.family: Theme.fontFamily
                            font.pixelSize: root.listFont

                            MouseArea {
                                id: playlistStarMouse
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    mouse.accepted = true
                                    root.togglePlaylistStar(modelData.name)
                                }
                            }
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
                visible: root.playlistPanelMode === "tracks"
                clip: true
                spacing: Theme.spacing2
                model: root.tracks

                Component.onCompleted: root.playlistTrackList = sidePlaylistTrackList
                Component.onDestruction: {
                    if (root.playlistTrackList === sidePlaylistTrackList)
                        root.playlistTrackList = null
                }

                onContentYChanged: {
                    if (root.playlistRestoreY < 0)
                        root.savePlaylistView(root.selectedPlaylist)
                }

                onHeightChanged: {
                    if (visible && root.playlistRestoreY >= 0)
                        playlistScrollRestoreTimer.restart()
                }

                onContentHeightChanged: {
                    if (root.playlistRestoreY < 0)
                        return
                    var maxY = Math.max(0, contentHeight - height)
                    contentY = Math.min(root.playlistRestoreY, maxY)
                }

                onVisibleChanged: {
                    if (visible && root.playlistRestoreY >= 0)
                        playlistScrollRestoreTimer.restart()
                }

                onMovementEnded: {
                    if (atYEnd)
                        root.loadMorePlaylistTracks()
                }

                Timer {
                    id: playlistScrollRestoreTimer
                    interval: 0
                    repeat: true
                    property int attempts: 0
                    onTriggered: {
                        if (root.playlistRestoreY < 0
                                || !root.playlistPanelOpen
                                || root.playlistPanelMode !== "tracks") {
                            stop()
                            attempts = 0
                            return
                        }
                        if (!sidePlaylistTrackList.visible || sidePlaylistTrackList.height <= 0)
                            return
                        var maxY = Math.max(0, sidePlaylistTrackList.contentHeight - sidePlaylistTrackList.height)
                        sidePlaylistTrackList.contentY = Math.min(root.playlistRestoreY, maxY)
                        attempts++
                        if (sidePlaylistTrackList.contentHeight > 0 || attempts > 8) {
                            root.playlistRestoreY = -1
                            stop()
                            attempts = 0
                        }
                    }
                }

                Connections {
                    target: root
                    function onTracksChanged() {
                        if (root.playlistRestoreY < 0)
                            return
                        playlistScrollRestoreTimer.attempts = 0
                        playlistScrollRestoreTimer.restart()
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.tracksLoading
                    text: "loading…"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.listFont
                    opacity: Theme.opacityDisabled
                }

                footer: Text {
                    width: sidePlaylistTrackList.width
                    visible: root.playlistTracksLoadingMore
                    horizontalAlignment: Text.AlignHCenter
                    text: "loading more…"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.listFont
                    opacity: Theme.opacityDisabled
                }

                delegate: BrowseTrackRow {
                    required property var modelData
                    required property int index
                    rowWidth: sidePlaylistTrackList.width
                    track: modelData
                    trackRevision: root.tracksRevision
                    selected: root.isTrackSelected(modelData.path)
                    playing: root.isTrackPlaying(modelData.path)
                    showGenre: false
                    onPressed: root.selectPlaylistTrack(index)
                    onPlayRequested: root.playTrackAt(index)
                    onLikeToggled: root.toggleTrackFavorite(modelData.path)
                    onRevealRequested: root.openTrackInThunar(modelData.path)
                    onFolderOpenRequested: root.openTrackFolder(modelData)
                    onAddRequested: root.appendTrackToCurrent(modelData)
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
                    onActivated: root.showNowPlaying()
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

                    delegate: BrowseTrackRow {
                        required property var modelData
                        required property int index
                        rowWidth: sideFilterTrackList.width
                        track: modelData
                        trackRevision: root.tracksRevision
                        selected: root.isTrackSelected(modelData.path)
                        playing: root.isTrackPlaying(modelData.path)
                        showGenre: false
                        onPressed: root.selectFilterTrack(index)
                        onPlayRequested: root.playFilterTrackAt(index)
                        onLikeToggled: root.toggleTrackFavorite(modelData.path)
                        onRevealRequested: root.openTrackInThunar(modelData.path)
                        onFolderOpenRequested: root.openTrackFolder(modelData)
                        onAddRequested: root.appendTrackToCurrent(modelData)
                    }
                }
            }
        }
    }

    component BriefTooltip: Item {
        property bool show: false
        property string text: ""

        z: 200
        width: 1
        height: 1

        HoverPopupLabelPill {
            visible: show && text !== ""
            anchors.bottom: parent.top
            anchors.bottomMargin: 5
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.text
            fontSize: Theme.fontSizeXs
            textOpacity: 0.9
            fieldsetLegend: false
            fill: Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.96)
        }
    }

    component BrowseTreeIcon: Item {
        id: treeIcon
        property string icon: ""
        property string hint: ""
        property color glyphColor: Theme.foreground
        property real glyphOpacity: 0.45
        property real hoverOpacity: 0.85
        signal activated()

        implicitWidth: glyph.implicitWidth + 8
        implicitHeight: glyph.implicitHeight + 8

        Text {
            id: glyph
            anchors.centerIn: parent
            text: treeIcon.icon
            color: treeIcon.glyphColor
            opacity: iconMouse.containsMouse ? treeIcon.hoverOpacity : treeIcon.glyphOpacity
            font.family: Theme.fontFamily
            font.pixelSize: root.listFont
        }

        MouseArea {
            id: iconMouse
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) {
                mouse.accepted = true
                treeIcon.activated()
            }
        }

        BriefTooltip {
            show: iconMouse.containsMouse && treeIcon.hint !== ""
            text: treeIcon.hint
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
