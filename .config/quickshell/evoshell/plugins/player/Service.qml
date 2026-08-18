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
        var notif = shell.serviceFor("evo.notifications")
        if (!notif || typeof notif.showMedia !== "function")
            return
        var needsArtUpdate = path === lastNotifiedPath && art !== "" && !lastNotifiedHadArt
        notif.showMedia({
            app: "evo.player",
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
                notifyArtProc.command = [playerScript, "art", "notify-cache", path]
                notifyArtProc.running = true
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

    function applyStatus(text) {
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
        player = parsed
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

    function pollStatus() {
        if (statusProc.running)
            return
        statusProc.command = [playerScript, "status", "--json"]
        statusProc.running = true
    }

    Timer {
        id: statusTimer
        interval: 500
        repeat: true
        running: true
        onTriggered: root.pollStatus()
    }

    Process {
        id: statusProc
        stdout: StdioCollector {
            onStreamFinished: root.applyStatus(text)
        }
    }

    Process {
        id: notifyArtProc
        stdout: StdioCollector {
            onStreamFinished: {
                var cached = String(text || "").trim()
                root.pushMediaNotification(cached)
            }
        }
    }

    Process {
        id: scrobbleProc
    }

    Process {
        id: warmProc
    }

    Component.onCompleted: Qt.callLater(pollStatus)
}
