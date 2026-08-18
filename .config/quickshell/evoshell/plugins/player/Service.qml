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

    readonly property string playerScript: (Quickshell.env("HOME") || "") + "/.local/bin/evo-player"

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
        var pathChanged = path !== lastNotifiedPath
        notif.showMedia({
            app: "evo.player",
            title: String(player.title || "Unknown"),
            artist: String(player.artist || ""),
            art: art,
            path: path
        })
        if (pathChanged) {
            runScrobble(["nowplaying"])
            scrobblePath = path
            scrobbleSubmitted = false
        } else if (needsArtUpdate) {
            runScrobble(["touch"])
        }
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
        var pathChanged = path !== lastNotifiedPath
        var needsArtUpdate = path === lastNotifiedPath && hasArt && !lastNotifiedHadArt
        if (!pathChanged && !needsArtUpdate)
            return
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
        var pos = Number(player.position) || 0
        if (pos < 60)
            return
        scrobbleSubmitted = true
        runScrobble(["submit"])
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
        player = parsed
        var path = String(player.path || "")
        var state = String(player.state || "")
        if (path && state === "playing")
            notifyNowPlaying()
        else if (!path || state === "stopped") {
            lastNotifiedPath = ""
            lastNotifiedHadArt = false
            lastNotifiedArt = ""
        }
        maybeSubmitScrobble()
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

    Component.onCompleted: Qt.callLater(pollStatus)
}
