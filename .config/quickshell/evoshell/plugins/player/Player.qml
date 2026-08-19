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
            keySurface.forceActiveFocus()
            if (playerContent && typeof playerContent.onActivated === "function")
                playerContent.onActivated()
        })
    }

    FloatingWindow {
        id: dashWindow
        visible: root.opened && root.dashScreen !== null
        title: "evo.player"
        screen: root.dashScreen
        color: Theme.background
        minimumSize: Qt.size(720, 480)

        Item {
            id: keySurface
            anchors.fill: parent
            focus: root.opened

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
                if (event.key === Qt.Key_H && event.modifiers === Qt.NoModifier) {
                    playerContent.toggleMenuBar()
                    event.accepted = true
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
