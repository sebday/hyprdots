import Quickshell
import QtQuick
import "../../Commons"
import "."

Item {
    id: root

    property var shell: null
    property bool opened: true

    readonly property string dashOutput: {
        if (shell && shell.shellConfig && shell.shellConfig.notifications && shell.shellConfig.notifications.output)
            return String(shell.shellConfig.notifications.output).trim()
        if (shell && shell.barConfig && shell.barConfig.output)
            return String(shell.barConfig.output).trim()
        return "HDMI-A-1"
    }

    readonly property var dashScreen: {
        var screens = Quickshell.screens
        if (!screens || screens.length === 0)
            return null
        var output = dashOutput
        if (output) {
            for (var i = 0; i < screens.length; i++) {
                if (screens[i] && String(screens[i].name) === output)
                    return screens[i]
            }
        }
        return screens[0]
    }

    function close() {
        opened = false
    }

    function open() {
        opened = true
    }

    function toggle() {
        if (opened)
            close()
        else
            open()
    }

    onOpenedChanged: activateMusic()

    function activateMusic() {
        if (!opened) {
            if (musicContent && typeof musicContent.onDeactivated === "function")
                musicContent.onDeactivated()
            return
        }
        Qt.callLater(function() {
            keySurface.forceActiveFocus()
            if (musicContent && typeof musicContent.onActivated === "function")
                musicContent.onActivated()
        })
    }

    Component.onCompleted: activateMusic()

    FloatingWindow {
        id: dashWindow
        visible: root.opened
        title: "evo.music"
        screen: root.dashScreen
        color: Theme.background
        minimumSize: Qt.size(720, 480)

        Item {
            id: keySurface
            anchors.fill: parent
            focus: root.opened

            Keys.onEscapePressed: root.close()

            MusicModule {
                id: musicContent
                anchors.fill: parent
                shell: root.shell
                host: root
            }
        }
    }
}
