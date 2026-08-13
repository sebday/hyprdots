import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../../Commons"

Item {
    id: root

    property var host: null

    readonly property string themeNamePath: Quickshell.env("HOME") + "/.themes/current/.theme-name"
    readonly property string evoThemePath: Quickshell.shellDir + "/theme.json"
    readonly property string wallpaperStatePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/evo-shell/wallpaper"

    property string currentThemeName: ""
    property string currentWallpaperPath: ""
    property bool evoThemeReady: false

    function onActivated() {
        themeNameFile.reload()
        wallpaperStateFile.reload()
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
        Qt.callLater(reloadPickers)
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

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        FramedPanel {
            label: "Theme"
            Layout.fillWidth: true

            PreviewPickerGrid {
                id: themePicker
                width: parent.width
                kind: "themes"
                selectedKey: root.currentThemeName
            }
        }

        FramedPanel {
            label: "Wallpaper"
            contentFill: true
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 140

            Flickable {
                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: wallpaperPicker.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                PreviewPickerGrid {
                    id: wallpaperPicker
                    width: parent.width
                    kind: "wallpapers"
                    selectedKey: root.currentWallpaperPath
                }
            }
        }
    }
}
