import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    readonly property int tileWidth: 192
    readonly property int tileHeight: 124
    readonly property int tileGap: 10
    readonly property string themeNamePath: Quickshell.env("HOME") + "/.themes/current/.theme-name"
    readonly property string evoThemePath: Quickshell.shellDir + "/theme.json"
    readonly property string wallpaperStatePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/evo-shell/wallpaper"

    property string currentThemeName: ""
    property string currentWallpaperPath: ""
    property bool evoThemeReady: false

    function onActivated() {
        themeNameFile.reload()
        wallpaperStateFile.reload()
        if (themePicker.entries.length === 0 || wallpaperPicker.entries.length === 0)
            Qt.callLater(reloadPickers)
    }

    function reloadPickers() {
        Qt.callLater(function() {
            themePicker.reload()
            wallpaperPicker.reload()
        })
    }

    function applyThemeState() {
        themeNameFile.reload()
        wallpaperStateFile.reload()
        Qt.callLater(function() {
            wallpaperPicker.reload()
        })
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

    readonly property int legendPad: 10
    implicitHeight: column.implicitHeight + legendPad

    ColumnLayout {
        id: column
        y: root.legendPad
        width: parent.width
        spacing: 16

        FramedPanel {
            label: "Theme"
            Layout.fillWidth: true

            PreviewPickerGrid {
                id: themePicker
                width: parent.width
                kind: "themes"
                tileWidth: root.tileWidth
                tileHeight: root.tileHeight
                spacing: root.tileGap
                selectedKey: root.currentThemeName
            }
        }

        FramedPanel {
            label: "Wallpaper"
            Layout.fillWidth: true

            PreviewPickerGrid {
                id: wallpaperPicker
                width: parent.width
                kind: "wallpapers"
                tileWidth: root.tileWidth
                tileHeight: root.tileHeight
                spacing: root.tileGap
                selectedKey: root.currentWallpaperPath
            }
        }
    }
}
