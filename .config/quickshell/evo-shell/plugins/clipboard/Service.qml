import QtQuick
import Quickshell.Io
import "../../Commons"

Item {
    id: root

    property var shell: null

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/evo-clipboard.sh"

    Component.onCompleted: watchProc.running = true

    Process {
        id: watchProc
        command: ["bash", root.script, "watch"]
    }
}
