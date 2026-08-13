import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../../Commons"

Item {
    id: root

    property var shell: null

    readonly property string home: Quickshell.env("HOME")
    readonly property string statePath: home + "/.local/state/evo-shell/wallpaper"
    readonly property string themeNamePath: home + "/.themes/current/.theme-name"
    readonly property int wallpaperFadeMs: 480

    property string currentBackground: ""
    property string displayedBackground: ""
    property string queuedWrite: ""
    property bool wallpaperSkipFade: false

    readonly property string defaultWallpaperCommand: [
        "dir=" + Util.shellQuote(home + "/.themes/current/backgrounds"),
        "find \"$dir\" -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\) 2>/dev/null | sort | head -n1"
    ].join("\n")

    readonly property string cycleScriptBody: [
        "dir=\"$HOME/.themes/current/backgrounds\"",
        "state=\"" + statePath + "\"",
        "if [[ ! -d \"$dir\" ]]; then exit 1; fi",
        "mapfile -d '' files < <(find \"$dir\" -type f -print0 | sort -z)",
        "[[ ${#files[@]} -eq 0 ]] && exit 1",
        "cur=\"\"",
        "[[ -f \"$state\" ]] && cur=\"$(cat \"$state\")\"",
        "idx=-1",
        "for i in \"${!files[@]}\"; do [[ \"${files[$i]}\" == \"$cur\" ]] && idx=$i; done",
        "if [[ \"$1\" == \"next\" ]]; then",
        "  idx=$(( (idx + 1) % ${#files[@]} ))",
        "else",
        "  idx=$(( (idx - 1 + ${#files[@]}) % ${#files[@]} ))",
        "fi",
        "echo \"${files[$idx]}\""
    ].join("\n")

    function imageUrl(path) {
        return Util.fileUrl(path)
    }

    function refreshBackground() {
        if (!readStateProc.running) readStateProc.running = true
    }

    function setBackground(path, instant) {
        path = String(path || "").trim()
        if (!path) return
        if (path === currentBackground && path === displayedBackground) return
        currentBackground = path
        wallpaperSkipFade = instant || !displayedBackground
        displayedBackground = path
        persistState(path)
        if (wallpaperSkipFade)
            Qt.callLater(function() { root.wallpaperSkipFade = false })
    }

    function persistState(path) {
        queuedWrite = path
        flushStateWrite()
    }

    function flushStateWrite() {
        if (writeStateProc.running || !queuedWrite) return
        var path = queuedWrite
        queuedWrite = ""
        writeStateProc.command = ["bash", "-c",
            "mkdir -p \"$(dirname " + Util.shellQuote(statePath) + ")\" && printf '%s' " + Util.shellQuote(path) + " > " + Util.shellQuote(statePath)]
        writeStateProc.running = true
    }

    function cycleWallpapers(direction) {
        var step = String(direction) === "prev" ? "prev" : "next"
        if (cycleProc.running)
            cycleProc.running = false
        cycleProc.command = ["bash", "-c", cycleScriptBody, "evo-bg-cycle", step]
        cycleProc.running = true
    }

    Process {
        id: readStateProc
        command: ["bash", "-c",
            "if [[ -f " + Util.shellQuote(root.statePath) + " ]]; then cat " + Util.shellQuote(root.statePath) + "; else " + root.defaultWallpaperCommand + "; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var path = String(text || "").trim()
                if (path) root.setBackground(path, !root.displayedBackground)
            }
        }
    }

    Process {
        id: writeStateProc
        onExited: root.flushStateWrite()
    }

    Process {
        id: cycleProc
        stdout: StdioCollector {
            onStreamFinished: {
                var path = String(text || "").trim()
                if (path) root.setBackground(path, false)
            }
        }
    }

    IpcHandler {
        target: "evo.background"

        function refresh(): void { root.refreshBackground() }
        function set(path: string): void { root.setBackground(path, false) }
        function setInstant(path: string): void { root.setBackground(path, true) }
        function next(): string { root.cycleWallpapers("next"); return "ok" }
        function prev(): string { root.cycleWallpapers("prev"); return "ok" }
    }

    Component.onCompleted: refreshBackground()

    component WallpaperLayer: Item {
        id: layer
        anchors.fill: parent

        readonly property string imagePath: root.displayedBackground
        readonly property int fadeMs: root.wallpaperFadeMs

        property string basePath: ""
        property string overlayPath: ""
        property bool crossfading: false

        Rectangle {
            anchors.fill: parent
            color: Theme.background
        }

        Image {
            id: baseWallpaper
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            mipmap: true
            source: basePath ? root.imageUrl(basePath) : ""
        }

        Image {
            id: overlayWallpaper
            anchors.fill: parent
            opacity: 0
            visible: opacity > 0 || crossfading
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            mipmap: true
            source: overlayPath ? root.imageUrl(overlayPath) : ""
            onStatusChanged: {
                if (layer.crossfading && status === Image.Ready && !crossfade.running)
                    crossfade.start()
            }
        }

        NumberAnimation {
            id: crossfade
            target: overlayWallpaper
            property: "opacity"
            from: 0
            to: 1
            duration: layer.fadeMs
            easing.type: Easing.InOutQuad
            onFinished: {
                basePath = overlayPath
                overlayWallpaper.opacity = 0
                crossfading = false
            }
        }

        function applyPath(path, instant) {
            path = String(path || "").trim()
            if (!path) return
            if (!basePath || instant || path === basePath) {
                crossfade.stop()
                crossfading = false
                overlayWallpaper.opacity = 0
                overlayPath = ""
                basePath = path
                return
            }
            if (path === overlayPath && crossfading) return
            overlayPath = path
            crossfading = true
            overlayWallpaper.opacity = 0
            if (overlayWallpaper.status === Image.Ready)
                crossfade.start()
        }

        Connections {
            target: root
            function onDisplayedBackgroundChanged() {
                layer.applyPath(root.displayedBackground, root.wallpaperSkipFade)
            }
        }

        Component.onCompleted: applyPath(imagePath, true)
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: true
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            aboveWindows: false
            WlrLayershell.namespace: "evo-background"
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            WallpaperLayer {}
        }
    }
}
