import QtQuick
import Quickshell
import Quickshell.Io
import "../../commons"

Item {
    id: root

    property var shell: null

    readonly property string script: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-clipboard")

    Component.onCompleted: watchProc.running = true

    Process {
        id: watchProc
        command: ["bash", root.script, "watch"]
    }
}
