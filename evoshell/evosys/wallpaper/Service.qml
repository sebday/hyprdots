import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../../commons"

Item {
    id: root

    property var shell: null

    readonly property string home: Quickshell.env("HOME")
    readonly property string statePath: Util.statePath(home, "wallpaper")
    readonly property string themeJsonPath: Util.statePath(home, "theme.json")
    readonly property string wallpapersDir: home + "/.themes/current/wallpapers"
    readonly property int wallpaperFadeMs: 480

    property string currentWallpaper: ""
    property string displayedWallpaper: ""
    property string queuedWrite: ""
    property bool wallpaperSkipFade: false
    property color backdropColor: Theme.background

    function syncBackdropFromToml() {
        var text = String(currentColorsFile.text() || "")
        if (!text)
            return
        var match = text.match(/^\s*background\s*=\s*"([^"]+)"/m)
        if (match && match[1])
            backdropColor = match[1]
    }

    function syncBackdropColor() {
        var text = String(themeJsonFile.text() || "").trim()
        if (text) {
            try {
                var data = JSON.parse(text)
                if (data.background) {
                    backdropColor = data.background
                    return
                }
            } catch (e) {
            }
        }
        syncBackdropFromToml()
    }

    function isWallpaperPath(path) {
        path = String(path || "").trim()
        return path.length > 0 && path.charAt(0) === "/"
    }

    function bootstrapWallpaper(path) {
        path = String(path || "").trim()
        if (!isWallpaperPath(path))
            return false
        setWallpaper(path, true)
        return true
    }

    FileView {
        id: themeJsonFile
        path: root.themeJsonPath
        watchChanges: true
        printErrors: false
        onLoaded: root.syncBackdropColor()
        onFileChanged: reload()
    }

    FileView {
        id: currentColorsFile
        path: home + "/.themes/current/colors.toml"
        watchChanges: true
        printErrors: false
        onLoaded: root.syncBackdropColor()
        onFileChanged: reload()
    }

    FileView {
        id: wallpaperStateFile
        path: root.statePath
        watchChanges: true
        printErrors: false
        onLoaded: {
            var path = String(wallpaperStateFile.text() || "").trim()
            if (isWallpaperPath(path) && path !== root.displayedWallpaper)
                root.bootstrapWallpaper(path)
        }
        onFileChanged: reload()
    }

    readonly property string defaultWallpaperCommand: [
        "dir=" + Util.shellQuote(wallpapersDir),
        "find \"$dir\" -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\) 2>/dev/null | sort | head -n1"
    ].join("\n")

    readonly property string wallpaperScript: Util.evoshellScript(home, shell, "evo-wallpaper")

    function imageUrl(path) {
        return Util.fileUrl(path)
    }

    function refreshWallpaper() {
        if (!readStateProc.running) readStateProc.running = true
    }

    function setWallpaper(path, instant) {
        path = String(path || "").trim()
        if (!isWallpaperPath(path)) return
        if (path === currentWallpaper && path === displayedWallpaper) return
        currentWallpaper = path
        wallpaperSkipFade = instant || !displayedWallpaper
        displayedWallpaper = path
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
        cycleProc.command = [wallpaperScript, step]
        cycleProc.running = true
    }

    Process {
        id: readStateProc
        command: ["bash", "-c",
            "state=" + Util.shellQuote(root.statePath) + "\n" +
            "dir=" + Util.shellQuote(root.wallpapersDir) + "\n" +
            "if [[ -f \"$state\" ]]; then\n" +
            "  path=\"$(cat \"$state\")\"\n" +
            "  if [[ -f \"$path\" ]]; then printf '%s' \"$path\"; exit 0; fi\n" +
            "  candidate=\"$dir/$(basename \"$path\")\"\n" +
            "  [[ -f \"$candidate\" ]] && printf '%s' \"$candidate\" && exit 0\n" +
            "fi\n" +
            root.defaultWallpaperCommand]
        stdout: StdioCollector {
            onStreamFinished: {
                var path = String(text || "").trim()
                if (path) root.setWallpaper(path, !root.displayedWallpaper)
            }
        }
    }

    Process {
        id: writeStateProc
        onExited: root.flushStateWrite()
    }

    Process {
        id: cycleProc
    }

    IpcHandler {
        target: "evo.sys.wallpaper"

        function refresh(): void { root.refreshWallpaper() }
        function set(path: string): void { root.setWallpaper(path, false) }
        function setInstant(path: string): void { root.setWallpaper(path, true) }
        function next(): string { root.cycleWallpapers("next"); return "ok" }
        function prev(): string { root.cycleWallpapers("prev"); return "ok" }
    }

    Component.onCompleted: {
        syncBackdropColor()
        var path = String(wallpaperStateFile.text() || "").trim()
        if (!bootstrapWallpaper(path))
            refreshWallpaper()
    }

    component WallpaperLayer: Item {
        id: layer
        anchors.fill: parent

        readonly property string imagePath: root.displayedWallpaper
        readonly property int fadeMs: root.wallpaperFadeMs
        readonly property color fillColor: root.backdropColor

        property string basePath: ""
        property string overlayPath: ""
        property bool crossfading: false

        Rectangle {
            anchors.fill: parent
            color: layer.fillColor
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
            function onDisplayedWallpaperChanged() {
                layer.applyPath(root.displayedWallpaper, root.wallpaperSkipFade)
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
            color: root.backdropColor
            aboveWindows: false
            WlrLayershell.namespace: "evo-sys-wallpaper"
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            WallpaperLayer {}
        }
    }
}
