import Quickshell
import QtQuick
import "../../Commons"
import "."

Item {
    id: root

    property var shell: null
    property bool opened: false

    readonly property var dashScreen: Util.screenForOutput(
        shell && shell.barConfig ? shell.barConfig.output : "",
        "HDMI-A-1"
    )

    function close() {
        opened = false
    }

    function open() {
        if (dashScreen && dashWindow)
            dashWindow.screen = dashScreen
        opened = true
    }

    function toggle() {
        if (opened)
            close()
        else
            open()
    }

    onOpenedChanged: activatePlayer()

    Component.onCompleted: {
        if (opened)
            Qt.callLater(activatePlayer)
    }

    function activatePlayer() {
        if (!opened) {
            if (playerContent && typeof playerContent.onDeactivated === "function")
                playerContent.onDeactivated()
            return
        }
        Qt.callLater(function() {
            if (playerContent && typeof playerContent.onActivated === "function")
                playerContent.onActivated()
            keySurface.forceActiveFocus()
        })
    }

    function applyDisplayArt(trackPath, artPath) {
        if (playerContent && typeof playerContent.applyPlayerArt === "function")
            playerContent.applyPlayerArt(trackPath, artPath)
    }

    FloatingWindow {
        id: dashWindow
        visible: root.opened && root.dashScreen !== null
        title: "evo.panel.player"
        screen: root.dashScreen
        color: Theme.background
        minimumSize: Qt.size(480, 300)

        onVisibleChanged: {
            if (visible)
                Qt.callLater(function() { keySurface.forceActiveFocus() })
        }

        Item {
            id: keySurface
            anchors.fill: parent
            focus: true

            MouseArea {
                anchors.fill: parent
                propagateComposedEvents: true
                onPressed: function(mouse) {
                    keySurface.forceActiveFocus()
                    mouse.accepted = false
                }
            }

            Keys.onPressed: function(event) {
                if (playerContent.trashConfirmOpen) {
                    if (event.key === Qt.Key_Escape) {
                        playerContent.cancelTrashTrack()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        playerContent.confirmTrashTrack()
                        event.accepted = true
                    } else {
                        event.accepted = true
                    }
                    return
                }
                if (playerContent.keyShortcutsBlocked)
                    return
                if (event.key === Qt.Key_B && event.modifiers === Qt.NoModifier) {
                    playerContent.toggleMenuBar()
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_C && event.modifiers === Qt.NoModifier) {
                    playerContent.toggleCompactMode()
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_P && event.modifiers === Qt.NoModifier) {
                    playerContent.togglePlaylistPanel()
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_N && event.modifiers === Qt.NoModifier) {
                    playerContent.showNowPlaying()
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_F && event.modifiers === Qt.NoModifier) {
                    playerContent.toggleBrowsePanel()
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Space && event.modifiers === Qt.NoModifier) {
                    playerContent.togglePlayback()
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Left && event.modifiers === Qt.NoModifier) {
                    playerContent.seekBy(-10)
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Right && event.modifiers === Qt.NoModifier) {
                    playerContent.seekBy(10)
                    event.accepted = true
                    return
                }
            }

            PlayerModule {
                id: playerContent
                anchors.fill: parent
                shell: root.shell
                host: root
            }
        }
    }
}
