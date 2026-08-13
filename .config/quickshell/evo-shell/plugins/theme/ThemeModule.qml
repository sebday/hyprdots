import Quickshell
import Quickshell.Io
import QtQuick
import "../../Commons"

Item {
    id: root

    property string kind: "themes"

    readonly property int tileWidth: 288
    readonly property int tileHeight: 186
    readonly property int tileGap: 10
    readonly property string themeNamePath: Quickshell.env("HOME") + "/.themes/current/.theme-name"
    readonly property string evoThemePath: Quickshell.shellDir + "/theme.json"
    readonly property string wallpaperStatePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/evo-shell/wallpaper"
    readonly property bool isWallpaper: kind === "wallpapers"

    property string currentThemeName: ""
    property string currentWallpaperPath: ""
    property bool evoThemeReady: false

    signal cursorMoved()
    signal picked()

    function onActivated() {
        themeNameFile.reload()
        wallpaperStateFile.reload()
        if (picker.entries.length === 0)
            Qt.callLater(picker.reload)
        else
            picker.syncCursorToSelected()
    }

    function applyThemeState() {
        themeNameFile.reload()
        wallpaperStateFile.reload()
        if (isWallpaper)
            Qt.callLater(picker.reload)
    }

    FileView {
        id: themeNameFile
        path: root.themeNamePath
        watchChanges: true
        printErrors: false
        onLoaded: root.currentThemeName = String(themeNameFile.text() || "").trim()
        onFileChanged: reload()
    }

    FileView {
        id: evoThemeFile
        path: root.evoThemePath
        watchChanges: true
        printErrors: false
        onLoaded: {
            if (!root.evoThemeReady) {
                root.evoThemeReady = true
                return
            }
            wallpaperRefreshTimer.restart()
        }
        onFileChanged: reload()
    }

    Timer {
        id: wallpaperRefreshTimer
        interval: 200
        repeat: false
        onTriggered: root.applyThemeState()
    }

    FileView {
        id: wallpaperStateFile
        path: root.wallpaperStatePath
        watchChanges: true
        printErrors: false
        onLoaded: root.currentWallpaperPath = String(wallpaperStateFile.text() || "").trim()
        onFileChanged: reload()
    }

    function handleMove(dx, dy) {
        if (picker.moveCursor(dx, dy)) {
            cursorMoved()
            return
        }
        var n = picker.entries.length
        if (n <= 0) return
        var cols = Math.max(1, picker.columns)
        if (dx !== 0) {
            picker.cursorIndex = (picker.cursorIndex + dx + n) % n
            cursorMoved()
            return
        }
        if (dy === 0) return
        var col = picker.cursorIndex % cols
        if (dy > 0) {
            picker.cursorIndex = Math.min(col, n - 1)
        } else {
            var lastRow = Math.max(0, Math.ceil(n / cols) - 1)
            var idx = lastRow * cols + col
            if (idx >= n) idx = n - 1
            picker.cursorIndex = idx
        }
        cursorMoved()
    }

    function handleActivate() {
        picker.activateCursor()
    }

    function cursorY() {
        return picker.mapToItem(root, 0, picker.cursorRowY()).y
    }

    Keys.onLeftPressed: handleMove(-1, 0)
    Keys.onRightPressed: handleMove(1, 0)
    Keys.onUpPressed: handleMove(0, -1)
    Keys.onDownPressed: handleMove(0, 1)
    Keys.onReturnPressed: handleActivate()
    Keys.onEnterPressed: handleActivate()

    implicitWidth: picker.implicitWidth
    implicitHeight: picker.implicitHeight

    PreviewPickerGrid {
        id: picker
        width: implicitWidth
        kind: root.isWallpaper ? "wallpapers" : "themes"
        tileWidth: root.tileWidth
        tileHeight: root.tileHeight
        spacing: root.tileGap
        selectedKey: root.isWallpaper ? root.currentWallpaperPath : root.currentThemeName
        keyboardFocus: true
        onActivated: root.picked()
    }
}
