import QtQuick
import Quickshell
import Quickshell.Io
import qs.commons

Item {
    id: root

    property var shell: null

    readonly property string script: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-clipboard")

    Component.onCompleted: watchProc.running = true

    Process {
        id: watchProc
        command: ["bash", root.script, "watch"]
        onExited: restartTimer.restart()
    }

    Timer {
        id: restartTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (!watchProc.running)
                watchProc.running = true
        }
    }
}
