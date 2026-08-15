import QtQuick
import Quickshell
import Quickshell.Io
import "../../Commons"

Item {
    id: root

    property var shell: null

    readonly property string script: Quickshell.shellDir + "/plugins/clipboard/evo-app-clipboard"

    Component.onCompleted: watchProc.running = true

    Process {
        id: watchProc
        command: ["bash", root.script, "watch"]
    }
}
