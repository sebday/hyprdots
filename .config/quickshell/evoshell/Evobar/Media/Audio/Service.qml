import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../../Commons"

Item {
    id: root

    property var shell: null

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.ready && sink.audio !== null
    readonly property real level: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : false
    readonly property int percent: muted ? 0 : Math.round(level * 100)
    readonly property string displayText: {
        if (!ready) return "󰕾"
        if (muted) return "󰝟"
        return SystemVolume.icon(percent, false) + " " + percent + "%"
    }

    readonly property real stepSize: 0.05
    readonly property real maxVolume: 1.5

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    function clampVolume(v: real): real {
        return Math.max(0, Math.min(maxVolume, v))
    }

    function setVolume(v: real): string {
        if (!ready) return "not-ready"
        var clamped = clampVolume(v)
        if (clamped > 0) sink.audio.muted = false
        sink.audio.volume = clamped
        return "ok"
    }

    function step(direction: string): string {
        var dir = String(direction || "").trim().toLowerCase()
        if (dir === "up") return setVolume(level + stepSize)
        if (dir === "down") return setVolume(level - stepSize)
        return "unknown"
    }

    function stepUp(): string { return setVolume(level + stepSize) }
    function stepDown(): string { return setVolume(level - stepSize) }

    function toggleMute(): string {
        if (!ready) return "not-ready"
        sink.audio.muted = !sink.audio.muted
        return "ok"
    }

    IpcHandler {
        target: "evo.bar.media.audio"

        function stepUp(): string { return root.stepUp() }
        function stepDown(): string { return root.stepDown() }
        function toggleMute(): string { return root.toggleMute() }
        function step(arg: string): string { return root.step(arg) }
    }
}
