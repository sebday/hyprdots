import QtQuick
import Quickshell
import Quickshell.Io
import "../../Commons"

Item {
    id: root

    property var shell: null
    property var player: ({})
    property string lastNotifiedPath: ""
    property bool lastNotifiedHadArt: false
    property string lastNotifiedArt: ""
    property string scrobblePath: ""
    property bool scrobbleSubmitted: false
    property real scrobbleStartPos: -1
    property int scrobbleStartedAt: 0

    readonly property string playerScript: (Quickshell.env("HOME") || "") + "/.local/bin/evo-player"
    readonly property string mpvSocketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/evo-player.sock"

    property var mpvPendingProps: ({})
    property int mpvNextReq: 100
    property bool mpvObserveSent: false
    property string enrichPath: ""
    property string enrichQueuedPath: ""

    function formatTime(sec) {
        var total = Math.max(0, Math.floor(Number(sec) || 0))
        var min = Math.floor(total / 60)
        var s = total % 60
        return min + ":" + (s < 10 ? "0" : "") + s
    }

    function mpvWrite(cmd) {
        if (!mpvSocket.connected)
            return -1
        var id = mpvNextReq++
        mpvSocket.write(JSON.stringify({ command: cmd, request_id: id }) + "\n")
        mpvSocket.flush()
        return id
    }

    function mpvGetProperty(name) {
        var id = mpvWrite(["get_property", name])
        if (id >= 0)
            mpvPendingProps[id] = name
    }

    function observeMpv() {
        if (mpvObserveSent)
            return
        mpvObserveSent = true
        var props = ["path", "pause", "time-pos", "duration", "volume", "mute", "shuffle"]
        for (var i = 0; i < props.length; i++)
            mpvWrite(["observe_property", i + 1, props[i]])
        for (i = 0; i < props.length; i++)
            mpvGetProperty(props[i])
    }

    function applyMpvProperty(name, data) {
        var patch = {}
        if (name === "path") {
            var p = String(data || "")
            patch.path = p
            if (p !== enrichPath) {
                enrichPath = p
                requestEnrich(p)
            }
            if (!p) {
                lastNotifiedPath = ""
                lastNotifiedHadArt = false
                lastNotifiedArt = ""
                resetScrobbleSession()
            }
        } else if (name === "pause") {
            patch.state = data ? "paused" : "playing"
        } else if (name === "time-pos") {
            patch.position = Number(data) || 0
            patch.position_label = formatTime(patch.position)
        } else if (name === "duration") {
            patch.duration = Number(data) || 0
            patch.duration_label = formatTime(patch.duration)
        } else if (name === "volume") {
            patch.volume = Math.round(Number(data) || 0)
        } else if (name === "mute") {
            if (data)
                patch.volume = 0
        } else if (name === "shuffle") {
            patch.shuffle = data === true || data === "yes"
        } else {
            return
        }
        mergePlayer(patch)
    }

    function handleMpvLine(line) {
        var msg
        try {
            msg = JSON.parse(String(line || ""))
        } catch (e) {
            return
        }
        if (msg.event === "property-change" && msg.name)
            applyMpvProperty(msg.name, msg.data)
        else if (msg.request_id !== undefined && mpvPendingProps[msg.request_id] !== undefined) {
            var prop = mpvPendingProps[msg.request_id]
            delete mpvPendingProps[msg.request_id]
            if (msg.error === "success" || msg.data !== undefined)
                applyMpvProperty(prop, msg.data)
        }
    }

    function mergePlayer(patch) {
        var prevPath = String(player.path || "")
        var prevState = String(player.state || "")
        var next = Object.assign({}, player, patch)
        var newPath = String(next.path || "")
        if (prevPath && newPath !== prevPath
                && scrobblePath === prevPath
                && !scrobbleSubmitted
                && prevState === "playing")
            maybeSubmitScrobble()
        player = next
        var state = String(player.state || "")
        if (newPath && state === "playing") {
            notifyNowPlaying()
            maybeSubmitScrobble()
        }
    }

    function applyStatusPayload(text) {
        var parsed
        try {
            parsed = JSON.parse(String(text || "{}"))
        } catch (e) {
            parsed = {}
        }
        var prevPath = String(player.path || "")
        var prevState = String(player.state || "")
        var newPath = String(parsed.path || "")
        if (prevPath && newPath !== prevPath
                && scrobblePath === prevPath
                && !scrobbleSubmitted
                && prevState === "playing")
            maybeSubmitScrobble()
        player = Object.assign({}, player, parsed)
        enrichPath = newPath
        var path = newPath
        var state = String(player.state || "")
        if (path && state === "playing") {
            notifyNowPlaying()
            maybeSubmitScrobble()
        } else if (!path) {
            lastNotifiedPath = ""
            lastNotifiedHadArt = false
            lastNotifiedArt = ""
            resetScrobbleSession()
        }
    }

    function requestEnrich(path) {
        var p = String(path || "")
        if (!p) {
            enrichQueuedPath = ""
            return
        }
        enrichQueuedPath = p
        if (enrichProc.running)
            return
        pumpEnrich()
    }

    function pumpEnrich() {
        var p = String(enrichQueuedPath || "")
        enrichQueuedPath = ""
        if (!p) {
            if (enrichQueuedPath)
                pumpEnrich()
            return
        }
        enrichProc.path = p
        enrichProc.command = [playerScript, "meta", p, "--json"]
        enrichProc.running = true
    }

    function beginScrobbleSession() {
        var path = String(player.path || "")
        if (!path)
            return
        scrobblePath = path
        scrobbleStartPos = Number(player.position) || 0
        scrobbleStartedAt = Math.floor(Date.now() / 1000 - scrobbleStartPos)
        scrobbleSubmitted = false
    }

    function resetScrobbleSession() {
        scrobblePath = ""
        scrobbleStartPos = -1
        scrobbleStartedAt = 0
        scrobbleSubmitted = false
    }

    function maybeWarmTrack() {
        var path = String(player.path || "")
        if (!path || warmProc.running)
            return
        var hasArt = String(player.art || "").trim() !== ""
        if (hasArt)
            return
        warmProc.command = [playerScript, "warm", path]
        warmProc.running = true
    }

    function pushMediaNotification(artPath) {
        if (!shell)
            return
        var path = String(player.path || "")
        if (!path)
            return
        var art = String(artPath || "")
        if (path === lastNotifiedPath && art === lastNotifiedArt)
            return
        var notif = shell.serviceFor("evo.sys.notifications")
        if (!notif || typeof notif.showMedia !== "function")
            return
        var needsArtUpdate = path === lastNotifiedPath && art !== "" && !lastNotifiedHadArt
        notif.showMedia({
            app: "evo.panel.player",
            title: String(player.title || "Unknown"),
            artist: String(player.artist || ""),
            art: art,
            path: path
        })
        if (needsArtUpdate)
            runScrobble(["touch"])
        lastNotifiedPath = path
        lastNotifiedHadArt = art !== ""
        lastNotifiedArt = art
    }

    function notifyNowPlaying() {
        if (!shell)
            return
        var path = String(player.path || "")
        if (!path)
            return
        var hasArt = String(player.art || "") !== ""
        var scrobbleTrackChanged = path !== scrobblePath
        var pathChanged = path !== lastNotifiedPath
        var needsArtUpdate = path === lastNotifiedPath && hasArt && !lastNotifiedHadArt

        if (scrobbleTrackChanged) {
            runScrobble(["nowplaying"])
            beginScrobbleSession()
            maybeWarmTrack()
        }

        if (!pathChanged && !needsArtUpdate)
            return

        if (pathChanged) {
            lastNotifiedPath = path
            lastNotifiedHadArt = false
            lastNotifiedArt = ""
        }

        if (hasArt) {
            if (!notifyArtProc.running) {
                notifyArtProc.requestedPath = path
                notifyArtProc.command = [playerScript, "art", "notify-cache", path]
                notifyArtProc.running = true
            } else {
                notifyArtProc.pendingPath = path
            }
            return
        }
        pushMediaNotification("")
    }

    function maybeSubmitScrobble() {
        if (!player.path || scrobbleSubmitted || String(player.path) !== scrobblePath)
            return
        if (String(player.state || "") !== "playing")
            return
        if (scrobbleStartPos < 0)
            return
        var pos = Number(player.position) || 0
        if (pos < scrobbleStartPos)
            scrobbleStartPos = pos
        var listened = pos - scrobbleStartPos
        if (listened < 60)
            return
        scrobbleSubmitted = true
        var started = scrobbleStartedAt > 0
            ? scrobbleStartedAt
            : Math.floor(Date.now() / 1000 - listened)
        runScrobble(["submit", "--started", String(started)])
    }

    function runScrobble(args) {
        if (scrobbleProc.running)
            return
        scrobbleProc.command = [playerScript, "scrobble"].concat(args || [])
        scrobbleProc.running = true
    }

    function ensureMpvConnect() {
        if (mpvSocket.connected)
            return
        if (!socketCheckProc.running)
            socketCheckProc.running = true
        else
            connectRetryTimer.start()
    }

    function ensureMpv() {
        if (mpvSocket.connected)
            return
        if (!startMpvProc.running)
            startMpvProc.running = true
        ensureMpvConnect()
    }

    Socket {
        id: mpvSocket
        path: root.mpvSocketPath
        connected: false

        parser: SplitParser {
            onRead: line => root.handleMpvLine(line)
        }

        onConnectedChanged: {
            if (connected) {
                root.mpvObserveSent = false
                Qt.callLater(root.observeMpv)
            }
        }
    }

    Timer {
        id: connectRetryTimer
        interval: 150
        repeat: true
        onTriggered: root.ensureMpvConnect()
    }

    Process {
        id: socketCheckProc
        command: ["test", "-S", root.mpvSocketPath]
        onExited: function(exitCode) {
            if (exitCode === 0) {
                mpvSocket.connected = true
                connectRetryTimer.stop()
            }
        }
    }

    Process {
        id: startMpvProc
        command: [root.playerScript, "start"]
        onExited: root.ensureMpvConnect()
    }

    Process {
        id: bootstrapProc
        command: [root.playerScript, "open", "--json"]
        stdout: StdioCollector {
            onStreamFinished: root.applyStatusPayload(text)
        }
    }

    Process {
        id: enrichProc
        property string path: ""

        stdout: StdioCollector {
            onStreamFinished: {
                var requested = String(enrichProc.path || "")
                if (!requested || requested !== String(root.enrichPath || ""))
                    return
                var parsed
                try {
                    parsed = JSON.parse(String(text || "{}"))
                } catch (e) {
                    parsed = {}
                }
                root.mergePlayer(parsed)
                if (String(root.enrichQueuedPath || ""))
                    root.pumpEnrich()
            }
        }

        onExited: {
            if (String(root.enrichQueuedPath || ""))
                root.pumpEnrich()
        }
    }

    Process {
        id: notifyArtProc
        property string requestedPath: ""
        property string pendingPath: ""

        stdout: StdioCollector {
            onStreamFinished: {
                var requested = String(notifyArtProc.requestedPath || "")
                notifyArtProc.requestedPath = ""
                var cached = String(text || "").trim()
                var currentPath = String(root.player.path || "")
                if (requested && currentPath === requested)
                    root.pushMediaNotification(cached)
                if (cached && requested && root.shell
                        && typeof root.shell.playerDisplayArtReady === "function")
                    root.shell.playerDisplayArtReady(requested, cached)
                var pending = String(notifyArtProc.pendingPath || "")
                if (pending) {
                    notifyArtProc.pendingPath = ""
                    notifyArtProc.requestedPath = pending
                    notifyArtProc.command = [root.playerScript, "art", "notify-cache", pending]
                    notifyArtProc.running = true
                }
            }
        }
    }

    Process {
        id: scrobbleProc
    }

    Process {
        id: warmProc
    }

    Component.onCompleted: {
        bootstrapProc.running = true
        ensureMpv()
    }
}
