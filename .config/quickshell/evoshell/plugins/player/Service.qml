import QtQuick
import Quickshell
import Quickshell.Io
import "../../Commons"

Item {
    id: root

    property var shell: null
    property var player: ({})
    property string lastNotifiedPath: ""
    property string scrobblePath: ""
    property bool scrobbleSubmitted: false

    readonly property string playerScript: (Quickshell.env("HOME") || "") + "/.local/bin/evo-player"

    function notifyNowPlaying() {
        if (!shell)
            return
        var path = String(player.path || "")
        if (!path || path === lastNotifiedPath)
            return
        var notif = shell.serviceFor("evo.notifications")
        if (!notif || typeof notif.showMedia !== "function")
            return
        var ok = notif.showMedia({
            app: "evo.player",
            title: String(player.title || "Unknown"),
            artist: String(player.artist || ""),
            art: String(player.art || ""),
            path: path
        })
        if (!ok)
            return
        lastNotifiedPath = path
        runScrobble(["nowplaying"])
        scrobblePath = path
        scrobbleSubmitted = false
    }

    function maybeSubmitScrobble() {
        if (!player.path || scrobbleSubmitted || String(player.path) !== scrobblePath)
            return
        if (String(player.state || "") !== "playing")
            return
        var dur = Number(player.duration) || 0
        var pos = Number(player.position) || 0
        if (dur <= 0)
            return
        var threshold = Math.min(dur * 0.1, 30)
        if (pos < threshold)
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
        else if (!path || state === "stopped")
            lastNotifiedPath = ""
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
        id: scrobbleProc
    }

    Component.onCompleted: Qt.callLater(pollStatus)
}
